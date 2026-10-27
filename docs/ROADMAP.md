# Roadmap

Build **one phase at a time**. A phase is done only when its acceptance tests pass. Do not implement later phases early.

Pointers: [ARCHITECTURE.md](ARCHITECTURE.md) · [DECISIONS.md](DECISIONS.md) · [AI_GUIDE.md](AI_GUIDE.md) · [phases/](phases/)

## Phase overview

| Phase | Name | Goal |
|-------|------|------|
| 0 | Skeleton | niri + lumen Ping + Quickshell status |
| 1 | Auth broker | Parallel TTY+GUI askpass; first success wins; device hook |
| 2 | Polkit | Session PolicyKit authentication agent |
| 3 | Shell chrome | Bar/launcher/theme; config-driven modules |
| 4 | ytmusicd control | Local player + MPRIS + bookmarks |
| 5 | Fetch/cache | Resolve media + art; cancel in-flight work |
| 6 | Shell media UI | Quickshell controls bound to MPRIS |
| 7 | Hardening | Creds, docs, optional shared cache rules |
| 8 | URL dispatch & receiver | Handler picker + remote URL/file intake (Termux) |

## Phase 0 — Skeleton

**Checklist:** [phases/00-skeleton.md](phases/00-skeleton.md)

- User service or exec-once starts `lumen`
- D-Bus `Ping` on session bus
- Bar shows connected/disconnected

## Phase 1 — Multi-channel auth broker

**Checklist:** [phases/01-askpass.md](phases/01-askpass.md)

- Fan-out challenge to TTY + GUI (device later)
- First success wins; cancel other channels
- No DISPLAY-only branching

## Phase 2 — Polkit agent

**Checklist:** [phases/02-polkit.md](phases/02-polkit.md)

## Phase 3 — Shell chrome

**Checklist:** [phases/03-shell-chrome.md](phases/03-shell-chrome.md)

## Phase 4 — ytmusicd control plane

**Checklist:** [phases/04-ytmusicd-control.md](phases/04-ytmusicd-control.md)

- Per-user service
- mpv (draft) + MPRIS2
- Resume from bookmark

## Phase 5 — Fetch / cache / art

**Checklist:** [phases/05-fetch-cache.md](phases/05-fetch-cache.md)

## Phase 6 — Shell media UI

**Checklist:** [phases/06-shell-media.md](phases/06-shell-media.md)

## Phase 7 — Hardening

**Checklist:** [phases/07-hardening.md](phases/07-hardening.md)

## Phase 8 — URL dispatch & receiver

**Checklist:** [phases/08-url-dispatch.md](phases/08-url-dispatch.md)

- Local URL/URI dispatch with handler picker (mimic/extend xdg-open)
- Per-scheme/mime handler rules, custom app list, "open with..." UI via Quickshell
- URL receiver server (local/network) to accept URLs/files from remote devices (e.g. Termux)
- Auth/token for receiver, allowlist, per-sender rules
- Integration with session D-Bus (`org.lumen.OpenURI` / `org.lumen.UrlReceiver`)

## Explicitly deferred

- Custom compositor
- Audio playback inside Quickshell
- Cross-user audio pipes / global multithreaded music server
- Official YT API (using unofficial lib per A16; expect breakage)
- Device pairing / transport (how phones are enrolled and notified — **A17, decide later**)
