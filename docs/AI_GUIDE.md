# AI coding guide

Use this repo with AI by scoping **one phase per session**.

## Session prompt template

Copy and fill:

```text
Project: ~/repo/lumen
Read: docs/ARCHITECTURE.md, docs/DECISIONS.md, docs/ROADMAP.md
Implement ONLY: docs/phases/NN-....md
Respect agreed decisions A1–A17 and current drafts in DECISIONS.md.
Do not implement later phases.
Do not play audio in Quickshell.
Do not use DISPLAY/WAYLAND_DISPLAY alone for channel selection.
Askpass/auth: multi-channel broker on session D-Bus (org.lumen.*); first success wins; per-endpoint mode; deny_policy config.
Do not design device pairing/transport (A17 — decide later).
YT Music: unofficial lib isolated in ytmusicd (A16).
URL dispatch/receiver: in `lumen` via `org.lumen.OpenURI`; rules in open.toml; spawn argv only; receiver loopback+token by default (A21/A22).
Packaging: Nix-first.
Compositor: niri. Shell UI: Quickshell.
Stop when acceptance tests in the phase file pass (or document blockers).
```

## Rules for the AI

1. Prefer editing within the phase’s directories.
2. If a design choice is in **Open**, ask or pick a reversible default and note it in `DECISIONS.md`.
3. Do not add a global multi-user music streaming design in v1.
4. Keep secrets out of logs and out of commit history.
5. Update the phase checklist checkboxes when done.
6. Never spawn URL handlers through a shell; use argv arrays. Receiver tokens are files, not literals.

## Definition of done (any phase)

- Acceptance tests in the phase doc are marked done or waived with reason
- `docs/DECISIONS.md` updated if a draft became agreed or an open item closed
- No drive-by refactors outside the phase
