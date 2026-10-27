# ADR-0005: URL dispatch and remote URL receiver

## Status

Draft (aligned with agreed decisions A21, A22; drafts D13)

## Context

Desktop sessions need to open links and files in the "right" application. `xdg-open` exists, but
its behavior is opaque and hard to customize per user or per NixOS/Home Manager configuration
(A20). The user also wants to send URLs or files from a remote device — first target is a Termux
script on a phone — and have them handled by the desktop with the same custom rules.

Two related problems:

1. **Dispatch** — resolve an input (URI, file path, MIME type) to a handler, optionally letting
   the user pick when several candidates exist. This should be the default `xdg-open`
   replacement and usable from the shell.
2. **Intake** — accept submissions from other devices over the network without opening an
   arbitrary remote-execution surface.

## Decision

Put both in the Rust `lumen` session daemon (A2), exposed on session D-Bus under `org.lumen`.

### Dispatch

- Interface `org.lumen.OpenURI`:
  - `Open(uri, options) -> request_id`
  - `OpenWith(uri, app_id) -> request_id`
  - `Ask(uri) -> request_id` (always show the picker)
  - `StateChanged` / `Completed(request_id, result)` signals
- CLI `lumen-open <uri|file> [--with <app-id>] [--ask]` is a thin D-Bus client. It can be installed
  as the `xdg-open` shim or registered as the default `x-scheme-handler/*` / MIME handler.
- Resolution order:
  1. explicit `--with` / `app_id`
  2. matching rule in `~/.config/lumen/open.toml`
  3. configured default for the scheme/MIME
  4. "open with…" picker in Quickshell when a GUI is healthy
  5. error (non-GUI sessions never hang waiting for a picker)
- Rules match on scheme, MIME type, and optional glob/regex against URI or path. Desktop entries
  from the XDG data dirs are discovered and addressable by desktop-file id; users can also
  declare custom apps with argv templates.
- Handlers are spawned as **argv arrays** (`execve` semantics). No shell interpolation, no
  `sh -c` of user-supplied strings.
- The picker UI lives in Quickshell (A9/A18) and is driven by the same config (A20). It shows
  candidate apps, "always use this" persistence, and cancel.

### Receiver

- Interface `org.lumen.UrlReceiver` for status/config reload, plus an HTTP(S) listener.
- Transport: HTTP with bearer token; Unix socket is also supported. Default bind is loopback
  (`127.0.0.1:8765`). LAN binding requires explicit opt-in in config. Draft D13.
- Endpoints:
  - `POST /v1/open` — JSON `{"url": "...", "app_id": "..."?}`
  - `POST /v1/upload` — multipart file upload; saved to staging and dispatched as a file open
  - `GET /v1/health` — unauthenticated liveness only (no secrets)
- Auth: token read from `token_file`; constant-time comparison; never logged. Optional
  timestamp/nonce to limit replay. Requests from unauthorized peers are rejected.
- Uploads: size cap (`max_bytes`), sanitized filename, dedicated staging dir under
  `$XDG_RUNTIME_DIR/lumen/incoming` (fallback `$XDG_DATA_HOME/lumen/incoming`), no traversal,
  optional TTL cleanup. Files are dispatched through the same handler rules — the receiver never
  executes commands directly.
- Default behavior for unknown senders is **drop**; an optional "ask first" mode routes to the
  Quickshell picker.
- The Termux side is a small `curl` script (`scripts/termux-send.sh`) that posts a URL or uploads
  a file with the token. SSH tunneling remains a valid deployment option.

### Configuration (draft shape)

```toml
# ~/.config/lumen/open.toml
[defaults]
browser = "firefox.desktop"
file_manager = "org.gnome.Nautilus.desktop"
ask_when_ambiguous = true

[handlers.media]
mime = ["video/*", "audio/*"]
exec = ["mpv", "--"]
schemes = []

[[handlers.custom]]
id = "my-editor"
name = "My Editor"
exec = ["kitty", "nvim"]
mime = ["text/*"]

[rules]
"https" = "firefox.desktop"
"magnet" = "transmission.desktop"
"application/pdf" = "org.gnome.Evince.desktop"

[receiver]
enabled = true
bind = "127.0.0.1:8765"
token_file = "~/.config/lumen/receiver.token"
max_bytes = 268435456
ask_unknown = false
```

## Consequences

- One dispatcher for local opens and remote intake; custom rules map directly to Nix/Home Manager.
- The receiver adds a network surface to a session daemon: mitigated by loopback default, token
  auth, size caps, sanitization, and no shell execution.
- Replaces `xdg-open` only when the user opts in; coexistence is fine.
- Device pairing/transport for auth (A17) remains separate and deferred; the receiver does not
  depend on it.
- Quickshell is needed only for the picker; dispatch and receiver work headless with defaults.

## Alternatives considered

- Extend `xdg-open` / `handlr` / `mimeopen` as external tools — no single owner for remote intake,
  weaker config mapping, and inconsistent GUI picker integration.
- A separate `lumen-open` system service — violates per-user model (A3) and duplicates D-Bus setup.
- Receiver as a public unauthenticated endpoint — rejected; arbitrary URL injection and uploads.
- Remote command execution API — rejected; only URI/file dispatch is allowed.
