#Requires AutoHotkey v2.0
; ============================================================
;  Restore.ahk - Devolver a una ventana su tamaño original al salirse de la zona
;  Cuando el motor coloca una ventana en una zona (atajo, Shift+arrastrar, vigilante)
;  se apunta el tamaño que tenía ANTES de entrar. Si luego se saca de esa zona
;  (arrastrándola fuera o redimensionándola más allá), recupera ese tamaño.
;  Se desactiva con [General] RestoreOnLeave=0 o desde el panel.
; ============================================================

ZoneOrig := Map()      ; hwnd -> Map(w, h, zone [izq, arr, der, aba], pending)
RestoreMouseDownSizes := Map()

; El temporizador solo corre mientras hay ventanas apuntadas (RestoreArm lo enciende, RestoreTick lo apaga al quedarse sin
; ninguna): en reposo no despierta el procesador.
StartRestore() {
    RestoreArm()
}

; Captura la ventana bajo el cursor al pulsar el ratón y compara su tamaño al soltarlo.
; Así los cambios de tamaño que Zonely hace después (p. ej. con un atajo) no se confunden
; con un redimensionado del usuario.
RestoreMouseDown() {
    global RestoreMouseDownSizes
    RestoreMouseDownSizes := Map()
    if !Config.RestoreOnLeave || !ZoneOrig.Count
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my, &under)
    if !under
        return
    hwnd := DllCall("GetAncestor", "Ptr", under, "UInt", 2, "Ptr") ; GA_ROOT
    if !hwnd || !ZoneOrig.Has(hwnd)
        return
    if !RestoreIsSizingEdge(hwnd, mx, my)
        return
    try {
        if WinGetMinMax(hwnd) != 0
            return
        WinGetPos(, , &w, &h, hwnd)
        if w > 50 && h > 50
            RestoreMouseDownSizes[hwnd] := [w, h]
    }
}

RestoreIsSizingEdge(hwnd, x, y) {
    point := ((y & 0xFFFF) << 16) | (x & 0xFFFF)
    result := Buffer(A_PtrSize, 0)
    if !DllCall("SendMessageTimeoutW", "Ptr", hwnd, "UInt", 0x84, "Ptr", 0, "Ptr", point,
        "UInt", 2, "UInt", 100, "Ptr", result, "Ptr") ; WM_NCHITTEST, SMTO_ABORTIFHUNG
        return false
    hit := NumGet(result, 0, "Ptr")
    return hit >= 10 && hit <= 17              ; HTLEFT...HTBOTTOMRIGHT
}

RestoreMouseUp() {
    global RestoreMouseDownSizes
    now := A_TickCount
    for hwnd, before in RestoreMouseDownSizes {
        if !WinExist(hwnd) || !ZoneOrig.Has(hwnd)
            continue
        try {
            WinGetPos(, , &w, &h, hwnd)
        } catch {
            continue
        }
        if w <= 50 || h <= 50 || (Abs(w - before[1]) <= 1 && Abs(h - before[2]) <= 1)
            continue
        o := ZoneOrig[hwnd]
        o["resizePending"] := Map("before", before, "last", [], "since", now, "deadline", now + 2500)
        o["pending"] := 0
        RestoreArm()
    }
    RestoreMouseDownSizes := Map()
}

~*LButton Up::RestoreMouseUp()

RestoreArm() {
    if ZoneOrig.Count > 0
        SetTimer(RestoreTick, 60)
}

; Rectángulo "normal" (el que tendría sin maximizar), útil si la ventana estaba maximizada.
NormalRect(hwnd) {
    wp := Buffer(44, 0)
    NumPut("uint", 44, wp)
    DllCall("GetWindowPlacement", "ptr", hwnd, "ptr", wp)
    l := NumGet(wp, 28, "int"), t := NumGet(wp, 32, "int"), r := NumGet(wp, 36, "int"), b := NumGet(wp, 40, "int")
    return [l, t, r - l, b - t]
}

; Se llama ANTES de colocar: guarda el tamaño original (solo la primera vez que entra en una zona).
RestoreNote(hwnd) {
    if !Config.RestoreOnLeave || ZoneOrig.Has(hwnd)
        return
    try {
        mm := WinGetMinMax(hwnd)
        if mm = -1
            return                                  ; minimizada: su tamaño no sirve
        if mm = 1 {
            r := NormalRect(hwnd)
        } else {
            WinGetPos(&x, &y, &w, &h, hwnd)
            r := [x, y, w, h]
        }
        if r[3] > 50 && r[4] > 50
            ZoneOrig[hwnd] := Map("w", r[3], "h", r[4], "zone", "", "pending", 0)
            RestoreArm()
    }
}

; Se llama DESPUÉS de colocar: apunta en qué zona está ahora.
RestoreTrack(hwnd) {
    if !ZoneOrig.Has(hwnd)
        return
    try {
        z := ZoneOf(hwnd)
        o := ZoneOrig[hwnd]
        o["zone"] := [z.X, z.Y, z.Right, z.Bottom]
        o["pending"] := 0
    }
}

