# lumen

Modular Linux desktop shell: **niri** + **Quickshell**, a Rust session daemon (multi-channel auth / polkit), and optional backends (YouTube Music via unofficial lib + MPRIS).

*Lumen* — Latin for light; D-Bus namespace `org.lumen`.

> **Status:** Phase 0 skeleton implemented; later phases are still plans. See [docs/ROADMAP.md](docs/ROADMAP.md).

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
  shell/          Quickshell status stub
  daemon/         Rust lumen daemon (Ping only)
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
