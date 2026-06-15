#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/Assets"
ICONSET_DIR="$ASSET_DIR/AppIcon.iconset"
PNG_1024="$ASSET_DIR/AppIcon-1024.png"
GENERATOR="$ROOT_DIR/.build/generate-icon"
MODULE_CACHE="$ROOT_DIR/.build/clang-module-cache"

mkdir -p "$ICONSET_DIR" "$MODULE_CACHE"

swiftc \
  -O \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$MODULE_CACHE" \
  "$ROOT_DIR/scripts/generate-icon.swift" \
  -o "$GENERATOR"

if [[ ! -f "$PNG_1024" ]]; then
  "$GENERATOR" "$PNG_1024"
fi
sips -s format png "$PNG_1024" --out "$PNG_1024" >/dev/null

sips -z 16 16 "$PNG_1024" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$PNG_1024" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$PNG_1024" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$PNG_1024" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$PNG_1024" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$PNG_1024" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$PNG_1024" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$PNG_1024" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$PNG_1024" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
cp "$PNG_1024" "$ICONSET_DIR/icon_512x512@2x.png"

for icon in "$ICONSET_DIR"/*.png; do
  tmp_icon="$icon.tmp.png"
  tmp_jpg="$icon.tmp.jpg"
  sips -s format jpeg "$icon" --out "$tmp_jpg" >/dev/null
  sips -s format png "$tmp_jpg" --out "$tmp_icon" >/dev/null
  rm -f "$tmp_jpg"
  mv "$tmp_icon" "$icon"
done

"$ROOT_DIR/scripts/make-icns.py" \
  "$ASSET_DIR/AppIcon.icns" \
  icp4 "$ICONSET_DIR/icon_16x16.png" \
  icp5 "$ICONSET_DIR/icon_32x32.png" \
  icp6 "$ICONSET_DIR/icon_32x32@2x.png" \
  ic07 "$ICONSET_DIR/icon_128x128.png" \
  ic08 "$ICONSET_DIR/icon_256x256.png" \
  ic09 "$ICONSET_DIR/icon_512x512.png" \
  ic10 "$ICONSET_DIR/icon_512x512@2x.png"

echo "$ASSET_DIR/AppIcon.icns"
