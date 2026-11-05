{ lib, config, pkgs, ... }:
let
  inherit (lib) mkOption types;
  cfg = config.programs.lumen;
  colors = [ "background" "surface" "foreground" "muted" "accent" "warning" ];
  sizes = [ "radius" "pill_radius" "spacing" "edge" ];
  modules = [ "workspaces" "network" "system" "clock" "launcher" "control_center" ];
in {
  options.programs.lumen = {
    theme = mkOption {
      type = types.submodule {
        options = lib.genAttrs colors (name: mkOption { type = types.str; description = "Lumen ${name} color."; })
          // lib.genAttrs sizes (name: mkOption { type = types.int; description = "Lumen ${name} size in pixels."; })
          // { background_opacity = mkOption { type = types.float; description = "Chrome background opacity from 0.0 to 1.0."; }; };
      };
      default = { };
      description = "Overrides for the Lumen design tokens.";
    };
    modules = mkOption {
      type = types.submodule {
        options = lib.genAttrs modules (name: mkOption { type = types.bool; description = "Show ${name} in the bar."; });
      };
      default = { };
      description = "Lumen bar modules.";
    };
  };
  config = {
    xdg.configFile."lumen/theme.toml" = lib.mkIf (cfg.theme != { }) {
      source = (pkgs.formats.toml { }).generate "lumen-theme.toml" { theme = cfg.theme; };
    };
    xdg.configFile."lumen/shell.toml" = lib.mkIf (cfg.modules != { }) {
      source = (pkgs.formats.toml { }).generate "lumen-shell.toml" { modules = cfg.modules; };
    };
  };
}
