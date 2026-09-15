#!/bin/bash
# Build a verified installer; preserve framework symlinks and executable modes.
set -euo pipefail
cd "$(dirname "$0")/.."
APP=build/macos/Build/Products/Release/cpredux.app
OUT="$PWD/dist/cpredux-macos.dmg"
STAGING=$(mktemp -d)
MOUNT=$(mktemp -d)
cleanup() {
  hdiutil detach "$MOUNT" >/dev/null 2>&1 || true
  rm -rf "$STAGING" "$MOUNT"
}
trap cleanup EXIT
codesign --verify --deep --strict "$APP"
ditto "$APP" "$STAGING/cpredux.app"
mkdir -p dist
rm -f "$OUT"
if command -v create-dmg >/dev/null 2>&1; then
  OPTIONS=()
  if [ "${CI:-}" = true ]; then OPTIONS+=(--skip-jenkins); fi
  if ! create-dmg --volname CPRedux \
    --volicon assets/branding/dmg_logo.icns \
    --background assets/branding/dmg_background.png \
    --window-pos 200 120 --window-size 660 400 --icon-size 128 \
    --text-size 12 --icon cpredux.app 175 190 \
    --hide-extension cpredux.app --app-drop-link 485 190 \
    --no-internet-enable ${OPTIONS[@]+"${OPTIONS[@]}"} "$OUT" "$STAGING"; then
    rm -f "$OUT"
  fi
fi
if [ ! -f "$OUT" ]; then
  if [ ! -L "$STAGING/Applications" ]; then
    ln -s /Applications "$STAGING/Applications"
  fi
  hdiutil create -volname CPRedux -srcfolder "$STAGING" -format UDZO "$OUT"
fi
hdiutil verify "$OUT"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "$OUT"
test "$(readlink "$MOUNT/Applications")" = /Applications
codesign --verify --deep --strict "$MOUNT/cpredux.app"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT/cpredux.app/Contents/Info.plist")" = \
  "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
echo "DMG verified: $OUT"
