# Decisions log

Track what is **agreed**, **draft**, or **open**. Update this when you change your mind so AI sessions do not invent conflicting designs.

## Agreed (for now)

| ID | Decision |
|----|----------|
| A1 | Reuse a compositor; do not write one first |
| A2 | Shell UI is separate from privileged/long-running backends |
| A3 | Prefer per-user systemd services over one global music daemon |
| A4 | Quickshell does **not** decode/play audio streams |
| A5 | Askpass must not rely on `DISPLAY` / `WAYLAND_DISPLAY` alone |
| A6 | Compositor is **niri** (not Hyprland) |
| A7 | Auth is a **multi-channel broker**: fan out in parallel; **first successful approval/secret wins**; cancel losers on success; offline channels skipped |
| A8 | On-channel **deny** behavior is **config-driven**: `deny_policy = "cancel_all" \| "wait_others"` |
| A9 | Shell / auth / polkit UI is **Quickshell** (primary reason for the project) |
| A10 | Auth challenge IPC is **session D-Bus** (not a custom socket protocol as the primary API) |
| A11 | Packaging is **Nix-first** (flake); Cargo workspace OK underneath if useful — either is fine |
| A12 | Auth challenge timeout is long-lived: **default ~10–15 minutes**, configurable upward |
| A13 | Shared cross-user media cache is **deferred** (later; may never happen) |
| A14 | Each auth **endpoint/module** has a configurable **mode** (e.g. `password`, `approve_only`, `totp`, later web); modes are per-target, not global |
| A15 | Project name is **lumen**; D-Bus prefix **`org.lumen`** |
| A16 | YT Music fetch uses an **unofficial** client/library (InnerTube-style / community libs); expect breakage and isolate behind `ytmusicd` |
| A17 | Device **pairing and transport** (how a phone is enrolled and how challenges reach it) is **deferred — decide later**; do not block TTY/GUI auth or other phases |
| A18 | Shell UI design system heavily features "eyecandy": squircles, pills, connected canvas (padding linking screen edge to bar). All visual elements are configurable via design tokens. |
| A19 | Caps-lock detection (exposed as `org.lumen.Input`) and Notification history (`org.freedesktop.Notifications`) live in the Rust `lumen` daemon. |
| A20 | All user-configurable settings (theme tokens, feature toggles) must map cleanly to JSON/TOML so they can be trivially set from NixOS / Home Manager modules. |
| A21 | `lumen` is the session **URI/MIME dispatcher**: `org.lumen.OpenURI` + `lumen-open` CLI (xdg-open replacement), per-scheme/MIME handler rules in `~/.config/lumen/open.toml`, optional "open with…" picker in Quickshell; handlers spawn as argv, never via a shell. |
| A22 | `lumen` runs a **URL receiver** for remote URL/file submissions (first client: Termux): loopback by default, token auth from a file, size-capped sanitized staging, and the same dispatch rules as local opens; it never executes arbitrary commands. |

## Draft (likely, but changeable)

| ID | Draft | Notes |
|----|-------|-------|
| D3 | Rust + zbus for `lumen` daemon | Fits A10; Go still OK if preferred |
| D4 | mpv as player backend for ytmusicd | GStreamer is fine too |
| D5 | MPRIS2 as the music control API | Custom D-Bus in addition is OK |
| D7 | Credentials eventually in keyring / daemon-owned config | Shell may pass token only in early prototype |
| D8 | Auth channels are pluggable backends behind one challenge id | tty / gui first; device / web later |
| D9 | Default `deny_policy = "cancel_all"` | safer default; users may set `wait_others` |
| D10 | Default challenge `timeout_secs = 900` (15 min) | floor ~600 (10 min) also fine via config |
| D11 | Default channels when available: `tty` + `gui` | headless: whatever is healthy |
| D12 | Binaries: `lumen` (daemon), `lumen-askpass`; config under `~/.config/lumen/` | adjust if packaging needs |
| D13 | URL receiver transport is **HTTP(S) with a bearer token** (Unix socket also supported); SSH tunneling is an acceptable alternative for remote use | Termux script uses `curl`; refine during Phase 8 |

## Open (not finalized)

None right now. Deferred items live under Agreed (A13, A17), not as blocking questions.

### Closed

| ID | Resolution |
|----|------------|
| O1 | **A15** — **lumen** / `org.lumen` |
| O2 | **A11** — Nix-first; Cargo optional |
| O3 | **A10** — D-Bus |
| O4 | **A16** — unofficial YT Music library |
| O5 | **A12** + **D10/D11** — long timeout; tty+gui when healthy |
| O6 | **A13** — later / maybe never |
| O7 | **A9** — Quickshell |
| O8 | **A8** — config flag |
| O9 (modes) | **A14** — per-module configurable modes |
| O9 (pairing / transport) | **A17** — decide later; not blocking |

## How to update

1. Move a row between sections when status changes.
2. Add an ADR under `docs/adr/` for anything that would be expensive to reverse.
3. Do **not** delete history — mark superseded ADRs instead.
