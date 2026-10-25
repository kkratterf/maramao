#!/usr/bin/env bash
# TEMPORARY probe: extract App Intents metadata for the SwiftPM executable by hand.
note() {
python3 - "$1" "$2" <<'PY'
import sys
title, path = sys.argv[1], sys.argv[2]
try:
    data = open(path, errors="replace").read()
except Exception as e:
    data = str(e)
if not data.strip():
    data = "(empty)"
for n in range(0, min(len(data), 3500 * 6), 3500):
    chunk = data[n:n+3500].replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print(f"::notice title={title} {n//3500}::{chunk}")
PY
}
set -x
rm -rf /tmp/dd
xcodebuild -scheme Maramao -destination 'platform=macOS,arch=arm64' -derivedDataPath /tmp/dd -configuration Release build > /tmp/xb.log 2>&1
P=$(find /tmp/dd -name "Maramao_const_extract_protocols.json" | head -1)
cp "$P" /tmp/protocols.json
note "protocols" /tmp/protocols.json

# Build with SwiftPM, asking the compiler for const values.
rm -rf .build/intents
swift build -c release --build-path .build/intents \
  -Xswiftc -emit-const-values -Xswiftc -const-gather-protocols-file -Xswiftc /tmp/protocols.json > /tmp/sb.log 2>&1
echo "swift build exit $?" > /tmp/q1.txt
tail -5 /tmp/sb.log >> /tmp/q1.txt
find .build/intents -name "*.swiftconstvalues" >> /tmp/q1.txt
note "spm-build" /tmp/q1.txt

CV=$(find .build/intents -name "*.swiftconstvalues" -path "*Maramao.build*" | head -1)
[ -n "$CV" ] || CV=$(find /tmp/dd -name "Maramao-master.swiftconstvalues" | head -1)
echo "$CV" > /tmp/cvlist.txt
find "$PWD/Sources/Maramao" -name "*.swift" > /tmp/srclist.txt
DEV=$(xcode-select -p)
SDK=$(xcrun --sdk macosx --show-sdk-path)
XV=$(xcodebuild -version | awk '/Build version/{print $3}')
rm -rf /tmp/ai-out; mkdir -p /tmp/ai-out
xcrun appintentsmetadataprocessor \
  --toolchain-dir "$DEV/Toolchains/XcodeDefault.xctoolchain" \
  --module-name Maramao \
  --sdk-root "$SDK" \
  --xcode-version "$XV" \
  --platform-family macOS \
  --deployment-target 13.0 \
  --bundle-identifier com.kkratterf.maramao \
  --output /tmp/ai-out \
  --target-triple arm64-apple-macos13.0 \
  --binary-file "$(find .build/intents -type f -name Maramao -perm -111 | head -1)" \
  --source-file-list /tmp/srclist.txt \
  --swift-const-vals-list /tmp/cvlist.txt \
  --force --compile-time-extraction --deployment-aware-processing \
  --no-app-shortcuts-localization > /tmp/q2.txt 2>&1
echo "processor exit $? (cv=$CV)" >> /tmp/q2.txt
find /tmp/ai-out -ls >> /tmp/q2.txt
note "processor" /tmp/q2.txt
for f in $(find /tmp/ai-out -type f | head -5); do echo "== $f"; head -c 1500 "$f"; echo; done > /tmp/q3.txt
note "output" /tmp/q3.txt
true
