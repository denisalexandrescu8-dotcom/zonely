#!/usr/bin/env bash
# Construye el instalador de macOS de Zonely:  dist/installer/Zonely-<versión>-mac-arm64.dmg
#   1) compila el motor (mac/, Swift) en modo release
#   2) empaqueta el panel (Electron) + el motor con electron-builder
#   3) firma la app
#
# Requisitos: Xcode o sus herramientas de línea de comandos, Node.js y `npm install` hecho en panel/.
#
# Firma. macOS liga el permiso de Accesibilidad a la identidad de la firma. Una firma «ad hoc» cambia en cada compilación, así
# que tras cada actualización macOS volvería a pedir el permiso. Por eso, si están MAC_SIGN_P12_BASE64 y MAC_SIGN_P12_PASSWORD
# (un certificado autofirmado, sin valor ante Apple, guardado como secreto del repositorio), la app y el motor se firman con
# ese certificado, que es siempre el mismo: la identidad no cambia entre versiones y el permiso se conserva. Sin ellos
# (compilación local, forks) se firma «ad hoc» y funciona igual, salvo que macOS vuelve a pedir el permiso en cada versión.
# Uso:  scripts/build-mac.sh [--dir]      (--dir: solo genera la carpeta de la app, sin el .dmg)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/version.txt")"
sign_name="Zonely Code Signing"

echo "Compilando el motor ($version)..."
(cd "$root/mac" && swift build -c release)
test -x "$root/mac/.build/release/ZonelyEngine"

cd "$root/panel"
test -d node_modules/electron-builder || { echo 'Falta electron-builder: ejecuta "npm install" dentro de panel.' >&2; exit 1; }

if [ -n "${MAC_SIGN_P12_BASE64:-}" ] && [ -n "${MAC_SIGN_P12_PASSWORD:-}" ]; then
  echo "Preparando el certificado de firma..."
  work="$(mktemp -d)"
  keychain="$work/zonely-signing.keychain-db"
  keychain_pw="$(uuidgen)"
  security create-keychain -p "$keychain_pw" "$keychain"
  security set-keychain-settings -lut 21600 "$keychain"
  security unlock-keychain -p "$keychain_pw" "$keychain"
  printf '%s' "$MAC_SIGN_P12_BASE64" | base64 --decode > "$work/sign.p12"
  security import "$work/sign.p12" -k "$keychain" -P "$MAC_SIGN_P12_PASSWORD" -T /usr/bin/codesign -T /usr/bin/security
  security set-key-partition-list -S apple-tool:,apple: -s -k "$keychain_pw" "$keychain" > /dev/null
  # que codesign encuentre este llavero junto a los demás
  security list-keychains -d user -s "$keychain" $(security list-keychains -d user | tr -d '"')
  security find-identity -p codesigning "$keychain" || true

  echo "Empaquetando el panel (sin firmar)..."
  rm -rf "$root/dist/installer"
  npx electron-builder --mac --dir --publish never "-c.extraMetadata.version=$version" "-c.mac.identity=null"
  app="$(find "$root/dist/installer" -maxdepth 2 -name 'Zonely.app' -print -quit)"
  test -d "$app" || { echo "No encuentro Zonely.app en dist/installer" >&2; exit 1; }

  echo "Firmando con «${sign_name}»..."
  # primero el motor (va suelto en Resources, con su propio identificador) y después la app entera
  codesign --force --sign "${sign_name}" --keychain "$keychain" --identifier com.zonely.engine "$app/Contents/Resources/ZonelyEngine"
  codesign --force --deep --sign "${sign_name}" --keychain "$keychain" "$app"
  codesign --verify --deep --strict "$app"
  echo "Requisito de la app:";    codesign -d -r- "$app" 2>&1 | grep -i "designated" || true
  echo "Requisito del motor:";    codesign -d -r- "$app/Contents/Resources/ZonelyEngine" 2>&1 | grep -i "designated" || true

  if [ "${1:-}" != "--dir" ]; then
    echo "Creando el .dmg..."
    npx electron-builder --mac dmg --prepackaged "$app" --publish never "-c.extraMetadata.version=$version" "-c.mac.identity=null"
  fi
  security delete-keychain "$keychain" || true
else
  echo "Empaquetando el panel (firma ad hoc)..."
  extra=()
  if [ "${1:-}" = "--dir" ]; then extra+=(--dir); fi
  npx electron-builder --mac --publish never "-c.extraMetadata.version=$version" ${extra[@]+"${extra[@]}"}
fi
echo "Listo: $root/dist/installer"
