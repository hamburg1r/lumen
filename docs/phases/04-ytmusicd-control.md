# Phase 4 — ytmusicd control plane

**Status:** not started  
**Depends on:** Phase 0  
**Goal:** Frontend controls playback; daemon runs local player + MPRIS.

## In scope

- [ ] `modules/ytmusicd` user service
- [ ] Local player backend (mpv draft — D4)
- [ ] MPRIS2 Play/Pause/Seek/Next + Metadata
- [ ] Bookmark persistence for resume
- [ ] Credentials loaded by daemon (prototype may accept set-once from shell — D7)

## Out of scope

- Streaming audio into Quickshell
- Cross-user pipes
- Picking a specific unofficial YT crate/lib version (A16 — do in Phase 5)

## Acceptance tests

- [ ] `playerctl` can play-pause the player
- [ ] Pause/stop mid-track; restart service; resume near same position
- [ ] Audio only on that user’s PipeWire
- [ ] Second OS user does not see first user’s queue/credentials

## Notes / blockers

_(fill during implementation)_
