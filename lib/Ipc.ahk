#Requires AutoHotkey v2.0
; ============================================================
;  Ipc.ahk - Comunicación con el panel de control (app Electron)
;  El panel escribe órdenes en ipc\cmd.txt (una por línea) y lee
;  el estado de ipc\state.json. Sin red ni dependencias: son dos
;  ficheros pequeños y un timer de 250 ms.
;
;  Órdenes:  profile <nombre> | watcher on|off | snap on|off | halves on|off | restore on|off | dim A|B|off | dimlevel <0-100> | watch | reload
; ============================================================

IpcDir := DataDir "\ipc"
IpcTicks := 0
IpcWatchUntil := 0                     ; el panel renueva esto cada 5 s mientras está abierto
IpcLastWin := 0                        ; última ventana activa que NO es el panel (para depuración y exclusiones)

IniStamp := ""                         ; fecha de zones.ini la última vez que se miró (recarga automática)

StartIpc() {
    global IniStamp
    DirCreate(IpcDir)
    try FileDelete(IpcDir "\cmd.txt")     ; descarta órdenes viejas
    try IniStamp := FileGetTime(Config.IniPath, "M")
    SetTimer(IpcTick, 250)
    WriteState()
}

; ¿Ha cambiado zones.ini (a mano o desde el panel)? Si el nuevo es válido, el motor se recarga solo conservando el estado;
; si no lo es, se deja la configuración anterior, se avisa y se anota en el registro.
CheckIniChanged() {
    global IniStamp
    try stamp := FileGetTime(Config.IniPath, "M")
    catch
        return
    if stamp = IniStamp
        return
    IniStamp := stamp
    msg := Config.TryLoad()
    if msg != "" {
        Log("zones.ini ha cambiado pero no es válido; se mantiene la configuración anterior: " msg, "WARN")
        Notify(T("zones.ini no es válido: {error}", "error", msg), 4000)
        return
    }
    Log("zones.ini ha cambiado: recargando")
    ReloadKeepingState()
    TrayRefreshProfiles()
}

IpcInterval := 250                     ; ms entre revisiones: 250 con el panel abierto, 1000 en reposo (ahorra batería)
IpcLastBeat := 0

IpcTick() {
    global IpcTicks, IpcInterval, IpcLastBeat
    IpcTicks++
    watching := A_TickCount < IpcWatchUntil
    want := watching ? 250 : 1000                       ; el panel manda «watch» cada 5 s mientras está abierto
    if want != IpcInterval {
        IpcInterval := want
        SetTimer(IpcTick, want)
    }
    TrackTarget()
    if watching && Mod(IpcTicks, 2) = 0                 ; solo se trabaja de más si el panel está mirando
        WriteDebug()
    cmdFile := IpcDir "\cmd.txt"
    if FileExist(cmdFile) {
        try {
            txt := FileRead(cmdFile, "UTF-8")
            FileDelete(cmdFile)
            for line in StrSplit(txt, "`n", "`r")
                if Trim(line) != ""
                    IpcRun(Trim(line))
        }
        WriteState()
        IpcLastBeat := A_TickCount
    } else if A_TickCount - IpcLastBeat >= 2000 {
        IpcLastBeat := A_TickCount
        WriteState()                       ; latido cada 2 s: el panel sabe que seguimos vivos
        CheckIniChanged()
    }
}

IpcRun(line) {
    parts := StrSplit(line, " ", , 2)
    arg := parts.Length > 1 ? parts[2] : ""
    switch StrLower(parts[1]) {
        case "profile":
            ApplyProfile(arg, "desde el panel")
        case "dim":                        ; dim A | dim B | dim off
            SetDim(RegExMatch(arg, "^[A-F](\+[A-F])*$") ? arg : "")
        case "dimlevel":
            if IsInteger(arg)
                SetDimLevel(Integer(arg))
        case "watcher":
            if (arg = "on") != WatcherOn
                ToggleWatcher()
        case "snap":
            SetSnap(arg = "on")
        case "halves":
            Config.SnapHalves := arg = "on"
        case "restore":
            Config.RestoreOnLeave := arg = "on"
            if arg != "on"
                ZoneOrig.Clear()
        case "watch":
            global IpcWatchUntil := A_TickCount + 15000
        case "reload":
            ReloadKeepingState()
        case "quit":                       ; Ajustes → Motor apagado: se cierra el motor (las ventanas en modo juego se restauran al salir)
            ExitApp()
    }
}

