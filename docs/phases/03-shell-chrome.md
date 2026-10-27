# Phase 3 — Shell chrome

**Status:** not started  
**Depends on:** Phase 0

## In scope

- [ ] Connected canvas layout (edge-to-bar padding, squircle radii)
- [ ] DMS-style workspace pills (pill-shaped workspace indicators)
- [ ] Click-toggle stats widgets (net throughput, CPU/RAM/temp popovers)
- [ ] Control Center panel (notification list with history, caps-lock badge, quick toggles)
- [ ] OSD overlays (volume, brightness, caps-lock)
- [ ] Theme design tokens (colors, radii, spacing, blur) — must be Nix-definable (JSON/TOML, A20)
- [ ] Config-driven module enable/disable in Quickshell
- [ ] Launcher entry point

## Acceptance tests

- [ ] Connected canvas renders seamless bar-to-edge padding with no visible seam
- [ ] Workspace pills update in real time when switching/creating/closing workspaces in niri
- [ ] Clicking a stats widget toggles its popover; clicking elsewhere or clicking again closes it
- [ ] Notification list shows history from `org.freedesktop.Notifications`; dismiss clears entry
- [ ] Caps-lock badge in Control Center reflects daemon state (`org.lumen.Input`)
- [ ] OSD appears on volume/brightness/caps-lock change and auto-hides
- [ ] Overriding a design token in `~/.config/lumen/theme.toml` changes shell appearance without rebuild
- [ ] Disabling a module in config removes it from bar without rebuild
- [ ] Theme tokens live in one obvious place and are settable via Home Manager option

## Notes / blockers

_(fill during implementation)_
