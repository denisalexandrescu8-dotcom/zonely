#!/usr/bin/env bash
# Construye el instalador de macOS de Zonely:  dist/installer/Zonely-<versión>-mac-arm64.dmg
#   1) compila el motor (mac/, Swift) en modo release
#   2) empaqueta el panel (Electron) + el motor con electron-builder
#
# Requisitos: Xcode o sus herramientas de línea de comandos, Node.js y `npm install` hecho en panel/.
# La app se firma «ad hoc» (sin certificado de Apple): al abrirla la primera vez, clic derecho → Abrir.
# Uso:  scripts/build-mac.sh [--dir]      (--dir: solo genera la carpeta de la app, sin el .dmg)
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
version="$(tr -d '[:space:]' < "$root/version.txt")"

echo "Compilando el motor ($version)..."
(cd "$root/mac" && swift build -c release)
test -x "$root/mac/.build/release/ZonelyEngine"

echo "Empaquetando el panel..."
cd "$root/panel"
test -d node_modules/electron-builder || { echo 'Falta electron-builder: ejecuta "npm install" dentro de panel.' >&2; exit 1; }
extra=()
if [ "${1:-}" = "--dir" ]; then extra+=(--dir); fi
npx electron-builder --mac --publish never "-c.extraMetadata.version=$version" ${extra[@]+"${extra[@]}"}
echo "Listo: $root/dist/installer"
