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
- **Proxy Chains (Chain Mode)**: Build multi-hop chains (entry → exit) that route traffic through several proxies in sequence via `dialer-proxy`. Toggle **Chain Mode** right from the Proxies page to send all traffic through a selected chain while keeping your subscription rules intact; disabling it (or removing all chains) returns to normal mode automatically.

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
# Ubuntu / Debian
sudo apt-get install libayatana-appindicator3-dev libkeybinder-3.0-dev

# Arch Linux
sudo pacman -S libayatana-appindicator libkeybinder3

# Fedora
sudo dnf install libayatana-appindicator-gtk3-devel keybinder3-devel

# Alpine
sudo apk add libayatana-appindicator-dev keybinder3-dev
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

## 🛡️ zapret2 Mode (DPI bypass)

MeowClash includes an **additive, opt-in** DPI-bypass mode built on the
[zapret2](https://github.com/bol-van/zapret2) engine. It is **off by default**,
**independent of the Clash/Mihomo proxy** (it can be toggled on its own), and
**never changes proxy behaviour** when disabled.

When enabled, it automatically finds a working circumvention strategy for your
network, caches it, and reuses it on the next launch.

### How to enable

1. Open **Settings → zapret2 (DPI bypass)**.
2. Toggle **Enable zapret2**. On first enable it runs an auto-selection search
   (see below); progress is shown live (which strategy is being tested, how many
   remain). This can take a while.
3. Once a working strategy is found it is applied and cached. Use
   **Re-check / reset strategy** to drop the cache and search again (e.g. after
   switching networks).

### How the auto-selection works

- **Blockcheck-style probing.** Each candidate strategy is applied, then the
  configured targets (Discord and YouTube by default; add your own domains/IPs)
  are probed for reachability + latency.
- **UCB1 multi-armed bandit.** Strategies are explored in a smart order: each has
  an average past reward plus an exploration bonus for being under-tested
  (`score = mean + sqrt(2·ln(N)/nᵢ)`). Unexplored strategies are tried first;
  previously-good strategies (from the cache) are tried first on subsequent runs.
- **Early stop.** The search stops as soon as a strategy clears the acceptance
  threshold — no full sweep of the catalogue.
- **Cache.** The winning strategy and per-strategy stats are saved to
  `<app-data>/zapret2/strategy_cache.json` as
  `{ engineVersion, platform, selectedStrategy, targets, testedAt, stats }`. The
  cache is invalidated automatically when the engine version, platform, or target
  set changes.
- **Logs.** The full selection log is written to `<app-data>/zapret2/select.log`
  for diagnostics.

### Per-platform support

| Platform | Backend | Status | Requirements |
|----------|---------|--------|--------------|
| **Windows** | `winws.exe` + WinDivert | ✅ Supported | Elevated (admin) to load the WinDivert driver |
| **Linux** | `nfqws` (NFQUEUE) | ✅ Supported | Root or `cap_net_admin` on the binary |
| **macOS** | local TUN backend | 🚧 Not built yet | NetworkExtension/utun packet path needed |
| **Android** | userspace packet mutation in the Go core | ⚙️ Experimental — native channel is built in | Android VPN permission |

On any platform where the backend is not available, the UI shows an **explicit
message** (missing binary, missing privileges, or platform unsupported) instead
of failing silently.

### ⚠️ Antivirus notice (Windows)

On Windows the engine uses **WinDivert**, a legitimate, signed packet-filter
driver. Some antivirus products flag packet-interception drivers heuristically.
**It is not a virus.** If your AV quarantines `WinDivert*.sys`/`.dll` or
`winws.exe`, add an exception for the MeowClash install directory.

### 🔒 Privacy

The whole feature is **local and open-source**. There is **no telemetry** and no
hidden network activity: the only network traffic it generates is the reachability
probes to the targets **you** configure. (This project has had malicious forks in
the past — trust matters; audit `lib/services/zapret/` and the bundled binaries.)

### Binary origin & license

Binaries are pinned to a single source of truth: [`zapret/version.go`](zapret/version.go)
(generated into `lib/zapret_version.dart` by `setup.dart`, mirroring the core
version pattern).

| Platform | Source | License |
|----------|--------|---------|
| Windows (`winws.exe`, `WinDivert.dll`/`.sys`) | [bol-van/zapret-win-bundle](https://github.com/bol-van/zapret-win-bundle) | zapret2: see repo; WinDivert: LGPLv3 / GPLv3 (dual) |
| Linux (`nfqws`) | [bol-van/zapret2](https://github.com/bol-van/zapret2) releases | see the zapret2 repository |
| macOS (local TUN backend) | planned in this project | part of this project |
| Android (packet mutation) | built into the Go core (`libclash.so`) | part of this project |

> Verify licensing of the upstream binaries before redistribution. The Windows
> bundle in particular ships no explicit top-level LICENSE at time of writing —
> pin a specific, audited release and document its provenance in your build.

### Building / obtaining the binaries

Binaries are staged next to the app by `setup.dart` (`bundleZapret2Binaries`),
mirroring how `libclash` is bundled. Point the build at a directory of staged
assets with `ZAPRET2_BUNDLE_DIR` (layout: `<dir>/<windows|linux|macos|android>/…`),
or drop a binary next to the executable / set `ZAPRET2_BIN_DIR` at runtime.

- **Windows / Linux:** take the prebuilt `winws.exe` + `WinDivert*` / `nfqws`
  from the upstream releases above and stage them under
  `zapret/windows/` / `zapret/linux/`.
- **macOS:** upstream zapret2 does not provide a macOS packet-capture backend.
  MeowClash no longer pretends that a standalone `nfqws-darwin` binary is enough;
  the supported direction is a local TUN/NetworkExtension path inside the app.
  Until that native path lands, the mode reports "native support is not built
  into this app".
- **Android (packet mutation in the Go core):** because a non-root device cannot
  run `nfqws` (no userspace NFQUEUE), DPI bypass is applied as **userspace packet
  mutation on the sing-tun read path inside the Go core**, driven from Dart over
  the `zapret2` method channel (`isSupported` / `apply` / `clear`). See
  [`core/zapret_android.go`](core/zapret_android.go) for the seam and
  `lib/services/zapret/backends/android_backend.dart` for the Dart side. The
  per-ABI native code ships inside `libclash.so` (same `setup.dart` per-ABI
  pipeline as the core — `armeabi-v7a`, `arm64-v8a`, `x86_64`). The Android app
  registers the `zapret2` channel in `Zapret2Plugin`; `apply`/`clear` are bridged
  into `libclash.so`.

---

## 📥 Download

Grab the latest pre-compiled binaries from the release pages:

<a href="https://github.com/Loischsiy/MeowClash/releases">
  <img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="220px"/>
</a>
<a href="https://gitlab.com/Loischsiy/MeowClash/-/releases">
  <img alt="Get it on GitLab" src="https://img.shields.io/badge/Get_it_on-GitLab-FC6D26?logo=gitlab&logoColor=white" width="220px"/>
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
