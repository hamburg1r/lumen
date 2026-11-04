# lumen

Modular Linux desktop shell: **niri** + **Quickshell**, a Rust session daemon (multi-channel auth / polkit), and optional backends (YouTube Music via unofficial lib + MPRIS).

*Lumen* — Latin for light; D-Bus namespace `org.lumen`.

> **Status:** Phase 1 auth broker and Phase 2 Quickshell Polkit agent implemented; Polkit authentication user-tested with `pkexec`, with remaining acceptance checks pending. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Goals

- Modern shell UI (Quickshell + niri) without writing a compositor
- Session daemon for auth broker and module orchestration
- Per-user music/playback with MPRIS (frontend controls; daemon fetches + plays)
- Multi-channel auth (TTY + GUI + future device; first success wins)
- URL/MIME dispatch with a handler picker, plus a token-protected receiver so remote devices
  (e.g. Termux) can send links/files into the desktop
- Modular enough to build with AI one phase at a time

## Non-goals (for now)

- Custom Wayland compositor
- Playing audio inside Quickshell
- One global multi-user music server streaming into each shell

## Layout

```text
lumen/
  docs/           architecture, roadmap, ADRs, phase checklists
  compositor/     niri launch snippet
  shell/          Quickshell status and askpass dialog
  daemon/         Rust lumen daemon and auth client helpers
  modules/        feature backends (e.g. ytmusicd)
  systemd/user/   user unit templates (packaged with store paths)
  scripts/        helpers
```

## Quick links

| Doc | Purpose |
|-----|---------|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | System design |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Phased build plan |
| [docs/DECISIONS.md](docs/DECISIONS.md) | Agreed / draft / open |
| [docs/AI_GUIDE.md](docs/AI_GUIDE.md) | How to drive AI coding sessions |
| [docs/adr/](docs/adr/) | Architecture decision records |
| [docs/phases/08-url-dispatch.md](docs/phases/08-url-dispatch.md) | URL dispatch & receiver plan |

## Suggested stack

| Piece | Choice |
|-------|--------|
| Compositor | niri |
| Shell UI | Quickshell (QML) |
| Session daemon | Rust + zbus (draft) |
| Packaging | Nix-first flake; Cargo OK underneath |
| Music | Per-user service + mpv + MPRIS2 + unofficial YT lib |
| URL dispatch | `lumen-open` + `org.lumen.OpenURI`; handler rules in `open.toml` |
| URL receiver | loopback HTTP + bearer token; Termux script posts URLs/files |
| Audio out | PipeWire (user session) |
| IPC | session D-Bus (`org.lumen.*`) |

## Phase 0: build and run

Linux + Nix with flakes enabled and a running session D-Bus are required. Quickshell needs a Wayland session to show its status indicator.

```bash
nix build .#default                  # packages lumen, lumen-shell, and user units
./result/bin/lumen &                 # terminal 1 (or foreground in a separate terminal)
busctl --user call org.lumen /org/lumen org.lumen.Daemon Ping  # s "pong"
./result/bin/lumen-shell             # in a niri/Wayland session
```

The shell displays **Lumen connected** or **Lumen disconnected** and updates within two seconds of a daemon state change. To install both commands in your profile: `nix profile install .#default`. The individual outputs are `.#lumen` and `.#lumen-shell`; `nix develop` provides the development tools.

For startup, choose **one** of: merge [compositor/niri.kdl](compositor/niri.kdl) into your niri config (after installing the package into your profile), or link the packaged units from `result/share/systemd/user/` with `systemctl --user link` and enable them. See [Phase 0](docs/phases/00-skeleton.md) for details and tests. Do not use both startup mechanisms at once.

## Phase 1: sudo askpass

Start `lumen` and `lumen-shell` in the same graphical session, then:

```sh
export SUDO_ASKPASS="$(readlink -f result)/bin/lumen-askpass"
sudo -A -k true
```

The TTY (if present) and Quickshell password dialog race; the first submission is returned to sudo. The daemon does **not** verify the password: sudo does. A GUI-only session works when the shell is healthy; without either channel the request fails immediately. No secret is placed in subprocess argv or environment. For headless SSH/tmux, start the daemon in that user's session bus and use a controlling TTY. `bash scripts/auth-smoke.sh` runs isolated D-Bus smoke checks without sudo or a desktop. Configuration and limitations: [Phase 1](docs/phases/01-askpass.md).

## Phase 2: PolicyKit agent

`lumen-shell` also registers a Polkit agent for its graphical logind session. It shows the action, identity, and PAM prompt in a Quickshell dialog; Cancel rejects, and Polkit (not Lumen's askpass broker) validates responses. Only one agent can register per session. If another agent is active, disable its autostart before launching Lumen to use the Lumen dialog. Test instructions and outstanding live checks: [Phase 2](docs/phases/02-polkit.md).
