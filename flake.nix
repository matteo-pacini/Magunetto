{
  description = "Magunetto - radial window snapper for GNOME Shell";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";

    # Not following nixpkgs: OpenSpec builds against its own pin (unstable dropped pnpm_9).
    openspec.url = "github:Fission-AI/OpenSpec";
  };

  outputs =
    inputs:
    let
      forAllSystems =
        f: builtins.mapAttrs (system: pkgs: f system pkgs) inputs.nixpkgs.legacyPackages;
    in
    {
      packages = forAllSystems (
        system: pkgs: rec {
          magunetto = pkgs.callPackage ./package.nix { };
          default = magunetto;
        }
      );

      checks = forAllSystems (
        system: pkgs:
        # The virtual-machine test only builds on Linux.
        pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          vm = import ./tests/nixos-test.nix {
            inherit pkgs;
            magunetto = inputs.self.packages.${system}.magunetto;
          };
        }
      );

      devShells = forAllSystems (
        system: pkgs: {
          default = pkgs.mkShell {
            packages = [
              inputs.openspec.packages.${system}.default

              pkgs.gnome-shell # gnome-shell, gnome-shell-test-tool
              pkgs.glib # gdbus, glib-compile-schemas, gsettings
              pkgs.dbus # dbus-run-session
              pkgs.gjs
              pkgs.gtk4 # test windows driven from gjs
              pkgs.nodejs
              pkgs.jq
            ];

            # The ambient GI_TYPELIB_PATH comes from the developer's own GNOME
            # session and mixes typelib versions, which makes gjs abort on a
            # duplicate type. Harness clients use this pinned path instead.
            MAGUNETTO_TYPELIB_PATH = pkgs.lib.makeSearchPath "lib/girepository-1.0" [
              pkgs.glib.out
              pkgs.gobject-introspection.out
              pkgs.gtk4.out
              pkgs.graphene.out
              pkgs.gdk-pixbuf.out
              pkgs.pango.out
              pkgs.harfbuzz.out
            ];

            shellHook = ''
              if [ ! -d openspec ]; then
                openspec init --tools claude,agents --no-animation
              fi
            '';
          };
        }
      );
    };
}
