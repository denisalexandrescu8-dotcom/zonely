#Requires AutoHotkey v2.0
; ============================================================
;  GameMode.ahk - Borderless en la zona A y restauración
;  Solo funciona con ventanas normales o "ventana sin bordes".
;  NO funciona con pantalla completa exclusiva ni con juegos
;  protegidos por anti-cheat que bloquean cambios en su ventana.
; ============================================================

; Estilos que se quitan para dejar la ventana sin bordes ni barra de título.
WS_CAPTION    := 0xC00000      ; barra de título (incluye WS_BORDER)
WS_THICKFRAME := 0x040000      ; borde redimensionable
WS_EX_FRAME   := 0x020301      ; DLGMODALFRAME | WINDOWEDGE | CLIENTEDGE | STATICEDGE

; Estado previo por ventana: hwnd -> Map(style, exStyle, x, y, w, h, minmax)
GameSaved := Map()

; Al salir del motor (no al recargar) devolvemos las ventanas que estaban en modo juego a su estado.
OnExit((reason, code) => reason != "Reload" ? GameRestoreAll() : 0)
GameRestoreAll() {
    for hwnd in GameSaved.Clone()
        if WinExist(hwnd)
            try LeaveGameMode(hwnd)
}

; Líneas "game=" para sobrevivir a una recarga del motor.
GameResumeLines() {
    out := ""
    for hwnd, s in GameSaved
        if WinExist(hwnd)
            out .= "`ngame=" hwnd "," s["style"] "," s["exStyle"] "," s["x"] "," s["y"] "," s["w"] "," s["h"] "," s["minmax"]
    return out
}

; Fuerza a Windows a repintar el marco tras cambiar estilos.
RefreshFrame(hwnd) {
    ; NOMOVE | NOSIZE | NOZORDER | FRAMECHANGED
    DllCall("SetWindowPos", "ptr", hwnd, "ptr", 0, "int", 0, "int", 0
        , "int", 0, "int", 0, "uint", 0x27)
}

; Win+Alt+G: alterna modo juego en la ventana activa.
; keep = true: "conservar tamaño": sin bordes pero con el MISMO tamaño interior que tenía
; (para juegos con una resolución propia, p. ej. 2560x1440 en una zona de 3440), centrado en la zona A.
ToggleGameMode(target := 0, keep := false) {
    if !(hwnd := ActiveManageable(target))
        return
    if GameSaved.Has(hwnd)
        LeaveGameMode(hwnd)
    else
        EnterGameMode(hwnd, keep)
}

; Zona donde se coloca el modo juego: por defecto la zona en la que ya está la ventana («auto»),
; o la fija que se haya elegido para el perfil activo (A, B o C).
GameZone(hwnd) {
    pick := Config.GameZoneOf.Has(Config.ProfileName) ? Config.GameZoneOf[Config.ProfileName] : "auto"
    if pick = "auto"
        return ZoneOf(hwnd)
    return Config.Zones.Has(pick) ? Config.Zones[pick] : Config.Zones["A"]
}

EnterGameMode(hwnd, keep := false) {
    WinGetPos(&x, &y, &w, &h, hwnd)
    GameSaved[hwnd] := Map("style", WinGetStyle(hwnd), "exStyle", WinGetExStyle(hwnd)
        , "x", x, "y", y, "w", w, "h", h, "minmax", WinGetMinMax(hwnd))

    if WinGetMinMax(hwnd) != 0
        WinRestore(hwnd)
    WinGetClientPos(, , &cw, &ch, hwnd)                  ; tamaño interior (lo que dibuja el juego)
    WinSetStyle("-" (WS_CAPTION | WS_THICKFRAME), hwnd)
    WinSetExStyle("-" WS_EX_FRAME, hwnd)
    RefreshFrame(hwnd)

    z := GameZone(hwnd)
    if keep {
        ; Sin bordes, con el tamaño interior de antes, centrado en la zona A.
        PlaceInRect(hwnd, z.X + Max(0, (z.W - cw) // 2), z.Y + Max(0, (z.H - ch) // 2), cw, ch, false)
        Notify(T("Modo juego (tamaño conservado): {w}x{h}", "w", cw, "h", ch))
        Log("Modo juego ON (conservar tamaño): " WinGetProcessName(hwnd) " " cw "x" ch " centrado en " z.Name)
        return
    }
    PlaceInRect(hwnd, z.X, z.Y, z.W, z.H, false)     ; el modo juego se deshace con su propio atajo
    Notify(T("Modo juego: {w}x{h}", "w", z.W, "h", z.H))
    Log("Modo juego ON: " WinGetProcessName(hwnd) " -> " z.W "x" z.H)
}

LeaveGameMode(hwnd) {
    s := GameSaved[hwnd]
    GameSaved.Delete(hwnd)
    if !WinExist(hwnd)
        return                          ; la ventana ya se cerró

    WinSetStyle(s["style"], hwnd)       ; valor absoluto: restaura tal cual estaba
    WinSetExStyle(s["exStyle"], hwnd)
    RefreshFrame(hwnd)
    WindowBorder(hwnd, true)
    if s["minmax"] = 1
        WinMaximize(hwnd)
    else
        WinMove(s["x"], s["y"], s["w"], s["h"], hwnd)
    Notify(T("Ventana restaurada"))
    Log("Modo juego OFF: " WinGetProcessName(hwnd))
}
