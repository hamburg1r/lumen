# Lumen session daemon (Phases 0–1)

`lumen` owns `org.lumen`: `org.lumen.Daemon.Ping` at `/org/lumen` and `org.lumen.Auth` at `/org/lumen/Auth`. `lumen-askpass` creates a single-use challenge and races TTY and healthy GUI channels; `lumen-auth-gui` provides a stdin-only secret submission helper for Quickshell. Run via `nix run .#lumen` or `nix build .#default` then `./result/bin/lumen`. See `docs/phases/01-askpass.md` for config and tests.
