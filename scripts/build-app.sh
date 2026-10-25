#!/usr/bin/env bash
# Builds Maramao.app (and a zip of it) from the Swift package.
# Usage: scripts/build-app.sh [debug|release]   (default: release)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Maramao.app"

cd "$ROOT"
swift build -c "$CONFIG" --arch arm64 --arch x86_64 2>/dev/null \
  || swift build -c "$CONFIG"
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null \
  || swift build -c "$CONFIG" --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Maramao" "$APP/Contents/MacOS/Maramao"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# App icon: drawn in code by scripts/make-icon.swift, so no binary is
# committed. A failure here only costs the icon, never the build.
ICON_DIR="$ROOT/.build/icon"
ICNS=""
if [ -f "$ROOT/Resources/AppIcon.icns" ]; then
  ICNS="$ROOT/Resources/AppIcon.icns"
else
  rm -rf "$ICON_DIR"
  mkdir -p "$ICON_DIR"
  if swift "$ROOT/scripts/make-icon.swift" "$ICON_DIR/AppIcon.iconset" \
    && iconutil -c icns "$ICON_DIR/AppIcon.iconset" -o "$ICON_DIR/AppIcon.icns"; then
    ICNS="$ICON_DIR/AppIcon.icns"
    echo "Created app icon $ICNS ($(wc -c < "$ICNS" | tr -d ' ') bytes)"
  else
    echo "warning: could not generate the app icon, building without it" >&2
  fi
fi
if [ -n "$ICNS" ]; then
  cp "$ICNS" "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "$APP/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist" || true
fi

# Ad-hoc signature: enough to run locally, not notarized.
codesign --force --deep --sign - "$APP"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
(cd "$DIST" && rm -f "Maramao-$VERSION.zip" && ditto -c -k --keepParent Maramao.app "Maramao-$VERSION.zip")

echo "Built $APP"
echo "Zipped $DIST/Maramao-$VERSION.zip"
