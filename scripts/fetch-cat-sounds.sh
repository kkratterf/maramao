#!/usr/bin/env bash
# Downloads the cat sounds listed in Resources/cat-sounds.tsv, converts them to mono AAC
# and writes them to <output>/<kind>/<name>.m4a.
# Usage: scripts/fetch-cat-sounds.sh <output-directory>
# Downloads are cached in .build/cat-sounds, so only the first build hits the network.
# Exits non-zero when a sound cannot be fetched, fails its checksum or cannot be converted.
set -euo pipefail

OUT="${1:?usage: fetch-cat-sounds.sh <output-directory>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$ROOT/Resources/cat-sounds.tsv"
CACHE="$ROOT/.build/cat-sounds"

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
  dest="$OUT/$kind/$name.m4a"
  # Mono, 44.1 kHz like the synthesized sounds, AAC to keep the app small.
  afconvert -f m4af -d aac@44100 -c 1 -b 96000 "$src" "$dest"
  size=$(wc -c < "$dest" | tr -d ' ')
  total=$((total + size))
  echo "cat sound $kind/$name.m4a: $size bytes (source sha256 $actual, $page, $author)"
done < "$LIST"
echo "Cat sounds: $((total / 1024)) KB"
