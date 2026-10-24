#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PLATFORM="${PLATFORM_NAME:-iphoneos}"
# iphonesimulator is a Debug-only UI preview path: VPN (PacketTunnel) does not
# run in the simulator, and release/IPA builds stay device-only.
if [[ "$PLATFORM" == iphonesimulator && "${CONFIGURATION:-Debug}" != Debug ]]; then
  echo "error: iOS Simulator builds are Debug-only (UI preview); release builds target arm64 devices." >&2
  exit 1
fi
if [[ "$(uname -s)" != Darwin || ( "$PLATFORM" != iphoneos && "$PLATFORM" != iphonesimulator ) || "${ARCHS:-arm64}" != arm64 ]]; then
  echo "error: MeowClash iOS supports arm64 devices (and the arm64 Simulator in Debug) only; install full Xcode on macOS." >&2
  exit 1
fi
SDK="$(xcrun --sdk "$PLATFORM" --show-sdk-path)"
CLANG="$(xcrun --sdk "$PLATFORM" --find clang)"
if [[ "$PLATFORM" == iphonesimulator ]]; then
  MIN_FLAG="-mios-simulator-version-min=15.0"
  OUT_DIR=ios-simulator
else
  MIN_FLAG="-miphoneos-version-min=15.0"
  OUT_DIR=ios
fi
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v go >/dev/null || { echo "error: Install Go and make it available to Xcode." >&2; exit 1; }
VERSION="$(sed -nE 's/.*var Version *= *"([^"]+)".*/\1/p' "$ROOT/core/constant/version.go")"
[[ -n "$VERSION" ]] || { echo "error: Missing canonical core version" >&2; exit 1; }
OUT="$ROOT/libclash/$OUT_DIR"
mkdir -p "$OUT"
STAGE="$(mktemp -d "$OUT/.core.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
export GOOS=ios GOARCH=arm64 CGO_ENABLED=1 CC="$CLANG"
export CGO_CFLAGS="-isysroot \"$SDK\" $MIN_FLAG -arch arm64"
export CGO_LDFLAGS="$CGO_CFLAGS"
(cd "$ROOT/core" && go build -mod=readonly -trimpath -tags=with_gvisor,cmfa \
  -buildmode=c-archive -ldflags="-w -s -X github.com/metacubex/mihomo/constant.Version=$VERSION" \
  -o "$STAGE/libclash.a" .)
for file in libclash.a libclash.h; do
  if ! cmp -s "$STAGE/$file" "$OUT/$file"; then mv -f "$STAGE/$file" "$OUT/$file"; fi
done
bash "$ROOT/ios/generate_icons.sh"
