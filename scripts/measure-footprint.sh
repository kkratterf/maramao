#!/usr/bin/env bash
# Measures what Maramao costs: bundle size, memory and CPU while idle, while a
# pomodoro runs and during each break mode. Prints a Markdown report (and appends
# it to $GITHUB_STEP_SUMMARY in CI).
# Usage: scripts/measure-footprint.sh [scenario ...]
#   default scenarios: idle work walkingCat memeWall sleepyCat catPile
# Needs dist/Maramao.app (scripts/build-app.sh release) and a logged-in GUI session.
# CI runners are shared VMs: compare numbers from the same runner type, and treat
# small CPU differences as noise.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Maramao.app"
BIN="$APP/Contents/MacOS/Maramao"
WARMUP="${WARMUP:-6}"
WINDOW="${WINDOW:-20}"

[ -x "$BIN" ] || { echo "error: $BIN not found, run scripts/build-app.sh release first" >&2; exit 1; }

if [ "$#" -gt 0 ]; then
  SCENARIOS=("$@")
else
  SCENARIOS=(idle work walkingCat memeWall sleepyCat catPile)
fi

kb() { awk -v b="$1" 'BEGIN { printf "%.0f KB", b / 1024 }'; }

# ps cputime ([[dd-]hh:]mm:ss.ss) in seconds.
cpu_seconds() {
  ps -o time= -p "$1" | awk '{
    n = split($1, p, /[-:]/); s = 0
    for (i = 1; i <= n; i++) s = s * 60 + p[i]
    print s
  }'
}

report="$(mktemp)"
{
  echo "## Maramao footprint"
  echo
  echo "| Bundle | Size |"
  echo "| --- | --- |"
  echo "| Executable (all architectures) | $(kb "$(stat -f%z "$BIN")") |"
  # Fat binaries only: one slice per architecture.
  lipo -detailed_info "$BIN" 2>/dev/null | awk '
    $1 == "architecture" { arch = $2 }
    $1 == "size" && arch != "" { printf "| Executable (%s) | %.0f KB |\n", arch, $2 / 1024 }
  ' || true
  echo "| Maramao.app | $(du -sk "$APP" | awk '{ print $1 }') KB |"
  for zip in "$ROOT"/dist/Maramao-*.zip; do
    [ -f "$zip" ] && echo "| $(basename "$zip") | $(kb "$(stat -f%z "$zip")") |"
  done
  echo
  echo "Each scenario: ${WARMUP}s warm-up, then ${WINDOW}s measured."
  echo
  echo "| Scenario | CPU (avg) | Idle wakeups/s | Memory footprint | RSS |"
  echo "| --- | --- | --- | --- | --- |"
} > "$report"

for scenario in "${SCENARIOS[@]}"; do
  pkill -x Maramao 2>/dev/null || true
  if [ "$scenario" = "idle" ]; then
    "$BIN" >/dev/null 2>&1 &
  else
    MARAMAO_MEASURE="$scenario" "$BIN" >/dev/null 2>&1 &
  fi
  pid=$!
  sleep "$WARMUP"
  if ! kill -0 "$pid" 2>/dev/null; then
    echo "| $scenario | crashed | | | |" >> "$report"
    continue
  fi

  cpu_start=$(cpu_seconds "$pid")
  # The second top sample covers the whole window; idlew is idle wakeups in it.
  wakeups=$(top -l 2 -s "$WINDOW" -pid "$pid" -stats pid,idlew 2>/dev/null \
    | awk -v pid="$pid" '$1 == pid { w = $2 } END { print w + 0 }')
  cpu_end=$(cpu_seconds "$pid")

  footprint_line=$(footprint -p "$pid" 2>/dev/null | awk '/[Ff]ootprint:/ { $1 = ""; print; exit }' || true)
  rss=$(ps -o rss= -p "$pid" | tr -d ' ')

  cpu=$(awk -v a="$cpu_start" -v b="$cpu_end" -v w="$WINDOW" 'BEGIN { printf "%.1f%%", (b - a) / w * 100 }')
  rate=$(awk -v n="$wakeups" -v w="$WINDOW" 'BEGIN { printf "%.1f", n / w }')
  echo "| $scenario | $cpu | $rate | ${footprint_line:-n/a} | $(awk -v k="$rss" 'BEGIN { printf "%.1f MB", k / 1024 }') |" >> "$report"

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
done

cat "$report"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$report" >> "$GITHUB_STEP_SUMMARY"
fi
rm -f "$report"
