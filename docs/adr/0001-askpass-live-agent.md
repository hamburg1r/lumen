# ADR-0001: Askpass via live session agent (not DISPLAY)

## Status

**Superseded by ADR-0003** (multi-channel auth broker).

Still valid: do **not** use `DISPLAY` / `WAYLAND_DISPLAY` alone (A5). Invalid: “GUI first, then TTY fallback, never both.”

## Context

Earlier draft assumed ordered fallback (GUI XOR TTY). Product intent is parallel channels with first success wins — see ADR-0003.

## Decision (historical)

GUI if agent live, else TTY. Rejected parallel prompts.

## Superseded by

[ADR-0003](0003-multi-channel-auth-broker.md)
