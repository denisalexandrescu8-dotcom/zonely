#Requires AutoHotkey v2.0
; ============================================================
;  Profiles.ahk - Cambiar de perfil y selector (Win+Alt+P)
;  El selector muestra una fila por perfil con la miniatura de sus zonas, su reparto en px y %,
;  y un botón «Aplicar»; un clic en cualquier parte de la fila aplica el perfil. Esc o la X lo cierran.
; ============================================================

PickerGui := ""

; Activa un perfil (atajo, selector o panel) y deja la capa oscura coherente.
ApplyProfile(name, origin := "") {
    if !Config.SetProfile(name)
        return false
    if !Config.Zoned
        SetDim("")                                   ; sin zonas no hay nada que atenuar
    else
        DimRefresh()
    Log("Perfil: " name (origin ? " (" origin ")" : ""))
    TrayRefreshProfiles()
    if origin = "selector" || origin = "bandeja"
        ProfileToast(name)                           ; confirmación breve al cambiar con Win+Alt+P o desde la bandeja
    return true
}

; Zonas de un perfil (Map nombre -> Zone) de izquierda a derecha.
ZonesSorted(zs) {
    list := []
    for _, z in zs
        list.Push(z)
    Loop list.Length - 1 {
        i := A_Index + 1, z := list[i], j := i - 1
        while j >= 1 && list[j].X > z.X {
            list[j + 1] := list[j]
            j--
        }
        list[j + 1] := z
    }
    return list
}

; Descripción corta de un perfil para la lista.
ProfileSummary(name) {
    zs := Config.Profiles[name]
    if !zs.Has("B")
        return "pantalla completa, sin zonas"
    txt := ""
    for z in ZonesSorted(zs)
        txt .= (txt = "" ? "" : " + ") z.Name " " z.W
    return txt
}

; Colores del selector (RRGGBB). Zonas A, B y C como en el panel.
PkBg := "0B0F17", PkRow := "151A24", PkRowOn := "10203F", PkLine := "1F2739", PkAccent := "3B82F6"
PkZone := Map("A", "3B82F6", "B", "8B5CF6", "C", "F472B6")

; «50 %» o «16.5 %» (sin el .0 sobrante).
Pct(w) => RegExReplace(Round(w / Config.MonW * 100, 1), "\.0$") " %"

