#!/usr/bin/env bash
# Generates Metadata.appintents (the Shortcuts actions in Sources/Maramao/App/Intents.swift)
# into the given directory, normally Maramao.app/Contents/Resources.
#
# Xcode runs `appintentsmetadataprocessor` after compiling; SwiftPM does not, and without
# this metadata the intents compile but never show up in Shortcuts. So: build once more
# with the compiler's constant-value extraction turned on, then run the processor on it.
#
# Usage: scripts/make-appintents-metadata.sh <output-dir> [debug|release]
set -euo pipefail

OUT="${1:?usage: make-appintents-metadata.sh <output-dir> [debug|release]}"
CONFIG="${2:-release}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/.build/appintents"
BUILD_PATH="$WORK/build"
DEPLOYMENT_TARGET="13.0"

cd "$ROOT"
mkdir -p "$WORK"

PROCESSOR="$(xcrun --find appintentsmetadataprocessor)"
TOOLCHAIN="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
XCODE_BUILD="$(xcodebuild -version | awk '/Build version/ {print $3}')"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$ROOT/Resources/Info.plist")"

# Protocols whose conforming types the compiler should describe in .swiftconstvalues.
cat > "$WORK/protocols.json" <<'JSON'
["AppIntent","EntityQuery","AppEntity","TransientEntity","AppEnum","AppShortcutProviding","AppShortcutsProvider","AnyResolverProviding","AppIntentsPackage","DynamicOptionsProvider"]
JSON

swift build -c "$CONFIG" --arch arm64 --build-path "$BUILD_PATH" \
  -Xswiftc -emit-const-values \
  -Xswiftc -Xfrontend -Xswiftc -const-gather-protocols-file \
  -Xswiftc -Xfrontend -Xswiftc "$WORK/protocols.json"
BIN_DIR="$(swift build -c "$CONFIG" --arch arm64 --build-path "$BUILD_PATH" --show-bin-path)"

find "$BUILD_PATH" -name "Maramao.swiftconstvalues" > "$WORK/constvalues.list"
find "$ROOT/Sources/Maramao" -name "*.swift" > "$WORK/sources.list"
: > "$WORK/metadata.list"
: > "$WORK/static-metadata.list"
if [ ! -s "$WORK/constvalues.list" ]; then
  echo "error: the compiler produced no .swiftconstvalues" >&2
  exit 1
fi

mkdir -p "$OUT"
rm -rf "$OUT/Metadata.appintents"
# --force: there is no Xcode dependency file to compare against, always regenerate.
"$PROCESSOR" \
  --toolchain-dir "$TOOLCHAIN" \
  --output "$OUT" \
  --module-name Maramao \
  --sdk-root "$SDK" \
  --xcode-version "$XCODE_BUILD" \
  --platform-family macOS \
  --deployment-target "$DEPLOYMENT_TARGET" \
  --bundle-identifier "$BUNDLE_ID" \
  --target-triple "arm64-apple-macos$DEPLOYMENT_TARGET" \
  --binary-file "$BIN_DIR/Maramao" \
  --dependency-file "$WORK/appintents.d" \
  --stringsdata-file "$WORK/appintents.stringsdata" \
  --source-file-list "$WORK/sources.list" \
  --metadata-file-list "$WORK/metadata.list" \
  --static-metadata-file-list "$WORK/static-metadata.list" \
  --swift-const-vals-list "$WORK/constvalues.list" \
  --compile-time-extraction \
  --deployment-aware-processing \
  --force

if [ ! -f "$OUT/Metadata.appintents/extract.actionsdata" ]; then
  echo "error: appintentsmetadataprocessor wrote no Metadata.appintents" >&2
  exit 1
fi
echo "Created $OUT/Metadata.appintents"
