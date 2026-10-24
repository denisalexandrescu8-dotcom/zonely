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
    SetTimer(WatcherTick, Config.WatcherInterval)       ; red de seguridad
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
    if idObject != 0 || !hwnd || !WatcherOn || A_IsSuspended || !Config.Zoned
        return
    try {
        if event = 0x0003 {
            if !WatcherNoAnim.Has(hwnd) && !WatcherSkips(hwnd) {
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
    Notify("Vigilante " (WatcherOn ? "activado" : "desactivado"))
}

; ¿Hay que dejar esta ventana en paz?
WatcherSkips(hwnd) {
    if WatcherIgnored.Has(hwnd) || GameSaved.Has(hwnd)       ; modo juego manual
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
    if A_IsSuspended || !Config.Zoned                ; sin zonas, maximizar es lo normal
        return
    try {
        hwnd := WinExist("A")
        if !hwnd || WinGetMinMax(hwnd) != 1 || WatcherSkips(hwnd)
            return
        WatcherFix(hwnd)
    }   ; la ventana puede desaparecer o ser de otro nivel de permisos: se ignora
}

WatcherFix(hwnd) {
    ; Anti-bucle: si una app se re-maximiza sola >4 veces en 3 s, la ignoramos.
    now := A_TickCount
    info := WatcherLoops.Has(hwnd) ? WatcherLoops[hwnd] : [0, now]
    if now - info[2] > 3000
        info := [0, now]
    info[1]++
    WatcherLoops[hwnd] := info
    if info[1] > 4 {
        WatcherIgnored[hwnd] := true
        Notify("El vigilante ignora esta ventana (se maximiza sola)", 2500)
        return
    }

    Log("Vigilante: " WinGetProcessName(hwnd) " estaba maximizada")
    WinRestore(hwnd)                 ; vuelve a su tamaño normal...
    z := ZoneOf(hwnd)                ; ...que nos dice en qué zona estaba
    PlaceInRect(hwnd, z.X, z.Y, z.W, z.H)
}
