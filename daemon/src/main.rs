use std::error::Error;

use zbus::blocking::connection::Builder;
mod auth;
mod input;
mod notifications;

struct Daemon;

#[zbus::interface(name = "org.lumen.Daemon")]
impl Daemon {
    fn ping(&self) -> &'static str {
        "pong"
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let config = auth::Config::load()?;
    let (notifications, history) = notifications::Notifications::new();
    // Keep the connection alive: zbus serves method calls on its internal executor.
    let _connection = Builder::session()?
        .name("org.lumen")?
        .name("org.freedesktop.Notifications")?
        .serve_at("/org/lumen", Daemon)?
        .serve_at("/org/lumen/Auth", auth::Auth::new(config))?
        .serve_at("/org/lumen/Input", input::Input)?
        .serve_at("/org/freedesktop/Notifications", notifications)?
        .serve_at("/org/lumen/Notifications", history)?
        .build()?;

    println!("lumen: serving org.lumen.Daemon at /org/lumen");
    loop {
        std::thread::park();
    }
}
