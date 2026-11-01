#!/usr/bin/env bash
# Downloads the cat photos listed in Resources/cat-photos.tsv, shrinks them and writes
# them to <output>/<kind>/<name>.heic (JPEG when sips cannot write HEIC).
# Usage: scripts/fetch-cat-photos.sh <output-directory>
# Downloads are cached in .build/cat-photos, so only the first build hits the network.
# Exits non-zero when a photo cannot be fetched or fails its checksum.
set -euo pipefail

OUT="${1:?usage: fetch-cat-photos.sh <output-directory>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$ROOT/Resources/cat-photos.tsv"
CACHE="$ROOT/.build/cat-photos"
# Long edge in pixels and quality: sharp enough full screen, small enough for the app.
MAX_EDGE=2048
QUALITY=60

mkdir -p "$CACHE"
rm -rf "$OUT"
total=0
while IFS=$'\t' read -r kind name url sha page author; do
  case "$kind" in ''|'#'*) continue ;; esac
  src="$CACHE/$name.${url##*.}"
  if [ ! -s "$src" ]; then
    curl -fsSL --retry 3 --retry-delay 2 -o "$src.part" "$url"
    mv "$src.part" "$src"
  fi
  actual="$(shasum -a 256 "$src" | cut -d' ' -f1)"
  # Tabs count as whitespace for read, so an empty column would shift the others: "-" means none.
  if [ "$sha" != "-" ] && [ "$sha" != "$actual" ]; then
    echo "error: $name: sha256 $actual, expected $sha ($url)" >&2
    rm -f "$src"
    exit 1
  fi
  mkdir -p "$OUT/$kind"
  dest="$OUT/$kind/$name.heic"
  if ! sips -Z "$MAX_EDGE" -s format heic -s formatOptions "$QUALITY" "$src" --out "$dest" >/dev/null 2>&1; then
    dest="$OUT/$kind/$name.jpg"
    sips -Z "$MAX_EDGE" -s format jpeg -s formatOptions "$QUALITY" "$src" --out "$dest" >/dev/null
  fi
  size=$(wc -c < "$dest" | tr -d ' ')
  total=$((total + size))
  echo "cat photo $kind/$(basename "$dest"): $size bytes (source sha256 $actual, $page, $author)"
done < "$LIST"
echo "Cat photos: $((total / 1024)) KB"
