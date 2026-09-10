# Platform gotchas (Windows / MSVC / QuickJS / iOS)

Router: `AGENTS.md`. Why the build code looks the way it does — do not "simplify" any of these.

## Repository-level surprises

- **`plugins/flutter_distributor/` is missing locally?** Expected; it is cloned by CI and by
  `setup.dart`. For local packaging, run the setup script or clone it manually.
- **`libclash/` missing?** It is the build output directory for compiled core binaries and is
  gitignored. `setup.dart` creates it.
- **No `.gitmodules` file exists**, despite the README mentioning
  `git submodule update --init --recursive`. The Go dependency on mihomo is fetched via `go mod`
  (`core/go.mod`). That submodule instruction is stale.
- **Windows helper cross-compilation**: `services/helper` uses
  `cargo build --release --features windows-service`. For `aarch64-pc-windows-msvc`, `setup.dart` adds
  `--target aarch64-pc-windows-msvc`.
- **Download badges live in six READMEs.** `README.md`, `README_RU.md`, `README_UK.md`, `README_FI.md`,
  `README_JA.md` and `README_ZH.md` each carry the same badge block under their `📥` download heading.
  The block is one `<div>` containing compact `<a><img></a>` items at `width="220px"`, arranged two per
  row: GitHub + Obtainium, then a `<br>`, then GitLab + GitVerse. Adding, removing or reordering a
  download channel means editing **all six** — they are not generated from a shared source.
  `README_FI.md` localizes the `alt` text (`Hae GitHubista`, `Hae GitLabista`), the others keep English
  `Get it on X`. These SVGs are referenced only from the READMEs; nothing in `lib/` or `setup.dart`
  reads them.

## Windows packaging

- **Flutter 3.44 removed `--target-platform` from `flutter build windows`**, which now always builds for
  the host. `setup.dart` probes `flutter build windows --help --target-platform` — **not** plain
  `--help`, because the `--analyze-size` description mentions `--target-platform` in prose on every SDK,
  so a substring search reports the flag as present even where it was removed. It forwards
  `--build-target-platform` to the distributor only when the SDK still accepts it *and* the requested
  arch differs from the host; otherwise it verifies the request matches `PROCESSOR_ARCHITECTURE`, the
  same value the distributor uses to find `build/windows/<arch>/runner/Release`. Cross-building Windows
  ARM64 from x64 therefore needs an older SDK. `flutter build linux` still accepts the flag, so Linux
  packaging is unchanged.
- **Inno Setup**: `{{ARCH}}` is never substituted by the packager, so installers used to carry no
  architecture restriction at all. The template now uses the supported `{{ARCHITECTURES_ALLOWED}}` and
  `{{ARCHITECTURES_INSTALL_IN_64BIT_MODE}}`, and `setup.dart` writes `x64`/`arm64` into
  `windows/packaging/exe/make_config.yaml` for the duration of packaging, restoring the original file
  afterwards.

## QuickJS on MSVC — the force-included shim

`native/quickjs/msvc_arm64_math.h` is force-included (`/FI`) into the C sources of the bridge. The file
name is historical: **the shim is not ARM64-only.**

- MSVC compiles parts of `<math.h>` as inline intrinsics, so QuickJS storing those libm addresses in its
  static `Math` table fails with `C2099: initializer is not a constant`. windows-arm64 broke first, then
  MSVC 19.44 (VS 17.14, Windows SDK 10.0.26100) started inlining the same names on x64 and failed on the
  same `quickjs.c` line. The wrappers therefore stay ungated by architecture — **never re-add an
  `_M_ARM64` guard**, because which names MSVC inlines changes with the toolchain/SDK. They still expand
  to nothing in C++ and on every non-MSVC toolchain. `MEOW_QUICKJS_FORCE_MATH_SHIM` exists so the
  wrappers can be compile-checked on a non-Windows host.
- `libregexp.c` and `quickjs.c` call `alloca()` without including `<malloc.h>`, and MSVC only recognises
  the bare name on x86/x64. ARM64 compiled cleanly and then died at link time with `LNK2019`/`LNK2001`
  on `alloca` → `LNK1120: 1 unresolved externals` for `quickjs_c_bridge.dll`. The shim maps `alloca`
  onto `_alloca` on **every** MSVC architecture; C++ is left untouched.
- `native/quickjs/CMakeLists.txt` and `test/build_platforms_test.dart` both encode how the shim is wired
  in; changing one without the other turns CI red (`.agents/testing.md`).

## iOS / signing

- **Swift Package Manager must stay off** (`flutter: config: enable-swift-package-manager: false` in
  `pubspec.yaml`). It is on by default from Flutter 3.44, but its Xcode migration only recognises the
  stock Runner project's object identifiers and aborts on this custom project
  (Runner + PacketTunnel + MeowCore) with `Could not find BuildableReference for Runner`. All native iOS
  dependencies come from CocoaPods and `flutter_js` has no SwiftPM support, so nothing is lost.
  Re-enabling it would require regenerating `ios/Runner.xcodeproj` from Flutter's template.
- **Toolchains**: Windows needs the native Visual Studio C++ toolchain, the Rust target
  `aarch64-pc-windows-msvc` (or `x86_64-pc-windows-msvc`) and Inno Setup with ARM64 support.
  Windows/Linux packaging needs the `plugins/flutter_distributor` checkout; core-only and iOS builds do
  not.
- **The released IPA is unsigned by design.** Resigning only the outer app is not enough: the embedded
  `.appex` needs its own provisioning profile with NetworkExtension (Packet Tunnel) and App Groups
  entitlements. No App Store/TestFlight credentials are configured.
- A green unsigned compile proves nothing about VPN routing, signing, extension memory or provider
  scripts on a real device. Physical-device acceptance for iOS/ARM64 releases belongs in the PR
  checklist, not in a tracked `.md`.