; Tras el evento de fin, espera a que la ventana deje de cambiar de tamaño. Solo un cambio dentro de la
; interacción directa del ratón actualiza el tamaño que se recuperará al salir de la zona.
RestoreUserResize(hwnd, o) {
    if !o.Has("resizePending") || GetKeyState("LButton")
        return
    pending := o["resizePending"]
    now := A_TickCount
    if now > pending["deadline"] {
        o.Delete("resizePending")
        return
    }
    try {
        WinGetPos(&x, &y, &w, &h, hwnd)
    } catch {
        return
    }
    if w <= 50 || h <= 50
        return
    last := pending["last"]
    if !last.Length || Abs(w - last[1]) > 1 || Abs(h - last[2]) > 1 {
        pending["last"] := [w, h]
        pending["since"] := now
        return
    }
    if now - pending["since"] < 240 || now - (pending["deadline"] - 2500) < 300
        return
    before := pending["before"]
    o.Delete("resizePending")
    if Abs(w - before[1]) <= 6 && Abs(h - before[2]) <= 6
        return
    o["w"] := w, o["h"] := h
    v := GetVisibleRect(hwnd)                                   ; lo que se ha estirado ya es parte de la zona (no es «salirse»)
    z := o["zone"]
    o["zone"] := [Min(z[1], v["L"]), Min(z[2], v["T"]), Max(z[3], v["R"]), Max(z[4], v["B"])]
    Log("Tamaño original actualizado con el ratón: " WinGetProcessName(hwnd) " " w "x" h)
}

RestoreForget(hwnd) {
    if ZoneOrig.Has(hwnd)
        ZoneOrig.Delete(hwnd)
}

RestoreTick() {
    if ZoneOrig.Count = 0 {
        SetTimer(RestoreTick, 0)                    ; nada apuntado: se para hasta que haya otra ventana
        return
    }
    if A_IsSuspended || !Config.RestoreOnLeave || !Config.AnyZoned()
        return
    if GetKeyState("LButton")
        return                                      ; se está arrastrando o pulsando: se espera a que suelte
    for hwnd, o in ZoneOrig.Clone() {
        if !WinExist(hwnd) {
            ZoneOrig.Delete(hwnd)
            continue
        }
        if o["zone"] = ""
            continue
        RestoreUserResize(hwnd, o)
        if o.Has("resizePending") {
            o["pending"] := 0
            continue                                         ; deja terminar y estabilizar el resize antes de probar si salió de la zona
        }
        if IsGameWindow(hwnd) {                             ; un juego en marcha no se redimensiona nunca
            ZoneOrig.Delete(hwnd)
            continue
        }
        try {
            if WinGetMinMax(hwnd) != 0 || GameSaved.Has(hwnd) {     ; maximizada, minimizada o en modo juego: no se toca
                o["pending"] := 0
                continue
            }
            v := GetVisibleRect(hwnd)
            z := o["zone"], tol := 10
            if v["L"] >= z[1] - tol && v["T"] >= z[2] - tol && v["R"] <= z[3] + tol && v["B"] <= z[4] + tol {
                o["pending"] := 0                   ; sigue dentro de su zona
                continue
            }
            o["pending"] += 1
            if o["pending"] < 2                     ; hay que verla fuera dos veces seguidas (evita carreras con el encaje de Shift)
                continue
            RestoreOriginal(hwnd, o, v)
        }
    }
}

; Devuelve la ventana a su tamaño original, colocándola donde está el cursor (si lo tiene encima) o centrada donde estaba.
RestoreOriginal(hwnd, o, v) {
    ow := o["w"], oh := o["h"]
    CoordMode("Mouse", "Screen")
    MouseGetPos(&cx, &cy)
    vw := Max(1, v["R"] - v["L"])
    if cx >= v["L"] && cx < v["R"] && cy >= v["T"] && cy < v["B"]
        nx := cx - Round((cx - v["L"]) / vw * ow)   ; el cursor queda en la misma proporción de la barra de título
    else
        nx := (v["L"] + v["R"]) // 2 - ow // 2
    ny := v["T"]
    area := MonitorAreaAt((v["L"] + v["R"]) // 2, (v["T"] + v["B"]) // 2)    ; el monitor donde está la ventana
    nx := Min(Max(nx, area[1]), Max(area[1], area[3] - ow))
    ny := Min(Max(ny, area[2]), Max(area[2], area[4] - oh))
    WinMove(nx, ny, ow, oh, hwnd)
    WindowBorder(hwnd, true)
    ZoneOrig.Delete(hwnd)
    Log("Tamaño original restaurado al salir de la zona: " WinGetProcessName(hwnd) " " ow "x" oh)
}

; Win+Alt+Q: devuelve la ventana activa a su tamaño original (el que tenía antes de entrar
; en una zona), aunque se haya movido o redimensionado muchas veces desde entonces.
RestoreActive(target := 0) {
    hwnd := target ? target : WinExist("A")
    if !hwnd || HasValue(SystemClasses, WinGetClass(hwnd)) {
        Notify(T("No hay ventana gestionable"))
        return
    }
    if GameSaved.Has(hwnd) {
        Notify(T("Está en modo juego: sal con el atajo del modo juego"))
        return
    }
    if !ZoneOrig.Has(hwnd) {
        Notify(T("No tengo guardado el tamaño original de esta ventana"), 2500)
        return
    }
    try {
        if WinGetMinMax(hwnd) != 0
            WinRestore(hwnd)
        RestoreOriginal(hwnd, ZoneOrig[hwnd], GetVisibleRect(hwnd))
    }
}

; Para sobrevivir a una recarga del motor.
RestoreResumeLines() {
    out := ""
    for hwnd, o in ZoneOrig
        if WinExist(hwnd) && o["zone"] != ""
            out .= "`norig=" hwnd "," o["w"] "," o["h"] "," o["zone"][1] "," o["zone"][2] "," o["zone"][3] "," o["zone"][4]
    return out
}
