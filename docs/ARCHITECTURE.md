# Architecture (draft)

## Layers

```text
┌─ Compositor (niri) ─────────────────────────────────────────┐
│  windows, input, workspaces                                   │
├─ Shell (Quickshell) ────────────────────────────────────────┤
│  connected canvas, workspace pills, stats popovers,           │
│  control center (notifications + toggles), OSD, media UI      │
│  (NO audio decode)                                          │
├─ Session daemon (lumen) ────────────────────────────────────┤
│  auth broker, caps-lock monitor (org.lumen.Input),           │
│  notifications (org.freedesktop.Notifications),              │
│  URL/MIME dispatch + remote URL receiver (org.lumen.OpenURI),│
│  sys/net telemetry helper, module registry                   │
├─ Feature modules (e.g. ytmusicd) ───────────────────────────┤
│  fetch/cache (unofficial YT lib), local player, MPRIS         │
└─ OS session services ───────────────────────────────────────┘
   PipeWire, session D-Bus, $XDG_RUNTIME_DIR
```

## Configuration & NixOS Integration (A20)

All user-facing settings (theme design tokens, widget toggles, channel behaviors) are parsed from structured config files (JSON/TOML) in `~/.config/lumen/`.
This ensures direct mapping to NixOS and Home Manager module options without requiring QML recompilation or custom scripting.

## Control plane vs data plane (music)

```text
Quickshell / playerctl          ytmusicd                    mpv/gst
     │                              │                          │
     │ Play/Pause/Seek (MPRIS)      │                          │
     ├─────────────────────────────►│ unofficial lib fetch     │
     │                              ├─────────────────────────►│
     │                              │                          ├─► PipeWire
     │ Metadata / position          │                          │
     │◄─────────────────────────────┤◄─────────────────────────┤
```

- **Control:** D-Bus / MPRIS (and optional `org.lumen.Music`)
- **Data:** bytes → local player → **this user’s** PipeWire
- **Persistence:** daemon stores bookmarks `{track_id, position_ms, queue}` for resume
- **YT access:** unofficial library inside `ytmusicd` only (A16 / ADR-0004)

## Multi-user model

Default: **one stack per user** via `systemd --user`.

```text
User A                         User B
lumen + ytmusicd               lumen + ytmusicd
session bus A                  session bus B
PipeWire A                     PipeWire B
```

Do not design v1 around a system daemon piping audio into each Quickshell.

## Auth broker (sudo / polkit / future device)

Create one **challenge** on **session D-Bus** (A10), fan out to every healthy channel, **first success wins**.

```text
sudo -A → lumen-askpass → AuthChallenge(id)   [session D-Bus]
                                │
              ┌─────────────────┼─────────────────┐
              ▼                 ▼                 ▼
            tty               gui            device/web
         mode=password    (Quickshell)     mode per device
              │                 │                 │
              └──── first Approve/Secret ─────────┘
                                │
                         cancel others
                                │
                         return to sudo
```

- **tty** — controlling terminal when present; typical `mode = "password"`
- **gui** — Quickshell (A9); skip if unhealthy; never DISPLAY-alone (A5)
- **device / web** (later; pairing/transport **A17 decide later**) — each endpoint has its own **mode** (A14): `approve_only`, `totp`, `password`, …
- Offline channels skipped; challenge single-use; timeout default **~15 min** (A12)
- **Deny:** `deny_policy = cancel_all | wait_others` (A8)

```toml
# ~/.config/lumen/auth.toml
[challenge]
timeout_secs = 900
deny_policy = "cancel_all"

[channels.tty]
enabled = true
mode = "password"

[channels.gui]
enabled = true
mode = "password"

[[channels.device]]
id = "phone-1"
enabled = true
mode = "approve_only"

[[channels.device]]
id = "token-app"
enabled = true
mode = "totp"

[[channels.device]]
id = "web-fallback"
enabled = false
mode = "password"
```

