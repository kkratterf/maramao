#!/usr/bin/env bash
# Renders every break mode to PNGs, so a visual change can be reviewed without a Mac.
# The app snapshots its own windows (MARAMAO_SHOTS, see Sources/Maramao/App/ScreenshotHooks.swift):
# no Screen Recording permission needed, which CI runners do not have.
# Usage: scripts/render-screenshots.sh [scenario ...]
#   default scenarios: every break mode
# Output: dist/screenshots/<scenario>/*.png plus a Markdown report (appended to
# $GITHUB_STEP_SUMMARY in CI). Needs dist/Maramao.app (scripts/build-app.sh release)
# and a logged-in GUI session.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/Maramao.app"
BIN="$APP/Contents/MacOS/Maramao"
OUT="${OUT:-$ROOT/dist/screenshots}"
DELAYS="${DELAYS:-2,5,9}"
# Generous: the app quits itself right after the last shot.
TIMEOUT="${TIMEOUT:-40}"

[ -x "$BIN" ] || { echo "error: $BIN not found, run scripts/build-app.sh release first" >&2; exit 1; }

if [ "$#" -gt 0 ]; then
  SCENARIOS=("$@")
else
  SCENARIOS=(walkingCat memeWall sleepyCat catPile laserChase keyboardCat)
fi

rm -rf "$OUT"
mkdir -p "$OUT"

report="$(mktemp)"
{
  echo "## Maramao screenshots"
  echo
  echo "Shots at ${DELAYS}s into each break, rendered by the app itself."
  echo
  echo "| Scenario | Shots | Blank | Notes |"
  echo "| --- | --- | --- | --- |"
} > "$report"

blank_total=0
empty_scenarios=""

for scenario in "${SCENARIOS[@]}"; do
  pkill -x Maramao 2>/dev/null || true
  dir="$OUT/$scenario"
  mkdir -p "$dir"
  MARAMAO_MEASURE="$scenario" MARAMAO_SHOTS="$dir" MARAMAO_SHOT_DELAYS="$DELAYS" \
    "$BIN" > "$dir/log.txt" 2>&1 &
  pid=$!

  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt "$TIMEOUT" ]; do
    sleep 1
    waited=$((waited + 1))
  done
  note=""
  if kill -0 "$pid" 2>/dev/null; then
    note="did not quit after ${TIMEOUT}s, killed"
    kill "$pid" 2>/dev/null || true
  fi
  wait "$pid" 2>/dev/null || true

  shots=$(find "$dir" -name '*.png' | wc -l | tr -d ' ')
  # "ink=0.0%" means the window rendered nothing at all.
  blank=0
  if [ -f "$dir/manifest.txt" ]; then
    blank=$(grep -c 'ink=0.0%' "$dir/manifest.txt" || true)
    none=$(grep -c 'none=no-visible-window' "$dir/manifest.txt" || true)
    if [ "$none" -gt 0 ]; then
      note="${note:+$note; }$none shot(s) had no window"
    fi
  else
    note="${note:+$note; }no manifest (crashed before the first shot?)"
  fi
  blank_total=$((blank_total + blank))
  if [ "$shots" -eq 0 ]; then
    empty_scenarios="${empty_scenarios:+$empty_scenarios }$scenario"
  fi

  echo "| $scenario | $shots | $blank | ${note:-ok} |" >> "$report"
done

pkill -x Maramao 2>/dev/null || true

cat "$report"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  cat "$report" >> "$GITHUB_STEP_SUMMARY"
fi
rm -f "$report"

# Blank frames are worth a look but not worth blocking a PR on: a mode may legitimately
# be mid-animation off screen at one of the delays.
if [ "$blank_total" -gt 0 ]; then
  echo "::warning::$blank_total screenshot(s) rendered an empty frame"
fi
# No screenshot at all means the app crashed or drew nothing: that is a real failure.
if [ -n "$empty_scenarios" ]; then
  echo "::error::no screenshot for: $empty_scenarios"
  exit 1
fi
