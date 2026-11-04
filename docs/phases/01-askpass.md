# Phase 1 — Multi-channel auth (askpass)

**Status:** implemented; manual environment-dependent acceptance tests outstanding
**Depends on:** Phase 0  
**Goal:** Parallel TTY + GUI over D-Bus; first success wins; per-channel modes; device stub.

## In scope

- [x] Auth broker on **session D-Bus** (`org.lumen.Auth`, `/org/lumen/Auth`)
- [x] **tty** channel when `/dev/tty` is available; password mode
- [x] **gui** channel via Quickshell heartbeat and password dialog
- [x] `lumen-askpass` as `SUDO_ASKPASS` → create challenge, wait for winner
- [x] Single-use challenge; ignore late submissions
- [x] D-Bus peer UID check and challenge-owner binding for Result / tty Submit
- [x] Config: `deny_policy`, `timeout_secs` (default 900), per-channel `mode` (password supported)
- [x] Config registry for future device endpoints (modes only; no transport)

## Out of scope

- Full polkit agent (Phase 2) — same broker + Quickshell UI
- Device pairing / transport (**A17 — decide later**; stub registry only)
- Implementing every mode on day one — ship `password`; stub `approve_only` / `totp`

## Acceptance tests

- [x] tty and gui both armed; success on **either** completes `sudo -A` (user-tested in tmux; PTY broker race smoke-tested)
- [x] After one success, other channels cannot complete the same challenge (late submission smoke-tested)
- [ ] `deny_policy = "cancel_all"` and `"wait_others"` behave as documented
- [ ] Challenge remains valid for configured timeout (default ~15 minutes)
- [ ] SSH + tmux with gui: both race; either works
- [ ] SSH + tmux without gui: tty works; no hang (local tmux TTY tested; SSH unverified)
- [ ] Other UID cannot complete someone else’s challenge

## Notes / blockers

### Implementation / configuration

`~/.config/lumen/auth.toml` (or `$XDG_CONFIG_HOME/lumen/auth.toml`) is loaded on daemon startup; absent file uses defaults. Example:

```toml
[challenge]
timeout_secs = 900
deny_policy = "wait_others" # or "cancel_all" (default)

[channels.tty]
enabled = true
mode = "password"

[channels.gui]
enabled = true
mode = "password"

[[channels.device]]
id = "phone-1"
enabled = false
mode = "approve_only" # registered but not armed; transport deferred
```

Non-password modes on active tty/gui channels are rejected at startup rather than silently misinterpreted. Empty tty input is a deny. With `cancel_all` any channel denial ends the challenge; with `wait_others` a denial removes only that channel, and the last denial ends the challenge. GUI is healthy only if its one-second poll ran in the last five seconds; a GUI-only request fails when the GUI disappears. Challenges are capped at 64 concurrent requests, last 900 seconds by default, and become invalid after their result is consumed. Result is readable only by the D-Bus connection that created the challenge. Same-UID GUI processes can submit via the helper; same-UID processes are **not** a security boundary. The broker forwards a password candidate; sudo performs actual authentication.

Local checks: `cargo test`, `nix build .#default`, `bash scripts/auth-smoke.sh` (GUI-only win, late submit rejected, deny fails, PTY GUI/TTY race, newline and terminal echo restoration), and Quickshell config load on Wayland passed. The user also confirmed sudo askpass from a TTY/tmux session and GUI. `wait_others` with both channels, SSH, other-UID D-Bus access, and full 15-minute timeout remain **unverified**. Try these before treating the phase as accepted.
