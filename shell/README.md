# Quickshell bar and auth dialogs (Phases 0–3)

`shell.qml` draws a full-width connected top bar and polls `Ping` every two seconds. It also polls `org.lumen.Auth` through `lumen-auth-gui` every second and displays a password dialog for pending sudo challenges. Passwords travel to the helper over stdin, never command arguments. A separate Quickshell Polkit agent registers for the shell's logind session and conducts Polkit's PAM conversation in its own dialog; it does not route candidate secrets through the sudo broker. Run `nix run .#lumen-shell` from a Wayland session. `quickshell ipc --path shell/shell.qml call status connection` reports the indicator state, and `... call status polkit` reports Polkit registration. A competing Polkit agent prevents registration; see `docs/phases/02-polkit.md`.

Phase 3 chrome uses `chrome.py` for CPU/RAM/network snapshots and a daemon-backed caps-lock/brightness watcher, niri's event stream for workspace pills, and Quickshell's PipeWire service for volume. Click workspace pills to focus niri workspaces, stats to open their popovers, ◇ to launch fuzzel (duplicate clicks are ignored), and ☷ for the Control Center. Opening the center closes fuzzel when launched from the bar. Click anywhere outside the center below the bar to dismiss it. The center shows notification history from the Rust daemon; use × to dismiss an entry or click an action button to send `ActionInvoked` to its client. The daemon must own `org.freedesktop.Notifications` (stop a competing notification server). The volume mute toggle requires PipeWire. Brightness uses sysfs, while caps-lock comes from `org.lumen.Input`; unavailable sources show n/a. CPU/network stats still poll every two seconds.
Notification history is per-user and persists across daemon restarts under
`${XDG_STATE_HOME:-~/.local/state}/lumen/notifications.json`; the directory is private
(0700) and the file is readable only by the owner (0600). History is limited to 100
entries; pending action buttons are cleared on daemon restart.

Create `~/.config/lumen/theme.toml` and `shell.toml` (both reload within three seconds):

```toml
# theme.toml
[theme]
background = "#202631"
accent = "#9de2b1"
radius = 18
pill_radius = 24
spacing = 10
edge = 8
background_opacity = 0.88 # 0.0 to 1.0; bar, popover and OSD backgrounds
```

```toml
# shell.toml
[modules]
network = false
system = true
```

Other theme colors: `surface`, `foreground`, `muted`, `warning`. Other modules:
`workspaces`, `clock`, `launcher`, `control_center`. Import
`home-manager/lumen.nix` in Home Manager and set `programs.lumen.theme.accent`
or `programs.lumen.modules.network` to generate the same files. Wayland layer-shell
namespaces are `lumen:bar`, `lumen:popup`, and `lumen:osd`; a compositor can match
these for effects. Transparency is not itself backdrop blur. See
`docs/phases/03-shell-chrome.md` for acceptance and outstanding gaps.

To diagnose a missing volume OSD in a running installed shell, use
`quickshell ipc --path <installed-shell.qml> call status volume`. It should
report `ready N%`; `... call status osd` reports the current OSD message or
`hidden`. Use the path shown by `quickshell list --all` or the shell's process
command, not the source-tree path if running a packaged instance.
