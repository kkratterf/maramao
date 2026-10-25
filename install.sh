#!/bin/sh
# Installs Maramao.app from the latest GitHub release.
#
#   curl -fsSL https://raw.githubusercontent.com/kkratterf/maramao/main/install.sh | sh
#
# Uninstall:
#   curl -fsSL https://raw.githubusercontent.com/kkratterf/maramao/main/install.sh | sh -s -- --uninstall
#
# Environment:
#   MARAMAO_VERSION      release to install, e.g. v0.1.0 (default: latest)
#   MARAMAO_INSTALL_DIR  where to put Maramao.app (default: /Applications,
#                        or ~/Applications if /Applications is not writable)
#   MARAMAO_NO_OPEN=1    do not offer to open Maramao after installing

set -eu

REPO="kkratterf/maramao"
APP_NAME="Maramao.app"
BUNDLE_ID="com.kkratterf.maramao"

say() { printf '%s\n' "$*"; }
warn() { printf 'maramao: %s\n' "$*" >&2; }
fail() { printf 'maramao: %s\n' "$*" >&2; exit 1; }

usage() {
  say "Uso: install.sh [--uninstall]"
  say ""
  say "  (nessuna opzione)  installa o aggiorna Maramao.app"
  say "  --uninstall        rimuove Maramao.app e le sue impostazioni"
  say ""
  say "Variabili: MARAMAO_VERSION, MARAMAO_INSTALL_DIR, MARAMAO_NO_OPEN=1"
}

mode="install"
for arg in "$@"; do
  case "$arg" in
    --uninstall) mode="uninstall" ;;
    -h | --help) usage; exit 0 ;;
    *) usage >&2; fail "opzione sconosciuta: $arg (unknown option)" ;;
  esac
done

[ "$(uname -s)" = "Darwin" ] \
  || fail "Maramao è un'app per macOS, qui non posso installarla (macOS only)"

macos="$(sw_vers -productVersion 2>/dev/null || echo 0)"
major="${macos%%.*}"
case "$major" in
  '' | *[!0-9]*) major=0 ;;
esac
[ "$major" -ge 13 ] \
  || fail "serve macOS 13 Ventura o successivo, qui c'è macOS $macos (macOS 13+ required)"

# Picks the folder for Maramao.app.
install_dir() {
  if [ -n "${MARAMAO_INSTALL_DIR:-}" ]; then
    printf '%s\n' "$MARAMAO_INSTALL_DIR"
  elif [ -w /Applications ]; then
    printf '%s\n' /Applications
  else
    printf '%s\n' "$HOME/Applications"
  fi
}

# Quits a running Maramao: politely first, then for real.
quit_maramao() {
  pgrep -x Maramao >/dev/null 2>&1 || return 0
  say "Chiudo Maramao..."
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  i=0
  while [ "$i" -lt 10 ] && pgrep -x Maramao >/dev/null 2>&1; do
    sleep 0.5
    i=$((i + 1))
  done
  pkill -x Maramao >/dev/null 2>&1 || true
}

# True when we can ask the user a question, even under `curl | sh`.
can_ask() {
  [ -t 1 ] && (: </dev/tty) 2>/dev/null
}

uninstall() {
  quit_maramao
  removed=0
  for dir in "${MARAMAO_INSTALL_DIR:-/Applications}" /Applications "$HOME/Applications"; do
    if [ -d "$dir/$APP_NAME" ]; then
      rm -rf "${dir:?}/$APP_NAME" || fail "non riesco a rimuovere $dir/$APP_NAME (prova con sudo)"
      say "Rimosso $dir/$APP_NAME"
      removed=1
    fi
  done
  if defaults read "$BUNDLE_ID" >/dev/null 2>&1; then
    defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
    say "Rimosse le impostazioni ($BUNDLE_ID)"
  fi
  [ "$removed" = 1 ] || say "Maramao.app non era installato."
  say "Se avevi attivato \"Apri Maramao all'avvio del Mac\", macOS toglie l'elemento"
  say "da solo; controlla in Impostazioni di Sistema → Generali → Elementi login."
  say "Ciao ciao! 🐱 I gatti ti mancheranno."
}

if [ "$mode" = "uninstall" ]; then
  uninstall
  exit 0
fi

command -v curl >/dev/null 2>&1 || fail "serve curl per scaricare Maramao (curl is required)"
command -v ditto >/dev/null 2>&1 || fail "serve ditto (ditto is required)"

api="https://api.github.com/repos/$REPO"

version="${MARAMAO_VERSION:-}"
if [ -z "$version" ]; then
  # /releases/latest skips pre-releases, so fall back to the newest release.
  json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api/releases/latest" 2>/dev/null)" \
    || json="$(curl -fsSL -H 'Accept: application/vnd.github+json' "$api/releases?per_page=1" 2>/dev/null)" \
    || fail "non riesco a trovare l'ultima release (GitHub API unreachable)"
  version="$(printf '%s\n' "$json" | grep -m 1 '"tag_name"' | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
  [ -n "$version" ] || fail "nessuna release trovata su github.com/$REPO/releases"
fi
case "$version" in
  v*) ;;
  *) version="v$version" ;;
esac

name="Maramao-${version#v}.zip"
base="https://github.com/$REPO/releases/download/$version"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

say "🍅 Scarico Maramao $version..."
curl -fsSL "$base/$name" -o "$tmp/$name" || fail "download fallito: $base/$name"

if curl -fsSL "$base/SHA256SUMS.txt" -o "$tmp/SHA256SUMS.txt" 2>/dev/null; then
  expected="$(grep " \*\{0,1\}$name\$" "$tmp/SHA256SUMS.txt" | cut -d' ' -f1)"
  actual="$(shasum -a 256 "$tmp/$name" | cut -d' ' -f1)"
  [ -n "$expected" ] || fail "$name non è in SHA256SUMS.txt"
  [ "$expected" = "$actual" ] || fail "checksum sbagliato per $name: il download è corrotto, riprova"
  say "Checksum SHA-256 verificato ✓"
else
  warn "questa release non ha SHA256SUMS.txt, salto la verifica del checksum"
fi

ditto -x -k "$tmp/$name" "$tmp/unzipped" || fail "non riesco a estrarre $name"
[ -d "$tmp/unzipped/$APP_NAME" ] || fail "$name non contiene $APP_NAME"

dir="$(install_dir)"
mkdir -p "$dir" || fail "non riesco a creare $dir"
[ -w "$dir" ] || fail "non posso scrivere in $dir (prova MARAMAO_INSTALL_DIR=\$HOME/Applications)"
dest="$dir/$APP_NAME"

quit_maramao
if [ -e "$dest" ]; then
  rm -rf "$dest" || fail "non riesco a sostituire $dest"
fi
ditto "$tmp/unzipped/$APP_NAME" "$dest" || fail "non riesco a copiare l'app in $dir"
# Not notarized yet: clear the quarantine flag so Gatekeeper lets it start.
xattr -dr com.apple.quarantine "$dest" 2>/dev/null || true

say "Tutto pronto! 🐱 Maramao $version installato in $dest"
say "Lo trovi nella barra dei menu, in alto a destra (niente icona nel Dock)."

if [ "${MARAMAO_NO_OPEN:-0}" = 1 ] || ! can_ask; then
  say "Per aprirlo: open \"$dest\""
  exit 0
fi
printf 'Apro Maramao adesso? [S/n] '
answer=""
read -r answer </dev/tty || answer="n"
case "$answer" in
  '' | [SsYy]*) open "$dest" ;;
  *) say "Per aprirlo: open \"$dest\"" ;;
esac
