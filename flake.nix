{
  description = "Multi-platform proxy client MeowClash based on ClashMeta";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in {
      packages = forAllSystems (system:
        let
          pkgs = pkgsFor system;
          meowclash-gui = pkgs.callPackage ./package.nix {};
        in {
          default = meowclash-gui;
          meowclash = meowclash-gui;
          meowclash-core = meowclash-gui.core;
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.meowclash}/bin/meowclash";
        };
      });

      devShells = forAllSystems (system:
        let
          pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            buildInputs = with pkgs; [
              flutter
              go
              pkg-config
              libcap
            ];
          };
        });

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.services.meowclash;
          # We need to pick the appropriate package for the system
          pkg = self.packages.${pkgs.system}.meowclash;
        in {
          options.services.meowclash = {
            enable = mkEnableOption "MeowClash multi-platform proxy client";

            tun = {
              enable = mkOption {
                type = types.bool;
                default = true;
                description = ''
                  Enable TUN support via security.wrappers.
                  This grants cap_net_admin to the MeowClashCore binary
                  so that it can create TUN devices without requiring root or setuid.
                '';
              };
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ pkg ];

            security.wrappers = mkIf cfg.tun.enable {
              MeowClashCore = {
                owner = "root";
                group = "root";
                capabilities = "cap_net_admin+ep";
                source = "${pkg.core}/bin/meowclash-core";
              };
            };
          };
        };
    };
}
