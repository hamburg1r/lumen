# Phase 1 — Multi-channel auth (askpass)

**Status:** not started  
**Depends on:** Phase 0  
**Goal:** Parallel TTY + GUI over D-Bus; first success wins; per-channel modes; device stub.

## In scope

- [ ] AuthChallenge broker on **session D-Bus** (A10)
- [ ] **tty** channel when controlling terminal present; `mode` configurable (A14)
- [ ] **gui** channel via Quickshell when healthy (A9); `mode` configurable
- [ ] `lumen-askpass` as `SUDO_ASKPASS` → create challenge, wait for winner
- [ ] Single-use challenge; ignore late submissions
- [ ] D-Bus peer credential checks
- [ ] Config: `deny_policy`, `timeout_secs` (default ~900), per-channel `mode` (A8/A12/A14)
- [ ] Stub registry for future device/web endpoints (modes only)

## Out of scope

- Full polkit agent (Phase 2) — same broker + Quickshell UI
- Device pairing / transport (**A17 — decide later**; stub registry only)
- Implementing every mode on day one — ship `password`; stub `approve_only` / `totp`

## Acceptance tests

- [ ] tty and gui both armed; success on **either** completes `sudo -A`
- [ ] After one success, other channels cannot complete the same challenge
- [ ] `deny_policy = "cancel_all"` and `"wait_others"` behave as documented
- [ ] Challenge remains valid for configured timeout (default ~15 minutes)
- [ ] SSH + tmux with gui: both race; either works
- [ ] SSH + tmux without gui: tty works; no hang
- [ ] Other UID cannot complete someone else’s challenge

## Notes / blockers

_(fill during implementation)_
