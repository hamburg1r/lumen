use std::fs;

pub struct Input;

pub fn caps_lock() -> bool {
    let Ok(entries) = fs::read_dir("/sys/class/leds") else {
        return false;
    };
    entries.flatten().any(|entry| {
        entry.file_name().to_string_lossy().ends_with("::capslock")
            && fs::read_to_string(entry.path().join("brightness"))
                .is_ok_and(|value| value.trim() == "1")
    })
}

#[zbus::interface(name = "org.lumen.Input")]
impl Input {
    fn get_caps_lock(&self) -> bool {
        caps_lock()
    }
}
