#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
SOURCE="$ROOT/assets/images/icon.png"
mkdir -p "$ROOT/build/ios-icons" "$OUT"
# App Store icons must be opaque. JPEG staging strips alpha from the existing
# MeowClash artwork; no reference-project branding is copied.
sips -s format jpeg "$SOURCE" --out "$ROOT/build/ios-icons/icon.jpg" >/dev/null
for size in 20 29 40 58 60 76 80 87 120 152 167 180 1024; do
  sips -s format png -z "$size" "$size" "$ROOT/build/ios-icons/icon.jpg" --out "$OUT/Icon-$size.png" >/dev/null
done
