use serde::Deserialize;
use std::{
    collections::HashMap,
    fs,
    path::PathBuf,
    sync::Mutex,
    time::{Duration, Instant},
};
use zbus::{fdo::DBusProxy, message::Header, names::BusName, Connection};

#[derive(Deserialize, Clone)]
#[serde(default, deny_unknown_fields)]
pub struct ChallengeConfig {
    pub timeout_secs: u64,
    pub deny_policy: String,
}
impl Default for ChallengeConfig {
    fn default() -> Self {
        Self {
            timeout_secs: 900,
            deny_policy: "cancel_all".into(),
        }
    }
}
#[derive(Deserialize, Clone)]
#[serde(default, deny_unknown_fields)]
pub struct Channel {
    pub enabled: bool,
    pub mode: String,
}
impl Default for Channel {
    fn default() -> Self {
        Self {
            enabled: true,
            mode: "password".into(),
        }
    }
}
#[derive(Deserialize, Default)]
#[serde(default, deny_unknown_fields)]
struct Channels {
    tty: Channel,
    gui: Channel,
    device: Vec<Device>,
}
#[derive(Deserialize, Default)]
#[serde(default, deny_unknown_fields)]
struct Device {
    id: String,
    enabled: bool,
    mode: String,
}
#[derive(Deserialize, Default)]
#[serde(default, deny_unknown_fields)]
pub struct Config {
    challenge: ChallengeConfig,
    channels: Channels,
}
impl Config {
    pub fn load() -> Result<Self, Box<dyn std::error::Error>> {
        let base = std::env::var_os("XDG_CONFIG_HOME")
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join(".config")))
            .ok_or("no config directory")?;
        let text = match fs::read_to_string(base.join("lumen/auth.toml")) {
            Ok(text) => text,
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => String::new(),
            Err(e) => return Err(e.into()),
        };
        let config: Self = toml::from_str(&text)?;
        if config.challenge.timeout_secs == 0
            || !["cancel_all", "wait_others"].contains(&config.challenge.deny_policy.as_str())
        {
            return Err("invalid challenge timeout or deny_policy".into());
        }
        for channel in [&config.channels.tty, &config.channels.gui] {
            if channel.enabled && channel.mode != "password" {
                return Err("only password mode is implemented for tty/gui".into());
            }
        }
        for d in &config.channels.device {
            if d.id.is_empty() || !["password", "approve_only", "totp"].contains(&d.mode.as_str()) {
                return Err("invalid device stub".into());
            }
            // Device transport is intentionally not active in Phase 1.
            let _ = d.enabled;
        }
        Ok(config)
    }
}

struct Challenge {
    owner: String,
    prompt: String,
    expires: Instant,
    tty: bool,
    gui: bool,
    tty_denied: bool,
    gui_denied: bool,
    result: Option<(String, String)>,
}
#[derive(Default)]
struct State {
    challenges: HashMap<String, Challenge>,
    gui_seen: Option<Instant>,
}
pub struct Auth {
    state: Mutex<State>,
    config: Config,
}
impl Auth {
    pub fn new(config: Config) -> Self {
        Self {
            state: Mutex::new(State::default()),
            config,
        }
    }
    async fn peer(conn: &Connection, header: &Header<'_>) -> zbus::fdo::Result<String> {
        let sender = header
            .sender()
            .ok_or(zbus::fdo::Error::AccessDenied("missing sender".into()))?;
        let uid = DBusProxy::new(conn)
            .await
            .map_err(|_| zbus::fdo::Error::Failed("bus unavailable".into()))?
            .get_connection_unix_user(BusName::from(sender.clone()))
            .await
            .map_err(|_| zbus::fdo::Error::AccessDenied("unknown peer".into()))?;
        if uid != unsafe { libc::geteuid() } {
            return Err(zbus::fdo::Error::AccessDenied("wrong UID".into()));
        }
        Ok(sender.to_string())
    }
    fn clean(state: &mut State) {
        state.challenges.retain(|_, c| c.expires > Instant::now());
    }
}

