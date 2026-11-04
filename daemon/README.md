# Lumen session daemon (Phase 0)

`lumen` owns the session bus name `org.lumen` and exports `org.lumen.Daemon.Ping` at `/org/lumen`. It responds with `"pong"`. It currently has no other responsibilities. Run via `nix run .#lumen` or `nix build .#default` then `./result/bin/lumen`. See `docs/phases/00-skeleton.md`.
