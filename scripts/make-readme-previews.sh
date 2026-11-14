#!/usr/bin/env bash
# Turns the website's mode recordings (site/media/mode-*.mp4) into the looping
# previews the README shows (Resources/readme/mode-*.webp). GitHub cannot play a
# video committed to the repository, but it plays an animated WebP inline.
# Run it again whenever the recordings change.
# Needs ffmpeg built with libwebp (brew install ffmpeg).
# Usage: scripts/make-readme-previews.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/Resources/readme"
mkdir -p "$OUT"

# name, seconds of the clip to use, playback speed (2 = twice as fast), WebP quality
while read -r name seconds speed quality; do
  src="$ROOT/site/media/mode-$name.mp4"
  [ -f "$src" ] || { echo "error: $src not found" >&2; exit 1; }
  ffmpeg -nostdin -v error -y -t "$seconds" -i "$src" \
    -vf "setpts=PTS/$speed,fps=12,scale=720:-1:flags=lanczos" \
    -an -c:v libwebp_anim -quality "$quality" -compression_level 6 -loop 0 \
    "$OUT/mode-$name.webp"
  echo "Wrote Resources/readme/mode-$name.webp ($(du -k "$OUT/mode-$name.webp" | cut -f1) KB)"
done <<'LIST'
laser 12 1.5 60
pile 19 2 40
sleepy 10 1 60
LIST