#[zbus::interface(name = "org.lumen.Auth")]
impl Auth {
    async fn begin(
        &self,
        prompt: &str,
        has_tty: bool,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
    ) -> zbus::fdo::Result<String> {
        let owner = Self::peer(conn, &header).await?;
        if prompt.len() > 2048 {
            return Err(zbus::fdo::Error::InvalidArgs("prompt too long".into()));
        }
        let mut state = self.state.lock().unwrap();
        Self::clean(&mut state);
        if state.challenges.len() >= 64 {
            return Err(zbus::fdo::Error::LimitsExceeded(
                "too many active challenges".into(),
            ));
        }
        let gui = self.config.channels.gui.enabled
            && state
                .gui_seen
                .is_some_and(|t| t.elapsed() < Duration::from_secs(5));
        let tty = has_tty && self.config.channels.tty.enabled;
        if !tty && !gui {
            return Err(zbus::fdo::Error::Failed(
                "no healthy authentication channel".into(),
            ));
        }
        let id = uuid::Uuid::new_v4().to_string();
        state.challenges.insert(
            id.clone(),
            Challenge {
                owner,
                prompt: prompt.into(),
                expires: Instant::now() + Duration::from_secs(self.config.challenge.timeout_secs),
                tty,
                gui,
                tty_denied: false,
                gui_denied: false,
                result: None,
            },
        );
        Ok(id)
    }
    // Result is returned once to the creating D-Bus connection only.
    async fn result(
        &self,
        id: &str,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
    ) -> zbus::fdo::Result<(String, String)> {
        let sender = Self::peer(conn, &header).await?;
        let mut state = self.state.lock().unwrap();
        let gui_healthy = state
            .gui_seen
            .is_some_and(|t| t.elapsed() < Duration::from_secs(5));
        let c = state.challenges.get(id).ok_or(zbus::fdo::Error::Failed(
            "unknown or expired challenge".into(),
        ))?;
        if c.owner != sender {
            return Err(zbus::fdo::Error::AccessDenied("not challenge owner".into()));
        }
        if c.expires <= Instant::now() {
            state.challenges.remove(id);
            return Ok(("timeout".into(), String::new()));
        }
        if c.result.is_none()
            && (!c.tty || c.tty_denied)
            && (!c.gui || c.gui_denied || !gui_healthy)
        {
            state.challenges.remove(id);
            return Ok(("denied".into(), String::new()));
        }
        if c.result.is_some() {
            return Ok(state.challenges.remove(id).unwrap().result.unwrap());
        }
        Ok(("pending".into(), String::new()))
    }
    async fn cancel(
        &self,
        id: &str,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
    ) -> zbus::fdo::Result<()> {
        let sender = Self::peer(conn, &header).await?;
        let mut state = self.state.lock().unwrap();
        if state.challenges.get(id).is_some_and(|c| c.owner == sender) {
            state.challenges.remove(id);
        }
        Ok(())
    }
    // Quickshell helper calls this once per second. Pending challenges are not sent to offline GUI.
    async fn gui_next(
        &self,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
    ) -> zbus::fdo::Result<(String, String)> {
        Self::peer(conn, &header).await?;
        let mut state = self.state.lock().unwrap();
        state.gui_seen = Some(Instant::now());
        Self::clean(&mut state);
        Ok(state
            .challenges
            .iter()
            .find(|(_, c)| c.gui && !c.gui_denied && c.result.is_none())
            .map(|(id, c)| (id.clone(), c.prompt.clone()))
            .unwrap_or_default())
    }
    async fn submit(
        &self,
        id: &str,
        channel: &str,
        secret: &str,
        deny: bool,
        #[zbus(connection)] conn: &Connection,
        #[zbus(header)] header: Header<'_>,
    ) -> zbus::fdo::Result<bool> {
        let sender = Self::peer(conn, &header).await?;
        let mut state = self.state.lock().unwrap();
        let gui_healthy = state
            .gui_seen
            .is_some_and(|t| t.elapsed() < Duration::from_secs(5));
        let Some(c) = state.challenges.get_mut(id) else {
            return Ok(false);
        };
        if c.expires <= Instant::now() || c.result.is_some() {
            return Ok(false);
        }
        let valid = match channel {
            "tty" => c.tty && !c.tty_denied && c.owner == sender,
            "gui" => c.gui && !c.gui_denied && gui_healthy,
            _ => false,
        };
        if !valid {
            return Ok(false);
        }
        if deny {
            if channel == "tty" {
                c.tty_denied = true;
            } else {
                c.gui_denied = true;
            }
            if self.config.challenge.deny_policy == "cancel_all"
                || (!c.tty || c.tty_denied) && (!c.gui || c.gui_denied)
            {
                c.result = Some(("denied".into(), String::new()));
            }
        } else if !secret.is_empty() && secret.len() <= 4096 {
            c.result = Some(("success".into(), secret.into()));
        } else {
            return Ok(false);
        }
        Ok(true)
    }
}
