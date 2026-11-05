# Phase 3 — Shell chrome

**Status:** accepted; brightness OSD waived on hardware without a backlight
**Depends on:** Phase 0

## In scope

- [x] Connected canvas layout (edge-to-bar padding, rounded radii)
- [x] DMS-style workspace pills (pill-shaped workspace indicators)
- [x] Click-toggle stats widgets (net throughput, CPU/RAM/temp popovers)
- [x] Control Center panel (notification history, daemon caps-lock badge, volume mute toggle)
- [x] OSD overlays (PipeWire volume events; sysfs brightness, daemon caps-lock polling)
- [x] Theme design tokens (colors, radii, spacing, transparent background as user-requested blur substitute)
- [x] Config-driven module enable/disable in Quickshell
- [x] Launcher entry point (`fuzzel`)

## Acceptance tests

- [x] Connected canvas renders seamless bar-to-edge padding with no visible seam (user confirmed no bar/popover gap or seam)
- [x] Workspace pills update in real time when switching/creating/closing workspaces in niri (user-confirmed)
- [x] Clicking a stats widget toggles its popover; clicking elsewhere or clicking again closes it (user confirmed gap/inside-click fixes)
- [x] Notification list shows history from `org.freedesktop.Notifications`; dismiss clears entry (test notification displayed and × removal user-confirmed)
- [x] Caps-lock badge in Control Center reflects daemon state (`org.lumen.Input`; user confirmed live transition)
- [x] OSD appears on volume/caps-lock change and auto-hides (volume OSD and caps detection user-confirmed; brightness explicitly waived on this machine)
- [x] Overriding a design token in `~/.config/lumen/theme.toml` changes shell appearance without rebuild (orange accent user-confirmed)
- [x] Disabling a module in config removes it from bar without rebuild (network widget hidden, then returned when temporary override was removed; user-confirmed)
- [x] Theme tokens live in one obvious place and are settable via Home Manager option (`home-manager/lumen.nix`; static option evaluation confirms both TOML files are generated)

## Notes / blockers

`shell/chrome.py` samples `/proc` CPU/memory/network and thermal sysfs every two seconds.
Niri workspace updates come from `niri msg -j event-stream` and are sorted by output
and index. PipeWire volume and mute changes use Quickshell's bound default sink;
`chrome.py watch-input` reads `org.lumen.Input.GetCapsLock` from the daemon and
brightness from sysfs about every 150 ms. Missing optional sources yield unavailable
readings instead of crashing. If the daemon is stopped, caps-lock is unavailable.
The helper also reads `theme.toml` and
`shell.toml` every three seconds; invalid/unreadable files retain defaults. The
`background_opacity` token defaults to 0.88 (0.0–1.0) for the bar, popover, and OSD;
each layer has a stable namespace (`lumen:bar`, `lumen:popup`, `lumen:osd`) for
compositor-side rules. This is transparency, not a promise of actual background blur.
The packaged shell includes these dependencies.

The daemon owns `org.freedesktop.Notifications`, serves `Notify`, `CloseNotification`,
`GetCapabilities`, and `GetServerInformation`, and keeps up to 100 entries in memory;
`org.lumen.Notifications.GetHistory` returns JSON and `Dismiss` removes an entry and
emits `NotificationClosed`. Action buttons are carried in the history; activating one
emits `ActionInvoked` to the originating client and clears the entry. An isolated
`notify-send -A` smoke test confirmed the action key arrives at the client. History
persists across daemon restarts in `${XDG_STATE_HOME:-~/.local/state}/lumen/notifications.json`
(private directory 0700, file 0600, atomic replacement). Action buttons are removed
on restart because their original client is no longer connected. Unit tests and an
isolated D-Bus restart test confirmed persistence and dismissal. The daemon
must acquire `org.freedesktop.Notifications` on startup; stop any competing notification
server first. `org.lumen.Input.GetCapsLock` reads the session's caps-lock LED state.
The Control Center offers a mute toggle and notification dismissal; additional quick
toggles and true squircle geometry are not implemented. The user chose transparency
plus layer-shell namespaces instead of a compositor-specific backdrop blur effect.
An input-catching surface below the bar dismisses the popover/Control Center on an
outside click; the Control Center now begins directly below the bar. The launcher
button ignores duplicate clicks while fuzzel is running; opening the Control Center
closes that launcher. The user confirmed the resulting layout and dismissal behavior.
The overlay ignores the bar's layer-shell exclusion zone before applying its 56px
top margin, preventing a clickable 56px gap; the popup absorbs its own clicks rather
than forwarding them to the outside-click handler. Both fixes were user-confirmed.
CPU/network stats can still lag by up to two seconds. The Rust unit test and an
isolated `dbus-run-session` test covered notification delivery, history, dismissal,
and the input method. No visual acceptance tests are marked passed without a live check.

User feedback confirmed quicker workspace/caps updates and improved Control Center
placement/dismissal. A Quickshell runtime warning revealed that the volume OSD's
initialization handler was never firing; the handler has been corrected, and the user
confirmed that volume OSD appears and auto-hides. Debug via
`quickshell ipc --path <installed-shell.qml> call status volume` (`ready N%` or
`unavailable`) and `... call status osd` (the visible OSD text or `hidden`).
Brightness on systems without `/sys/class/backlight` is unavailable, not 0%.
The live daemon `GetCapsLock` and Quickshell IPC `status caps` both returned `false`
at the same instant; the user also confirmed a real Control Center badge transition.
The user confirmed transparency and the seamless bar/popover join after restarting
the shell. An isolated Quickshell MCP runtime lacked a compositor; QML validation via
the MCP timed out fetching docs, so the Nix build, qmllint, and helper tests covered
the final edit.
