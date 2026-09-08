#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
if [[ "$(uname -s)" != Darwin || "${PLATFORM_NAME:-iphoneos}" != iphoneos || "${ARCHS:-arm64}" != arm64 ]]; then
  echo "error: MeowClash iOS supports physical arm64 devices only; install full Xcode on macOS." >&2
  exit 1
fi
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
CLANG="$(xcrun --sdk iphoneos --find clang)"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
command -v go >/dev/null || { echo "error: Install Go and make it available to Xcode." >&2; exit 1; }
VERSION="$(sed -nE 's/.*var Version *= *"([^"]+)".*/\1/p' "$ROOT/core/constant/version.go")"
[[ -n "$VERSION" ]] || { echo "error: Missing canonical core version" >&2; exit 1; }
OUT="$ROOT/libclash/ios"
mkdir -p "$OUT"
STAGE="$(mktemp -d "$OUT/.core.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
export GOOS=ios GOARCH=arm64 CGO_ENABLED=1 CC="$CLANG"
export CGO_CFLAGS="-isysroot \"$SDK\" -miphoneos-version-min=15.0 -arch arm64"
export CGO_LDFLAGS="$CGO_CFLAGS"
(cd "$ROOT/core" && go build -mod=readonly -trimpath -tags=with_gvisor,cmfa \
  -buildmode=c-archive -ldflags="-w -s -X github.com/metacubex/mihomo/constant.Version=$VERSION" \
  -o "$STAGE/libclash.a" .)
for file in libclash.a libclash.h; do
  if ! cmp -s "$STAGE/$file" "$OUT/$file"; then mv -f "$STAGE/$file" "$OUT/$file"; fi
done
bash "$ROOT/ios/generate_icons.sh"
