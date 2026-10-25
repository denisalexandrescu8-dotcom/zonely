#Requires AutoHotkey v2.0
; ============================================================
;  Watcher.ahk - Vigilante de maximizado
;  Si Windows maximiza la ventana activa (botón o Win+Arriba),
;  la devolvemos a su tamaño normal y la ajustamos a su zona,
;  para que nunca ocupe los 5120 px.
;  Solo vigila la ventana activa: es ligero, y una maximización
;  hecha por el usuario siempre ocurre en la ventana activa.
; ============================================================

WS_CAPTION_MASK := 0xC00000
WatcherOn := false
WatcherLoops := Map()      ; hwnd -> [veces, tick inicial]  (anti-bucle)
WatcherIgnored := Map()    ; hwnds que se pelean con nosotros: se dejan en paz

WatcherHooks := []         ; manejadores de SetWinEventHook (reaccionan al instante, sin esperar al temporizador)
WatcherNoAnim := Map()     ; hwnd -> true: ya sin animación de maximizar/restaurar

StartWatcher() {
    global WatcherOn := true, WatcherHooks
    SetTimer(WatcherTick, Max(Config.WatcherInterval, 500))     ; red de seguridad: lo normal es que reaccionen los eventos de ventana
    if WatcherHooks.Length = 0 {
        cb := CallbackCreate(WatcherEvent, , 7)
        for ev in [0x0003, 0x800B]                      ; cambio de ventana activa / cambio de posición o tamaño
            WatcherHooks.Push(DllCall("SetWinEventHook", "UInt", ev, "UInt", ev, "Ptr", 0, "Ptr", cb, "UInt", 0, "UInt", 0, "UInt", 0, "Ptr"))
    }
}

StopWatcher() {
    global WatcherOn := false, WatcherHooks
    SetTimer(WatcherTick, 0)
    for h in WatcherHooks
        DllCall("UnhookWinEvent", "Ptr", h)
    WatcherHooks := []
}

; Reacción inmediata: al maximizarse la ventana activa la recolocamos en el mismo instante, y a cada ventana
; que pasa a ser la activa le quitamos la animación de maximizar para que no se vea el «amago» de pantalla completa.
WatcherEvent(hook, event, hwnd, idObject, idChild, thread, time) {
    if idObject != 0 || !hwnd || !WatcherOn || A_IsSuspended
        return
    Critical "On"
    try {
        v := GetVisibleRect(hwnd)
        Config.UseAt((v["L"] + v["R"]) // 2, (v["T"] + v["B"]) // 2)
        if Config.Zoned
            WatcherEventHere(event, hwnd)
    }
    Config.UseMain()
}

WatcherEventHere(event, hwnd) {
    try {
        if event = 0x0003 {
            if !WatcherNoAnim.Has(hwnd) && !WatcherSkips(hwnd, false) {
                DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 3, "Int*", 1, "UInt", 4)   ; TRANSITIONS_FORCEDISABLED
                WatcherNoAnim[hwnd] := true
            }
        } else if hwnd = WinExist("A") && WinGetMinMax(hwnd) = 1 && !WatcherSkips(hwnd) {
            WatcherFix(hwnd)
        }
    }
}

; Win+Alt+W / bandeja: activa o desactiva el vigilante.
ToggleWatcher(*) {
    if WatcherOn
        StopWatcher()
    else
        StartWatcher()
    TrayWatcherChecked(WatcherOn)
    Notify(WatcherOn ? T("Vigilante activado") : T("Vigilante desactivado"))
}

; ¿Hay que dejar esta ventana en paz?
WatcherSkips(hwnd, onlyMonitor := true) {
    if WatcherIgnored.Has(hwnd) || GameSaved.Has(hwnd)       ; modo juego manual
        return true
    if onlyMonitor && !WindowOnMonitor(hwnd)                 ; en los demás monitores, maximizar es lo normal
        return true
    if IsGameWindow(hwnd)
        return true
    cls := WinGetClass(hwnd)
    if HasValue(SystemClasses, cls) || HasValue(Config.ExcludeClasses, cls)
        return true
    if HasValue(Config.ExcludeProcesses, WinGetProcessName(hwnd))
        return true
    ; Pantalla completa de verdad: sin barra de título (el maximizado normal la tiene).
    if (WinGetStyle(hwnd) & WS_CAPTION_MASK) != WS_CAPTION_MASK
        return true
    return false
}

