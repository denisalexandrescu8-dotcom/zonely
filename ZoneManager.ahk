#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, StdOut                  ; los avisos del analizador NO abren diálogos que bloqueen el arranque
Persistent

; Datos del ejecutable cuando se compila con Ahk2Exe (scripts\build-installer.ps1).
;@Ahk2Exe-SetName Zonely
;@Ahk2Exe-SetDescription Zonely (motor)
;@Ahk2Exe-SetCompanyName Zonely

; ============================================================
;  ZoneManager.ahk - Zonely, gestor de zonas para monitor 5120x1440
; ============================================================

; DPI: Per-Monitor V2 (-4) para que todas las coordenadas sean píxeles reales.
; AHK v2 ya arranca así, pero lo forzamos para no depender de la versión.
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr")

#Include lib\Log.ahk
#Include lib\Config.ahk
#Include lib\Tray.ahk
#Include lib\Zones.ahk
#Include lib\Profiles.ahk
#Include lib\GameMode.ahk
#Include lib\Watcher.ahk
#Include lib\Debug.ahk
#Include lib\Dim.ahk
#Include lib\Snap.ahk
#Include lib\Restore.ahk
#Include lib\Hotkeys.ahk
#Include lib\Ipc.ahk
#Include lib\Updates.ahk

try {
    Config.Load()
} catch Error as e {
    Log("Configuración no válida: " e.Message, "ERROR")
    MsgBox("Error en zones.ini:`n`n" e.Message, "Zonely", "Iconx")
    ExitApp
}

DirCreate(IpcDir)
ApplyResume()
InitTray()
if Config.WatcherEnabled
    StartWatcher()
TrayWatcherChecked(Config.WatcherEnabled)
if Config.SnapEnabled
    StartSnap()
StartRestore()
RegisterHotkeys()
StartIpc()
StartBackgroundUpdates()
DimRefresh()
ShowZonesSummary()
Log("Motor iniciado v" AppVersion " · perfil " Config.ProfileName " · vigilante " (WatcherOn ? "sí" : "no") " · encaje " (SnapOn ? "sí" : "no"))
OnExit((reason, code) => Log("Motor detenido (" reason ")"))

; Muestra un aviso con las zonas cargadas (útil al arrancar y al recargar).
ShowZonesSummary() {
    txt := "Perfil: " Config.ProfileName
    for _, z in Config.Zones
        txt .= "`n" z.ToString()
    TrayTip(txt, "Zonely activo")
}
