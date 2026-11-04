use std::{
    error::Error,
    io::{self, BufRead},
};
use zbus::blocking::{Connection, Proxy};

fn run() -> Result<(), Box<dyn Error>> {
    let mut args = std::env::args().skip(1);
    let conn = Connection::session()?;
    let p = Proxy::new(&conn, "org.lumen", "/org/lumen/Auth", "org.lumen.Auth")?;
    match args.next().as_deref() {
        Some("next") => {
            let (id, prompt): (String, String) = p.call("GuiNext", &())?;
            println!("{}", serde_json::json!({"id":id,"prompt":prompt}));
        }
        Some("submit") => {
            let id = args.next().ok_or("missing challenge id")?;
            // Never put a secret in argv or environment: Quickshell writes it on stdin.
            let mut secret = String::new();
            io::stdin().lock().read_line(&mut secret)?;
            let secret = secret.trim_end_matches(['\r', '\n']);
            let accepted: bool = p.call("Submit", &(&id, "gui", secret, false))?;
            if !accepted {
                return Err("challenge no longer active".into());
            }
        }
        Some("deny") => {
            let id = args.next().ok_or("missing challenge id")?;
            let _: bool = p.call("Submit", &(&id, "gui", "", true))?;
        }
        _ => return Err("usage: lumen-auth-gui next|submit ID|deny ID".into()),
    }
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("lumen-auth-gui: {e}");
        std::process::exit(1);
    }
}
