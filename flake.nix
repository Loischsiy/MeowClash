{
  description = "MeowClash Flutter client with NixOS packaging support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      supportedSystems = [
        "x86_64-linux"
      ];
      forAllSystems = lib.genAttrs supportedSystems;
      mkPkgs = system: import nixpkgs { inherit system; };
      mkPackage =
        pkgs:
        pkgs.callPackage ./nix/package.nix {
          buildGoModule = pkgs.buildGo124Module or pkgs.buildGoModule;
          flutter = pkgs.flutter;
        };

      # Throwaway NixOS system used by `checks.<system>.nixos-module-eval`.
      # This is evaluation only: nothing here forces the package to be built,
      # so it fails in seconds when the module stops evaluating.
      mkModuleEval =
        system:
        lib.nixosSystem {
          modules = [
            self.nixosModules.meowclash
            {
              nixpkgs.hostPlatform = system;

              programs.meowclash = {
                enable = true;
                tunMode.enable = true;
              };

              # Minimal scaffolding so a NixOS configuration evaluates at all.
              boot.loader.grub.enable = false;
              fileSystems."/" = {
                device = "/dev/vda1";
                fsType = "ext4";
              };
              system.stateVersion = lib.trivial.release;
            }
          ];
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          meowclash = mkPackage pkgs;
        in
        {
          default = meowclash;
          meowclash = meowclash;
          core = meowclash.core;
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.flutter
              (pkgs.go_1_24 or pkgs.go)
              pkgs.pkg-config
              pkgs.cmake
              pkgs.ninja
              pkgs.gtk3
              pkgs.libayatana-appindicator
              pkgs.keybinder3
            ];
          };
        }
      );

      # `nix flake check` is the NixOS gate for this repository:
      #   nixos-module-eval - cheap, evaluation only; catches a broken module
      #   core / package    - proves the Go core and the Flutter app compile
      #   nixos-vm          - boots real NixOS VMs and exercises the module
      checks = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
          meowclash = self.packages.${system}.default;
          moduleConfig = (mkModuleEval system).config;
          wrapper = moduleConfig.security.wrappers.MeowClashCore;

          expectations = {
            "programs.meowclash.enable installs the MeowClash package" = lib.any (
              pkg: lib.isDerivation pkg && pkg.outPath == meowclash.outPath
            ) moduleConfig.environment.systemPackages;

            "tunMode.enable creates the MeowClashCore capability wrapper" =
              wrapper.capabilities == "cap_net_admin+ep";

            "the capability wrapper is owned by root:root" =
              wrapper.owner == "root" && wrapper.group == "root";

            "the capability wrapper points at the core binary" = lib.hasSuffix "/bin/MeowClashCore" (
              toString wrapper.source
            );

            "corePackage follows programs.meowclash.package" =
              moduleConfig.programs.meowclash.corePackage.outPath == meowclash.core.outPath;
          };

          failures = lib.attrNames (lib.filterAttrs (_name: ok: !ok) expectations);
        in
        {
          inherit (self.packages.${system}) core;

          package = meowclash;

          nixos-module-eval =
            if failures != [ ] then
              throw ''
                The MeowClash NixOS module no longer satisfies:
                  - ${lib.concatStringsSep "\n  - " failures}
              ''
            else
              pkgs.runCommand "meowclash-nixos-module-eval" { } ''
                echo "programs.meowclash evaluates cleanly on ${system}" > "$out"
              '';

          nixos-vm = import ./nix/tests/nixos-module.nix {
            inherit pkgs meowclash;
            nixosModule = self.nixosModules.meowclash;
          };
        }
      );

      nixosModules = {
        default = self.nixosModules.meowclash;
        meowclash = import ./nix/module.nix {
          packageFor = system: self.packages.${system}.default;
        };
      };
    };
}
