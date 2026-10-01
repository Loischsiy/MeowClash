# Changelog

All notable changes to **MeowClash** will be documented in this file.

## [v1.1.1]

### ✨ New Features
- **Site Availability Widget**: Added dashboard cards and a full categorized page (ported from Bettbox) that check AI, streaming, social, developer, gaming, and crypto services through the current node. Blocked or unreachable sites show a block icon and "Unavailable" instead of latency; checks run only while the core is running and pause in the background.
- **Roblox Check**: Added Roblox to the Gaming category with latency to the Roblox gateway (`www.roblox.com`) and the exit country as seen by Roblox's Cloudflare-fronted help centre.
- **Core Status Dialog**: Tapping the memory card now opens a core status dialog (ported from Bettbox) with a memory ring, allocated/reclaimable memory, goroutines, heap objects, rule/proxy/provider counts, GEO usage, and separate Flutter shell and core RAM stats. It polls only while open and in the foreground, and manual GC moved from the card tap into the dialog.
- **URL-Test Concurrency Setting**: Added a General setting to change how many proxy delay tests run in parallel (0 = unlimited, up to 1000); the Go core limiter now follows the value sent with each request.

### 🚀 Improvements
- **Core**: Updated mihomo proxy engine to version 1.19.32.
- **Delay Testing**: Raised the default URL-test concurrency on Windows, macOS, and Linux from 10 to 32; Android and iOS keep 10.
- **Navigation**: Added a fade transition when `NavigationPageView` jumps more than one page away.
- **Docs**: Updated `flutter analyze` flags in `AGENTS.md` to ignore info and warning levels.

## [v1.1.0]

### ✨ New Features
- **iOS & ARM64 Support**: Added official iOS build target with NetworkExtension packet tunnel provider support (physical devices, unsigned IPA) and full ARM64 support across Windows, Linux, and iOS.
- **Dashboard**: Added IP details dialog displaying country, region, city, and connection domain via ipwho.is with offline country name localization across all six app languages (Unicode CLDR) and 5-minute LRU caching.
- **Core Delay Testing**: Implemented bounded delay testing queue in the Go core with platform concurrency limits and optimized Flutter delay testing UI for large proxy lists.
- **Android Provider Refresh**: Moved automatic and manual encrypted HTTP proxy and rule provider updates to the Android VPN service-engine isolate with immutable proxy snapshots and separated candidate namespaces.
- **UI Suspension**: Added window lifecycle management (`UiLifecycleController`, `SuspendableUi`, `UiActivityScope`) to suspend UI rendering and idle polling loops when the window is hidden.

### 🐛 Bug Fixes
- **QuickJS / MSVC**: Added and configured MSVC math shim (`msvc_arm64_math.h`) and alloca resolution for QuickJS to resolve C2099 static Math table initializer errors on MSVC across all architectures (x64 and ARM64).
- **Windows Packaging**: Adapted Windows installer and setup scripts for Flutter 3.44+ changes, improved Windows ARM64 cross-build detection, and restricted installers to target architecture.
- **Subscriptions**: Auto-select and activate the default subscription on first launch when saving via EditProfileView if no profile is currently active.

### 🚀 Improvements
- **Core**: Updated mihomo proxy engine to version 1.19.31 and refreshed Go dependencies.
- **Diagnostics**: Detailed TLS failure diagnostics when downloading subscriptions, providers, or updates with explicit error causes (expired certificate, hostname mismatch, untrusted chain, self-signed certificate).
- **Performance**: Reduced idle CPU and memory usage by removing the forced Go GC, coalescing reclaims via a single-flight memory gate, moving profile script evaluation to short-lived isolates, and introducing lifecycle-aware polling.
- **Flutter Hardening**: Configured explicit image-cache budgets, explicit FFI allocator ownership for synchronous core config APIs, and CommonTargetIcon caching surviving rebuilds.
- **Testing & CI**: Consolidated tests into `test/`, added CI workflows for iOS builds, ARM64 platform checks, and native QuickJS testing across Ubuntu and Windows runners.
- **Documentation**: Restructured project documentation by splitting `AGENTS.md` into a lean router with modular `.agents/` topic guides and removing the obsolete `docs/` folder.
- **Releases**: Updated download badges, removed redundant checksum sidecars from release workflows, and updated Nix vendorHash.

