#!/usr/bin/env bash
# Builds dist/Maramao-<version>.dmg: a tall styled installer window with
# Maramao.app on top, an Applications shortcut below it and a background
# drawn in code by scripts/make-dmg-background.swift (the PNGs are kept in
# .build/dmg/background for review).
#
# Usage: scripts/build-dmg.sh [--rebuild]
#   Reuses dist/Maramao.app when it exists (so a signed app is kept),
#   otherwise (or with --rebuild) runs scripts/build-app.sh release first.
#
# Environment:
#   SIGN_IDENTITY  codesign identity for the .dmg (default "-", ad-hoc)
#
# The Finder layout is set with AppleScript, which can fail on a headless
# machine. It is retried once; if it still fails the DMG is built anyway,
# without the custom layout, and a warning is printed.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
APP="$DIST/Maramao.app"
WORK="$ROOT/.build/dmg"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
VOLNAME="Maramao"

# Window geometry: must match scripts/make-dmg-background.swift.
WIN_W=440
WIN_H=588
WIN_X=200
WIN_Y=120
ICON_SIZE=128
APP_POS="220, 196"
APPS_POS="220, 430"

warn() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::warning::$*"
  else
    echo "warning: $*" >&2
  fi
}

if [ "${1:-}" = "--rebuild" ] || [ ! -d "$APP" ]; then
  "$ROOT/scripts/build-app.sh" release
else
  echo "Reusing $APP"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$DIST/Maramao-$VERSION.dmg"
RW_DMG="$WORK/Maramao-rw.dmg"
STAGING="$WORK/staging"

rm -rf "$WORK"
mkdir -p "$STAGING/.background"

# 1. Staging folder: the app, a link to /Applications, the background.
ditto "$APP" "$STAGING/Maramao.app"
ln -s /Applications "$STAGING/Applications"

BACKGROUND=""
if swift "$ROOT/scripts/make-dmg-background.swift" "$WORK/background" \
  && tiffutil -cathidpicheck "$WORK/background/background.png" "$WORK/background/background@2x.png" \
    -out "$STAGING/.background/background.tiff"; then
  BACKGROUND="background.tiff"
  echo "Created DMG background ($(wc -c < "$STAGING/.background/background.tiff" | tr -d ' ') bytes)"
else
  warn "could not draw the DMG background, building without it"
  rmdir "$STAGING/.background" 2>/dev/null || true
fi

# 2. A read-write image with some headroom for Finder's .DS_Store.
SIZE_MB=$(( $(du -sm "$STAGING" | cut -f1) + 20 ))
hdiutil create -srcfolder "$STAGING" -volname "$VOLNAME" -fs HFS+ \
  -format UDRW -size "${SIZE_MB}m" -ov "$RW_DMG" >/dev/null

# 3. Mount it. The volume may come up as "Maramao 1" if a Maramao volume
# is already mounted, so read the real mount point back from hdiutil.
ATTACH_OUT="$(hdiutil attach -readwrite -noverify -noautoopen "$RW_DMG")"
DEVICE="$(echo "$ATTACH_OUT" | grep -E '^/dev/' | head -n 1 | awk '{print $1}')"
MOUNT="$(echo "$ATTACH_OUT" | grep -E 'Apple_HFS' | sed -E 's/^.*Apple_HFS[[:space:]]+//' | head -n 1)"
if [ -z "$DEVICE" ] || [ -z "$MOUNT" ] || [ ! -d "$MOUNT" ]; then
  echo "error: could not mount $RW_DMG" >&2
  echo "$ATTACH_OUT" >&2
  exit 1
fi
DISK_NAME="$(basename "$MOUNT")"
echo "Mounted $DEVICE at $MOUNT"

detach() {
  local attempt
  for attempt in 1 2 3 4 5; do
    if hdiutil detach "$DEVICE" -quiet; then
      return 0
    fi
    echo "hdiutil detach failed (attempt $attempt), retrying..." >&2
    sleep $(( attempt * 2 ))
  done
  hdiutil detach "$DEVICE" -force
}
trap 'detach >/dev/null 2>&1 || true' EXIT

