use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    fs::{self, OpenOptions},
    os::unix::fs::{OpenOptionsExt, PermissionsExt},
    path::PathBuf,
    sync::{Arc, Mutex},
    time::{SystemTime, UNIX_EPOCH},
};
use zbus::{object_server::SignalEmitter, zvariant::OwnedValue};

const MAX_HISTORY: usize = 100;

#[derive(Clone, Serialize, Deserialize)]
struct Entry {
    id: u32,
    app: String,
    summary: String,
    body: String,
    #[serde(default)]
    actions: Vec<Action>,
    timestamp: u64,
}

#[derive(Clone, Serialize, Deserialize)]
struct Action {
    key: String,
    label: String,
}

fn parse_actions(raw: &[String]) -> Vec<Action> {
    raw.chunks_exact(2)
        .filter(|pair| !pair[0].is_empty())
        .map(|pair| Action { key: pair[0].clone(), label: pair[1].clone() })
        .collect()
}

#[derive(Default, Serialize, Deserialize)]
struct State {
    next_id: u32,
    history: Vec<Entry>,
    #[serde(skip)]
    path: Option<PathBuf>,
}

impl State {
    fn load(path: PathBuf) -> Self {
        let mut state: Self = match fs::read(&path) {
            Ok(contents) => serde_json::from_slice(&contents).unwrap_or_default(),
            Err(err) if err.kind() == std::io::ErrorKind::NotFound => Self::default(),
            Err(err) => {
                eprintln!("lumen: cannot read notification history: {err}");
                Self::default()
            }
        };
        state.history.truncate(MAX_HISTORY);
        // The notification's original client is no longer connected after a restart.
        for entry in &mut state.history {
            entry.actions.clear();
            state.next_id = state.next_id.max(entry.id);
        }
        state.path = Some(path);
        state
    }

    fn persist(&self) {
        if let Some(path) = &self.path {
            if let Err(err) = self.write_to(path) {
                eprintln!("lumen: cannot save notification history: {err}");
            }
        }
    }

    fn write_to(&self, path: &PathBuf) -> std::io::Result<()> {
        let parent = path.parent().expect("history path has parent");
        fs::create_dir_all(parent)?;
        fs::set_permissions(parent, fs::Permissions::from_mode(0o700))?;
        let temp = parent.join(format!("notifications-{}.tmp", uuid::Uuid::new_v4()));
        let result = (|| {
            use std::io::Write;
            let mut file = OpenOptions::new().write(true).create_new(true).mode(0o600).open(&temp)?;
            serde_json::to_writer(&mut file, self)?;
            file.flush()?;
            file.sync_all()?;
            fs::rename(&temp, path)
        })();
        if result.is_err() {
            let _ = fs::remove_file(temp);
        }
        result
    }
}

pub struct Notifications(Arc<Mutex<State>>);
pub struct History(Arc<Mutex<State>>);

impl Notifications {
    pub fn new() -> (Self, History) {
        let base = std::env::var_os("XDG_STATE_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|home| PathBuf::from(home).join(".local/state")));
        let state = base.map(|base| State::load(base.join("lumen/notifications.json")))
            .unwrap_or_default();
        Self::from_state(state)
    }

    fn from_state(state: State) -> (Self, History) {
        let state = Arc::new(Mutex::new(state));
        (Self(state.clone()), History(state))
    }

    fn insert(&self, app: &str, replaces: u32, summary: &str, body: &str, actions: &[String]) -> u32 {
        let mut state = self.0.lock().unwrap();
        let id = if replaces != 0 && state.history.iter().any(|item| item.id == replaces) {
            replaces
        } else {
            state.next_id = state.next_id.wrapping_add(1).max(1);
            state.next_id
        };
        state.history.retain(|item| item.id != id);
        state.history.insert(
            0,
            Entry {
                id,
                app: app.to_owned(),
                summary: summary.to_owned(),
                body: body.to_owned(),
                actions: parse_actions(actions),
                timestamp: SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs(),
            },
        );
        state.history.truncate(MAX_HISTORY);
        state.persist();
        id
    }

    fn remove(&self, id: u32) -> bool {
        let mut state = self.0.lock().unwrap();
        let length = state.history.len();
        state.history.retain(|item| item.id != id);
        if state.history.len() != length {
            state.persist();
            true
        } else {
            false
        }
    }

    fn has_action(&self, id: u32, key: &str) -> bool {
        self.0.lock().unwrap().history.iter().any(|entry|
            entry.id == id && entry.actions.iter().any(|action| action.key == key))
    }
}

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl Notifications {
    fn get_capabilities(&self) -> Vec<&'static str> {
        vec!["body", "actions"]
    }