## [v1.0.8]

### ✨ New Features
- **Android**: Added boot receiver for VPN auto-start on boot/update.
- **Profiles**: Added decryption support when updating URL profiles.

### 🐛 Bug Fixes
- **Windows**: Properly quote helper path in service binPath to avoid path parsing issues.
- **NixOS**: Pinned kernel to 6.12 LTS for VM test stability.

### 🚀 Improvements
- **Core**: Updated mihomo proxy engine to version 1.19.30 and refreshed Go dependencies.
- **Core**: Updated utls for newer browser fingerprints (Firefox 148, Safari 26.3).
- **Android**: Replaced flutter_launcher_icons with manual adaptive icon and splash setup; replaced FlClashX art with MeowClash paw logo.
- **Dependencies**: Updated re_editor to 0.10.0.
- **Build**: Use default Flutter package from nixpkgs for Nix builds.
- **CI**: Added NixOS verification workflow with integration tests; added test environment option to release workflow.
- **Docs**: Added mihomo version bump checklist and vendorHash update guide.

## [v1.0.7]

### ✨ New Features
- **Localization**: Added complete Finnish language support for the app and documentation.
- **Android**: Added permission handling and short-lived caching when reading installed applications.

### 🐛 Bug Fixes
- **Core Input**: Added file-size validation when selecting core input files.

### 🚀 Improvements
- **Core**: Updated mihomo proxy engine to version 1.19.29 and refreshed Go dependencies.
- **Subscriptions**: Removed the legacy `meowclash-*` provider-override system while preserving subscription decryption.
- **Notifications**: Simplified foreground notification handling and removed obsolete server-name caching.
- **Docs**: Added an Obtainium badge and switched the GitLab badge to the bundled asset.

## [v1.0.6]

### ✨ New Features
- **Proxy Chains**: Added support for group hops in chains, including inline groups, runtime-selected groups, and provider-backed groups.
- **Sync**: Added token authentication for Send to TV profile transfer.
- **Profiles**: Added YAML merge key (`<<`) support when reading profile and provider data.

### 🐛 Bug Fixes
- **Security**: Hardened backup recovery so archives can restore only safe profile entries and cannot write outside the profiles directory.
- **Core**: Added a 16 MiB input guard for profiles, providers, subscriptions, and core config operations.
- **Proxies**: Fixed proxy group drill-down behavior, hidden group visibility, and selection cycle handling.
- **Proxy Chains**: Skipped invalid proxy definitions without a valid `type` field instead of building broken chains.

### 🚀 Improvements
- **Core**: Updated mihomo proxy engine to version 1.19.29 and refreshed Go dependencies.
- **Release**: Added GitLab release publishing and updated download links to GitHub/GitLab release pages.
- **Internal**: Improved shell command handling safety and added focused tests for backup recovery, core input limits, and proxy chains.

## [v1.0.5]

### ✨ New Features
- **Linux Packaging**: Added portable `tar.gz` builds and custom AppImage packaging with an updated AppRun execution path.
- **Linux**: Improved graphics initialization and ensured `/dev/net/tun` exists before enabling TUN mode.
- **Proxy Chains**: Added multi-hop proxy chain support with chain mode.
- **Sync**: Integrated concurrent IP checks, atomic saving, and more robust Send to TV sync from PR #96.

### 🐛 Bug Fixes
- **Security**: Removed a shell injection risk in privilege escalation and hardened backup archive path validation.
- **Linux**: Improved proxy error handling, TUN mode support, and core authorization with better `setcap` path resolution.
- **CI**: Dropped `custom_lint` / `riverpod_lint` to avoid the analyzer plugin crash during `build_runner`.

