# Instala los accesos directos:
#  - Inicio de Windows: arranca el motor (ZoneManager.ahk) al iniciar sesión.
#  - Menú Inicio: "Zonely" abre el panel de control.
# Uso:  powershell -ExecutionPolicy Bypass -File scripts\install-startup.ps1
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ahk = @("$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe", "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahk) { throw 'No encuentro AutoHotkey v2 (AutoHotkey64.exe).' }
$electron = Join-Path $root 'panel\node_modules\electron\dist\electron.exe'
if (-not (Test-Path $electron)) { throw 'Falta el panel: ejecuta "npm install" dentro de la carpeta panel.' }

$shell = New-Object -ComObject WScript.Shell
function New-Link($path, $target, $linkArgs, $workDir, $desc) {
  $l = $shell.CreateShortcut($path)
  $l.TargetPath = $target; $l.Arguments = $linkArgs; $l.WorkingDirectory = $workDir; $l.Description = $desc; $l.IconLocation = (Join-Path $root 'assets\zonely.ico')
  $l.Save()
  Write-Host "Creado: $path"
}
$startup = [Environment]::GetFolderPath('Startup')
$programs = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
New-Link (Join-Path $startup 'Zonely (motor).lnk') $ahk "`"$root\ZoneManager.ahk`"" $root 'Zonely: motor'
New-Link (Join-Path $programs 'Zonely.lnk') $electron "`"$root\panel`"" (Join-Path $root 'panel') 'Zonely: panel'
