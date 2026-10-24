# Construye el instalador de Windows de Zonely:  dist\installer\Zonely-Setup-<versión>.exe
#   1) compila el motor (ZoneManager.ahk) a dist\engine\ZonelyEngine.exe con Ahk2Exe
#   2) empaqueta el panel (Electron) + el motor con electron-builder (NSIS, por usuario)
#
# Requisitos: AutoHotkey v2, Ahk2Exe (https://github.com/AutoHotkey/Ahk2Exe/releases) y `npm install` hecho en panel\.
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1 [-Ahk2Exe C:\ruta\Ahk2Exe.exe] [-DirOnly]
#   -DirOnly  solo genera la carpeta sin empaquetar (dist\installer\win-unpacked), útil para probar.
#   -AhkBase  ruta de AutoHotkey64.exe (v2) que se usa como base del .exe (variable AHK_BASE); por defecto, el instalado.
param([string]$Ahk2Exe = $env:AHK2EXE, [string]$AhkBase = $env:AHK_BASE, [switch]$DirOnly)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$version = (Get-Content (Join-Path $root 'version.txt') -Raw).Trim()

# --- 1) Motor ---
if (-not $Ahk2Exe) {
  $Ahk2Exe = @("$env:LOCALAPPDATA\Programs\AutoHotkey\Compiler\Ahk2Exe.exe", "$env:ProgramFiles\AutoHotkey\Compiler\Ahk2Exe.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Ahk2Exe -or -not (Test-Path $Ahk2Exe)) { throw 'No encuentro Ahk2Exe.exe: pasa -Ahk2Exe <ruta> o define la variable AHK2EXE.' }
$base = @($AhkBase, "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe", "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe") | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $base) { throw 'No encuentro AutoHotkey v2 (AutoHotkey64.exe).' }
$engineDir = Join-Path $root 'dist\engine'
New-Item -ItemType Directory -Force $engineDir | Out-Null
$engine = Join-Path $engineDir 'ZonelyEngine.exe'
Write-Host "Compilando el motor ($version)..."
$p = Start-Process $Ahk2Exe -ArgumentList '/in', "`"$root\ZoneManager.ahk`"", '/out', "`"$engine`"", '/icon', "`"$root\assets\zonely.ico`"", '/base', "`"$base`"", '/silent', 'verbose' -Wait -PassThru -WindowStyle Hidden
if ($p.ExitCode -ne 0 -or -not (Test-Path $engine)) { throw "Ahk2Exe falló (código $($p.ExitCode))." }

# --- 2) Panel + instalador ---
Push-Location (Join-Path $root 'panel')
try {
  if (-not (Test-Path 'node_modules\electron-builder')) { throw 'Falta electron-builder: ejecuta "npm install" dentro de panel.' }
  $ebArgs = @('electron-builder', '--win', "-c.extraMetadata.version=$version")
  if ($DirOnly) { $ebArgs += '--dir' }
  Write-Host 'Empaquetando el panel...'
  & npx @ebArgs
  if ($LASTEXITCODE -ne 0) { throw "electron-builder falló (código $LASTEXITCODE)." }
} finally { Pop-Location }
Write-Host "Listo: $root\dist\installer"
