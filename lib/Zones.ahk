#Requires AutoHotkey v2.0
; ============================================================
;  Zones.ahk - Colocar ventanas dentro de las zonas
; ============================================================

; Clases de ventana que nunca se tocan (escritorio y barra de tareas).
SystemClasses := ["Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd"
    , "XamlExplorerHostIslandWindow", "MultitaskingViewFrame", "ForegroundStaging", "Windows.UI.Core.CoreWindow"]   ; escritorio, bandeja, Alt+Tab, menú inicio...

; Mensaje breve junto al cursor (se borra solo).
Notify(text, ms := 1200) {
    ToolTip(text)
    SetTimer(() => ToolTip(), -ms)
}

; Ventana activa si se puede gestionar; si no, 0 y avisa.
; Con un perfil sin zonas las acciones de colocación no tienen sentido.
ActiveManageable(target := 0) {
    if !Config.Zoned {
        Notify(T("El perfil «{name}» no tiene zonas", "name", Config.ProfileName))
        return 0
    }
    hwnd := target ? (WinExist(target) ? target : 0) : WinExist("A")
    if !hwnd || HasValue(SystemClasses, WinGetClass(hwnd)) {
        Notify(T("No hay ventana gestionable"))
        return 0
    }
    return hwnd
}

HasValue(arr, val) {
    for v in arr
        if v = val
            return true
    return false
}

; ¿Es la ventana de un juego de la lista [Exclusions] Games? Esas no se tocan automáticamente
; (cambiar su tamaño o posición en marcha rompe la captura del ratón y choca con los anti-cheat).
IsGameWindow(hwnd) {
    try return HasValue(Config.GameProcesses, WinGetProcessName(hwnd))
    return false
}

; ¿Es una ventana "de verdad" (visible, con título, no oculta ni del sistema)?
IsRealWindow(hwnd) {
    try {
        if !(WinGetStyle(hwnd) & 0x10000000)                 ; WS_VISIBLE
            return false
        ex := WinGetExStyle(hwnd)
        if (ex & 0x80) && !(ex & 0x40000)                    ; ventana de herramientas sin APPWINDOW
            return false
        title := WinGetTitle(hwnd)
        if title = "" || title = "Zonely" || HasValue(SystemClasses, WinGetClass(hwnd))
            return false
        cloaked := Buffer(4, 0)                              ; apps UWP "fantasma"
        DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 14, "ptr", cloaked, "uint", 4)
        return !NumGet(cloaked, 0, "int")
    }
    return false
}

; Rectángulo VISIBLE de la ventana (sin la sombra invisible que Windows 10/11
; añade alrededor). Devuelve Map con L, T, R, B.
GetVisibleRect(hwnd) {
    rc := Buffer(16)
    DllCall("dwmapi\DwmGetWindowAttribute", "ptr", hwnd, "uint", 9   ; DWMWA_EXTENDED_FRAME_BOUNDS
        , "ptr", rc, "uint", 16)
    return Map("L", NumGet(rc, 0, "int"), "T", NumGet(rc, 4, "int")
             , "R", NumGet(rc, 8, "int"), "B", NumGet(rc, 12, "int"))
}

; Muestra u oculta el borde de 1 px que Windows 11 dibuja alrededor de la ventana (DWMWA_BORDER_COLOR).
; Oculto, la fila superior es contenido de la ventana y queda pegada a la zona. Sin efecto en Windows 10.
WindowBorder(hwnd, show) {
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "int", 34
        , "uint*", show ? 0xFFFFFFFF : 0xFFFFFFFE, "int", 4)        ; COLOR_DEFAULT / COLOR_NONE
}

InsetCache := Map()        ; hwnd -> [izq, arr, der, aba] de sombra invisible medida la última vez que se colocó

; Compensación entre las coordenadas de pantalla y las «de espacio de trabajo» de WINDOWPLACEMENT en el monitor que
; contiene el punto: es la posición del área de trabajo respecto al monitor (la barra de tareas a la izquierda o arriba).
WorkspaceOffset(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if x >= l && x < r && y >= t && y < b {
            MonitorGetWorkArea(A_Index, &wl, &wt)
            return [wl - l, wt - t]
        }
    }
    return [0, 0]
}

