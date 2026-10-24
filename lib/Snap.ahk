#Requires AutoHotkey v2.0
; ============================================================
;  Snap.ahk - Arrastrar con Shift para encajar en una zona
;  (como FancyZones). Mientras arrastras una ventana con el botÃ³n
;  izquierdo y mantienes la tecla (Shift por defecto), se dibujan
;  las zonas; al soltar, la ventana se encaja en la resaltada.
;    - Zona A:  toda la zona.
;    - Zona B:  tercio superior = mitad de arriba, tercio inferior =
;               mitad de abajo, centro = toda la zona.
;  DetecciÃ³n por sondeo cada 30 ms: no instala hooks de ratÃ³n.
; ============================================================

CoordMode "Mouse", "Screen"      ; MouseGetPos en coordenadas de pantalla, no de ventana
SnapOn := false
SnapPrevDown := false          ; Â¿estaba pulsado el botÃ³n en el tick anterior?
SnapWin := 0                   ; ventana sobre la que se pulsÃ³
SnapStartPos := [0, 0]
SnapDragging := false          ; la ventana se estÃ¡ moviendo de verdad
SnapShown := false             ; overlay visible
SnapTarget := ""               ; Map(x,y,w,h) de la zona resaltada
SnapGuis := ""                 ; Map(A, B, HL)

StartSnap() {
    global SnapOn := true, SnapGuis
    if !IsObject(SnapGuis) {
        SnapGuis := Map("A", SnapMakeGui(0x3B82F6, 40), "B", SnapMakeGui(0x8B5CF6, 40), "C", SnapMakeGui(0xF472B6, 40)
                      , "HL", SnapMakeGui(0xFFFFFF, 95))
    }
}

; Sin sondeo continuo: solo se vigila el ratón (cada 30 ms) mientras el botón izquierdo está pulsado. Al pulsarlo, este
; hotkey (con ~ el clic sigue su camino) arranca el temporizador; SnapTick lo para al soltar. En reposo no gasta nada.
~*LButton:: {
    if SnapOn && !A_IsSuspended
        SetTimer(SnapTick, 30)
}

StopSnap() {
    global SnapOn := false
    SetTimer(SnapTick, 0)
    SnapReset()
}

; Ventana de superposiciÃ³n: sin bordes, siempre encima, atravesable por el ratÃ³n, sin foco.
SnapMakeGui(color, alpha) {
    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
    g.BackColor := Format("{:06X}", color)
    WinSetTransparent(alpha, g.Hwnd)
    return g
}

SnapReset() {
    global SnapPrevDown := false, SnapWin := 0, SnapDragging := false
    SnapHideOverlay()
}

SnapHideOverlay() {
    global SnapShown := false
    if IsObject(SnapGuis)
        for _, g in SnapGuis
            g.Hide()
}

SnapTick() {
    global SnapPrevDown, SnapWin, SnapStartPos, SnapDragging, SnapShown
    if A_IsSuspended {
        if SnapPrevDown || SnapShown
            SnapReset()
        SetTimer(SnapTick, 0)
        return
    }
    down := GetKeyState("LButton")

    if down && !SnapPrevDown {                       ; botÃ³n reciÃ©n pulsado
        MouseGetPos(, , &h)
        SnapWin := h
        SnapDragging := false
        try {
            if HasValue(SystemClasses, WinGetClass(h)) || IsGameWindow(h)
                SnapWin := 0
            WinGetPos(&x, &y, , , h)
            SnapStartPos := [x, y]
        } catch
            SnapWin := 0
    } else if down && SnapWin {                      ; botÃ³n mantenido
        try {
            if !SnapDragging {
                WinGetPos(&x, &y, , , SnapWin)
                if Abs(x - SnapStartPos[1]) > 6 || Abs(y - SnapStartPos[2]) > 6
                    SnapDragging := true             ; la ventana se moviÃ³: es un arrastre
            }
            if SnapDragging {
                if GetKeyState(Config.SnapKey)
                    SnapUpdateOverlay()
                else
                    SnapHideOverlay()
            }
        } catch
            SnapReset()
    } else if !down && SnapPrevDown {                ; botÃ³n soltado
        if SnapDragging && SnapShown && IsObject(SnapTarget) {
            try PlaceInRect(SnapWin, SnapTarget["x"], SnapTarget["y"], SnapTarget["w"], SnapTarget["h"])
        }
        SnapHideOverlay()
        SnapWin := 0
        SnapDragging := false
    }
    SnapPrevDown := down
    if !down
        SetTimer(SnapTick, 0)                        ; botón soltado: se deja de vigilar hasta el próximo clic
}

; Calcula la zona bajo el cursor y dibuja el overlay.
SnapUpdateOverlay() {
    global SnapShown := true, SnapTarget
    if !Config.Zoned {                               ; perfil sin zonas: nada que encajar
        SnapShown := false
        return
    }
    MouseGetPos(&mx, &my)
    if !Config.OnMonitor(mx, my) {                   ; el cursor está en otro monitor: nada que encajar
        SnapShown := false
        SnapHideOverlay()
        return
    }
    ; zona bajo el cursor (la más cercana si está en un hueco o fuera)
    list := Config.ZonesByX()
    zone := list[1]
    for z in list
        if mx >= z.X
            zone := z

    t := Map("x", zone.X, "y", zone.Y, "w", zone.W, "h", zone.H)
    if zone.Name = "B" && Config.SnapHalves {         ; mitades opcionales, solo en la zona B
        rel := (my - zone.Y) / zone.H
        half := zone.H // 2
        if rel < 0.33
            t["h"] := half
        else if rel > 0.67 {
            t["y"] := zone.Y + half
            t["h"] := zone.H - half
        }
    }
    SnapTarget := t

    for name in ["A", "B", "C"] {                      ; tintes de las zonas del perfil; se ocultan las que no existen
        if Config.Zones.Has(name) {
            z := Config.Zones[name]
            SnapGuis[name].Show("NA x" z.X " y" z.Y " w" z.W " h" z.H)
        } else
            SnapGuis[name].Hide()
    }
    SnapGuis["HL"].Show("NA x" t["x"] " y" t["y"] " w" t["w"] " h" t["h"])
}

; Para el panel / IPC.
SetSnap(on) {
    if on && !SnapOn
        StartSnap()
    else if !on && SnapOn
        StopSnap()
}
