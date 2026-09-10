# Build system

Router: `AGENTS.md`. Platform quirks that explain *why* this code looks odd: `.agents/platform-gotchas.md`.

The entry point is **`setup.dart`**, not raw `flutter build`. It cross-compiles the Go core, runs
`flutter_distributor` packaging and handles platform-specific steps.

## Local commands

| Task | Command |
|------|---------|
| Android (arm64) | `make android_arm64` or `dart setup.dart android --arch arm64` |
| Android (all ABIs) | `dart setup.dart android` (universal + three split APKs) |
| iOS (arm64, unsigned IPA) | `make ios_arm64` or `dart setup.dart ios --arch arm64` → `dist/MeowClash-<version>-ios-arm64-unsigned.ipa` |
| Windows (arm64) | `make windows_arm64` or `dart setup.dart windows --arch arm64` |
| Linux (arm64) | `make linux_arm64` or `dart setup.dart linux --arch arm64` |
| macOS (arm64) local | `make macLocal` (cleans `dist/` + `build/` first) |
| macOS (amd64) local | `make macLocal_amd64` |
| Core only (skip app) | `dart setup.dart <platform> --arch <arch> --out core` |
| Nix Linux package | `nix build .#meowclash` or `make nixBuild` |
| Nix Linux core only | `nix build .#core` or `make nixCore` |
| NixOS checks (fast, eval only) | `nix flake check --no-build` or `make nixCheck` |
| NixOS VM integration test | `nix build .#checks.x86_64-linux.nixos-vm -L` or `make nixTest` |
| Everything NixOS | `make nixAll` |

## Important build behaviors

- **Android**: builds `libclash.so` (CGO, `c-shared`) for all ABIs (`armeabi-v7a`, `arm64-v8a`, `x86_64`). `setup.dart` produces a universal APK.
- **Desktop** (win/linux/mac): builds a `MeowClashCore` executable (Go, no CGO).
- **Windows**: also builds the Rust `helper.exe` and packages with `flutter_distributor` into `exe` + `zip`.
- **macOS**: uses `create-dmg` to produce a DMG in `dist/`.
- **Linux**: installs `libayatana-appindicator3-dev`, `libkeybinder-3.0-dev`, etc. For amd64 also produces AppImage + RPM.
- **iOS**: `ios/build_core.sh` produces `MeowCore.xcframework`, then Runner + PacketTunnel are compiled into an **unsigned** IPA. Needs full Xcode (Command Line Tools have no iPhoneOS SDK) and CocoaPods. Simulator builds are intentionally rejected.
- **Windows/Linux ARM64**: rebuild the pinned `flutter_js` QuickJS C bridge for the host architecture; the final CMake install rule replaces the dependency's x64-only prebuilt file. Shared pub-cache files and Apple's JavaScriptCore are untouched.
- **Nix/NixOS**: `flake.nix` builds the Go core with `buildGoModule` and the app with nixpkgs `buildFlutterApplication`; it does not use `setup.dart` or `flutter_distributor`. Both `x86_64-linux` and `aarch64-linux` are declared — the old x86-64-only limitation is gone because `native/quickjs/` rebuilds the bridge from checksum-pinned source (a fixed-output download, so no configure-time network access inside the Nix sandbox) instead of relying on the dependency's x64-only `libquickjs_c_bridge_plugin.so`. See `.agents/nix.md`.

## Environment variables

- `ANDROID_NDK` — required for Android. CI resolves it from `ANDROID_NDK_LATEST_HOME` or `ANDROID_HOME/ndk/<latest>`.
- `APP_ENV` — `stable` or `pre`. Controls branding/release behavior.
- `APP_BUNDLE_ID`, `APP_GROUP_ID` — iOS identifiers in `ios/Config/Identifiers.xcconfig`. The extension is always `<APP_BUNDLE_ID>.PacketTunnel`; both targets share `APP_GROUP_ID`.
- `DEVELOPMENT_TEAM` — Apple team id in `ios/Config/Signing.xcconfig`. That file is **gitignored**: never commit it, certificates, private keys or provisioning profiles.

## Running the app locally (desktop)

1. Ensure Flutter and Go are installed.
2. `flutter pub get`
3. Build the core so the executable exists, e.g. `dart setup.dart macos --arch arm64 --out core`.
4. `flutter run` — it looks for the core binary / shared lib in platform-specific paths.

On macOS you may need to codesign the local core binary or relax Gatekeeper for it.
