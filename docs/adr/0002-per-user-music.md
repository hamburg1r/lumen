# ADR-0002: Per-user music service (not global streamer)

## Status

Draft (aligned with agreed decisions A3, A4)

## Context

Multiple users need isolated credentials, queues, and PipeWire outputs. Streaming from one system daemon into Quickshell is complex and puts AV in the wrong process.

## Decision

Run `ytmusicd` as a **systemd --user** service. Playback via local player (mpv draft) into that user’s PipeWire. Control via MPRIS2. Quickshell is UI/control only.

## Consequences

- Natural multi-user isolation
- Standard tooling (`playerctl`) works
- No cross-user pipe protocol in v1
- Duplicate caches possible unless a later shared-cache design is added

## Alternatives considered

- System daemon + per-user pipes into Quickshell — deferred / rejected for v1
- Embedding player in Quickshell — rejected
