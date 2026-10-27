# Phase 5 — Fetch / cache / art

**Status:** not started  
**Depends on:** Phase 4

## In scope

- [ ] Resolve playable media via unofficial YT lib (A16); quarantine dependency here
- [ ] Cache policy (details TBD)
- [ ] Publish `mpris:artUrl`
- [ ] Cancel in-flight fetch on skip/new Play

## Acceptance tests

- [ ] Skip mid-download does not leave runaway work
- [ ] Cached play works when online resolve fails (if cache present)
- [ ] Unofficial lib failures surface cleanly (no shell crash)
## Notes / blockers

_(fill during implementation)_
