# lumen

Modular Linux desktop shell: **niri** + **Quickshell**, a Rust session daemon (multi-channel auth / polkit), and optional backends (YouTube Music via unofficial lib + MPRIS).

*Lumen* — Latin for light; D-Bus namespace `org.lumen`.

> **Status:** early design. See [docs/DECISIONS.md](docs/DECISIONS.md).

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
  compositor/     niri config snippets
  shell/          Quickshell UI (placeholder)
  daemon/         Rust workspace for lumen + lumen-askpass (placeholder)
  modules/        feature backends (e.g. ytmusicd)
  systemd/user/   user unit templates
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

## Getting started

Nothing to build yet. Read `docs/ROADMAP.md` Phase 0 when ready.

```bash
cd ~/repo/lumen
```
