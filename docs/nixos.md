# MeowClash on NixOS

MeowClash has first-class NixOS support, implementing an architecture similar to the `throne` package in nixpkgs. The application separates the GUI component from the Core binary and does not attempt to modify binaries or execute `sudo` at runtime.

Instead of `setuid`, MeowClash takes advantage of Linux capabilities (`cap_net_admin`) to support TUN mode natively without needing root privileges.

## Usage in Flake

You can include MeowClash in your NixOS configuration by consuming the flake directly:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    meowclash.url = "github:Loischsiy/MeowClash";
  };

  outputs = { self, nixpkgs, meowclash, ... }: {
    nixosConfigurations.my-machine = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        # ... your other configuration ...

        # 1. Include the meowclash NixOS module
        meowclash.nixosModules.default

        ({ config, pkgs, ... }: {
          # 2. Enable the service
          services.meowclash = {
            enable = true;
            tun.enable = true; # Automatically configured via security.wrappers
          };
        })
      ];
    };
  };
}
```

## How TUN Works on NixOS

When you enable `services.meowclash.tun.enable`, the MeowClash NixOS module automatically adds a security wrapper for `MeowClashCore` to your system.

```nix
security.wrappers.MeowClashCore = {
  owner = "root";
  group = "root";
  capabilities = "cap_net_admin+ep";
  source = "${meowclash-core}/bin/meowclash-core";
};
```

This ensures that the core binary has the `cap_net_admin` capability needed to create and configure the TUN device, but without making the entire binary `setuid` or requiring you to type your `sudo` password each time the application starts.

MeowClash discovers the correct path to the core automatically via `$PATH`. The launcher wrapper ensures both `/run/wrappers/bin` and the standard nix store binary path are prioritized correctly.
