# systemd --user units (Phase 0)

The `.service` files here are templates: `@LUMEN@` and `@LUMEN_SHELL@` are replaced with absolute Nix store paths in the default flake output, `result/share/systemd/user/`. Link the **packaged** units with `systemctl --user link`, then `systemctl --user enable --now lumen.service lumen-shell.service` from a graphical session. Re-link on package upgrades. Do not enable these if niri's `spawn-at-startup` is also configured. See `docs/phases/00-skeleton.md`.
