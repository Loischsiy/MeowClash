# Changelog

All notable changes to **MeowClash** will be documented in this file.

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
