# NixOS integration test for the MeowClash package and the NixOS module.
#
# This boots two real NixOS VMs and asserts that everything the desktop app
# needs at runtime is actually present on a NixOS system:
#
#   * the `meowclash` launcher is installed system wide
#   * the desktop entry and the icon are installed
#   * the launcher wrapper exports the NixOS specific environment
#     (MEOWCLASH_NIX_PACKAGE / MEOWCLASH_CORE_PATH / /run/wrappers/bin in PATH)
#   * with `tunMode.enable = true` the cap_net_admin wrapper exists and the core
#     binary really executes (this is what catches a broken or unpatched ELF)
#   * with `tunMode.enable = false` no capability wrapper is created, so the app
#     must show the NixOS module hint instead of chmod'ing the read-only store
#
# Run with:  nix build .#checks.x86_64-linux.nixos-vm -L
# Requires KVM on the build machine.
{
  pkgs,
  meowclash,
  nixosModule,
}:

pkgs.testers.runNixOSTest {
  name = "meowclash-nixos";

  nodes = {
    # A NixOS machine configured the way AGENTS.md/README tell users to
    # configure it for TUN mode.
    tun =
      { pkgs, ... }:
      {
        imports = [ nixosModule ];

        programs.meowclash = {
          enable = true;
          package = meowclash;
          tunMode.enable = true;
        };

        # `getcap` lives in libcap and is not installed by default.
        environment.systemPackages = [ pkgs.libcap ];

        virtualisation = {
          cores = 2;
          memorySize = 2048;
          diskSize = 4096;
        };
      };

    # The same machine without TUN mode, to make sure the capability wrapper
    # stays opt-in and never leaks into a plain installation.
    plain =
      { ... }:
      {
        imports = [ nixosModule ];

        programs.meowclash = {
          enable = true;
          package = meowclash;
          tunMode.enable = false;
        };

        virtualisation = {
          cores = 1;
          memorySize = 1024;
          diskSize = 2048;
        };
      };
  };

  testScript = ''
    start_all()

    tun.wait_for_unit("multi-user.target")
    plain.wait_for_unit("multi-user.target")

    with subtest("the launcher is installed system wide"):
        tun.succeed("test -x /run/current-system/sw/bin/meowclash")

    with subtest("the desktop entry and the icon are installed"):
        tun.succeed(
            "test -f /run/current-system/sw/share/applications/meowclash.desktop"
        )
        tun.succeed(
            "test -f /run/current-system/sw/share/icons/hicolor/512x512/apps/meowclash.png"
        )
        tun.succeed(
            "grep -q '^Exec=meowclash' "
            "/run/current-system/sw/share/applications/meowclash.desktop"
        )

    with subtest("the launcher exports the NixOS specific environment"):
        launcher = tun.succeed(
            "readlink -f /run/current-system/sw/bin/meowclash"
        ).strip()
        for needle in [
            "MEOWCLASH_NIX_PACKAGE",
            "MEOWCLASH_CORE_PATH",
            "/run/wrappers/bin",
        ]:
            tun.succeed("grep -a -q -F '{}' {}".format(needle, launcher))

    with subtest("tunMode.enable installs a cap_net_admin wrapper"):
        tun.succeed("test -e /run/wrappers/bin/MeowClashCore")
        capabilities = tun.succeed("getcap /run/wrappers/bin/MeowClashCore")
        assert "cap_net_admin" in capabilities, capabilities

    with subtest("the core binary really runs on NixOS"):
        # The core exits 1 with "Arguments error" when called without a port.
        # Getting that far proves the ELF loads and links correctly.
        output = tun.fail("/run/wrappers/bin/MeowClashCore 2>&1")
        assert "Arguments error" in output, output

    with subtest("tunMode disabled leaves no capability wrapper behind"):
        plain.succeed("test -x /run/current-system/sw/bin/meowclash")
        plain.fail("test -e /run/wrappers/bin/MeowClashCore")
  '';
}
