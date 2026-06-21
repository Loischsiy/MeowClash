# Changelog

All notable changes to **MeowClash** will be documented in this file.

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
