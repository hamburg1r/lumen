use std::{
    error::Error,
    fs::OpenOptions,
    io::{self, Read, Write},
    os::fd::AsRawFd,
    sync::{
        atomic::{AtomicBool, Ordering},
        Arc,
    },
    thread,
    time::Duration,
};
use zbus::blocking::{Connection, Proxy};

fn proxy(conn: &Connection) -> zbus::Result<Proxy<'_>> {
    Proxy::new(conn, "org.lumen", "/org/lumen/Auth", "org.lumen.Auth")
}

// Returns true if a prompt was displayed but no newline was written yet.
fn tty_prompt(conn: Connection, id: String, prompt: String, stop: Arc<AtomicBool>) -> bool {
    let Ok(mut tty) = OpenOptions::new().read(true).write(true).open("/dev/tty") else {
        return false;
    };
    let fd = tty.as_raw_fd();
    let mut old = unsafe { std::mem::zeroed::<libc::termios>() };
    if unsafe { libc::tcgetattr(fd, &mut old) } != 0 {
        return false;
    }
    let mut hidden = old;
    hidden.c_lflag &= !libc::ECHO;
    if unsafe { libc::tcsetattr(fd, libc::TCSANOW, &hidden) } != 0 {
        return false;
    }
    struct Restore(i32, libc::termios);
    impl Drop for Restore {
        fn drop(&mut self) {
            unsafe {
                libc::tcsetattr(self.0, libc::TCSANOW, &self.1);
            }
        }
    }
    let _restore = Restore(fd, old);
    if stop.load(Ordering::Relaxed) {
        return false;
    }
    if write!(tty, "{} ", prompt)
        .and_then(|_| tty.flush())
        .is_err()
    {
        return false;
    }
    let mut line = Vec::new();
    let mut failed = false;
    loop {
        if stop.load(Ordering::Relaxed) {
            // Discard an unfinished password before restoring terminal echo.
            unsafe {
                libc::tcflush(fd, libc::TCIFLUSH);
            }
            return true;
        }
        let mut pollfd = libc::pollfd {
            fd,
            events: libc::POLLIN,
            revents: 0,
        };
        let ready = unsafe { libc::poll(&mut pollfd, 1, 100) };
        if ready == 0
            || (ready < 0 && io::Error::last_os_error().kind() == io::ErrorKind::Interrupted)
        {
            continue;
        }
        if ready < 0 || pollfd.revents & (libc::POLLERR | libc::POLLHUP | libc::POLLNVAL) != 0 {
            failed = true;
            break;
        }
        let mut byte = [0u8];
        match tty.read(&mut byte) {
            Ok(1) if byte[0] == b'\n' => break,
            Ok(1) if line.len() < 4096 => line.push(byte[0]),
            Ok(1) | Ok(0) | Err(_) => {
                failed = true;
                break;
            }
            _ => unreachable!(),
        }
    }
    let _ = writeln!(tty);
    let secret = String::from_utf8(line).unwrap_or_default();
    let deny = failed || secret.is_empty();
    if let Ok(p) = proxy(&conn) {
        let _: zbus::Result<bool> = p.call("Submit", &(id, "tty", secret.as_str(), deny));
    }
    false
}

fn run() -> Result<(), Box<dyn Error>> {
    let prompt = std::env::args()
        .nth(1)
        .unwrap_or_else(|| "Password:".into());
    let has_tty = OpenOptions::new()
        .read(true)
        .write(true)
        .open("/dev/tty")
        .is_ok();
    let conn = Connection::session()?;
    let p = proxy(&conn)?;
    let id: String = p.call("Begin", &(&prompt, has_tty))?;
    let stop = Arc::new(AtomicBool::new(false));
    let tty = if has_tty {
        let (conn, id, prompt) = (conn.clone(), id.clone(), prompt.clone());
        let stop = stop.clone();
        Some(thread::spawn(move || tty_prompt(conn, id, prompt, stop)))
    } else {
        None
    };
    let outcome: Result<String, Box<dyn Error>> = loop {
        let (status, secret): (String, String) = match p.call("Result", &id) {
            Ok(reply) => reply,
            Err(e) => break Err(e.into()),
        };
        match status.as_str() {
            "success" => break Ok(secret),
            "pending" => thread::sleep(Duration::from_millis(150)),
            _ => break Err(format!("authentication {status}").into()),
        }
    };
    stop.store(true, Ordering::Relaxed);
    if let Some(tty) = tty {
        if tty.join().unwrap_or(false) {
            // The GUI won while the TTY prompt was still on the current line.
            if let Ok(mut terminal) = OpenOptions::new().write(true).open("/dev/tty") {
                let _ = writeln!(terminal);
            }
        }
    }
    println!("{}", outcome?);
    Ok(())
}
fn main() {
    if let Err(e) = run() {
        eprintln!("lumen-askpass: {e}");
        std::process::exit(1);
    }
}
