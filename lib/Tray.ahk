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
    tray.Add(T("Abrir Zonely"), OpenPanel)
    tray.Default := T("Abrir Zonely")      ; el doble clic sobre el icono abre el panel
    tray.Add()
    tray.Add(T("Perfiles"), TrayProfiles)  ; submenú con los perfiles de zones.ini (TrayRefreshProfiles lo rellena)
    TrayRefreshProfiles()
    tray.Add()
    tray.Add(T("Vigilante de maximizado"), ToggleWatcher)
    tray.Add(T("Pausar atajos"), TogglePause)
    tray.Add()
    tray.Add(T("Salir"), (*) => ExitApp())
}

TrayProfiles := Menu()

; Vuelve a rellenar el submenú «Perfiles» con los de zones.ini y marca el activo.
; Se llama al arrancar, al cambiar de perfil y cuando zones.ini se recarga.
TrayRefreshProfiles() {
    global TrayProfiles
    try TrayProfiles.Delete()
    for name in Config.ProfileOrder
        TrayProfiles.Add(name, TrayPickProfile)
    try TrayProfiles.Check(Config.ProfileName)
}

TrayPickProfile(name, *) {
    ApplyProfile(name, "bandeja")
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
        Notify(T("No encuentro el panel de Zonely"), 2500)
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
        A_IconTip := T("{name} (PAUSADO)", "name", TrayName)
    } else {
        A_TrayMenu.Uncheck(itemName)
        A_IconTip := TrayName
    }
}

; Marca/desmarca la entrada del vigilante según su estado.
TrayWatcherChecked(on) {
    if on
        A_TrayMenu.Check(T("Vigilante de maximizado"))
    else
        A_TrayMenu.Uncheck(T("Vigilante de maximizado"))
}
