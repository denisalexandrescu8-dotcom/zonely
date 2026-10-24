#Requires AutoHotkey v2.0
; ============================================================
;  Debug.ahk - Ventanita de depuración (Win+Alt+D)
;  Muestra proceso, posición y tamaño REAL de la ventana que
;  estaba activa al pulsar el atajo, y se refresca sola cada
;  medio segundo: así ves si un juego respeta la zona o la cambia.
;  No roba el foco, para no molestar al juego.
; ============================================================

DebugGui := ""
DebugEdit := ""
DebugTarget := 0
DebugLast := ""

; Win+Alt+D: abre la ventanita (o la cierra si ya está abierta).
ToggleDebug() {
    global DebugGui, DebugEdit, DebugTarget
    if IsObject(DebugGui) {
        CloseDebug()
        return
    }
    if !(DebugTarget := ActiveManageable())
        return

    DebugGui := Gui("+AlwaysOnTop +ToolWindow", "Depuración de ventana (Win+Alt+D cierra)")
    DebugGui.SetFont("s9", "Consolas")
    DebugEdit := DebugGui.Add("Edit", "ReadOnly -Wrap w520 r15")
    DebugGui.OnEvent("Close", (*) => CloseDebug())

    ; Se coloca en la zona B para no tapar el juego de la zona A.
    b := Config.Zones.Has("B") ? Config.Zones["B"] : Config.Zones["A"]
    DebugGui.Show("NoActivate x" (b.X + 10) " y" (b.Y + 10))
    SetTimer(RefreshDebug, 500)
    RefreshDebug()
}

CloseDebug() {
    global DebugGui, DebugLast
    SetTimer(RefreshDebug, 0)
    if IsObject(DebugGui)
        DebugGui.Destroy()
    DebugGui := ""
    DebugLast := ""
}

RefreshDebug() {
    global DebugLast
    if !IsObject(DebugGui)
        return
    txt := DebugReport(DebugTarget)
    if txt != DebugLast {                 ; evita parpadeo si no cambió nada
        DebugEdit.Value := txt
        DebugLast := txt
    }
}

; Construye el texto con los datos de la ventana.
DebugReport(hwnd) {
    if !WinExist(hwnd)
        return "La ventana ya no existe."
    try {
        WinGetPos(&x, &y, &w, &h, hwnd)
        WinGetClientPos(&cx, &cy, &cw, &ch, hwnd)
        v := GetVisibleRect(hwnd)
        vw := v["R"] - v["L"], vh := v["B"] - v["T"]
        style := WinGetStyle(hwnd)
        state := ["minimizada", "normal", "maximizada"][WinGetMinMax(hwnd) + 2]
        z := ZoneOf(hwnd)
        exact := v["L"] = z.X && v["T"] = z.Y && vw = z.W && vh = z.H

        out := "Proceso : " WinGetProcessName(hwnd) "`r`n"
        out .= "Ruta    : " WinGetProcessPath(hwnd) "`r`n"
        out .= "Clase   : " WinGetClass(hwnd) "`r`n"
        out .= "Título  : " WinGetTitle(hwnd) "`r`n"
        out .= "HWND    : " Format("0x{:X}", hwnd) "   Estado: " state "`r`n"
        out .= "Estilo  : " Format("0x{:08X}", style)
            . ((style & 0xC00000) = 0xC00000 ? "  (con barra de título)" : "  (SIN barra de título)") "`r`n`r`n"
        out .= "Ventana (con sombra) : x=" x " y=" y "  " w "x" h "`r`n"
        out .= "Visible              : x=" v["L"] " y=" v["T"] "  " vw "x" vh "`r`n"
        out .= "Área cliente         : " cw "x" ch "`r`n`r`n"
        out .= "Zona detectada: " z.Name " (" z.X "," z.Y " " z.W "x" z.H ")`r`n"
        out .= exact ? "RESULTADO: la ventana coincide EXACTAMENTE con la zona."
                     : "RESULTADO: NO coincide con la zona (difiere " (vw - z.W) " px de ancho, " (vh - z.H) " px de alto)."
        return out
    } catch Error as e {
        return "No puedo leer esta ventana (¿permisos de administrador / anti-cheat?):`r`n" e.Message
    }
}
