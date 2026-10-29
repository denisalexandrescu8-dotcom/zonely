#Requires AutoHotkey v2.0
; ============================================================
;  Profiles.ahk - Cambiar de perfil y selector (Win+Alt+P)
;  El selector muestra una fila por perfil con la miniatura de sus zonas, su reparto en px y %,
;  y un botón «Aplicar»; un clic en cualquier parte de la fila aplica el perfil. Esc o la X lo cierran.
; ============================================================

PickerGui := ""
PickerMon := ""            ; monitor del que el selector abierto cambia el perfil

; Nombre del monitor tal como lo detecta Windows (el que se enseña en el panel); "" si solo hay uno.
MonitorLabel(id) {
    if MonitorGetCount() < 2
        return ""
    Loop MonitorGetCount()
        if MonitorGetName(A_Index) = id
            return MonitorModelName(id, A_Index)
    return ""
}

; Activa un perfil en el monitor indicado (cada monitor con zonas tiene el suyo) y vuelve al monitor principal.
ApplyProfileOn(id, name, origin := "") {
    Critical "On"
    ok := false
    if Config.Use(id)
        ok := ApplyProfile(name, origin)
    Config.UseMain()
    return ok
}

; Activa un perfil (atajo, selector o panel) y deja la capa oscura coherente.
ApplyProfile(name, origin := "") {
    if !Config.SetProfile(name)
        return false
    if Config.MonId = Config.MainId {                ; la capa oscura y la bandeja son las del monitor principal
        if !Config.Zoned
            SetDim("")                               ; sin zonas no hay nada que atenuar
        else
            DimRefresh()
    }
    Log("Perfil: " name (origin ? " (" origin ")" : "") (MonitorLabel(Config.MonId) != "" ? " · " MonitorLabel(Config.MonId) : ""))
    if Config.MonId = Config.MainId
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
        while j >= 1 && (list[j].X > z.X || (list[j].X = z.X && list[j].Y > z.Y)) {
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
        return T("pantalla completa, sin zonas")
    txt := ""
    for z in ZonesSorted(zs)
        txt .= (txt = "" ? "" : " + ") z.Name " " z.W
    return txt
}

; Colores del selector (RRGGBB). Zonas A, B y C como en el panel.
PkBg := "0B0F17", PkHeader := "0D121B", PkRow := "1A2030", PkRowOn := "1A2030", PkLine := "1F2739", PkAccent := "3B82F6"
PkZone := Map("A", "3B82F6", "B", "8B5CF6", "C", "F472B6", "D", "22D3EE", "E", "F59E0B", "F", "34D399")

; «50 %» o «16.5 %» (sin el .0 sobrante).
Pct(w) => RegExReplace(Round(w / Config.MonW * 100, 1), "\.0$") " %"

; Win+Alt+P: abre (o cierra) el selector. Una fila por perfil; clic = aplicar.
ShowProfilePicker() {
    global PickerGui
    if IsObject(PickerGui) {
        ClosePicker()
        return
    }
    MouseGetPos(&cx, &cy)
    Config.UseAt(cx, cy)                             ; el selector cambia el perfil del monitor donde está el cursor
    global PickerMon := Config.MonId
    Config.ReloadProfiles()                          ; por si se editó zones.ini a mano
    pad := 24, rowW := 612, rowH := 98, gap := 10, miniW := 230, miniH := 65, btnW := 104, btnH := 38
    winW := rowW + pad * 2

    g := Gui("+AlwaysOnTop -Caption +ToolWindow", T("Elegir perfil"))
    g.BackColor := PkBg
    g.MarginX := 0, g.MarginY := 0

    ; Cabecera integrada con el panel: mismo tono, marca discreta y separador fino.
    Card(g, 0, 0, winW, 78, PkHeader, (*) => 0)
    Card(g, 0, 77, winW, 1, PkLine, (*) => 0)
    g.Add("Picture", "x" (pad + 2) " y20 w44 h44 BackgroundTrans", A_ScriptDir "\assets\zonely.png")
    g.SetFont("s16 w600 cEEF0F7", "Segoe UI")
    g.Add("Text", "x" (pad + 62) " y20 w" (rowW - 110) " BackgroundTrans", T("Elegir perfil"))
    g.SetFont("s10 w400 c8A92A8", "Segoe UI")
    mlabel := MonitorLabel(Config.MonId)
    g.Add("Text", "x" (pad + 62) " y52 w" (rowW - 110) " BackgroundTrans", mlabel != "" ? T("Monitor: {name}", "name", mlabel) : T("Aplica una distribución de zonas a tu pantalla."))
    g.SetFont("s14 w400 c8A92A8", "Segoe UI")
    closeBtn := g.Add("Text", "x" (winW - pad - 28) " y22 w28 h28 Center +0x200 +0x100 BackgroundTrans", "✕")
    ; Destruir el GUI dentro de su propio evento de clic puede dejar el control
    ; nativo en un estado inconsistente. Cierra igual que al elegir un perfil:
    ; fuera del callback del ratón.
    closeBtn.OnEvent("Click", (*) => SetTimer(ClosePicker, -10))

    ry := 92
    for name in Config.ProfileOrder {
        zs := Config.Profiles[name]
        cur := name = Config.ProfileName
        pick := PickerChoose.Bind(name)

        ; borde (azul si es el perfil actual) y fondo de la fila
        rowBg := g.Add("Picture", "x" pad " y" ry " w" rowW " h" rowH " +0x100", A_ScriptDir "\assets\profile-row" (cur ? "-active" : "") ".png")
        rowBg.OnEvent("Click", pick)

        ; miniatura ilustrada del escritorio con sus zonas
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
            px := T("Pantalla completa, sin zonas")
        g.SetFont("s13 w600 cEEF0F7", "Segoe UI")
        PickText(g, tx, ry + 10, tw, StrUpper(SubStr(name, 1, 1)) SubStr(name, 2), pick)
        g.SetFont("s10 w400 cA3A9BD", "Segoe UI")
        PickText(g, tx, ry + 37, tw, px, pick)
        g.SetFont("s9 w400 c6E768C", "Segoe UI")
        PickText(g, tx, ry + 58, tw, pc, pick)
        if cur {
            g.SetFont("s9 w600 c5B9BFF", "Segoe UI")
            PickText(g, tx, ry + 76, tw, T("●  Activo ahora"), pick)
        }

        ; botón Aplicar / Aplicado
        bx := pad + rowW - btnW - 16, by := ry + (rowH - btnH) // 2
        buttonBg := g.Add("Picture", "x" bx " y" by " w" btnW " h" btnH " +0x100", A_ScriptDir "\assets\profile-button" (cur ? "-active" : "") ".png")
        buttonBg.OnEvent("Click", pick)
        g.SetFont("s10 w600 " (cur ? "cFFFFFF" : "cA3A9BD"), "Segoe UI")
        b := g.Add("Text", "x" bx " y" by " w" btnW " h" btnH " BackgroundTrans Center +0x200 +0x100", cur ? T("Aplicado") : T("Aplicar"))
        b.OnEvent("Click", pick)
        ry += rowH + gap
    }
    ry += 10
    g.SetFont("s9 w400 c6E768C", "Segoe UI")
    g.Add("Text", "x" pad " y" ry " w" rowW " BackgroundTrans", T("Esc para cerrar"))
    winH := ry + 36

    g.OnEvent("Escape", (*) => ClosePicker())
    g.OnEvent("Close", (*) => ClosePicker())
    PickerGui := g

    ; Siempre en el centro de la pantalla, sea cual sea el perfil.
    g.Show("Hide w" winW " h" winH)
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

; Mezcla dos colores RRGGBB: a = 0 → bg, a = 1 → fg (para simular la transparencia del panel).
Mix(fg, bg, a) {
    out := ""
    for i in [1, 3, 5] {
        f := Integer("0x" SubStr(fg, i, 2)), b := Integer("0x" SubStr(bg, i, 2))
        out .= Format("{:02X}", Round(b + (f - b) * a))
    }
    return out
}

; Miniatura del monitor como escritorio: fondo abstracto, ventanas de ejemplo dentro de las zonas,
; etiquetas con sus letras y una barra de tareas. Sirve para el selector y para el aviso de cambio.
MiniMonitor(g, x, y, w, h, zs, onClick) {
    ; La miniatura se mantiene cuadrada: al escalar radios redondos tan pequeños
    ; aparecían halos oscuros en el borde.
    Card(g, x - 1, y - 1, w + 2, h + 2, "29384A", onClick)
    Card(g, x, y, w, h, "142236", onClick)
    for z in ZonesSorted(zs) {
        zx := x + Round((z.X - Config.MonLeft) / Config.MonW * w), zw := Round(z.W / Config.MonW * w)
        zy := y + Round((z.Y - Config.MonTop) / Config.MonH * h), zh := Round(z.H / Config.MonH * h)
        col := PkZone[z.Name]
        zoneFill := Mix(col, "142236", 0.48)
        windowEdge := Mix(col, "29384A", 0.54)
        windowFill := Mix(col, "0E151F", 0.27)
        windowBar := Mix(col, "101A29", 0.46)
        tileFill := Mix(col, "1A2A3D", 0.4)
        if zw > 3 && zh > 3
            Card(g, zx + 1, zy + 1, zw - 2, zh - 2, zoneFill, onClick)

        ; Ventana de ejemplo escalada dentro de la zona.
        wx := zx + 5, wy := zy + 13, ww := zw - 10, wh := zh - 17
        if ww > 28 && wh > 20 {
            Card(g, wx + 2, wy + 3, ww, wh, "0B1220", onClick)                ; sombra desplazada
            Card(g, wx, wy, ww, wh, windowEdge, onClick)
            Card(g, wx + 1, wy + 1, ww - 2, wh - 2, windowFill, onClick)
            Card(g, wx + 2, wy + 2, ww - 4, Max(5, Round(wh * 0.2)), windowBar, onClick)
            Card(g, wx + 3, wy + 2, ww - 6, 1, Mix("FFFFFF", col, 0.12), onClick) ; brillo suave superior
            dot := Max(2, Min(4, Round(ww / 45)))
            Card(g, wx + 4, wy + 3, dot, dot, "E87878", onClick)
            Card(g, wx + 4 + dot + 2, wy + 3, dot, dot, "E5B957", onClick)
            Card(g, wx + 4 + (dot + 2) * 2, wy + 3, dot, dot, "62C68E", onClick)
            Card(g, wx + ww - Max(12, Round(ww * 0.2)) - 4, wy + 3, Max(8, Round(ww * 0.2)), 3, Mix(col, "18314C", 0.52), onClick)
            if wh > 31 {
                rail := Max(4, Round(ww * 0.12))
                bodyY := wy + Max(6, Round(wh * 0.2)) + 1
                Card(g, wx + 2, bodyY, rail, wh - (bodyY - wy) - 2, "111B29", onClick)
                cx := wx + rail + 6, cy := bodyY + 3
                Card(g, cx, cy, Max(8, Round((ww - rail - 12) * 0.48)), 3, "A9B8CA", onClick)
                Card(g, cx, cy + 7, Max(8, Round((ww - rail - 12) * 0.8)), 2, "344255", onClick)
                Card(g, cx, cy + 12, Max(7, Round((ww - rail - 12) * 0.61)), 2, "344255", onClick)
                if wh > 45 {
                    cardY := cy + 19, cardW := Max(7, Round((ww - rail - 16) / 3))
                    Loop 3
                    Card(g, cx + (A_Index - 1) * (cardW + 3), cardY, cardW, Max(6, wh - (cardY - wy) - 4), tileFill, onClick)
                }
            }
        }

        ; Etiqueta de zona encima de la ventana ilustrada.
        labelW := Max(6, Min(24, zw - 6))
        Card(g, zx + 3, zy + 3, labelW, 11, Mix(col, "0B1220", 0.36), onClick)
        g.SetFont("s8 w700 c" col, "Segoe UI")
        labelTextW := Max(2, labelW - 2)
        t := g.Add("Text", "x" (zx + 4) " y" (zy + 2) " w" labelTextW " h11 BackgroundTrans Center +0x200 +0x100", z.Name)
        t.OnEvent("Click", onClick)
    }
    ; Barra de tareas discreta que completa la lectura de «escritorio».
    Card(g, x + 1, y + h - 5, w - 2, 4, "0B1220", onClick)
    Card(g, x + 7, y + h - 3, 3, 2, "5B9BFF", onClick)
    Card(g, x + 14, y + h - 3, 3, 2, "596779", onClick)
}
PickerChoose(name, *) {
    SetTimer(() => (ClosePicker(), ApplyProfileOn(PickerMon, name, "selector")), -10)    ; se cierra fuera del evento del clic
}

ClosePicker() {
    global PickerGui
    if IsObject(PickerGui) {
        g := PickerGui
        PickerGui := ""
        g.Destroy()
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
    w := 360, h := 84, miniW := 122, miniH := 38

    g := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20 +E0x08000000")     ; sin foco y atravesable
    g.BackColor := PkRow
    g.MarginX := 0, g.MarginY := 0
    mx := 18, my := (h - miniH) // 2
    MiniMonitor(g, mx, my, miniW, miniH, zs, (*) => 0)
    g.SetFont("s9 w500 c8A92A8", "Segoe UI")
    mlabel := MonitorLabel(Config.MonId)
    g.Add("Text", "x" (mx + miniW + 20) " y17 w190 BackgroundTrans", mlabel != "" ? T("Perfil aplicado") " · " mlabel : T("Perfil aplicado"))
    g.SetFont("s14 w600 cEEF0F7", "Segoe UI")
    g.Add("Text", "x" (mx + miniW + 20) " y37 w190 BackgroundTrans", StrUpper(SubStr(name, 1, 1)) SubStr(name, 2))

    g.Show("NA Hide w" w " h" h)
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 33, "int*", 2, "int", 4)               ; esquinas redondeadas
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 34, "uint*", 0x39271F, "int", 4)       ; borde de 1 px
    DllCall("dwmapi\DwmSetWindowAttribute", "ptr", g.Hwnd, "int", 38, "uint*", 0x0030201A, "int", 4)   ; fondo #1A2030, igual que las tarjetas del panel
    WinSetTransparent(0, g.Hwnd)
    g.Show("NA x" (Config.MonLeft + (Config.MonW - w) // 2) " y" (Config.MonTop + Config.MonH - h - 96))
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
