#Requires AutoHotkey v2.0
; ============================================================
;  Tray.ahk - Icono de bandeja: vigilante, pausar, salir
; ============================================================

TrayName := "Zonely"
TrayIcon := A_ScriptDir "\assets\zonely.ico"

InitTray() {
    A_IconTip := TrayName
    if FileExist(TrayIcon)
        TraySetIcon(TrayIcon)          ; el icono de Zonely en lugar de la «H» verde de AutoHotkey
    tray := A_TrayMenu
    tray.Delete()                       ; quita las entradas por defecto de AHK
    tray.Add("Abrir Zonely", OpenPanel)
    tray.Default := "Abrir Zonely"      ; el doble clic sobre el icono abre el panel
    tray.Add()
    tray.Add("Vigilante de maximizado", ToggleWatcher)
    tray.Add("Pausar atajos", TogglePause)
    tray.Add()
    tray.Add("Salir", (*) => ExitApp())
}

; Comando que abre el panel: instalado, Zonely.exe está junto a la carpeta resources; desde el código, Electron con la carpeta panel.
; Devuelve "" si no encuentra ninguno. Si el panel ya está abierto, se trae al frente (el panel es de instancia única).
PanelCommand() {
    installed := A_ScriptDir "\..\Zonely.exe"
    if FileExist(installed)
        return '"' installed '"'
    electron := A_ScriptDir "\panel\node_modules\electron\dist\electron.exe"
    if FileExist(electron)
        return '"' electron '" "' A_ScriptDir '\panel"'
    return ""
}

OpenPanel(*) {
    cmd := PanelCommand()
    if cmd = "" {
        Notify("No encuentro el panel de Zonely", 2500)
        return
    }
    try Run(cmd, A_ScriptDir)
    catch Error as e
        Log("No pude abrir el panel: " e.Message, "WARN")
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
