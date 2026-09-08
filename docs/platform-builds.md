# iOS and ARM64 builds

## Targets

| Platform | Architectures | Outputs |
| --- | --- | --- |
| Android | ARMv7, ARM64, x86-64 | Per-ABI APKs; universal APK when all ABIs are selected |
| Windows | x64 (`amd64`), ARM64 | Architecture-specific installer and portable ZIP |
| Linux | x64 (`amd64`), ARM64 | DEB, RPM, AppImage, portable `.tar.gz` |
| NixOS/Linux | `x86_64-linux`, `aarch64-linux` | Flake app/core packages and checks |
| iOS 15+ / iPadOS 15+ | ARM64 physical devices | Runner + PacketTunnel; unsigned IPA for subsequent signing |
| macOS | Existing x64/ARM64 | Existing DMG workflow, unchanged |

New targets are source/build integrations, not a claim of device certification.
A successful unsigned compile does **not** prove VPN routing, signing, extension
memory use, or provider scripts work on a physical iPhone. Run the device checklist
below before distributing an iOS release. Simulator builds are intentionally rejected.

## Commands

Run from the repository root, after `flutter pub get`:

```sh
# Native host is required for Flutter desktop packaging.
dart setup.dart windows --arch arm64 --env stable
dart setup.dart windows --arch amd64 --env stable
dart setup.dart linux --arch arm64 --env stable
dart setup.dart linux --arch amd64 --env stable

# --arch arm64 now builds only the matching Flutter APK and Go JNI library.
dart setup.dart android --arch arm64 --env stable
# No --arch: ARMv7 + ARM64 + x86-64; universal and three split APKs.
dart setup.dart android --env stable

# On macOS with full Xcode selected, Go, Flutter, and CocoaPods installed:
dart setup.dart ios --arch arm64 --env pre
# Output: dist/MeowClash-<version>-ios-arm64-unsigned.ipa
# Core only:
dart setup.dart ios --arch arm64 --out core
```

The new Windows ARM64/iOS jobs pin Flutter 3.44.1; existing macOS jobs retain
3.35.7. Windows/Linux ARM hosts use a pinned SDK checkout when no stable host
archive is available (`channel: master` on flutter-action is a checkout mechanism,
not a request to build an unpinned moving SDK). Go uses the canonical version in
`core/constant/version.go`; do not edit `lib/core_version.dart` manually.

Windows/Linux packaging also requires the distributor checkout used by the
existing CI. If `plugins/flutter_distributor` is absent, prepare it once:

```sh
git clone --depth 1 https://github.com/leanflutter/flutter_distributor plugins/flutter_distributor
```

The existing packaging routine activates that local Dart tool. Core-only and iOS
builds do not require the distributor checkout.

Windows requires the native Visual Studio C++ toolchain, Rust target
`aarch64-pc-windows-msvc` (or `x86_64-pc-windows-msvc`) and Inno Setup with ARM64
support. Linux packaging installs its existing apt dependencies. Android requires
`ANDROID_NDK`, matching the project's Gradle NDK installation.

Windows/Linux rebuild the pinned `flutter_js` QuickJS C bridge for **both** host
architectures. The final CMake install rule replaces the dependency's x64-only
prebuilt file. Shared pub-cache files and Apple's JavaScriptCore are untouched.
See [native bridge details](../native/quickjs/README.md).

Nix obtains the same checksum-pinned source through a fixed-output download;
there is no configure-time network request inside the Nix sandbox. Existing Go
vendor hash, Flutter lockfile, and the VM test's LTS kernel pin are unchanged.

## iOS signing and installation

1. Select full Xcode (Command Line Tools alone do not include the iPhoneOS SDK).
2. Set a unique `APP_BUNDLE_ID` in `ios/Config/Identifiers.xcconfig`. The extension
   uses `<APP_BUNDLE_ID>.PacketTunnel`; both use `APP_GROUP_ID`.
3. Register the two App IDs and the App Group with your Apple Developer team.
   Enable **Network Extensions / Packet Tunnel** and **App Groups** for both.
4. Create local `ios/Config/Signing.xcconfig` (gitignored):
   ```xcconfig
   DEVELOPMENT_TEAM = YOUR_APPLE_TEAM_ID
   ```
5. Run `flutter pub get`, build the core (`dart setup.dart ios --arch arm64 --out core`),
   then `cd ios && pod install`. Open `ios/Runner.xcworkspace`, select Runner and a
   physical device, and verify signing/provisioning on **both targets**.
6. Build/run or archive using Xcode. The first VPN start displays iOS's VPN consent.

The CI IPA is deliberately named **unsigned**. It is not directly installable;
resigning only the outer app is insufficient. The embedded `.appex` needs its own
matching provisioning profile and NetworkExtension/App Group entitlements. Never
commit certificates, private keys, provisioning profiles, or the local signing file.
This integration does not configure App Store/TestFlight distribution credentials.

## iOS ownership and compatibility

- Dart retains MeowClash's `id / method / data` and `code` protocol, including its
  double-encoded config strings. The newer reference project's protocol was not
  copied into this older core.