See [ADR-0003](adr/0003-multi-channel-auth-broker.md).

## YouTube Music (A16)

`ytmusicd` uses an **unofficial** community/InnerTube-style library for login + stream URLs. Quarantine that dependency in the module; MPRIS + mpv stay the stable boundary. Expect occasional breakage. See [ADR-0004](adr/0004-unofficial-ytmusic.md).

## Module shape (draft contract)

Each backend should aim for:

```text
org.lumen.Module.<Name>
  Start / Stop / Status / Capabilities
  StateChanged signal
  config: ~/.config/lumen/modules/<name>.toml
  unit:   systemd --user
```

Music additionally implements MPRIS2 so generic clients work.

## URL dispatch (A21)

`lumen` is the session's URI/MIME dispatcher, replacing ad-hoc `xdg-open` behavior:

```text
lumen-open (CLI / xdg-open shim)      other apps / shell
            │                              │
            └──────────► org.lumen.OpenURI ◄┘
                              │
                    resolve handler rules
                    (~/.config/lumen/open.toml)
                              │
              ┌───────────────┼────────────────┐
              ▼               ▼                ▼
        explicit id      scheme/mime rule   picker (Quickshell)
              │               │                │
              └───────────────┴────────────────┘
                              │
                        spawn argv (no shell)
```

- `lumen-open <uri|file> [--with <app-id>] [--ask]` is the user-facing entry point; it can be
  installed as the `xdg-open` replacement (or the default handler for `x-scheme-handler/*`).
- Handler resolution order: explicit `--with` → matching rule in config → configured default →
  ask via Quickshell picker → error.
- Rules match on URI scheme, MIME type, and optional glob/regex on the URI or path.
- Apps are declared as `{id, name, exec (argv), mime, schemes}`; desktop entries under the XDG
  data dirs are discovered and can be referenced by desktop-file id.
- The picker UI lives in Quickshell and is configurable (A18/A20); non-GUI sessions get the
  configured default or a clear error, never a hang.
- Spawning uses argv arrays with `execve`-style semantics — no shell string interpolation.

See [ADR-0005](adr/0005-url-dispatch-and-receiver.md).

## URL receiver (A22)

A small intake service inside `lumen` accepts URLs and files from other devices (first target:
Termux on a phone) and feeds them into the same dispatch path:

```text
Termux script ──HTTP(S)/token──► lumen receiver ──staging──► resolve ──► handler
   (curl)                        (localhost/LAN)              (open.toml)
```

- Default bind is **loopback only** (`127.0.0.1:8765`, or a Unix socket under
  `$XDG_RUNTIME_DIR`). LAN access requires explicitly enabling it in config.
- Auth: bearer token from a configured `token_file` (never logged); requests without a valid
  token are rejected. Optional timestamp/nonce to limit replay.
- Payload: JSON `{"url": ...}` for links, or multipart/form-data for file uploads. Files are
  written to a staging dir with sanitized names, size caps, and no path traversal.
- Receiver never executes arbitrary commands; it only creates a dispatch request, so allowlists
  and handler rules apply exactly as for local opens.
- Errors and rejections are logged without secrets and surfaced via D-Bus state for the shell.
- Submissions from unknown/unauthorized peers are dropped, not queued for approval by default;
  an optional "ask first" mode can route them to the Quickshell picker.

See [ADR-0005](adr/0005-url-dispatch-and-receiver.md).

## Security notes (draft)

- D-Bus peer credential checks (same UID) for auth interfaces
- Receiver is loopback by default; tokens come from a file, are compared in constant time, and
  are never logged
- Uploads are size-capped and staged in a dedicated dir; filenames are sanitized; no traversal
- Spawning handlers uses argv arrays, never a shell
- Secrets not logged; prefer daemon-owned storage / keyring over long-lived tokens in shell config
- Session D-Bus for challenge API (A10)

## Diagram index

Deferred (decide later, A17): device pairing and transport. Name and YT approach are locked (A15, A16).
