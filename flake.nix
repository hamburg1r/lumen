{
  description = "Lumen desktop shell (Phase 3)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.quickshell-mcp.url = "github:franklinnolasco7/quickshell-mcp";

  outputs = { self, nixpkgs, quickshell-mcp }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f (import nixpkgs { inherit system; }));
    in {
      packages = forAllSystems (pkgs:
        let
          lumen = pkgs.rustPlatform.buildRustPackage {
            pname = "lumen";
            version = "0.1.0";
            src = ./daemon;
            cargoLock.lockFile = ./daemon/Cargo.lock;
          };
          lumen-shell = pkgs.stdenvNoCC.mkDerivation {
            pname = "lumen-shell";
            version = "0.1.0";
            src = ./shell;
            nativeBuildInputs = [ pkgs.makeWrapper ];
            dontBuild = true;
            installPhase = ''
              mkdir -p $out/bin $out/share/lumen
              cp shell.qml chrome.py $out/share/lumen/
              makeWrapper ${pkgs.quickshell}/bin/quickshell $out/bin/lumen-shell \
                --add-flags "--path $out/share/lumen/shell.qml" \
                --prefix PATH : ${pkgs.lib.makeBinPath [ pkgs.systemd pkgs.python3 pkgs.niri pkgs.fuzzel pkgs.wireplumber pkgs.brightnessctl lumen ]}
            '';
          };
          units = pkgs.runCommand "lumen-user-units" { } ''
            mkdir -p $out/share/systemd/user
            substitute ${./systemd/user/lumen.service} $out/share/systemd/user/lumen.service \
              --replace-fail @LUMEN@ ${lumen}/bin/lumen
            substitute ${./systemd/user/lumen-shell.service} $out/share/systemd/user/lumen-shell.service \
              --replace-fail @LUMEN_SHELL@ ${lumen-shell}/bin/lumen-shell
          '';
        in {
          inherit lumen lumen-shell;
          default = pkgs.symlinkJoin {
            name = "lumen-phase3";
            paths = [ lumen lumen-shell units ];
          };
        });

      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            cargo
            rustc
            quickshell
            niri
            systemd
            dbus
            quickshell-mcp.packages.${pkgs.system}.default
          ];
        };
      });
    };
}
