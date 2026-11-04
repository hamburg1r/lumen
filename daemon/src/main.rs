use std::error::Error;

use zbus::blocking::connection::Builder;
mod auth;

struct Daemon;

#[zbus::interface(name = "org.lumen.Daemon")]
impl Daemon {
    fn ping(&self) -> &'static str {
        "pong"
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    let config = auth::Config::load()?;
    // Keep the connection alive: zbus serves method calls on its internal executor.
    let _connection = Builder::session()?
        .name("org.lumen")?
        .serve_at("/org/lumen", Daemon)?
        .serve_at("/org/lumen/Auth", auth::Auth::new(config))?
        .build()?;

    println!("lumen: serving org.lumen.Daemon at /org/lumen");
    loop {
        std::thread::park();
    }
}
