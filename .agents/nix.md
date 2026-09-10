# Nix / NixOS

Router: `AGENTS.md`. Go dependency hashes live in `.agents/core-version.md`.

## Build verification

`flake.nix` exposes a `checks` output so NixOS support cannot silently rot.

| Check | Cost | What it proves |
|-------|------|----------------|
| `nixos-module-eval` | seconds, no build | The NixOS module still evaluates and `programs.meowclash` installs the package, wires `corePackage` to `package.core`, and declares the `cap_net_admin+ep` wrapper on the core binary. |
| `core` | Go build | The mihomo core compiles with `buildGoModule`. |
| `package` | Flutter build | The app compiles with `buildFlutterApplication` (this is where `nix/pubspec.lock.json` drift shows up). |
| `nixos-vm` | boots 2 VMs, needs KVM | On a real NixOS system: launcher, desktop entry and icon are installed; the wrapper exports `MEOWCLASH_NIX_PACKAGE`/`MEOWCLASH_CORE_PATH` and puts `/run/wrappers/bin` on PATH; `/run/wrappers/bin/MeowClashCore` carries `cap_net_admin` and actually executes; and with `tunMode.enable = false` no capability wrapper is created. |

The VM test lives in `test/nixos-module.nix` (imported by `flake.nix`). It calls the core with no
arguments and expects the `Arguments error` exit — the cheapest way to prove the ELF loads and links
on NixOS. If you change how the core parses `os.Args`, update that assertion.

Regenerate `nix/pubspec.lock.json` (see `.agents/codegen-and-lint.md`) whenever `pubspec.lock`
changes, otherwise `checks.package` fails.

> **No `flake.lock` is committed.** Every evaluation re-resolves `nixpkgs-unstable`, so a green run
> today can break tomorrow with no code change. Run `nix flake lock` and commit the result to make
> NixOS builds reproducible; CI emits a warning while it is missing and runs the full check weekly on
> a schedule to catch upstream drift.

## The VM nodes pin an LTS kernel

Both nodes import a small `ltsKernel` module that sets `boot.kernelPackages = pkgs.linuxPackages_6_12`.
**Do not remove it to "use a newer kernel".** Because no `flake.lock` is committed, the test otherwise
boots whatever kernel `nixpkgs-unstable` shipped that day, and on 2026-08-17 that was 6.18.44, which
hits `kernel BUG at arch/x86/kernel/alternative.c:2531` in `__text_poke` while `udev` loads
`virtio_net`. The udev worker dies with SIGSEGV, udev wedges, `virtio_blk` never probes,
`/dev/disk/by-label/nixos` never appears, and the VM sits in the initrd until the 300 s device timeout
drops it to `emergency.target`. The kernel is not what this check exercises, so it is pinned rather
than tracked. If that attribute is ever dropped from nixpkgs, move the pin to the current LTS series —
do not fall back to the default kernel.

## Debugging a failed VM test

**Ignore the Python traceback**: `RuntimeError: Shell disconnected` only means the machine stopped
answering. NixOS test instrumentation ships `panic-on-fail.service`
(`wantedBy = [ "emergency.target" ]`), which runs `echo c > /proc/sysrq-trigger`, so any boot failure
ends as a deliberate kernel panic and the traceback always blames whichever `wait_for_unit` was in
flight. The real cause is in the serial console above it:

```bash
nix log /nix/store/<hash>-vm-test-run-meowclash-nixos.drv \
  | grep -E '^(plain|tun) #' \
  | grep -iE 'BUG|Oops|SEGV|Failed to start|Dependency failed|timed out|Out of memory'
```

An `initrd-*` prefix on the failed units means the machine died **before** `pivot_root`, so nothing
about `programs.meowclash` was ever evaluated — look at the kernel and the virtio devices, not at this
repo.

## NixOS TUN mode

Use the flake module when TUN mode is needed on NixOS:

```nix
{
  imports = [ inputs.meowclash.nixosModules.default ];

  programs.meowclash = {
    enable = true;
    tunMode.enable = true;
  };
}
```

The module creates a `/run/wrappers/bin/MeowClashCore` wrapper with `cap_net_admin+ep`. The app package
sets `MEOWCLASH_CORE_PATH=MeowClashCore` and searches `/run/wrappers/bin` before the store core, so TUN
works without trying to mutate the read-only Nix store. If `tunMode.enable` is false, the app must not
attempt to `chown`/`chmod` the store core; it should show the NixOS module hint instead.
