<div align="center">

# MeowClash

[![Downloads](https://img.shields.io/github/downloads/Loischsiy/MeowClash/total?style=flat-square&logo=github&color=b966cf)](https://github.com/Loischsiy/MeowClash/releases/)
[![Last Version](https://img.shields.io/github/release/Loischsiy/MeowClash/all.svg?style=flat-square&color=8c52ff)](https://github.com/Loischsiy/MeowClash/releases/)
[![License](https://img.shields.io/github/license/Loischsiy/MeowClash?style=flat-square&color=4296f4)](LICENSE)
[![Platform Support](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-e84393?style=flat-square)](#ダウンロード)

[**English**](README.md) | [**Русский**](README_RU.md) | [**Українська**](README_UK.md) | **日本語** | [**简体中文**](README_ZH.md)

</div>

---

**MeowClash** は、**ClashMeta (mihomo)** コアをベースにした、モダンで機能豊富なオープンソースのマルチプラットフォームプロキシクライアントです。プロキシ接続を管理するための美しい Material You UI を提供し、完全に広告なしで、Android、Windows、macOS、および Linux 上でネイティブに動作します。

*MeowClash は、優れた [FlClashX](https://github.com/pluralplay/FlClashX) プロジェクトのフォークです。*

---

## 📸 スクリーンショット

### デスクトップ
<div align="center">
  <img alt="MeowClash デスクトップインターフェース" src="snapshots/desktop.gif" width="85%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

### モバイル
<div align="center">
  <img alt="MeowClash モバイルインターフェース" src="snapshots/mobile.gif" width="35%" style="border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.3);">
</div>

---

## 🎨 主な機能

### ✨ UI とデザイン (Material You)
- **Material 3 インターフェース**: Surfboard にインスパイアされた、クリーンでモダン、かつアダプティブな UI。
- **ダイナミックテーマ**: ダークモード、ライトモード、ピュアブラックモードをサポートする複数のカラースキーム（TonalSpot、Fidelity、Monochrome、Neutral、Vibrant、Expressive、Content、Rainbow、FruitSalad）。
- **間隔と列のカスタマイズ**: デバイスの画面サイズに応じて、レイアウトの密度（タイト、標準、ルーズ）とグリッド列数（1〜4列）を調整可能。
- **レスポンシブレイアウト**: モバイルレイアウトとデスクトップレイアウトのシームレスな切り替え。

### ⚙️ プロキシエンジン (ClashMeta / mihomo)
- **高性能コア**: 強力な Go ベースの `mihomo` コアを内部で使用。
- **ルーティングモード**: 「ルール」(Rule)、「グローバル」(Global)、「直結」(Direct) のルーティングをサポート。
- **リアルタイム統計**: 動的なネットワーク速度チャート（アップロード/ダウンロード）と全体的なトラフィック監視。
- **プロキシプロバイダーコントロール**: 遅延、名前、またはデフォルト設定順でプロキシノードをソート。
- **接続の自動切断**: プロキシノード切り替え時に、アクティブな接続を自動的に終了。
- **プロキシチェーン（チェーンモード）**: `dialer-proxy` を利用して複数のプロキシを順番に経由するマルチホップチェーン（入口 → 出口）を構築。プロキシ画面から**チェーンモード**を切り替えると、サブスクリプションのルールを維持したまま、選択したチェーンを通じてすべてのトラフィックを送出できます。無効化（またはすべてのチェーンを削除）すると、自動的に通常モードに戻ります。

### 🛡️ ネットワークとシステム設定
- **システムプロキシ**: Windows および macOS のシステムプロキシ設定を簡単に切り替え。
- **TUN モード**: 仮想ネットワークアダプター経由でシステムレベルのすべてのネットワークトラフィックをルーティング（管理者/root 権限が必要）。
- **スプリットトンネリング (アクセス制御)**: (Android) 特定のアプリのホワイトリスト/ブラックリスト設定、システムアプリのフィルタリング。
- **DNS の上書き**: ネームサーバー、デフォルトネームサーバー、フォールバック、プロキシネームサーバーをカスタマイズし、DOH (DNS-over-HTTPS) HTTP/3 優先順位付けを強制。
- **LAN アクセス (AllowLan)**: ローカルネットワーク上の他のデバイスがプロキシ経由で接続することを許可。
- **バイパスドメイン**: システムプロキシをバイパスするドメインリストを設定。
- **IPv6 サポート**: IPv6 受信トラフィックルーティングを完全に切り替え。
- **低メモリローダー**: リソースを節約するために Geo データベースの Geo Low Memory モードを有効化。

### ☁️ 同期、暗号化、およびプロバイダー機能
- **WebDAV 同期**: 設定とプロファイルをリモートでバックアップおよび復元。
- **暗号化されたサブスクリプションの復号**: カスタムヘッダー `meowclash-password` および `meowclash-password-iterations` を使用して、暗号化されたサブスクリプション（AES-256-CBC、PBKDF2 で派生したキー）をネイティブに復号。
- **カスタムヘッダーの処理**:
  - `announce`: アプリ内でユーザーにカスタム通知/アナウンスを表示。
  - `support-url`: プロファイル詳細に直接サポートリンクを提供。
  - `profile-update-interval`: 特定のサブスクリプション自動更新間隔を適用。
  - `x-hwid-limit`: 専用のハードウェア ID 登録ダイアログでデバイス制限の警告を表示。

### 💻 デスクトップ統合と便利なユーティリティ
- **システムトレイに最小化**: メインウィンドウを閉じた後もバックグラウンドで静かに実行を継続。
- **自動起動設定**: システム起動時の自動実行 (Auto-launch) や、バックグラウンドでのサイレント起動 (Silent-launch) を設定可能。
- **グローバルホットキー**: ウィンドウの表示/非表示、VPN の開始/停止、プロキシモードの切り替え、TUN モードの制御のためのキーボードショートカットを割り当て。
- **UWP ループバックアンロッカー**: (Windows) Windows ストア (UWP) アプリのローカルホストへのネットワークアクセスを簡単に有効化するツール。
- **TV に送信 (TV 同期)**: QR コードスキャンまたはローカルネットワーク経由で、Android TV / スマート TV にプロファイルを簡単に共有。
- **診断ツール**: リアルタイムのリクエストビューア、アクティブな接続の管理、ファイルへのエクスポート機能付きの詳細なログコンソール、アプリデータのリセットオプション。

---

## 🔧 OS固有の要件

### Linux
アプリケーションを実行する前に、必要なシステムライブラリをインストールしてください：
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

NixOS を使用している場合は、提供されている Flake インプットと NixOS モジュールを利用できます。

`flake.nix` の `inputs` に以下を追加します：
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    meowclash.url = "github:Loischsiy/MeowClash";
  };

  outputs = { self, nixpkgs, meowclash, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      modules = [
        # モジュールをインポート
        meowclash.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

その後、`configuration.nix` でプログラムを有効化・設定します：
```nix
{
  # プログラムを有効化し、必要に応じて TUN モジュールを設定（コア用のケーパビリティラッパーを作成）
  programs.meowclash = {
    enable = true;
    tunMode.enable = true; # root 権限なしで TUN モードを動作させるために必要
  };
}
```

### Android
インテントを使用して、サードパーティの自動化ツール（Tasker など）経由でアプリを制御できます：
- **VPNの開始**: `com.meowclash.app.action.START`
- **VPNの停止**: `com.meowclash.app.action.STOP`
- **状態の切り替え**: `com.meowclash.app.action.TOGGLE`

---

## 📥 ダウンロード

以下のリリースページから最新のプリコンパイル済みバイナリを取得してください：

<a href="https://github.com/Loischsiy/MeowClash/releases">
  <img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" width="220px"/>
</a>
<a href="https://gitlab.com/Loischsiy/MeowClash/-/releases">
  <img alt="Get it on GitLab" src="https://img.shields.io/badge/Get_it_on-GitLab-FC6D26?logo=gitlab&logoColor=white" width="220px"/>
</a>

---

## 🛠️ ソースからのビルド

### 必要要件
1. **Flutter SDK (3.35.7)** をインストール。
2. **Golang (1.24.0)** をインストール（プロキシコアのビルドに必要）。
3. Windows 向けにビルドする場合：**Rust** (最新のツールチェーン、Helper Service 用)、**GCC**、および **Inno Setup** をインストール。
4. Android 向けにビルドする場合：**Android SDK** と **NDK** をインストールし、環境変数 `ANDROID_NDK` を定義。

### ビルド手順
1. **リポジトリとサブモジュールをクローンします:**
   ```bash
   git clone https://github.com/Loischsiy/MeowClash.git
   cd MeowClash
   git submodule update --init --recursive
   ```

2. **Flutter パッケージを取得します:**
   ```bash
   flutter pub get
   ```

3. **モデル、プロバイダー、およびローカライズ用のコードを生成します:**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   flutter pub run intl_utils:generate
   ```

4. **セットアップスクリプトを使用してアプリケーションをビルドします:**

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

## 🔄 フォークの背景と重要な変更点

### プロバイダー上書きシステムの変更（2026年5月）
カスタム `meowclash-*` 上書きシステムは完全に削除されました。以前は、これらの設定はサブスクリプションの HTTP **レスポンスヘッダー**からのみ読み取られ（プロファイルの YAML ボディからは読み取られず）、プロファイル内での YAML の上書きが機能していませんでした。

- **維持され、完全に機能するもの**:
  - **サブスクリプションの復号**: ヘッダー `meowclash-password` および `meowclash-password-iterations` による暗号化されたサブスクリプションのネイティブ復号。
  - **特別なレスポンスヘッダー**: `announce`（お知らせバナー）、`support-url`、`profile-update-interval`（自動更新間隔制御）、および `x-hwid-limit`（デバイス制限ダイアログ）。
- **削除された設定（ユーザー設定から手動で完全に制御可能になりました）**:
  `meowclash-settings`、`meowclash-hex`、`meowclash-widgets`、`meowclash-view`、`meowclash-custom`、`meowclash-androidsecure`、`meowclash-servicename`、`meowclash-servicelogo`、`meowclash-serverinfo`、`meowclash-globalmode`、`meowclash-denywidgets`、`meowclash-background`。ユーザーは、起動動作、背景オプション、およびテーマを手動で完全に制御できるようになりました。

---

## 🤝 謝辞

- [FlClashX](https://github.com/pluralplay/FlClashX) — このアプリのベースとなったオリジナルプロジェクト。
- [mihomo (ClashMeta)](https://github.com/MetaCubeX/mihomo) — コアを支える高性能プロキシエンジン。
- アプリケーションのテストや翻訳をサポートしてくれたすべての貢献者の皆様。

## 📄 ライセンス
MeowClash はオープンソースであり、[GPL-3.0 License](LICENSE) の下でリリースされています。
