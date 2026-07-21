<div align="center">

# MeowClash

[![Downloads](https://img.shields.io/github/downloads/Loischsiy/MeowClash/total?style=flat-square&logo=github&color=b966cf)](https://github.com/Loischsiy/MeowClash/releases/)
[![Last Version](https://img.shields.io/github/release/Loischsiy/MeowClash/all.svg?style=flat-square&color=8c52ff)](https://github.com/Loischsiy/MeowClash/releases/)
[![License](https://img.shields.io/github/license/Loischsiy/MeowClash?style=flat-square&color=4296f4)](LICENSE)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-e84393?style=flat-square)](#下载)

[**English**](README.md) | [**Suomi**](README_FI.md) | [**Русский**](README_RU.md) | [**Українська**](README_UK.md) | [**日本語**](README_JA.md) | **简体中文**

</div>

---

**MeowClash** 是一款基于 **ClashMeta (mihomo)** 内核的现代化、功能丰富的开源多平台代理客户端。它提供了一个美观的 Material You 界面用于管理您的代理连接，完全无广告，并支持在 Android、Windows、macOS 和 Linux 上原生运行。

*MeowClash 是优秀的 [FlClashX](https://github.com/pluralplay/FlClashX) 项目的一个分支（Fork）。*

---

## 📸 界面预览

### 桌面端
<div align="center">
  <img alt="MeowClash 桌面端界面" src="snapshots/desktop.gif" width="85%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

### 移动端
<div align="center">
  <img alt="MeowClash 移动端界面" src="snapshots/mobile.gif" width="35%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

---

## 🎨 核心功能

### ✨ 界面与样式 (Material You)
- **Material 3 界面**: 纯净、现代、自适应的 UI 设计，灵感源自 Surfboard。
- **动态主题**: 支持多种配色方案（TonalSpot、Fidelity、Monochrome、Neutral、Vibrant、Expressive、Content、Rainbow、FruitSalad），支持深色、浅色以及纯黑模式。
- **自定义布局与列数**: 可根据设备屏幕尺寸，调整界面间距（紧凑、标准、宽松）和网格列数（1 至 4 列）。
- **自适应布局**: 在移动端和桌面端布局之间无缝切换。

### ⚙️ 代理引擎 (ClashMeta / mihomo)
- **高性能内核**: 底层使用强大的 Go 语言编写的 `mihomo` 内核。
- **出站模式**: 支持「规则」(Rule)、「全局」(Global) 和「直连」(Direct) 路由模式。
- **实时统计**: 动态网络速度图表（上传/下载）及总体流量监测。
- **代理组控制**: 可按延迟、名称或默认配置对节点进行排序。
- **自动关闭连接**: 切换代理节点时自动中断当前活动连接。
- **代理链（链模式）**: 通过 `dialer-proxy` 构建多跳链（入口 → 出口），使流量依次经过多个代理。在代理页面直接切换**链模式**，即可在保留订阅规则的同时，将所有流量通过选定的链路转发；关闭该模式（或删除所有链）后会自动恢复普通模式。

### 🛡️ 网络与系统设置
- **系统代理**: 轻松一键切换 Windows 和 macOS 的系统代理设置。
- **TUN 模式**: 通过虚拟网卡接管并路由系统层面的所有网络流量（需要管理员/root 权限）。
- **分流控制 (应用过滤)**: (Android) 配置特定应用的白名单或黑名单，并可过滤系统应用。
- **DNS 重写**: 自定义域名服务器 (nameservers)、默认域名服务器、Fallback 备用服务器、代理域名服务器，并强制优先使用基于 HTTP/3 的 DOH (DNS-over-HTTPS)。
- **局域网共享 (AllowLan)**: 允许局域网内的其他设备通过本代理进行连接。
- **绕过域名 (Bypass)**: 配置绕过系统代理的域名列表。
- **IPv6 支持**: 完整切换入站和路由中的 IPv6 流量。
- **低内存模式**: 开启 Geo 数据库的低内存加载模式（Geo Low Memory Mode）以节省系统资源。

### ☁️ 同步、解密与订阅服务
- **WebDAV 同步**: 支持在云端远程备份和恢复您的配置与配置文件。
- **加密订阅解密**: 支持通过自定义响应头 `meowclash-password` 和 `meowclash-password-iterations` 本地解密 AES-256-CBC (基于 PBKDF2 派生密钥) 加密的 base64 订阅内容。
- **自定义响应头处理**:
  - `announce`: 在应用内向用户展示自定义公告/通知。
  - `support-url`: 在配置文件详情中提供直接的客服/支持链接。
  - `profile-update-interval`: 强制规定订阅的自动更新间隔。
  - `x-hwid-limit`: 设备额度超限时显示设备限制警告，并提供专用的 HWID 注册对话框。

### 💻 桌面端集成与辅助工具
- **最小化至系统托盘**: 关闭主窗口后，应用会在后台保持安静运行。
- **开机自启配置**: 支持设置开机自启 (Auto-launch)、后台静默启动 (Silent-launch) 以及开启自动启动代理。
- **全局快捷键**: 绑定键盘快捷键以实现：显示/隐藏窗口、启动/停止 VPN、切换代理模式、控制 TUN 模式等。
- **UWP 回环网络解锁**: (Windows) 轻松为 Windows 商店应用（UWP 应用）解锁 localhost 回环网络访问权限的实用工具。
- **发送至电视 (TV 同步)**: 支持通过扫码或局域网轻松将配置文件共享至 Android TV / 智能电视。
- **诊断与日志**: 实时连接请求查看器、活动连接管理器、支持导出为文件的详细日志控制台，以及清除全部数据的重置选项。

---

## 🔧 各操作系统特定要求

### Linux
在运行应用之前，请确保已安装以下系统依赖库：
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

如果您使用的是 NixOS，可以使用项目提供的 Flake 和 NixOS 模块。

在您的 `flake.nix` 的 inputs 中添加：
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    meowclash.url = "github:Loischsiy/MeowClash";
  };

  outputs = { self, nixpkgs, meowclash, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        # 导入模块
        meowclash.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

然后，在您的 `configuration.nix` 中配置应用：
```nix
{
  # 启用应用并选择性开启 TUN 模式（配置核心的 cap_net_admin 包装器）
  programs.meowclash = {
    enable = true;
    tunMode.enable = true; # 无需 root 权限运行 TUN 模式所需
  };
}
```

### Android
支持通过第三方自动化工具（如 Tasker）使用 Intents (意图) 来控制客户端：
- **启动 VPN**: `com.meowclash.app.action.START`
- **停止 VPN**: `com.meowclash.app.action.STOP`
- **切换状态**: `com.meowclash.app.action.TOGGLE`

---

## 📥 下载

从以下发布页面下载最新预编译好的安装包：

<a href="https://github.com/Loischsiy/MeowClash/releases">
  <img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="220px"/>
</a>
<a href="obtainium://add/https://github.com/Loischsiy/MeowClash">
  <img alt="Get it on Obtainium" src="snapshots/get-it-on-obtainium.svg" width="220px"/>
</a>
<a href="https://gitlab.com/Loischsiy/MeowClash/-/releases">
  <img alt="Get it on GitLab" src="snapshots/get-it-on-gitlab.svg" width="220px"/>
</a>

---

## 🛠️ 从源码构建

### 前提条件
1. 安装 **Flutter SDK (3.35.7)**。
2. 安装 **Golang (1.24.0)** (构建代理内核所需)。
3. 若为 Windows 构建：安装 **Rust** (最新工具链，用于辅助服务 Helper)、**GCC** 以及 **Inno Setup**。
4. 若为 Android 构建：安装 **Android SDK** 和 **NDK**，并配置 `ANDROID_NDK` 环境变量。

### 构建步骤
1. **克隆仓库及子模块:**
   ```bash
   git clone https://github.com/Loischsiy/MeowClash.git
   cd MeowClash
   git submodule update --init --recursive
   ```

2. **获取 Flutter 依赖包:**
   ```bash
   flutter pub get
   ```

3. **生成代码 (模型类、Provider 及 l10n):**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter pub run intl_utils:generate
   ```

4. **使用构建脚本打包应用:**

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

## 🔄 分支说明与重要变更

### 订阅提供商覆盖系统重构 (2026年5月)
自定义的 `meowclash-*` 覆盖系统已被完全移除。在之前的版本中，这些覆盖设置仅能从订阅链接的 HTTP **响应头**中读取（而不能从配置文件的 YAML 本体中读取），导致配置文件内部的覆盖配置失效。

- **保留并完全正常工作的功能**:
  - **订阅解密**: 响应头中的 `meowclash-password` 和 `meowclash-password-iterations` 仍用于原生解密安全的 base64 加密订阅。
  - **特殊响应头**: `announce`（公告横幅）、`support-url`、`profile-update-interval`（自动更新频率控制）以及 `x-hwid-limit`（设备数量额度限制对话框）。
- **已删除的参数 (现已改为完全由用户在设置中手动控制)**:
  `meowclash-settings`、`meowclash-hex`、`meowclash-widgets`、`meowclash-view`、`meowclash-custom`、`meowclash-androidsecure`、`meowclash-servicename`、`meowclash-servicelogo`、`meowclash-serverinfo`、`meowclash-globalmode`、`meowclash-denywidgets`、`meowclash-background`。用户现在可以完全手动且自由地配置应用开机行为、后台图片和主题配色。

---

## 🤝 致谢

- [FlClashX](https://github.com/pluralplay/FlClashX) — 本应用基于的原始项目。
- [mihomo (ClashMeta)](https://github.com/MetaCubeX/mihomo) — 强劲且高效的核心代理引擎。
- 感谢所有协助测试和翻译应用的贡献者们。

## 📄 开源协议
MeowClash 开源并遵循 [GPL-3.0 协议](LICENSE)。