- Runner hosts a foreground preview core. PacketTunnel hosts the independent VPN
  core with no Flutter engine. Backgrounding or disposing Flutter does not stop VPN.
- Both use the App Group for profiles/geodata. Each process has its **own BoltDB**
  under `.ios-ui-cache` / `.ios-tunnel-cache`, preventing concurrent ownership of
  a single database. Runner releases preview providers/listeners before VPN starts.
- A successful config, selected proxy map, raw updates, and core state are saved
  atomically for reconnects. Rejected config updates do not replace that snapshot.
- Large requests use bounded UUID-scoped files in the App Group. Only the small
  UUID envelope goes through `sendProviderMessage`; no public TCP control server
  is exposed. Timeouts and normal completions clean files; stale files are pruned.
- Requests/responses are limited to **8 MiB on iOS**. Event storage is bounded to
  **128 events / 256 KiB**, drained only while Flutter is foregrounded. Dropping
  old UI events does not interrupt the tunnel.
- iOS's extension memory allowance is tight. Go has a 32 MiB soft memory limit,
  **not** a guarantee about total RSS. Large geodata, huge rule sets and complex
  transports must be tested on-device; the OS can still terminate an oversized NE.
- The extension owns TUN/DNS/routes; Go receives a duplicated NE socket descriptor.
  Internal auto-routing, process discovery, external-controller and arbitrary
  profile-defined inbound listeners are disabled on iOS. Loopback HTTP/SOCKS ports
  remain available inside the core when running.
- IPv4/IPv6, custom `tun.route-address`, mode, stack, and proxy selection are applied
  through NE/core together. Per-application Android access control and Android's
  system-proxy/allow-bypass switches are not advertised on iOS. Disabling IPv6
  removes IPv6 tunnel routes; it is **not** an IPv6 kill switch.
- Subscription decryption and JS profile/provider transforms stay in existing Dart
  services. Refresh requiring decryption/JS runs while the app is foregrounded;
  there is no Android-style Flutter background service inside PacketTunnel.
- iOS routing is subject to NetworkExtension/OS exclusions. No kill-switch,
  per-app routing, always-on management, or universal leak-prevention guarantee is
  made by this initial integration.

## Verification

```sh
flutter analyze --no-fatal-infos --no-fatal-warnings
flutter test
CGO_ENABLED=0 go -C core test ./...
go -C core test -race ./mobilebridge
python3 -m unittest discover -s scripts -p 'test_*.py'
```

`platform-checks.yaml` also builds/runs the actual native JS bridge on Windows and
Linux x64/ARM64, cross-builds desktop Go cores, and compiles both iOS targets on a
macOS/Xcode runner. `build.yaml` includes manual iOS/Windows ARM64 builds;
`release-all.yaml` includes their distinctly named artifacts. Asset normalization
rejects ambiguous architecture labels/collisions instead of overwriting binaries.

### Required physical-device checks

- Fresh install and VPN permission denial/retry; verify clear App Group/signing errors.
- Import encrypted and plain subscriptions; execute the existing profile JS transform.
- Start, rapid start/stop/start, and cancel while consent/connection is pending.
- Background/lock/force-close UI while connected; re-open and verify status/traffic
  reflect the extension. Stop/start from iOS Settings while the app is suspended.
- Reboot/unlock, then reconnect from Settings using the saved selected proxy/profile.
- Wi-Fi/cellular changes, IPv4/IPv6, DNS, custom routes, UDP, and each supported TUN stack.
- Switch proxy/config while connected; deliberately fail a reload and confirm rollback.
- Refresh encrypted providers, verify the updated cache is used after reconnect.
- Stress a large profile under memory pressure; examine PacketTunnel logs/jetsam reports.
- Windows/Linux ARM64: launch the packaged app, transform a JS profile, start/stop TUN;
  confirm executable, helper and `quickjs_c_bridge` machine types, not only file names.


## Validation recorded (2026-09-08)

- Flutter 3.44.1 / Dart 3.12.1: 167 tests passed, including the new iOS protocol
  and build-target tests. Analysis has no errors; its four pre-existing warnings
  remain (unused isolate imports and existing main.dart diagnostics).
- Go 1.26.0: core/transport tests, mobilebridge race tests and vet passed.
- Go cores cross-compiled for Linux and Windows, each amd64 and arm64.
- Native QuickJS bridge compiled and executed its ten-cycle ABI/evaluation smoke
  on an ARM64 Mac. This validates the source/ABI on that host, not Windows/Linux
  packaging. CI also runs real Dart profile transformations on all four desktop
  OS/architecture combinations against their newly built native libraries.
- iOS Go bridge API compiled in a macOS-only overlay harness. Swift parsing and
  shared/PacketTunnel type checks passed against macOS system frameworks; the
  Runner service was type-checked with a Flutter-channel stub. These checks do
  **not** replace an iOS SDK build, linking, signing, or device testing.
- Release filename tests passed (5); iOS plist/XML/asset metadata and generated
  opaque 1024px app icon were checked.
- Full Xcode/iPhoneOS SDK is absent on the available machine. Unsigned iOS app,
  Windows/Linux installers, ARM64 Rust helper and Nix outputs still require their
  target CI/host builds. No workflow, release, signing or repository push was run.