WatcherTick() {
    if A_IsSuspended
        return
    Critical "On"
    try {
        hwnd := WinExist("A")
        if hwnd {
            v := GetVisibleRect(hwnd)
            Config.UseAt((v["L"] + v["R"]) // 2, (v["T"] + v["B"]) // 2)
            if Config.Zoned && WinGetMinMax(hwnd) = 1 {
                if !WatcherSkips(hwnd)           ; sin zonas, maximizar es lo normal
                    WatcherFix(hwnd)
            } else if Config.Zoned {
                WatcherFullScreenFix(hwnd)       ; pantalla completa de vídeo o F11
            }
        }
    }   ; la ventana puede desaparecer o ser de otro nivel de permisos: se ignora
    Config.UseMain()
}

; Anti-bucle: si una app se re-maximiza sola (o vuelve a pantalla completa) más de 4 veces en 3 s, la ignoramos.
; Devuelve false si hay que dejarla en paz.
WatcherLoopOk(hwnd) {
    now := A_TickCount
    info := WatcherLoops.Has(hwnd) ? WatcherLoops[hwnd] : [0, now]
    if now - info[2] > 3000
        info := [0, now]
    info[1]++
    WatcherLoops[hwnd] := info
    if info[1] > 4 {
        WatcherIgnored[hwnd] := true
        Notify(T("El vigilante ignora esta ventana (se maximiza sola)"), 2500)
        return false
    }
    return true
}

WatcherFix(hwnd) {
    if !WatcherLoopOk(hwnd)
        return

    Log("Vigilante: " WinGetProcessName(hwnd) " estaba maximizada")
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "UInt", 3, "Int*", 1, "UInt", 4)    ; sin fundido de restaurar
    ; La zona donde estaba antes de maximizarse la da su posición normal (sin restaurarla antes: se haría en dos pasos
    ; y se vería la ventana con su tamaño anterior un instante).
    r := NormalRect(hwnd)
    v := GetVisibleRect(hwnd)
    off := WorkspaceOffset((v["L"] + v["R"]) // 2, (v["T"] + v["B"]) // 2)
    z := ZoneAt(r[1] + off[1] + r[3] // 2, r[2] + off[2] + r[4] // 2)
    PlaceInRect(hwnd, z.X, z.Y, z.W, z.H)       ; de maximizada a la zona de un solo paso
}

; Pantalla completa de vídeo o F11 (no es «maximizada», así que WatcherTick no la ve): la ventana ocupa todo el monitor y no
; tiene barra de título. Con «Pantalla completa a la zona» activada vuelve a su zona, como en Mac. Los juegos y las
; exclusiones se dejan en paz.
WatcherFullScreenFix(hwnd) {
    if !hwnd || !Config.FullScreenToZone || WinGetMinMax(hwnd) = 1 || WatcherIgnored.Has(hwnd) || GameSaved.Has(hwnd)
        return
    if !WindowOnMonitor(hwnd) || IsGameWindow(hwnd)
        return
    cls := WinGetClass(hwnd)
    if HasValue(SystemClasses, cls) || HasValue(Config.ExcludeClasses, cls) || HasValue(Config.ExcludeProcesses, WinGetProcessName(hwnd))
        return
    WinGetPos(&x, &y, &w, &h, hwnd)
    m := MonitorAreaAt(x + w // 2, y + h // 2)
    if x > m[1] || y > m[2] || x + w < m[3] || y + h < m[4]          ; no cubre el monitor entero: no es pantalla completa
        return
    if !WatcherLoopOk(hwnd)
        return
    ; la zona donde estaba la ventana (si Zonely la colocó); si no, la de donde está el ratón
    if ZoneOrig.Has(hwnd) && ZoneOrig[hwnd]["zone"] != "" {
        r := ZoneOrig[hwnd]["zone"]
        z := Zone("", r[1], r[2], r[3] - r[1], r[4] - r[2])
    } else {
        MouseGetPos(&mx, &my)
        z := ZoneAt(mx, my)
    }
    Log("Vigilante: " WinGetProcessName(hwnd) " ocupa toda la pantalla; vuelve a su zona")
    PlaceInRect(hwnd, z.X, z.Y, z.W, z.H, false)
}
