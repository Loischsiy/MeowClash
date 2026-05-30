# Changelog

All notable changes to **MeowClash** will be documented in this file.

## [Recent Updates]

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
