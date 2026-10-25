#!/usr/bin/env bash
# TEMPORARY probe: how can App Intents metadata be extracted for a SwiftPM executable?
# Output goes to annotations, since CI logs are not reachable from the agent.
note() { # chunks a file into notice annotations
  local title="$1" file="$2" i=0
  while IFS= read -r -d '' chunk || [ -n "$chunk" ]; do :; done < /dev/null
  python3 - "$title" "$file" <<'PY'
import sys
title, path = sys.argv[1], sys.argv[2]
data = open(path, errors="replace").read()
if not data.strip():
    data = "(empty)"
for n in range(0, min(len(data), 3500 * 8), 3500):
    chunk = data[n:n+3500].replace("%", "%25").replace("\r", "").replace("\n", "%0A")
    print(f"::notice title={title} {n//3500}::{chunk}")
PY
}
{
  xcodebuild -version
  xcrun --find appintentsmetadataprocessor
  xcrun appintentsmetadataprocessor --help 2>&1 | head -60
} > /tmp/p1.txt 2>&1
note "tools" /tmp/p1.txt

rm -rf /tmp/dd
xcodebuild -scheme Maramao -destination 'platform=macOS' -derivedDataPath /tmp/dd -configuration Release build > /tmp/xb.log 2>&1
echo "xcodebuild exit $?" > /tmp/p2.txt
grep -E "error:|BUILD (SUCCEEDED|FAILED)" /tmp/xb.log | head -10 >> /tmp/p2.txt
find /tmp/dd -iname "*appintents*" | head -20 >> /tmp/p2.txt
find /tmp/dd -name "*.swiftconstvalues" | head -3 >> /tmp/p2.txt
note "xcodebuild" /tmp/p2.txt

grep -n -E "^(ExtractAppIntentsMetadata|AppIntentsSSUTraining)" -A 3 /tmp/xb.log | cut -c1-6000 | head -20 > /tmp/p3.txt
grep -o -E "appintentsmetadataprocessor .*" /tmp/xb.log | head -1 | tr ' ' '\n' > /tmp/p4.txt
note "extract-step" /tmp/p3.txt
note "processor-args" /tmp/p4.txt
grep -o -E "swift-frontend .*Maramao.*" /tmp/xb.log | head -1 | tr ' ' '\n' | grep -n -i -E "const|emit" > /tmp/p5.txt
grep -o -E -- "-const-gather-protocols-file [^ ]+" /tmp/xb.log | head -1 | awk '{print $2}' | xargs cat >> /tmp/p5.txt 2>/dev/null
note "swiftc-const" /tmp/p5.txt
true
