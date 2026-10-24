# Quita los accesos directos creados por install-startup.ps1.
$startup = [Environment]::GetFolderPath('Startup')
$programs = Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs'
foreach ($f in @((Join-Path $startup 'Zonely (motor).lnk'), (Join-Path $programs 'Zonely.lnk'), (Join-Path $startup 'Gestor de zonas (motor).lnk'), (Join-Path $programs 'Gestor de zonas.lnk'))) {   # incluye los nombres antiguos
  if (Test-Path $f) { Remove-Item $f; Write-Host "Borrado: $f" }
}
