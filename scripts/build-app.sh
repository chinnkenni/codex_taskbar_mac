#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Codex Taskbar"
BUILD_APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
BUILD_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-taskbar-build.XXXXXX")"
APP_DIR="$BUILD_ROOT/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
VERSION="$(tr -d '[:space:]' < "$ROOT_DIR/VERSION")"

cleanup() {
  rm -rf "$BUILD_ROOT"
}
trap cleanup EXIT

cd "$ROOT_DIR"

export CLANG_MODULE_CACHE_PATH="$ROOT_DIR/.build/clang-module-cache"
export XDG_CACHE_HOME="$ROOT_DIR/.build/xdg-cache"
mkdir -p "$CLANG_MODULE_CACHE_PATH" "$XDG_CACHE_HOME"

"$ROOT_DIR/scripts/generate-icon.sh" >/dev/null

swiftc \
  -O \
  -sdk "$(xcrun --sdk macosx --show-sdk-path)" \
  -target arm64-apple-macos13.0 \
  -module-cache-path "$CLANG_MODULE_CACHE_PATH" \
  "$ROOT_DIR/Sources/CodexTaskbar/main.swift" \
  -o "$ROOT_DIR/.build/CodexTaskbar"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cp "$ROOT_DIR/.build/CodexTaskbar" "$MACOS_DIR/Codex Taskbar"
cp "$ROOT_DIR/Assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleExecutable</key>
  <string>Codex Taskbar</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.withkeni.codextaskbar</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Codex Taskbar</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>__VERSION__</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHumanReadableCopyright</key>
  <string>Copyright © 2026</string>
</dict>
</plist>
PLIST

/usr/bin/perl -0pi -e "s/__VERSION__/$VERSION/g" "$CONTENTS_DIR/Info.plist"

xattr -cr "$APP_DIR"
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR" >/dev/null
xattr -d com.apple.FinderInfo "$APP_DIR" 2>/dev/null || true

rm -rf "$BUILD_APP_DIR"
mkdir -p "$ROOT_DIR/build"
cp -R "$APP_DIR" "$BUILD_APP_DIR"
xattr -cr "$BUILD_APP_DIR"
xattr -d com.apple.FinderInfo "$BUILD_APP_DIR" 2>/dev/null || true

echo "$BUILD_APP_DIR"
