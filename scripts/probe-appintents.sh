#!/usr/bin/env bash
# TEMPORARY probe: how can App Intents metadata be extracted for a SwiftPM executable?
set -x
xcodebuild -version
TC="$(xcode-select -p)/Toolchains/XcodeDefault.xctoolchain/usr/bin"
ls "$TC" | grep -i -E "intent|const" || true
xcrun --find appintentsmetadataprocessor || true
xcrun appintentsmetadataprocessor --help 2>&1 | head -80 || true
swiftc -frontend -help 2>&1 | grep -i const || true
swiftc --help-hidden 2>&1 | grep -i const || true
rm -rf /tmp/dd
xcodebuild -scheme Maramao -destination 'platform=macOS' -derivedDataPath /tmp/dd -configuration Release build > /tmp/xb.log 2>&1
echo "xcodebuild exit $?"
tail -20 /tmp/xb.log
grep -n -i -E "appintents|ExtractAppIntents|swiftconstvalues|const-gather" /tmp/xb.log | cut -c1-3000 | head -40
find /tmp/dd -iname "*appintents*" | head -20
find /tmp/dd -name "*.swiftconstvalues" | head -5
find /tmp/dd -name "*ConstExtract*" | head -5
true
