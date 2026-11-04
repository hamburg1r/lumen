# Quickshell status stub (Phase 0)

`shell.qml` draws a small top-left indicator. It calls `Ping` with `busctl` every two seconds and distinguishes responsive and unavailable daemons. The `lumen-shell` flake package wraps Quickshell with the QML path and `busctl` on `PATH`; run `nix run .#lumen-shell` from a Wayland session. `quickshell ipc --path shell/shell.qml call status connection` reports the indicator state for tests. Full bar/media UI belongs to later phases.