; Recarga el script conservando perfil, vigilante, encaje y capa oscura (si no, volverían a lo que diga el .ini).
ReloadKeepingState() {
    Log("Recargando (perfil " Config.ProfileName ")")
    try {
        f := FileOpen(IpcDir "\resume.txt", "w", "UTF-8-RAW")
        f.Write("profile=" Config.ProfileName "`nwatcher=" (WatcherOn ? 1 : 0) "`nsnap=" (SnapOn ? 1 : 0)
            . "`ndim=" DimZoneName GameResumeLines() RestoreResumeLines())
        f.Close()
    }
    Reload()
}

; Tras Config.Load(): aplica el estado guardado por ReloadKeepingState (si existe).
ApplyResume() {
    global DimZoneName
    file := IpcDir "\resume.txt"
    if !FileExist(file)
        return
    try {
        for line in StrSplit(FileRead(file, "UTF-8"), "`n", "`r") {
            kv := StrSplit(line, "=", , 2)
            if kv.Length < 2
                continue
            switch kv[1] {
                case "profile": Config.SetProfile(kv[2])
                case "watcher": Config.WatcherEnabled := kv[2] = 1
                case "snap":    Config.SnapEnabled := kv[2] = 1
                case "dim":     DimZoneName := kv[2]
                case "orig":
                    og := StrSplit(kv[2], ",")
                    if og.Length = 7 && WinExist(Integer(og[1]))
                        ZoneOrig[Integer(og[1])] := Map("w", Integer(og[2]), "h", Integer(og[3]), "zone", [Integer(og[4]), Integer(og[5]), Integer(og[6]), Integer(og[7])], "pending", 0)
                case "game":
                    g := StrSplit(kv[2], ",")
                    if g.Length = 8 && WinExist(Integer(g[1]))
                        GameSaved[Integer(g[1])] := Map("style", Integer(g[2]), "exStyle", Integer(g[3]), "x", Integer(g[4])
                            , "y", Integer(g[5]), "w", Integer(g[6]), "h", Integer(g[7]), "minmax", Integer(g[8]))
            }
        }
    }
    try FileDelete(file)
}

; Recuerda la última ventana activa que no sea el propio panel (el panel roba el foco al hacer clic).
TrackTarget() {
    global IpcLastWin
    try {
        hwnd := WinExist("A")
        if hwnd && WinGetTitle(hwnd) != "Zonely" && !HasValue(SystemClasses, WinGetClass(hwnd))
            IpcLastWin := hwnd
    }
}

