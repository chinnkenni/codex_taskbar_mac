#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/build/Codex Taskbar.app"
DIST_DIR="$ROOT_DIR/dist"
DMG_PATH="$DIST_DIR/Codex-Taskbar.dmg"
PACKAGE_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/codex-taskbar-package.XXXXXX")"
STAGING_DIR="$PACKAGE_ROOT/dmg-staging"

cleanup() {
  rm -rf "$PACKAGE_ROOT"
}
trap cleanup EXIT

cd "$ROOT_DIR"

"$ROOT_DIR/scripts/build-app.sh" >/dev/null

mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
xattr -cr "$STAGING_DIR/Codex Taskbar.app"
codesign --force --deep --sign - "$STAGING_DIR/Codex Taskbar.app" >/dev/null
codesign --verify --deep --strict "$STAGING_DIR/Codex Taskbar.app"

rm -f "$DMG_PATH"
hdiutil create \
  -volname "Codex Taskbar" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

echo "$DMG_PATH"
