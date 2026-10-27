# Phase 0 — Skeleton

**Status:** not started  
**Goal:** Prove session wiring end-to-end.

## In scope

- [ ] Placeholder `lumen` that can answer `Ping` on session D-Bus (`org.lumen`)
- [ ] Session start hook (niri spawn-at-startup and/or systemd user unit draft)
- [ ] Quickshell stub showing daemon status
- [ ] Minimal compositor snippet documenting how the session launches pieces

## Out of scope

- Askpass, polkit, music, theming polish

## Acceptance tests

- [ ] After login (or manual start), something owns the draft IPC name/socket
- [ ] `Ping` succeeds from a local client
- [ ] Shell UI shows connected vs not connected
- [ ] README or this file notes how to start manually for development

## Notes / blockers

_(fill during implementation)_
