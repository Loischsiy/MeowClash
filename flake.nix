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

      nixosModules = {
        default = self.nixosModules.meowclash;
        meowclash = import ./nix/module.nix {
          packageFor = system: self.packages.${system}.default;
        };
      };
    };
}