    fn get_server_information(&self) -> (&'static str, &'static str, &'static str, &'static str) {
        ("Lumen", "Lumen", env!("CARGO_PKG_VERSION"), "1.2")
    }

    async fn notify(
        &self,
        app_name: &str,
        replaces_id: u32,
        _app_icon: &str,
        summary: &str,
        body: &str,
        actions: Vec<String>,
        _hints: HashMap<String, OwnedValue>,
        _expire_timeout: i32,
    ) -> u32 {
        self.insert(app_name, replaces_id, summary, body, &actions)
    }

    async fn close_notification(&self, id: u32, #[zbus(signal_emitter)] emitter: SignalEmitter<'_>) {
        if self.remove(id) {
            let _ = Self::notification_closed(&emitter, id, 3).await;
        }
    }

    #[zbus(signal)]
    async fn notification_closed(
        emitter: &SignalEmitter<'_>,
        id: u32,
        reason: u32,
    ) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn action_invoked(
        emitter: &SignalEmitter<'_>,
        id: u32,
        action_key: &str,
    ) -> zbus::Result<()>;
}

#[zbus::interface(name = "org.lumen.Notifications")]
impl History {
    fn get_history(&self) -> String {
        serde_json::to_string(&self.0.lock().unwrap().history).unwrap_or_else(|_| "[]".into())
    }

    async fn dismiss(&self, id: u32, #[zbus(connection)] conn: &zbus::Connection) -> bool {
        if Notifications(self.0.clone()).remove(id) {
            if let Ok(emitter) = SignalEmitter::new(conn, "/org/freedesktop/Notifications") {
                let _ = Notifications::notification_closed(&emitter, id, 2).await;
            }
            true
        } else {
            false
        }
    }

    async fn invoke_action(
        &self,
        id: u32,
        key: &str,
        #[zbus(connection)] conn: &zbus::Connection,
    ) -> bool {
        let notifications = Notifications(self.0.clone());
        if !notifications.has_action(id, key) {
            return false;
        }
        if let Ok(emitter) = SignalEmitter::new(conn, "/org/freedesktop/Notifications") {
            let _ = Notifications::action_invoked(&emitter, id, key).await;
            if notifications.remove(id) {
                let _ = Notifications::notification_closed(&emitter, id, 2).await;
            }
        }
        true
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn history_replaces_dismisses_and_bounds() {
        let (service, _) = Notifications::from_state(State::default());
        let first = service.insert("test", 0, "old", "body", &[]);
        assert_eq!(first, service.insert("test", first, "new", "body", &["open".into(), "Open".into()]));
        assert_eq!(service.0.lock().unwrap().history.len(), 1);
        assert_eq!(service.0.lock().unwrap().history[0].summary, "new");
        assert!(service.has_action(first, "open"));
        assert!(!service.has_action(first, "unknown"));
        assert!(service.remove(first));
        assert!(!service.remove(first));
        for _ in 0..150 {
            service.insert("test", 0, "test", "", &[]);
        }
        assert_eq!(service.0.lock().unwrap().history.len(), MAX_HISTORY);
    }

    #[test]
    fn actions_are_pairs_and_ignore_incomplete_trailing_key() {
        let actions = parse_actions(&["yes".into(), "Yes".into(), "orphan".into()]);
        assert_eq!(actions.len(), 1);
        assert_eq!(actions[0].key, "yes");
        assert_eq!(actions[0].label, "Yes");
    }

    #[test]
    fn history_survives_restart_but_actions_do_not() {
        let dir = std::env::temp_dir().join(format!("lumen-test-{}", uuid::Uuid::new_v4()));
        let path = dir.join("notifications.json");
        let (service, _) = Notifications::from_state(State::load(path.clone()));
        let id = service.insert("test", 0, "persist", "body", &["open".into(), "Open".into()]);
        let loaded = State::load(path.clone());
        assert_eq!(loaded.history[0].summary, "persist");
        assert!(loaded.history[0].actions.is_empty());
        assert_eq!(loaded.next_id, id);
        assert_eq!(fs::metadata(&path).unwrap().permissions().mode() & 0o777, 0o600);
        assert_eq!(fs::metadata(&dir).unwrap().permissions().mode() & 0o777, 0o700);
        fs::remove_file(path).unwrap();
        fs::remove_dir(dir).unwrap();
    }
}
