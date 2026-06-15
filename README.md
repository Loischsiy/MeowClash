<div align="center">

# MeowClash

[![Downloads](https://img.shields.io/github/downloads/Loischsiy/MeowClash/total?style=flat-square&logo=github&color=b966cf)](https://github.com/Loischsiy/MeowClash/releases/)
[![Last Version](https://img.shields.io/github/release/Loischsiy/MeowClash/all.svg?style=flat-square&color=8c52ff)](https://github.com/Loischsiy/MeowClash/releases/)
[![License](https://img.shields.io/github/license/Loischsiy/MeowClash?style=flat-square&color=4296f4)](LICENSE)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-e84393?style=flat-square)](#download)

**English** | [**Русский**](README_RU.md) | [**Українська**](README_UK.md) | [**日本語**](README_JA.md) | [**简体中文**](README_ZH.md)

</div>

---

**MeowClash** is a modern, feature-rich, and open-source multi-platform proxy client based on the **ClashMeta (mihomo)** core. It provides a beautiful Material You UI for managing your proxy connections, is completely ad-free, and runs natively on Android, Windows, macOS, and Linux.

*MeowClash is a fork of the excellent [FlClashX](https://github.com/pluralplay/FlClashX) project.*

---

## 📸 Preview

### Desktop
<div align="center">
  <img alt="MeowClash Desktop Interface" src="snapshots/desktop.gif" width="85%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

### Mobile
<div align="center">
  <img alt="MeowClash Mobile Interface" src="snapshots/mobile.gif" width="35%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

---

## 🎨 Key Features

### ✨ UI & Styling (Material You)
- **Material 3 Interface**: Clean, modern, adaptive UI inspired by Surfboard.
- **Dynamic Themes**: Multiple color schemes (TonalSpot, Fidelity, Monochrome, Neutral, Vibrant, Expressive, Content, Rainbow, FruitSalad) supporting dark mode, light mode, and pure black mode.
- **Adaptive Spacing & Columns**: Customize layout density (tight, standard, loose) and grid columns (1 to 4 columns) depending on your device's screen size.
- **Responsive Layout**: Seamless transition between mobile and desktop layouts.

### ⚙️ Proxy Engine (ClashMeta / mihomo)
- **High-Performance Core**: Uses the powerful Go-based `mihomo` core under the hood.
- **Outbound Modes**: Supports `Rule`, `Global`, and `Direct` routing.
- **Real-Time Statistics**: Dynamic network speed charts (Upload/Download) and overall traffic monitoring.
- **Proxy Provider Controls**: Sort proxy nodes by delay, name, or default configuration.
- **Auto-Close Connections**: Automatically terminate active connections when switching proxy nodes.

### 🛡️ Network & Advanced Core Options
- **System Proxy**: Easily toggle system-wide proxy settings for Windows and macOS.
- **TUN Mode**: Route all system-level network traffic via a virtual network adapter (requires Administrator/root privileges).
- **Split Tunneling (Access Control)**: (Android) Whitelist or blacklist specific applications, and filter system apps.
- **DNS Override**: Customize nameservers, default nameservers, fallbacks, proxy nameservers, and force DOH (DNS-over-HTTPS) HTTP/3 prioritization.
- **LAN Access (AllowLan)**: Allow other devices on the local network to connect through your proxy.
- **Bypass Domains**: Set list of domains that should bypass the system proxy.
- **IPv6 Support**: Fully toggle IPv6 inbound traffic routing.
- **Low Memory Loader**: Enable Go Low Memory mode for Geo databases to save resources.

### ☁️ Sync, Encryption & Provider Features
- **WebDAV Synchronization**: Backup and restore your configuration and profiles remotely.
- **Encrypted Subscription Decryption**: Decrypt base64-encoded encrypted subscriptions (AES-256-CBC, key derived via PBKDF2) using custom headers `meowclash-password` and `meowclash-password-iterations`.
- **Custom Header Processing**:
  - `announce`: Displays custom notifications/announcements to users.
  - `support-url`: Provides direct support links in the profile details.
  - `profile-update-interval`: Enforces specific subscription auto-update intervals.
  - `x-hwid-limit`: Shows device limit warnings with a dedicated hardware-ID registration dialog.

### 💻 Desktop Integration & Extra Utilities
- **Minimize to System Tray**: Keeps running quietly in the background when the main window is closed.
- **Autostart Settings**: Set to Auto-run, Auto-launch (start on boot), and Silent-launch (start hidden).
- **Global Hotkeys**: Bind keyboard shortcuts for showing/hiding the window, starting/stopping VPN, toggling proxy modes, and controlling TUN mode.
- **UWP Loopback Unlocker**: (Windows) Tool to easily enable loopback network access for Windows Store (UWP) apps.
- **Send to TV (TV Sync)**: Share configuration profiles to Android TV/Smart TVs easily using QR code scanning or network transfer.
- **Diagnostic Tools**: Live request viewer, connection details manager, detailed logs console with export capability, and clean data reset options.

---

## 🔧 OS-Specific Requirements

### Linux
Before running the application, make sure to install the required system libraries:
```bash
sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev
```

### NixOS (Flake)

If you are using NixOS, you can use the provided Flake input and NixOS module.

Add the input to your `flake.nix`:
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    meowclash.url = "github:Loischsiy/MeowClash";
  };

  outputs = { self, nixpkgs, meowclash, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        # Import the module
        meowclash.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

Then configure the program in your `configuration.nix`:
```nix
{
  # Enable the program and optionally TUN mode (sets up a capability wrapper for the core)
  programs.meowclash = {
    enable = true;
    tunMode.enable = true; # Required for TUN mode to work without root permissions
  };
}
```

### Android
Supports control via third-party automation tools (such as Tasker) using Intents:
- **Start VPN**: `com.meowclash.app.action.START`
- **Stop VPN**: `com.meowclash.app.action.STOP`
- **Toggle VPN**: `com.meowclash.app.action.TOGGLE`

---

## 📥 Download

Grab the latest pre-compiled binaries from the GitHub Releases page:

<a href="https://github.com/Loischsiy/MeowClash/releases">
  <img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="220px"/>
</a>
<a href="https://github.com/Loischsiy/MeowClash-fdroid-repo">
  <img alt="Get it on F-Droid" src="snapshots/get-it-on-fdroid.svg" width="220px"/>
</a>

---

## 🛠️ Building from Source

### Prerequisites
1. Install **Flutter SDK (3.35.7)**.
2. Install **Golang (1.24.0)** (required to build the proxy core).
3. If building for Windows: Install **Rust** (latest toolchain, for the Helper Service), **GCC**, and **Inno Setup**.
4. If building for Android: Install **Android SDK** and **NDK**, and define the `ANDROID_NDK` environment variable.

### Build Steps
1. **Clone the repository and submodules:**
   ```bash
   git clone https://github.com/Loischsiy/MeowClash.git
   cd MeowClash
   git submodule update --init --recursive
   ```

2. **Fetch Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Generate code (for models, providers, and l10n):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter pub run intl_utils:generate
   ```

4. **Build the application using the setup helper:**

   - **Android:**
     ```bash
     dart setup.dart android
     ```
   - **Windows:**
     ```bash
     dart setup.dart windows --arch <arm64 | amd64>
     ```
   - **Linux:**
     ```bash
     dart setup.dart linux --arch <arm64 | amd64>
     ```
   - **macOS:**
     ```bash
     dart setup.dart macos --arch <arm64 | amd64>
     ```

---

## 🔄 Fork Context & Important Changes

### Provider-Override System Refactoring (May 2026)
The custom `meowclash-*` override system was fully removed. Previously, these settings were only read from the subscription's HTTP **response headers** (rather than the profile's YAML body), making YAML overrides inside profiles non-functional.

- **Kept & Fully Working**:
  - **Subscription Decryption**: Headers `meowclash-password` and `meowclash-password-iterations` continue to decrypt secure base64 subscription payloads natively.
  - **Special Response Headers**: `announce` (announcement banner), `support-url`, `profile-update-interval` (auto-update frequency control), and `x-hwid-limit` (device limit dialog).
- **Deleted Settings (Now fully user-controlled via settings)**:
  `meowclash-settings`, `meowclash-hex`, `meowclash-widgets`, `meowclash-view`, `meowclash-custom`, `meowclash-androidsecure`, `meowclash-servicename`, `meowclash-servicelogo`, `meowclash-serverinfo`, `meowclash-globalmode`, `meowclash-denywidgets`, `meowclash-background`. Users now have complete manual control over application startup behavior, background options, and themes.

---

## 🤝 Acknowledgements

- [FlClashX](https://github.com/pluralplay/FlClashX) — The original project this app is based on.
- [mihomo (ClashMeta)](https://github.com/MetaCubeX/mihomo) — The high-performance proxy engine powering the core.
- All contributors who helped test and translate the application.

## 📄 License
MeowClash is open-source and released under the [GPL-3.0 License](LICENSE).