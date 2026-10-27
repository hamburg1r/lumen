# ADR-0004: Unofficial YouTube Music library

## Status

Accepted (A16)

## Context

There is no stable official public API for a third-party YouTube Music desktop backend. `ytmusicd` still needs login + playable stream URLs.

## Decision

Use an **unofficial** / community library (InnerTube-style or similar). Isolate all YT-specific code inside `modules/ytmusicd` so a breakage or swap does not ripple into the shell or MPRIS control plane.

## Consequences

- Can ship Phase 5 without waiting on Google
- Expect occasional breakage; version-pin and quarantine the dependency
- ToS / account risk is on the user; document plainly in module README
- MPRIS + mpv remain the stable boundary

## Alternatives considered

- Official API only — not available for this use case
- Browser/cookie bridge only — deferred as optional later path
- MPRIS-only wrapping an external app — too weak for “our” backend