; Pasa una ventana maximizada a su zona en una sola operación (SetWindowPlacement con la posición normal ya en la zona),
; en lugar de restaurar y mover después: así nunca se ve la ventana con su tamaño anterior entre medias.
; La sombra invisible se estima (la medida la última vez, o la típica de Windows); luego PlaceInRect afina.
PlaceFromMaximized(hwnd, x, y, w, h) {
    ins := InsetCache.Has(hwnd) ? InsetCache[hwnd] : 0
    if !ins {
        dpi := 96
        try dpi := DllCall("GetDpiForWindow", "ptr", hwnd, "uint")
        side := Round(7 * dpi / 96)
        ins := [side, 0, side, side]
    }
    off := WorkspaceOffset(x + w // 2, y + h // 2)
    wp := Buffer(44, 0)
    NumPut("uint", 44, wp)
    DllCall("GetWindowPlacement", "ptr", hwnd, "ptr", wp)
    NumPut("uint", 1, wp, 8)                                   ; showCmd = SW_SHOWNORMAL (restaurar)
    NumPut("int", x - ins[1] - off[1], wp, 28)
    NumPut("int", y - ins[2] - off[2], wp, 32)
    NumPut("int", x + w + ins[3] - off[1], wp, 36)
    NumPut("int", y + h + ins[4] - off[2], wp, 40)
    DllCall("SetWindowPlacement", "ptr", hwnd, "ptr", wp)
}

; Mueve una ventana normal (no maximizada) a (x, y, w, h). Con «Animar al colocar» se desliza en ~170 ms con frenada suave,
; como en Mac; sin animación (apagada, o el sistema pide reducir el movimiento) se mueve de golpe.
MovePlaced(hwnd, x, y, w, h) {
    if !Config.AnimateWindows || ReduceMotion() {
        WinMove(x, y, w, h, hwnd)
        return
    }
    WinGetPos(&fx, &fy, &fw, &fh, hwnd)
    if Abs(fx - x) + Abs(fy - y) + Abs(fw - w) + Abs(fh - h) < 24 {
        WinMove(x, y, w, h, hwnd)
        return
    }
    steps := 10
    Loop steps {
        e := 1 - (1 - A_Index / steps) ** 3                   ; frenada suave
        WinMove(Round(fx + (x - fx) * e), Round(fy + (y - fy) * e), Round(fw + (w - fw) * e), Round(fh + (h - fh) * e), hwnd)
        if A_Index < steps
            Sleep(17)
    }
}

; ¿El sistema pide reducir el movimiento? (Accesibilidad: efectos de animación desactivados)
ReduceMotion() {
    b := Buffer(4, 0)
    DllCall("SystemParametersInfo", "uint", 0x1042, "uint", 0, "ptr", b, "uint", 0)    ; SPI_GETCLIENTAREAANIMATION
    return NumGet(b, 0, "int") = 0
}

; Coloca la parte visible de la ventana exactamente en (x, y, w, h).
; Si estaba maximizada/minimizada la restaura primero. Se hace en dos pasos:
; mover, medir cuánta sombra invisible hay y compensarla.
; `record := false` para colocaciones que no deben poder deshacerse con Win+Alt+Retroceso.
PlaceInRect(hwnd, x, y, w, h, record := true) {
    if record {
        UndoPush(hwnd)
        RestoreNote(hwnd)                  ; tamaño original (solo la primera vez que entra en una zona)
    }
    try {
        mm := WinGetMinMax(hwnd)
        if mm = 1 {
            PlaceFromMaximized(hwnd, x, y, w, h)    ; de maximizada a la zona de un solo paso: sin fotograma intermedio
        } else {
            if mm != 0
                WinRestore(hwnd)
            MovePlaced(hwnd, x, y, w, h)
        }

        WinGetPos(&wx, &wy, &ww, &wh, hwnd)
        v := GetVisibleRect(hwnd)
        insetL := v["L"] - wx                 ; sombra a la izquierda
        insetT := v["T"] - wy
        insetR := (wx + ww) - v["R"]
        insetB := (wy + wh) - v["B"]
        InsetCache[hwnd] := [insetL, insetT, insetR, insetB]
        if InsetCache.Count > 200
            InsetCache.Clear()
        WinMove(x - insetL, y - insetT, w + insetL + insetR, h + insetT + insetB, hwnd)
        WindowBorder(hwnd, false)             ; sin la línea de 1 px del borde: la ventana queda pegada al borde de la zona
    } catch {
        return                                ; la ventana se cerró a mitad de la colocación: no hay nada que hacer
    }

    ; Comprobación: ¿ha respetado el tamaño pedido? (útil para saber qué juegos "se resisten")
    Sleep(60)
    try {
        v := GetVisibleRect(hwnd)
        if Abs(v["L"] - x) > 2 || Abs(v["T"] - y) > 2 || Abs((v["R"] - v["L"]) - w) > 2 || Abs((v["B"] - v["T"]) - h) > 2
            Log("No respeta la zona: " WinGetProcessName(hwnd) " · pedido " x "," y " " w "x" h " · obtenido " v["L"] "," v["T"] " " (v["R"] - v["L"]) "x" (v["B"] - v["T"]), "WARN")
    }
    if record
        RestoreTrack(hwnd)                 ; ahora está en esta zona
}

; Rectángulo [izquierda, arriba, derecha, abajo] del monitor que contiene el punto (el elegido si no cae en ninguno).
MonitorAreaAt(x, y) {
    Loop MonitorGetCount() {
        MonitorGet(A_Index, &l, &t, &r, &b)
        if x >= l && x < r && y >= t && y < b
            return [l, t, r, b]
    }
    return [Config.MonLeft, Config.MonTop, Config.MonLeft + Config.MonW, Config.MonTop + Config.MonH]
}

; ¿El centro de la ventana está en el monitor al que se aplican las zonas?
WindowOnMonitor(hwnd) {
    v := GetVisibleRect(hwnd)
    return Config.OnMonitor((v["L"] + v["R"]) // 2, (v["T"] + v["B"]) // 2)
}

; Zona que contiene el centro de la ventana (A por defecto).
ZoneOf(hwnd) {
    v := GetVisibleRect(hwnd)
    return ZoneAt((v["L"] + v["R"]) // 2, (v["T"] + v["B"]) // 2)
}

; Zona que contiene el punto (cx, cy) del escritorio; si cae en un hueco o fuera, la más cercana (A si no hay ninguna).
ZoneAt(cx, cy) {
    best := Config.Zones["A"], bestD := 0x7FFFFFFF
    for _, z in Config.Zones {
        dx := cx < z.X ? z.X - cx : (cx >= z.Right ? cx - z.Right + 1 : 0)
        dy := cy < z.Y ? z.Y - cy : (cy >= z.Bottom ? cy - z.Bottom + 1 : 0)
        if dx = 0 && dy = 0
            return z
        d := dx * dx + dy * dy
        if d < bestD
            best := z, bestD := d
    }
    return best
}

; Centra la ventana en una zona SIN cambiarle el tamaño (Win+Alt+Mayús+←/→).
; Pensado para juegos que no aceptan el tamaño de la zona: el juego conserva
; su resolución y el ratón sigue casando con lo que se ve.
CenterInZone(name, target := 0) {
    if !(hwnd := ActiveManageable(target))
        return
    z := Config.Zones[name]
    UndoPush(hwnd)
    RestoreNote(hwnd)                                    ; tamaño original (solo la primera vez que entra en una zona)
    if WinGetMinMax(hwnd) != 0
        WinRestore(hwnd)
    v := GetVisibleRect(hwnd)
    w := v["R"] - v["L"], h := v["B"] - v["T"]
    WinGetPos(&ox, &oy, , , hwnd)
    dx := v["L"] - ox, dy := v["T"] - oy                 ; sombra invisible de la ventana
    x := z.X + Max(0, (z.W - w) // 2)
    y := z.Y + Max(0, (z.H - h) // 2)
    WinMove(x - dx, y - dy, , , hwnd)                    ; solo posición: no se toca el tamaño
    RestoreTrack(hwnd)                                   ; ahora está en esta zona (sin esto, la zona apuntada quedaba obsoleta)
    if w > z.W || h > z.H
        Notify(T("La ventana ({w}x{h}) es mayor que la zona {zone} ({zw}x{zh})", "w", w, "h", h, "zone", name, "zw", z.W, "zh", z.H), 2500)
    Log("Centrada sin redimensionar: " WinGetProcessName(hwnd) " " w "x" h " en la zona " name)
}

; Win+Alt+Mayús+Izq/Der: centrar (sin cambiar el tamaño) en la zona de la izquierda / derecha.
CenterStep(dir, target := 0) {
    if !(hwnd := ActiveManageable(target))
        return
    CenterInZone(NeighbourZone(hwnd, dir).Name, target)
}

; ---- Deshacer la última colocación (Win+Alt+Retroceso) --------
UndoStack := []

; Guarda dónde estaba la ventana antes de moverla (máx. 20).
UndoPush(hwnd) {
    try {
        mm := WinGetMinMax(hwnd)
        if mm = -1
            return                                   ; minimizada: su posición no sirve
        WinGetPos(&x, &y, &w, &h, hwnd)
        UndoStack.Push(Map("hwnd", hwnd, "x", x, "y", y, "w", w, "h", h, "mm", mm))
        if UndoStack.Length > 20
            UndoStack.RemoveAt(1)
    }
}

; Devuelve la última ventana colocada a su sitio anterior (salta las que ya no existen).
UndoPlacement() {
    while UndoStack.Length {
        e := UndoStack.Pop()
        if !WinExist(e["hwnd"])
            continue
        try {
            hwnd := e["hwnd"]
            if WinGetMinMax(hwnd) != 0
                WinRestore(hwnd)
            if e["mm"] = 1
                WinMaximize(hwnd)
            else
                WinMove(e["x"], e["y"], e["w"], e["h"], hwnd)
            RestoreForget(hwnd)                        ; vuelve a como estaba: ya no hay nada que restaurar
            WindowBorder(hwnd, true)
            Log("Deshacer: " WinGetProcessName(hwnd) " vuelve a " e["x"] "," e["y"] " " e["w"] "x" e["h"])
            Notify(T("Colocación deshecha"))
            return
        }
    }
    Notify(T("Nada que deshacer"))
}

; ---- Acciones de los atajos ----------------------------------

; Win+Alt+Z: ocupar toda la zona actual.
ZoneMaximize(target := 0) {
    if !(hwnd := ActiveManageable(target))
        return
    z := ZoneOf(hwnd)
    PlaceInRect(hwnd, z.X, z.Y, z.W, z.H)
}

; Win+Alt+Izq/Der: pasar a la zona de la izquierda / derecha (ocupándola entera).
; Con dos zonas es "A" / "B" de siempre; con tres, va saltando de una a la siguiente.
MoveStep(dir, target := 0) {
    if !(hwnd := ActiveManageable(target))
        return
    z := NeighbourZone(hwnd, dir, target)
    PlaceInRect(hwnd, z.X, z.Y, z.W, z.H)
}

; Zona vecina (dir = -1 izquierda, +1 derecha); en el extremo se queda en la misma.
NeighbourZone(hwnd, dir, target := 0) {
    list := Config.ZonesByX()
    cur := ZoneOf(hwnd)
    idx := 1
    for i, z in list
        if z.Name = cur.Name
            idx := i
    return list[Min(Max(idx + dir, 1), list.Length)]
}
; Win+Alt+Arriba/Abajo: mitad superior/inferior, solo en la zona B.
; Con `target` (desde el panel) la ventana pasa siempre a la zona B.
SnapHalf(top, target := 0) {
    if !(hwnd := ActiveManageable(target))
        return
    z := target ? Config.Zones["B"] : ZoneOf(hwnd)
    if z.Name != "B" {
        Notify(T("Las mitades solo funcionan en la zona B"))
        return
    }
    half := z.H // 2
    if top
        PlaceInRect(hwnd, z.X, z.Y, z.W, half)
    else
        PlaceInRect(hwnd, z.X, z.Y + half, z.W, z.H - half)
}

