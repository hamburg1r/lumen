use std::error::Error;

use zbus::blocking::connection::Builder;

struct Daemon;

#[zbus::interface(name = "org.lumen.Daemon")]
impl Daemon {
    fn ping(&self) -> &'static str {
        "pong"
    }
}

fn main() -> Result<(), Box<dyn Error>> {
    // Keep the connection alive: zbus serves method calls on its internal executor.
    let _connection = Builder::session()?
        .name("org.lumen")?
        .serve_at("/org/lumen", Daemon)?
        .build()?;

    println!("lumen: serving org.lumen.Daemon at /org/lumen");
    loop {
        std::thread::park();
    }
}
