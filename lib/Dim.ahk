#Requires AutoHotkey v2.0
; ============================================================
;  Dim.ahk - Capa oscura para atenuar zonas
;  Un panel negro, siempre encima y atravesable por el ratón, cubre
;  cada zona elegida. En un OLED el negro puro apaga los píxeles.
;  La opacidad sale de [Dim] Opacity (0-100) en zones.ini.
; ============================================================

DimZoneName := ""              ; "" = capa apagada, o zonas separadas por "+" ("B", "A+C"...)
DimGuis := Map()               ; nombre de zona -> Gui

; Atenúa las zonas indicadas ("B", "A+C") o apaga la capa ("").
SetDim(zones) {
    global DimZoneName := Config.Zoned ? zones : ""        ; sin zonas no hay nada que atenuar
    DimRefresh()
}

; Redibuja la capa (tras cambiar de perfil, de opacidad o de zona).
DimRefresh() {
    global DimGuis
    wanted := Map()
    if Config.Zoned
        for name in StrSplit(DimZoneName, "+")
            if name != "" && Config.Zones.Has(name)
                wanted[name] := true
    for name, g in DimGuis
        if !wanted.Has(name)
            g.Hide()
    for name, _ in wanted {
        if !DimGuis.Has(name) {
            ; -Caption sin bordes | E0x20 click-through | E0x08000000 no roba el foco
            g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")
            g.BackColor := "000000"
            DimGuis[name] := g
        }
        z := Config.Zones[name]
        DimGuis[name].Show("NA x" z.X " y" z.Y " w" z.W " h" z.H)
        WinSetTransparent(Round(Config.DimOpacity * 255 / 100), DimGuis[name].Hwnd)
    }
}

SetDimLevel(pct) {
    Config.DimOpacity := Min(100, Max(0, pct))
    DimRefresh()
}

; Win+Alt+O: atenúa las zonas donde NO está la ventana activa (la del juego), o apaga la capa.
ToggleDim() {
    if DimZoneName != "" {
        SetDim("")
        return
    }
    if !Config.Zoned {
        Notify(T("El perfil «{name}» no tiene zonas", "name", Config.ProfileName))
        return
    }
    hwnd := WinExist("A")
    active := (hwnd && !HasValue(SystemClasses, WinGetClass(hwnd))) ? ZoneOf(hwnd).Name : "A"
    others := ""
    for name, _ in Config.Zones
        if name != active
            others .= (others = "" ? "" : "+") name
    SetDim(others)
    Notify(T("Capa oscura sobre la zona {zones}", "zones", StrReplace(DimZoneName, "+", ", ")))
}