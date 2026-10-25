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
rm -rf /tmp/dd
xcodebuild -scheme Maramao -destination 'platform=macOS' -derivedDataPath /tmp/dd -configuration Release build > /tmp/xb.log 2>&1
echo "xcodebuild exit $?" > /tmp/p2.txt
grep -E "error:|BUILD (SUCCEEDED|FAILED)" /tmp/xb.log | head -10 >> /tmp/p2.txt
find /tmp/dd -iname "*appintents*" | head -20 >> /tmp/p2.txt
find /tmp/dd -name "*.swiftconstvalues" | head -3 >> /tmp/p2.txt
note "xcodebuild" /tmp/p2.txt


grep -n "^ExtractAppIntentsMetadata" /tmp/xb.log > /tmp/p3.txt
for n in $(grep -n "^ExtractAppIntentsMetadata" /tmp/xb.log | cut -d: -f1); do
  sed -n "$((n+3)),$((n+25))p" /tmp/xb.log | cut -c1-400 >> /tmp/p3.txt
  echo ---- >> /tmp/p3.txt
done
find /tmp/dd -name "Metadata.appintents" -o -name "*.appintents" -type d >> /tmp/p3.txt
note "extract-steps" /tmp/p3.txt
line=$(grep -E "swiftc? .*-module-name Maramao " /tmp/xb.log | head -1)
echo "$line" | tr ' ' '\n' | grep -n -i -E "const|emit|wmo|whole|output-file-map|^-j|parse" > /tmp/p5.txt
for f in $(echo "$line" | tr ' ' '\n' | grep -A1 -- "-const-gather-protocols-file" | tail -1); do cat "$f"; done >> /tmp/p5.txt 2>&1
note "swiftc-const" /tmp/p5.txt
cat /tmp/dd/Build/Intermediates.noindex/Maramao.build/Release/Maramao.build/Objects-normal/arm64/Maramao.SwiftConstValuesFileList > /tmp/p6.txt 2>&1
head -c 3000 /tmp/dd/Build/Intermediates.noindex/Maramao.build/Release/Maramao.build/Objects-normal/arm64/Maramao-master.swiftconstvalues >> /tmp/p6.txt
note "constvalues" /tmp/p6.txt
true
