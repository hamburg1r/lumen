# ADR-0003: Multi-channel auth broker (first success wins)

## Status

Draft (aligned with agreed decisions A7, A10, A14, A15)

## Context

`sudo` / polkit / future privileged actions should not pick a single UI. The user wants **several auth channels at once** (TTY, desktop GUI, later phone push / webhook to registered devices — Google-style approval). Whichever channel returns a valid approval or secret first is the source of truth; others are cancelled.

SSH + tmux must still work: TTY is always a channel when a controlling tty exists. DISPLAY guessing remains forbidden (A5).

## Decision

`lumen` owns an **AuthChallenge broker** on session D-Bus (`org.lumen`):

1. `lumen-askpass` (or polkit agent) creates a challenge: `{id, prompt, reason, timeout, created_at}`.
2. Broker **fans out** to all **enabled, healthy** channels in parallel. Each channel/endpoint has a configurable **mode** (A14):
   - **tty** — e.g. `mode = "password"`
   - **gui** — Quickshell dialog (A9); e.g. `password` or `approve_only`
   - **device** / **web** (later) — per-device modes: `approve_only`, `totp`, `password`, …
3. **First terminal outcome wins** (success path fixed; deny path config-driven):
   - success with secret or approval (per mode) → complete askpass/polkit; cancel other channels
   - explicit deny/cancel from a channel → controlled by config **`deny_policy`** (A8):
     - `cancel_all` — deny ends the whole challenge (fail); cancel remaining channels
     - `wait_others` — ignore that channel’s deny; keep waiting on remaining channels until success, global timeout, or all channels exhausted
4. Challenge timeout default **~10–15 minutes** (A12); configurable higher.
5. Challenge is single-use; secrets never logged; D-Bus peer credentials checked.

Channels that are offline are skipped (not “wait forever”). Example: no GUI agent → TTY + future device still race.

```text
                 lumen-askpass / polkit
                           │
                           ▼
              AuthChallenge broker (lumen)
                           │
         ┌─────────────────┼─────────────────┐
         ▼                 ▼                 ▼
       tty              gui dialog      device push
    (this SSH)        (niri seat)     (webhook later)
         │                 │                 │
         └──────── first success ────────────┘
                           │
                    cancel losers
                           │
                    return to sudo
```

## Consequences

- Extensible: new channel = register a backend; no askpass rewrite
- UX can show TTY and GUI together; typing in either completes sudo
- Need cancel/broadcast so a late GUI submit does not reuse a spent challenge
- Device endpoints: pairing/transport **deferred (A17, decide later)**; **modes** are config per device (A14)
- Deny semantics are user-configurable (`deny_policy`); default draft `cancel_all` (D9)
- Challenge IPC is D-Bus (A10); packaging Nix-first (A11)

## Alternatives considered

- GUI-only then TTY fallback (ADR-0001) — rejected; does not match product
- Parallel race without cancel — unsafe (double submit)
- Always TTY — no desktop/phone story
