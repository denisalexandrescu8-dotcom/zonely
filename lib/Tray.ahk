#Requires AutoHotkey v2.0
; ============================================================
;  Tray.ahk - Icono de bandeja: pausar, recargar, salir
; ============================================================

TrayName := "Zonely"
TrayIcon := A_ScriptDir "\assets\zonely.ico"

InitTray() {
    A_IconTip := TrayName
    if FileExist(TrayIcon)
        TraySetIcon(TrayIcon)          ; el icono de Zonely en lugar de la «H» verde de AutoHotkey
    tray := A_TrayMenu
    tray.Delete()                       ; quita las entradas por defecto de AHK
    tray.Add("Vigilante de maximizado", ToggleWatcher)
    tray.Add("Pausar atajos", TogglePause)
    tray.Add("Recargar (zones.ini)", (*) => ReloadKeepingState())
    tray.Add()
    tray.Add("Salir", (*) => ExitApp())
}

; Pausa/reanuda todos los atajos. Marca la entrada cuando está en pausa.
TogglePause(itemName, *) {
    Suspend(-1)
    if A_IsSuspended {
        A_TrayMenu.Check(itemName)
        A_IconTip := TrayName " (PAUSADO)"
    } else {
        A_TrayMenu.Uncheck(itemName)
        A_IconTip := TrayName
    }
}

; Marca/desmarca la entrada del vigilante según su estado.
TrayWatcherChecked(on) {
    if on
        A_TrayMenu.Check("Vigilante de maximizado")
    else
        A_TrayMenu.Uncheck("Vigilante de maximizado")
}
