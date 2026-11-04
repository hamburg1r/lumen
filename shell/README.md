# Quickshell status and auth dialog (Phases 0–1)

`shell.qml` draws a small top-left indicator and polls `Ping` every two seconds. It also polls `org.lumen.Auth` through `lumen-auth-gui` every second and displays a password dialog for pending challenges. Passwords travel to the helper over stdin, never command arguments. Run `nix run .#lumen-shell` from a Wayland session. `quickshell ipc --path shell/shell.qml call status connection` reports the indicator state. Full bar/media UI belongs to later phases.
