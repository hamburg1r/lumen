# Phase 0 — Skeleton

**Status:** implemented and locally verified
**Goal:** Prove session wiring end-to-end.

## In scope

- [x] Placeholder `lumen` that can answer `Ping` on session D-Bus (`org.lumen`)
- [x] Session start hook (niri spawn-at-startup and packaged systemd user units)
- [x] Quickshell stub showing daemon status
- [x] Minimal compositor snippet documenting how the session launches pieces
- [x] Nix flake builds and installs daemon, shell wrapper, and user units

## Out of scope

- Askpass, polkit, music, theming polish

## Acceptance tests

- [x] On manual start, daemon owns `org.lumen` on the session bus
- [x] `Ping` succeeds from a local client
- [x] Shell UI shows connected vs not connected
- [x] README or this file notes how to start manually for development

## Notes / blockers

### Manual development session

```sh
nix build .#default
./result/bin/lumen &
busctl --user call org.lumen /org/lumen org.lumen.Daemon Ping
./result/bin/lumen-shell  # needs Wayland; run separately if desired
```

The expected D-Bus reply is `s "pong"`. The QML stub polls every two seconds, displaying green **Lumen connected** or red **Lumen disconnected**. Its IPC test hook reports the same state: `quickshell ipc --path shell/shell.qml call status connection` (run inside `nix develop` if `quickshell` isn't installed). Stop the background daemon with `kill %1` in the same shell. `nix run .#lumen` and `nix run .#lumen-shell` also work; the default output installs both commands.

### Session startup (choose one)

- **niri:** `nix profile install .#default`, then merge `compositor/niri.kdl` into `~/.config/niri/config.kdl` and restart the session. This assumes your profile's `bin` directory is on niri's `PATH`.
- **systemd --user:** `nix build .#default`, then `systemctl --user link "$(readlink -f result)/share/systemd/user/lumen.service" "$(readlink -f result)/share/systemd/user/lumen-shell.service"` and `systemctl --user enable --now lumen.service lumen-shell.service` from a graphical session. Re-link the packaged units after upgrading. The shell unit pulls in the daemon. On niri, use `--session` if relying on graphical-session.target for automatic session start; `--now` starts them immediately.

Never enable both startup paths. The source `.service` files are templates, not directly installable units; the flake output fills in executable paths.

### Verification performed

- `nix build .#default` and `nix flake check` passed on x86_64-linux. The flake also declares aarch64-linux, not locally tested.
- `niri validate -c compositor/niri.kdl` passed.
- In `dbus-run-session`, `busctl --user call org.lumen /org/lumen org.lumen.Daemon Ping` returned `s "pong"` and the name disappeared after stopping the daemon.
- Under a running Wayland session, `lumen-shell` loaded successfully; its IPC state changed **disconnected → connected → disconnected** when the daemon was started and stopped. Automated login/boot behavior was not tested; use the startup instructions above for your setup.