; Win+Alt+P: abre (o cierra) el selector. Una fila por perfil; clic = aplicar.
ShowProfilePicker() {
    global PickerGui
    if IsObject(PickerGui) {
        ClosePicker()
        return
    }
    Config.ReloadProfiles()                          ; por si se editó zones.ini a mano
    pad := 24, rowW := 612, rowH := 98, gap := 10, miniW := 230, miniH := 65, btnW := 112, btnH := 40
    winW := rowW + pad * 2

    g := Gui("+AlwaysOnTop -Caption +ToolWindow", "Elegir perfil")
    g.BackColor := PkBg
    g.MarginX := 0, g.MarginY := 0

    ; Cabecera: icono 2×2, título, subtítulo y cierre.
    Rounded(Card(g, pad + 2, 25, 23, 17, "3B82F6", (*) => 0), 8)           ; icono de Zonely: dos bloques a la izquierda y uno alto a la derecha
    Rounded(Card(g, pad + 2, 46, 23, 17, "6B76F6", (*) => 0), 8)
    Rounded(Card(g, pad + 29, 25, 17, 38, "8B5CF6", (*) => 0), 8)
    g.SetFont("s16 w600 cEEF0F7", "Segoe UI")
    g.Add("Text", "x" (pad + 62) " y20 w" (rowW - 110) " BackgroundTrans", "Elegir perfil")
    g.SetFont("s10 w400 c8A92A8", "Segoe UI")
    g.Add("Text", "x" (pad + 62) " y52 w" (rowW - 110) " BackgroundTrans", "Aplica una distribución de zonas a tu pantalla.")
    g.SetFont("s14 w400 c8A92A8", "Segoe UI")
    closeBtn := g.Add("Text", "x" (winW - pad - 28) " y22 w28 h28 Center +0x200 +0x100 BackgroundTrans", "✕")
    closeBtn.OnEvent("Click", (*) => ClosePicker())

    ry := 92
    for name in Config.ProfileOrder {
        zs := Config.Profiles[name]
        cur := name = Config.ProfileName
        pick := PickerChoose.Bind(name)

        ; borde (azul si es el perfil actual) y fondo de la fila
        Rounded(Card(g, pad, ry, rowW, rowH, cur ? PkAccent : PkLine, pick), 20)
        Rounded(Card(g, pad + (cur ? 2 : 1), ry + (cur ? 2 : 1), rowW - (cur ? 4 : 2), rowH - (cur ? 4 : 2), cur ? PkRowOn : PkRow, pick), cur ? 18 : 19)

        ; miniatura del monitor con sus zonas, a escala (como las tarjetas del panel)
        mx := pad + 16, my := ry + (rowH - miniH) // 2
        MiniMonitor(g, mx, my, miniW, miniH, zs, pick)

        ; nombre, reparto en px y en %, y marca de activo
        tx := mx + miniW + 22, tw := rowW - miniW - btnW - 70
        px := "", pc := ""
        if zs.Has("B") {
            for z in ZonesSorted(zs) {
                px .= (px = "" ? "" : " + ") z.W " px"
                pc .= (pc = "" ? "" : "  +  ") Pct(z.W)
            }
        } else
            px := "Pantalla completa, sin zonas"
        g.SetFont("s13 w600 cEEF0F7", "Segoe UI")
        PickText(g, tx, ry + 10, tw, StrUpper(SubStr(name, 1, 1)) SubStr(name, 2), pick)
        g.SetFont("s10 w400 cA3A9BD", "Segoe UI")
        PickText(g, tx, ry + 37, tw, px, pick)
        g.SetFont("s9 w400 c6E768C", "Segoe UI")
        PickText(g, tx, ry + 58, tw, pc, pick)
        if cur {
            g.SetFont("s9 w600 c5B9BFF", "Segoe UI")
            PickText(g, tx, ry + 76, tw, "●  Activo ahora", pick)
        }

        ; botón Aplicar / Aplicado
        g.SetFont("s10 w600 " (cur ? "cFFFFFF" : "cA3A9BD"), "Segoe UI")
        b := g.Add("Text", "x" (pad + rowW - btnW - 16) " y" (ry + (rowH - btnH) // 2) " w" btnW " h" btnH
            . " Background" (cur ? PkAccent : "1A2133") " Center +0x200 +0x100", cur ? "Aplicado" : "Aplicar")
        b.OnEvent("Click", pick)
        Rounded(b, 14)
        ry += rowH + gap
    }
    ry += 10
    g.SetFont("s9 w400 c6E768C", "Segoe UI")
    g.Add("Text", "x" pad " y" ry " w" rowW " BackgroundTrans", "Esc para cerrar")
    winH := ry + 36

    g.OnEvent("Escape", (*) => ClosePicker())
    g.OnEvent("Close", (*) => ClosePicker())
    PickerGui := g

    ; Siempre en el centro de la pantalla, sea cual sea el perfil.
    g.Show("Hide w" winW " h" winH)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "int*", 2, "int", 4)       ; esquinas redondeadas (Windows 11)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 34, "uint*", 0x39271F, "int", 4)       ; borde de 1 px (#1F2739 en BGR)
    g.Show("x" (Config.MonLeft + (Config.MonW - winW) // 2) " y" (Config.MonTop + (Config.MonH - winH) // 2))
}

; Rectángulo de color clicable (fondo, borde, miniatura).
Card(g, x, y, w, h, color, onClick) {
    c := g.Add("Text", "x" x " y" y " w" w " h" h " Background" color " +0x100")
    c.OnEvent("Click", onClick)
    return c
}

; Texto clicable sobre el fondo de la fila.
PickText(g, x, y, w, txt, onClick) {
    t := g.Add("Text", "x" x " y" y " w" w " BackgroundTrans +0x100", txt)
    t.OnEvent("Click", onClick)
    return t
}

; Esquinas redondeadas en un control (región de la ventana del control). Devuelve el control.
Rounded(ctrl, r) {
    ctrl.GetPos(, , &w, &h)
    rgn := DllCall("CreateRoundRectRgn", "int", 0, "int", 0, "int", w + 1, "int", h + 1, "int", r * 2, "int", r * 2, "ptr")
    DllCall("SetWindowRgn", "ptr", ctrl.Hwnd, "ptr", rgn, "int", true)
    return ctrl
}

; Mezcla dos colores RRGGBB: a = 0 → bg, a = 1 → fg (para simular la transparencia del panel).
Mix(fg, bg, a) {
    out := ""
    for i in [1, 3, 5] {
        f := Integer("0x" SubStr(fg, i, 2)), b := Integer("0x" SubStr(bg, i, 2))
        out .= Format("{:02X}", Round(b + (f - b) * a))
    }
    return out
}

; Miniatura del monitor igual que la del panel: fondo casi negro, y cada zona con relleno translúcido,
; borde de su color y su letra. Sirve para el selector y para el aviso de cambio de perfil.
MiniMonitor(g, x, y, w, h, zs, onClick) {
    Rounded(Card(g, x - 1, y - 1, w + 2, h + 2, "2A3350", onClick), 11)
    Rounded(Card(g, x, y, w, h, "05070D", onClick), 10)
    for z in ZonesSorted(zs) {
        zx := x + Round((z.X - Config.MonLeft) / Config.MonW * w), zw := Round(z.W / Config.MonW * w)
        col := PkZone[z.Name]
        Rounded(Card(g, zx + 2, y + 2, zw - 4, h - 4, Mix(col, "05070D", 0.4), onClick), 7)                  ; borde de la zona
        g.SetFont("s" (h > 40 ? 13 : 10) " w700 c" col, "Segoe UI")
        t := g.Add("Text", "x" (zx + 3) " y" (y + 3) " w" (zw - 6) " h" (h - 6)
            . " Background" Mix(col, "05070D", 0.13) " Center +0x200 +0x100", z.Name)        ; relleno translúcido + letra
        t.OnEvent("Click", onClick)
        Rounded(t, 6)
    }
}

PickerChoose(name, *) {
    SetTimer(() => (ClosePicker(), ApplyProfile(name, "selector")), -10)    ; se cierra fuera del evento del clic
}

ClosePicker() {
    global PickerGui
    if IsObject(PickerGui) {
        PickerGui.Destroy()
        PickerGui := ""
    }
}
; ---- Aviso breve al cambiar de perfil -------------------------
; Tarjeta pequeña con la miniatura y el nombre del perfil; no roba el foco, deja pasar el ratón
; y desaparece sola (entra en 150 ms, se queda 1,5 s y se desvanece en 300 ms).
ToastGui := ""
ToastStart := 0

ProfileToast(name) {
    global ToastGui, ToastStart
    ToastClose()
    zs := Config.Profiles[name]
    w := 340, h := 76, miniW := 112, miniH := 32

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")     ; sin foco y atravesable
    g.BackColor := PkBg
    g.MarginX := 0, g.MarginY := 0
    mx := 18, my := (h - miniH) // 2
    MiniMonitor(g, mx, my, miniW, miniH, zs, (*) => 0)
    g.SetFont("s9 w400 c94A3B8", "Segoe UI")
    g.Add("Text", "x" (mx + miniW + 18) " y14 w180 BackgroundTrans", "Perfil aplicado")
    g.SetFont("s14 w600 cEEF0F7", "Segoe UI")
    g.Add("Text", "x" (mx + miniW + 18) " y32 w180 BackgroundTrans", StrUpper(SubStr(name, 1, 1)) SubStr(name, 2))

    g.Show("NA Hide w" w " h" h)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "int*", 2, "int", 4)               ; esquinas redondeadas
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 34, "uint*", 0x39271F, "int", 4)       ; borde de 1 px
    WinSetTransparent(0, g.Hwnd)
    g.Show("NA x" (Config.MonLeft + (Config.MonW - w) // 2) " y" (Config.MonTop + Config.MonH - h - 90))
    ToastGui := g
    ToastStart := A_TickCount
    SetTimer(ToastStep, 20)
}

ToastStep() {
    global ToastGui
    if !IsObject(ToastGui) {
        SetTimer(ToastStep, 0)
        return
    }
    e := A_TickCount - ToastStart
    if e >= 1950 {
        ToastClose()
        return
    }
    a := e < 150 ? 255 * e / 150 : (e < 1650 ? 255 : 255 * (1950 - e) / 300)
    try WinSetTransparent(Round(a), ToastGui.Hwnd)
}

ToastClose() {
    global ToastGui
    SetTimer(ToastStep, 0)
    if IsObject(ToastGui) {
        try ToastGui.Destroy()
        ToastGui := ""
    }
}