### 🚀 Improvements
- **UI**: Switched the default app font to Noto Sans with JetBrains Mono fallback, added the Noto Sans variable font, set JetBrains Mono on Linux, improved text input and clipboard handling, and made form text fields height-consistent.
- **Dashboard**: Removed the ServiceInfo and ChangeServer widgets.
- **Docs**: Added distro-specific Linux install tips and refreshed agent documentation with the CLAUDE guide.
- **Dependencies**: Bumped dependency versions.
- **Release**: Bumped app version to `1.0.5+20260620`.

### 🧹 Internal
- Removed dead widget builders, an unused YAML conversion utility, commented-out listener mixins, and unused models.
- Added unit tests for ProxyChain and OverrideData chains.
- Updated `.gitignore` so `CLAUDE.md` and `.fvmrc` are tracked.

## [v1.0.4]

### ✨ New Features
- **External Providers**: Added pre-download, decryption, and background auto-update support for proxy and rule providers.
- **Nix/NixOS**: Added flake packaging, a dev shell, a core-only package, and a NixOS module with TUN capability support.
- **Linux**: Added automatic cleanup of stale TUN devices during core initialization.

### 🐛 Bug Fixes
- **Security**: Prevented path traversal during profile extraction.
- **Android**: Improved battery optimization prompts, VPN permission handling, DNS management, and foreground service configuration.
- **Core**: Added automatic core restart with exponential backoff after unexpected process exits.
- **NixOS**: Fixed module command quoting and package system detection.

### 🚀 Improvements
- **Core**: Updated mihomo proxy engine to version 1.19.27 and refreshed Go dependencies.
- **Release**: Standardized release asset names, fixed RPM release links, and consolidated Android releases to a single universal APK.
- **Build**: Added GOARM configuration, automatic Linux build output renaming, AppImage launcher verification, and Android compileSdk 36.
- **Docs**: Refreshed README documentation and added multi-language README files.

## [v1.0.3]

### ✨ New Features
- Added Ukrainian language support.
- Localization improvements: Simplified and stabilized localization, localized "time ago" strings.

### 🐛 Bug Fixes
- **Desktop**: Prevented zombie process states on exit and suppressed socket errors.
- **Android**: Improved VPN TUN stability and applied general stability fixes.
- **Security**: Removed insecure global certificate validation (`badCertificateCallback`).
- **Service**: Isolated service engine method channel to maintain traffic updates and allow VPN stop when main UI is closed.

### 🚀 Improvements
- **Performance**: Optimized membership check in `SubscriptionNotificationService` and implemented asynchronous file reading for Profiles.
- **Core**: Updated Clash core to version 1.19.26.
- **HotKeys**: Refactored HotKey handling to use logical keys for better compatibility.

### 🧹 Internal
- Refactored subscription handling: Removed `meowclash-*` override headers while preserving subscription decryption.
- Updated default application settings.
- Cleaned up dead code and unused methods in theme builder and UI components.
- Removed legacy patch scripts (`patch_safe_ui.py`, etc.).

## [v1.0.2]

### ✨ New Features
- **Subscription Normalization**: You can now use V2Ray-style subscription links; they will be automatically converted into valid Clash profiles.

### 🐛 Bug Fixes
- **Windows**:
  - Fixed an annoying infinite UAC (User Account Control) prompt loop.
  - Fixed the application icon (no more old icons!).
- **macOS**:
  - Fixed the application icon display.
  - Resolved an issue that prevented the app from launching on some macOS versions.
- **Profiles**: Fixed a bug where profile encryption was not being applied correctly.

### 🚀 Improvements
- **Desktop Dashboard**: TUN and proxy panel buttons are now visible by default for quicker access.
- **Windows**: Optimized installation packaging and update workflows for a smoother experience.
- **macOS**: Added necessary system permissions for file access and network connectivity.
- **Android**: Updated internal package name to `com.meowclash.app` (internal migration).
- **Core**: Improved error messages and visibility when TUN mode fails to start.
- **Internal**: Refactored internal communication bridges (JNI) and standardized build configurations.

---