# 4. Volume icon: the app icon, flagged as a custom icon on the volume.
ICNS="$APP/Contents/Resources/AppIcon.icns"
if [ -f "$ICNS" ]; then
  cp "$ICNS" "$MOUNT/.VolumeIcon.icns"
  if command -v SetFile >/dev/null 2>&1; then
    SetFile -c icnC "$MOUNT/.VolumeIcon.icns" || true
    SetFile -a C "$MOUNT" || warn "SetFile could not flag the volume icon"
  else
    # kHasCustomIcon (0x0400) in the Finder flags of the volume root.
    xattr -wx com.apple.FinderInfo \
      "0000000000000000040000000000000000000000000000000000000000000000" "$MOUNT" \
      || warn "could not flag the volume icon"
  fi
  echo "Set the volume icon"
else
  warn "no AppIcon.icns in the app, the DMG keeps the default volume icon"
fi

# 5. Finder window layout.
background_line=""
if [ -n "$BACKGROUND" ]; then
  background_line="set background picture of viewOptions to file \".background:$BACKGROUND\""
fi
LAYOUT_SCRIPT="
tell application \"Finder\"
  tell disk \"$DISK_NAME\"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {$WIN_X, $WIN_Y, $((WIN_X + WIN_W)), $((WIN_Y + WIN_H))}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to $ICON_SIZE
    set text size of viewOptions to 13
    $background_line
    set position of item \"Maramao.app\" of container window to {$APP_POS}
    set position of item \"Applications\" of container window to {$APPS_POS}
    close
    open
    update without registering applications
    delay 2
    close
  end tell
end tell
"

# Runs the layout script, killing it if Finder does not answer in time
# (macOS has no `timeout`).
run_layout() {
  osascript -e "$LAYOUT_SCRIPT" &
  local pid=$!
  local waited=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$waited" -ge 90 ]; then
      kill "$pid" 2>/dev/null || true
      wait "$pid" 2>/dev/null || true
      echo "osascript timed out after ${waited}s" >&2
      return 1
    fi
    sleep 1
    waited=$((waited + 1))
  done
  wait "$pid"
}

LAYOUT_OK=0
for attempt in 1 2; do
  if run_layout; then
    LAYOUT_OK=1
    break
  fi
  echo "Finder layout failed (attempt $attempt)" >&2
  sleep 3
done

# Finder writes .DS_Store lazily; give it a moment.
if [ "$LAYOUT_OK" = 1 ]; then
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -f "$MOUNT/.DS_Store" ] && break
    sleep 1
  done
fi
if [ "$LAYOUT_OK" = 1 ] && [ -f "$MOUNT/.DS_Store" ]; then
  echo "Finder layout: OK (icon view, background, icons placed)"
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "::notice::DMG Finder layout applied (icon view, background, icons placed)"
  fi
else
  LAYOUT_OK=0
  warn "Finder layout could not be applied; the DMG works but shows a plain window"
fi

# 6. Finish the volume: read-only permissions, no Spotlight leftovers.
chmod -Rf go-w "$MOUNT" 2>/dev/null || true
rm -rf "$MOUNT/.fseventsd" "$MOUNT/.Trashes" 2>/dev/null || true
sync
detach
trap - EXIT

# 7. Compress and sign.
rm -f "$DMG"
hdiutil convert "$RW_DMG" -format UDZO -imagekey zlib-level=9 -o "$DMG" >/dev/null
rm -f "$RW_DMG"

if [ "$SIGN_IDENTITY" = "-" ]; then
  codesign --force --sign - "$DMG"
else
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi
hdiutil verify "$DMG" >/dev/null

echo "Built $DMG ($(du -h "$DMG" | cut -f1 | tr -d ' '), Finder layout: $([ "$LAYOUT_OK" = 1 ] && echo yes || echo no))"
