#!/usr/bin/env bash
# Builds Maramao.app (and a zip of it) from the Swift package.
# Usage: scripts/build-app.sh [debug|release]   (default: release)
# Environment: SIGN_IDENTITY  codesign identity (default "-", ad-hoc)
set -euo pipefail

CONFIG="${1:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Maramao.app"

cd "$ROOT"
# Release builds are optimised for size: the app is a timer that sleeps most of the
# time, so a smaller binary (less to load and page in) beats the last bit of speed.
FLAGS=""
if [ "$CONFIG" = "release" ]; then
  FLAGS="-Xswiftc -Osize"
fi
swift build -c "$CONFIG" $FLAGS --arch arm64 --arch x86_64 2>/dev/null \
  || swift build -c "$CONFIG" $FLAGS
BIN_DIR="$(swift build -c "$CONFIG" $FLAGS --arch arm64 --arch x86_64 --show-bin-path 2>/dev/null \
  || swift build -c "$CONFIG" $FLAGS --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Maramao" "$APP/Contents/MacOS/Maramao"
if [ "$CONFIG" = "release" ]; then
  # Drop debug info, local and Swift-internal symbols: only crash symbolication
  # needs them, and an ad-hoc build has no dSYM workflow anyway. Must run before
  # codesign. -T (Swift symbols) needs Xcode 15's strip; fall back without it.
  BEFORE=$(wc -c < "$APP/Contents/MacOS/Maramao" | tr -d ' ')
  strip -S -T -x "$APP/Contents/MacOS/Maramao" 2>/dev/null || strip -S -x "$APP/Contents/MacOS/Maramao"
  AFTER=$(wc -c < "$APP/Contents/MacOS/Maramao" | tr -d ' ')
  echo "Stripped the executable: $BEFORE -> $AFTER bytes"
fi
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

# Shortcuts actions (App Intents): SwiftPM does not generate the metadata Xcode
# would. A failure here only costs the Shortcuts actions; maramao:// URLs still work.
if ! "$ROOT/scripts/make-appintents-metadata.sh" "$APP/Contents/Resources" "$CONFIG"; then
  echo "warning: could not generate the App Intents metadata, no Shortcuts actions" >&2
fi

# Signature. Ad-hoc by default: enough to run locally, not notarized.
# SIGN_IDENTITY="Developer ID Application: ..." signs for distribution with
# the hardened runtime and a secure timestamp, as notarization requires.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP"
else
  codesign --force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
(cd "$DIST" && rm -f "Maramao-$VERSION.zip" && ditto -c -k --keepParent Maramao.app "Maramao-$VERSION.zip")

echo "Built $APP"
echo "Zipped $DIST/Maramao-$VERSION.zip"
