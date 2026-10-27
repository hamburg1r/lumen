# Phase 8 — URL dispatch & receiver

**Status:** not started  
**Depends on:** Phase 0 (daemon + D-Bus); Phase 3 recommended for the handler picker UI  
**Goal:** One config-driven URI/MIME dispatcher, plus a token-protected intake server for remote
URLs/files (first client: Termux).

## In scope

### Dispatch

- [ ] `org.lumen.OpenURI` on session D-Bus: `Open`, `OpenWith`, `Ask`, `Completed` signal
- [ ] `lumen-open` CLI as an `xdg-open` replacement / default scheme handler
- [ ] Config `~/.config/lumen/open.toml`: defaults, rules by scheme/MIME, custom apps, ambiguity policy
- [ ] Discover desktop entries from XDG data dirs; address apps by desktop-file id
- [ ] Resolution order: explicit app → rule → default → Quickshell picker → error
- [ ] Spawn handlers as argv arrays; no shell interpolation
- [ ] Non-GUI sessions fall back to configured default or clear error (never hang)

### Receiver

- [ ] HTTP listener in `lumen`: `POST /v1/open`, `POST /v1/upload`, `GET /v1/health`
- [ ] Default bind loopback (`127.0.0.1:8765`) or Unix socket; LAN only by explicit opt-in
- [ ] Bearer-token auth from `token_file`, constant-time compare, optional timestamp/nonce
- [ ] Upload staging dir with sanitized filenames, size cap, TTL cleanup, no traversal
- [ ] Dispatched submissions use the same handler rules; receiver never executes commands
- [ ] Unknown-sender policy: drop by default; optional "ask first" via Quickshell
- [ ] `scripts/termux-send.sh` helper (URL + file upload via `curl`)

## Out of scope

- Device pairing/transport for auth (A17 — decide later)
- Replacing the auth broker or polkit agent (Phases 1–2)
- Deep-link registration for every app; we dispatch existing handlers
- Sync/queue semantics for offline devices

## Acceptance tests

- [ ] `lumen-open https://example.com` opens the configured browser from a niri session
- [ ] Unknown scheme with GUI healthy shows the Quickshell picker; choosing "always" persists a rule
- [ ] Unknown scheme without GUI exits non-zero with a clear message (no hang)
- [ ] A file path resolves by MIME and opens in the configured app
- [ ] Rule precedence works: explicit `--with` beats config rule beats default
- [ ] `curl -H "Authorization: Bearer $TOKEN" -d '{"url":"https://example.com"}' localhost:8765/v1/open` opens it
- [ ] Request without/with wrong token is rejected (401) and not dispatched
- [ ] File upload lands in staging with a sanitized name and opens; oversize upload rejected
- [ ] Receiver bound to loopback by default; enabling LAN requires config change
- [ ] No handler is ever spawned through a shell; logs contain no tokens

## Notes / blockers

_(fill during implementation)_
