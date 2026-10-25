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
echo "Architectures: $(lipo -archs "$APP/Contents/MacOS/Maramao" 2>/dev/null || echo unknown)"

# Sparkle (auto-update): embed the framework and let the executable find it
# in Contents/Frameworks. SwiftPM copies it next to the binary; the artifacts
# folder is the fallback. Must happen before codesign.
SPARKLE_FW="$BIN_DIR/Sparkle.framework"
if [ ! -d "$SPARKLE_FW" ]; then
  SPARKLE_FW="$(find "$ROOT/.build/artifacts" -type d -path '*macos-arm64_x86_64/Sparkle.framework' -print 2>/dev/null | head -n 1)"
fi
if [ -z "$SPARKLE_FW" ] || [ ! -d "$SPARKLE_FW" ]; then
  echo "error: Sparkle.framework not found in $BIN_DIR or .build/artifacts" >&2
  exit 1
fi
mkdir -p "$APP/Contents/Frameworks"
ditto "$SPARKLE_FW" "$APP/Contents/Frameworks/Sparkle.framework"
if ! otool -l "$APP/Contents/MacOS/Maramao" | grep -q '@executable_path/../Frameworks'; then
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Maramao"
fi
echo "Embedded Sparkle.framework ($(du -sk "$APP/Contents/Frameworks/Sparkle.framework" | cut -f1) KB)"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
# Sparkle compares CFBundleVersion to decide what is newer, so it follows the
# marketing version (0.2.0 > 0.1.9) instead of a hand-maintained counter.
SHORT_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $SHORT_VERSION" "$APP/Contents/Info.plist"

# Localizations (issue #30): Italian is the source language, English comes from
# the String Catalog. SwiftPM compiles it into the target's resource bundle; the
# .lproj folders go into Contents/Resources so Bundle.main (SwiftUI Text,
# String(localized:)) finds them. Falls back to xcstringstool if SwiftPM did not.
CATALOG="$ROOT/Sources/Maramao/Resources/Localizable.xcstrings"
RES="$APP/Contents/Resources"
found_lproj=0
while IFS= read -r lproj; do
  [ -n "$lproj" ] || continue
  ditto "$lproj" "$RES/$(basename "$lproj")"
  found_lproj=1
done < <(find "$BIN_DIR" -path '*Maramao_Maramao.bundle*' -type d -name '*.lproj' 2>/dev/null)
if [ ! -f "$RES/en.lproj/Localizable.strings" ]; then
  echo "No compiled en.lproj in the SwiftPM bundle (found: $found_lproj), compiling $CATALOG with xcstringstool"
  xcrun xcstringstool compile "$CATALOG" --output-directory "$RES" \
    || { xcrun xcstringstool compile --help || true; exit 1; }
fi
# Italian strings are the keys themselves; the folder tells macOS the app speaks Italian.
mkdir -p "$RES/it.lproj"
if [ ! -f "$RES/en.lproj/Localizable.strings" ]; then
  echo "error: en.lproj/Localizable.strings missing from $APP" >&2
  exit 1
fi
echo "Localizations: $(cd "$RES" && ls -d ./*.lproj | sed 's|^\./||' | tr '\n' ' ')"

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

# App Intents metadata (the Focus filter). Xcode extracts it for app targets
# but not for SwiftPM executables, so do Xcode's two steps by hand: ask the
# compiler for the "const values" of the app module, then run Xcode's
# appintentsmetadataprocessor to write Metadata.appintents into Resources.
# Without it macOS does not offer Maramao in System Settings → Focus → Focus
# filters. A failure costs only the Focus filter, never the build.
extract_app_intents() {
  local work="$ROOT/.build/appintents"
  rm -rf "$work"
  mkdir -p "$work"
  # The protocols Xcode 16 asks the compiler to gather (Maramao_const_extract_protocols.json).
  printf '%s' '["AppIntent","EntityQuery","AppEntity","TransientEntity","AppEnum","AppShortcutProviding","AppShortcutsProvider","AnyResolverProviding","AppIntentsPackage","DynamicOptionsProvider","_IntentValueRepresentable","_AssistantIntentsProvider","_GenerativeFunctionExtractable"]' \
    > "$work/protocols.json"
  # A separate single-architecture build: the metadata does not depend on the CPU.
  swift build -c release --build-path "$work/build" \
    -Xswiftc -emit-const-values \
    -Xswiftc -Xfrontend -Xswiftc -const-gather-protocols-file \
    -Xswiftc -Xfrontend -Xswiftc "$work/protocols.json" || return 1
  find "$work/build" -name "*.swiftconstvalues" | grep -v "MaramaoCore" | grep "Maramao" > "$work/constvalues.txt" || true
  if [ ! -s "$work/constvalues.txt" ]; then
    echo "no const values found for the Maramao module" >&2
    find "$work/build" -name "*.swiftconstvalues" >&2 || true
    return 1
  fi
  find "$ROOT/Sources/Maramao" -name "*.swift" > "$work/sources.txt"

  local developer sdk xcode_version bundle_id
  developer="$(xcode-select -p)"
  sdk="$(xcrun --sdk macosx --show-sdk-path)"
  xcode_version="$(xcodebuild -version | awk '/Build version/ {print $3}')"
  bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")"
  xcrun appintentsmetadataprocessor \
    --toolchain-dir "$developer/Toolchains/XcodeDefault.xctoolchain" \
    --module-name Maramao \
    --sdk-root "$sdk" \
    --xcode-version "$xcode_version" \
    --platform-family macOS \
    --deployment-target 13.0 \
    --bundle-identifier "$bundle_id" \
    --output "$APP/Contents/Resources" \
    --target-triple "$(uname -m)-apple-macos13.0" \
    --source-file-list "$work/sources.txt" \
    --swift-const-vals-list "$work/constvalues.txt" \
    --force --compile-time-extraction --deployment-aware-processing \
    --no-app-shortcuts-localization || return 1
  [ -f "$APP/Contents/Resources/Metadata.appintents/extract.actionsdata" ]
}
if extract_app_intents; then
  echo "Added App Intents metadata (Focus filter)"
else
  echo "warning: could not extract the App Intents metadata, the Focus filter will not be available" >&2
  if [ "${GITHUB_ACTIONS:-}" = "true" ]; then
    found="$(find "$ROOT/.build/appintents" -name '*.swiftconstvalues' 2>/dev/null | tr '\n' ' ')"
    echo "::warning::App Intents metadata not extracted. Const values found: ${found:-none}"
  fi
fi

# Signature. Ad-hoc by default: enough to run locally, not notarized.
# SIGN_IDENTITY="Developer ID Application: ..." signs for distribution with
# the hardened runtime and a secure timestamp, as notarization requires.
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --deep --sign - "$APP"
else
  # Inside out, as Sparkle documents it: its helpers first, then the
  # framework, then the app. --deep would drop the Downloader entitlements.
  FW="$APP/Contents/Frameworks/Sparkle.framework"
  sign() { codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$@"; }
  sign "$FW/Versions/B/XPCServices/Installer.xpc"
  sign --preserve-metadata=entitlements "$FW/Versions/B/XPCServices/Downloader.xpc"
  sign "$FW/Versions/B/Autoupdate"
  sign "$FW/Versions/B/Updater.app"
  sign "$FW"
  sign "$APP"
  codesign --verify --deep --strict --verbose=2 "$APP"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
(cd "$DIST" && rm -f "Maramao-$VERSION.zip" && ditto -c -k --keepParent Maramao.app "Maramao-$VERSION.zip")

echo "Built $APP"
echo "Zipped $DIST/Maramao-$VERSION.zip"