; Escapa un texto para meterlo en JSON.
JsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, "`"", "\`"")
    s := RegExReplace(s, "[\x00-\x1F]", " ")
    return s
}

; Datos de la última ventana usada en JSON ("null" si no hay).
TargetJson() {
    try {
        if IpcLastWin && WinExist(IpcLastWin)
            return '{"hwnd":' IpcLastWin ',"proc":"' JsonStr(WinGetProcessName(IpcLastWin)) '","title":"' JsonStr(SubStr(WinGetTitle(IpcLastWin), 1, 80)) '"}'
    }
    return "null"
}

; Ficha JSON completa de una ventana (la que enseña la tarjeta de depuración del panel).
WindowInfo(hwnd) {
    try {
        mm := WinGetMinMax(hwnd)
        v := GetVisibleRect(hwnd)
        vw := v["R"] - v["L"], vh := v["B"] - v["T"]
        z := ZoneOf(hwnd)
        exact := v["L"] = z.X && v["T"] = z.Y && vw = z.W && vh = z.H
        WinGetPos(&ox, &oy, &ow, &oh, hwnd)
        WinGetClientPos(, , &cw, &ch, hwnd)
        style := WinGetStyle(hwnd)
        return '{"hwnd":' hwnd ',"proc":"' JsonStr(WinGetProcessName(hwnd)) '","title":"' JsonStr(SubStr(WinGetTitle(hwnd), 1, 90))
            . '","state":' mm ',"zone":"' (mm = -1 ? "" : z.Name) '","x":' v["L"] ',"y":' v["T"] ',"w":' vw ',"h":' vh
            . ',"exact":' (exact ? "true" : "false") ',"dw":' (vw - z.W) ',"dh":' (vh - z.H)
            . ',"game":' (GameSaved.Has(hwnd) ? "true" : "false")
            . ',"class":"' JsonStr(WinGetClass(hwnd)) '","path":"' JsonStr(WinGetProcessPath(hwnd)) '"'
            . ',"style":"' Format("0x{:08X}", style) '","caption":' ((style & 0xC00000) = 0xC00000 ? "true" : "false")
            . ',"ox":' ox ',"oy":' oy ',"ow":' ow ',"oh":' oh ',"cw":' cw ',"ch":' ch
            . ',"zx":' z.X ',"zy":' z.Y ',"zw":' z.W ',"zh":' z.H '}'
    }
    return ""
}

; Datos completos de la última ventana usada.
WriteDebug() {
    info := (IpcLastWin && WinExist(IpcLastWin)) ? WindowInfo(IpcLastWin) : ""
    WriteJson("debug.json", info != "" ? info : "null")
}

; Escribe un JSON en ipc\ (a un temporal y renombrando: nunca se lee a medias).
WriteJson(name, json) {
    tmp := IpcDir "\" name ".tmp"
    try {
        f := FileOpen(tmp, "w", "UTF-8-RAW")
        f.Write(json)
        f.Close()
        FileMove(tmp, IpcDir "\" name, 1)
    }
}

; Escribe el estado en JSON.
WriteState() {
    ts := DateDiff(A_NowUTC, "19700101000000", "Seconds")
    json := '{"ts":' ts ',"version":"' AppVersion '","profile":"' Config.ProfileName '","watcher":' (WatcherOn ? "true" : "false")
        . ',"snap":' (SnapOn ? "true" : "false")
        . ',"dim":"' DimZoneName '","dimLevel":' Config.DimOpacity
        . ',"target":' TargetJson()
        . ',"monitor":"' JsonEsc(Config.MonId) '","monitors":' MonitorsJson()
        . ',"paused":' (A_IsSuspended ? "true" : "false") '}'
    WriteJson("state.json", json)
}

JsonEsc(s) => StrReplace(StrReplace(s, "\", "\\"), '"', '\"')

MonitorNames := Map()            ; nombre de Windows (\\.\DISPLAY1) -> nombre del modelo, leído una vez por conexión
MonitorNamesCount := -1

; Modelo del monitor tal como lo detecta Windows: el nombre que lleva el propio monitor en su EDID (p. ej. «Odyssey OLED G9»).
; Si no se puede leer, «Monitor N». `adapter` es el nombre del monitor en Windows (\\.\DISPLAY1).
MonitorModelName(adapter, index) {
    fallback := "Monitor " index
    try {
        dd := Buffer(840, 0)                                   ; DISPLAY_DEVICE: cb, DeviceName, DeviceString, StateFlags, DeviceID, DeviceKey
        NumPut("UInt", 840, dd, 0)
        if !DllCall("EnumDisplayDevicesW", "Str", adapter, "UInt", 0, "Ptr", dd, "UInt", 0)
            return fallback
        devId := StrGet(dd.Ptr + 328, 128, "UTF-16")          ; MONITOR\SAM7000\{guid}\0004
        parts := StrSplit(devId, "\")
        if parts.Length < 4
            return fallback
        model := parts[2], driver := parts[3] "\" parts[4]
        base := "HKLM\SYSTEM\CurrentControlSet\Enum\DISPLAY\" model
        Loop Reg, base, "K" {
            try {
                if RegRead(base "\" A_LoopRegName, "Driver") != driver
                    continue
                edid := RegRead(base "\" A_LoopRegName "\Device Parameters", "EDID")       ; REG_BINARY -> cadena hexadecimal
                Loop 4 {
                    pos := 54 + (A_Index - 1) * 18                                       ; cuatro descriptores de 18 bytes
                    if SubStr(edid, pos * 2 + 1, 8) = "000000FC" {                       ; 0xFC = nombre del monitor
                        name := ""
                        Loop 13 {
                            b := Integer("0x" SubStr(edid, (pos + 4 + A_Index) * 2 + 1, 2))
                            if b = 10 || b = 0
                                break
                            name .= Chr(b)
                        }
                        name := Trim(name)
                        if name != ""
                            return name
                    }
                }
            }
        }
    }
    return fallback
}

; Monitores conectados, para que el panel deje elegir a cuál se aplican las zonas.
MonitorsJson() {
    global MonitorNames, MonitorNamesCount
    n := MonitorGetCount()
    if n != MonitorNamesCount {                                ; se vuelve a leer solo cuando se conecta o desconecta alguno
        MonitorNamesCount := n
        MonitorNames := Map()
        seen := Map()
        Loop n {
            nm := MonitorModelName(MonitorGetName(A_Index), A_Index)
            seen[nm] := seen.Has(nm) ? seen[nm] + 1 : 1
            MonitorNames[A_Index] := seen[nm] > 1 ? nm " (" seen[nm] ")" : nm      ; dos iguales: «Modelo» y «Modelo (2)»
        }
    }
    out := ""
    prim := MonitorGetPrimary()
    Loop n {
        MonitorGet(A_Index, &l, &t, &r, &b)
        out .= (out = "" ? "" : ",") '{"id":"' JsonEsc(MonitorGetName(A_Index)) '","name":"' JsonEsc(MonitorNames[A_Index]) '","x":' l ',"y":' t
            . ',"w":' (r - l) ',"h":' (b - t) ',"primary":' (A_Index = prim ? "true" : "false") '}'
    }
    return "[" out "]"
}