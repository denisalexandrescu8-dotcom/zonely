#!/usr/bin/env bash
# Instala (o actualiza) Zonely en macOS, Apple Silicon, sin el aviso de Gatekeeper.
#
#   curl -fsSL https://raw.githubusercontent.com/denisalexandrescu8-dotcom/zonely/main/scripts/install-mac.sh | bash
#
# Por qué existe: Zonely no está notarizada (hace falta una cuenta de pago de Apple). macOS marca como «en cuarentena»
# lo que se descarga con un navegador, y por eso pide ir a Privacidad y seguridad → «Abrir igualmente». Descargado con
# `curl` no se marca, así que la app se abre directamente. El script descarga el .dmg de la última release de GitHub,
# comprueba su SHA-256 y copia Zonely.app a /Applications. No instala nada más.
set -euo pipefail

REPO="denisalexandrescu8-dotcom/zonely"
DEST="/Applications/Zonely.app"

[ "$(uname -s)" = "Darwin" ] || { echo "Este instalador es solo para macOS." >&2; exit 1; }
[ "$(uname -m)" = "arm64" ] || { echo "Zonely para Mac está compilada solo para Apple Silicon (arm64)." >&2; exit 1; }

tmp="$(mktemp -d)"
mount=""
cleanup() {
  if [ -n "$mount" ]; then hdiutil detach "$mount" -quiet 2>/dev/null || true; fi
  rm -rf "$tmp"
}
trap cleanup EXIT

echo "Buscando la última versión de Zonely..."
json="$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest")"
url="$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*mac-arm64\.dmg"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
sums_url="$(printf '%s' "$json" | grep -o '"browser_download_url": *"[^"]*SHA256SUMS\.txt"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')"
[ -n "$url" ] || { echo "No encuentro el instalador de Mac en la última release." >&2; exit 1; }

name="$(basename "$url")"
dmg="$tmp/$name"
echo "Descargando $name..."
curl -fL --progress-bar -o "$dmg" "$url"

if [ -n "$sums_url" ]; then
  expected="$(curl -fsSL "$sums_url" | grep -F "$name" | awk '{print $1}' | head -1)"
  actual="$(shasum -a 256 "$dmg" | awk '{print $1}')"
  if [ -n "$expected" ] && [ "$expected" != "$actual" ]; then
    echo "La suma de comprobación no coincide: no se instala nada." >&2
    exit 1
  fi
  echo "Suma de comprobación correcta."
fi

# Si Zonely está abierta (panel o motor), se cierra antes de sustituirla.
osascript -e 'tell application "Zonely" to quit' >/dev/null 2>&1 || true
pkill -x ZonelyEngine 2>/dev/null || true
sleep 1

echo "Instalando en /Applications..."
mount="$(hdiutil attach "$dmg" -nobrowse -readonly | awk -F'\t' '/\/Volumes\//{print $NF; exit}')"
[ -n "$mount" ] || { echo "No pude abrir el .dmg." >&2; exit 1; }
app="$(find "$mount" -maxdepth 1 -name '*.app' | head -1)"
[ -n "$app" ] || { echo "No encuentro la aplicación dentro del .dmg." >&2; exit 1; }

rm -rf "$DEST" 2>/dev/null || sudo rm -rf "$DEST"
ditto "$app" "$DEST"
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true

echo "Zonely instalada en $DEST. Abriéndola..."
open "$DEST"
echo "Recuerda: la primera vez, concede el permiso de Accesibilidad a ZonelyEngine (Ajustes del Sistema → Privacidad y seguridad → Accesibilidad)."
