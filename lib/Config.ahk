#Requires AutoHotkey v2.0
; ============================================================
;  Config.ahk - Lectura y validación de zones.ini
;  Ninguna medida de zona está escrita a mano en el código:
;  todo sale de este archivo.
; ============================================================

; Una zona rectangular en píxeles del escritorio virtual.
class Zone {
    __New(name, x, y, w, h) {
        this.Name := name
        this.X := x
        this.Y := y
        this.W := w
        this.H := h
    }
    Right  => this.X + this.W
    Bottom => this.Y + this.H
    ToString() => this.Name ": " this.X "," this.Y "  " this.W "x" this.H
}

class Config {
    static IniPath := DataDir "\zones.ini"
    static ProfileOrder := []     ; nombres de perfil en el orden de zones.ini
    static GameZoneOf := Map()    ; perfil -> zona del modo juego ("A", "B", "C" o "auto" = la zona donde esté la ventana)
    static Profiles := Map()      ; nombre de perfil -> Map("A", Zone[, "B", Zone])
    static ProfileName := ""      ; perfil activo
    static MonW := 0              ; tamaño real (px) del monitor al que se aplican las zonas
    static MonH := 0
    static MonLeft := 0           ; esquina superior izquierda de ese monitor en el escritorio virtual
    static MonTop := 0
    static MonId := ""            ; nombre de Windows del monitor elegido (\\.\DISPLAY2)
    static DesignW := 0           ; tamaño para el que están escritas las zonas de zones.ini ([Monitor] Width/Height)
    static DesignH := 0
    static DimOpacity := 85
    static SnapHalves := false         ; Shift+arrastrar: ¿se pueden elegir mitades en la zona B?
    static RestoreOnLeave := true      ; al salirse de una zona, la ventana recupera su tamaño original
    static SnapEnabled := true
    static SnapKey := "Shift"
    static WatcherEnabled := true
    static WatcherInterval := 150
    static ExcludeProcesses := []
    static ExcludeClasses := []
    static GameProcesses := []         ; juegos: el encaje, el vigilante y la restauración los ignoran por completo
    ; Un contexto por monitor con zonas: el elegido en el panel ([Monitor] de zones.ini, el «principal» del motor) y los demás
    ; que tienen su conjunto de perfiles en monitors\<monitor>.ini. Los campos de arriba (Profiles, ProfileName, Mon*…) son
    ; los del contexto en uso; los otros están aparcados en Parked. Use()/UseAt() cambian de contexto y UseMain() vuelve al
    ; principal: el resto del motor sigue trabajando con `Config.Zones`, `Config.MonW`… sin enterarse.
    static MainId := ""
    static Parked := Map()
    static CtxFields := ["ProfileOrder", "GameZoneOf", "Profiles", "ProfileName", "MonW", "MonH", "MonLeft", "MonTop", "MonId", "DesignW", "DesignH"]

    ; Carga el .ini completo. Lanza Error con mensaje claro si algo no cuadra.
    static Load() {
        if !FileExist(this.IniPath)
            throw Error("No encuentro " this.IniPath)

        this.DesignW := Integer(IniRead(this.IniPath, "Monitor", "Width", 5120))
        this.DesignH := Integer(IniRead(this.IniPath, "Monitor", "Height", 1440))
        this._ResolveMonitor(IniRead(this.IniPath, "Monitor", "Id", ""))
        this.MainId := this.MonId

        this._LoadProfiles()
        if this.Profiles.Count = 0
            throw Error("zones.ini no define ningún perfil [Profile.xxx]")

        this.ProfileName := IniRead(this.IniPath, "General", "Profile", "ultrawide")
        last := this.LastProfile(this.MonId)               ; el último perfil usado en este monitor gana sobre el del .ini
        if last != "" && this.Profiles.Has(last)
            this.ProfileName := last
        if !this.Profiles.Has(this.ProfileName)
            throw Error("El perfil '" this.ProfileName "' no existe en zones.ini")
        this._LoadOptions()
        this._LoadParked()
    }

    ; Nombre de archivo de un monitor (como en el panel): \.DISPLAY2 -> _DISPLAY2.
    static Slug(id) => RegExReplace(id, "[^\w-]+", "_")

    ; Los demás monitores con zonas: uno por archivo monitors\<monitor>.ini (lo escribe el panel con el mismo formato que
    ; zones.ini). Solo cuentan los que están conectados ahora.
    static _LoadParked() {
        this.Parked := Map()
        main := Map()
        for name in this.CtxFields
            main[name] := this.%name%
        mainIni := this.IniPath
        Loop Files DataDir "\monitors\*.ini" {
            try {
                id := IniRead(A_LoopFilePath, "Monitor", "Id", "")
                if id = "" || id = this.MainId || !this.MonitorConnected(id)
                    continue
                this.IniPath := A_LoopFilePath
                this.DesignW := Integer(IniRead(A_LoopFilePath, "Monitor", "Width", 0))
                this.DesignH := Integer(IniRead(A_LoopFilePath, "Monitor", "Height", 0))
                this._ResolveMonitor(id)
                this._LoadProfiles()
                if this.Profiles.Count = 0
                    continue
                this.ProfileName := IniRead(A_LoopFilePath, "General", "Profile", "")
                last := this.LastProfile(id)
                if last != "" && this.Profiles.Has(last)
                    this.ProfileName := last
                if !this.Profiles.Has(this.ProfileName)
                    this.ProfileName := this.ProfileOrder[1]
                snap := Map()
                for name in this.CtxFields
                    snap[name] := this.%name%
                this.Parked[id] := snap
            } catch Error as e {
                try Log("Perfiles del monitor " A_LoopFileName ": " e.Message, "WARN")
            }
        }
        this.IniPath := mainIni
        for name, value in main
            this.%name% := value
    }

    static MonitorConnected(id) {
        Loop MonitorGetCount()
            if MonitorGetName(A_Index) = id
                return true
        return false
    }

    ; Cambia al contexto de ese monitor. Devuelve false si el monitor no tiene zonas (y deja el contexto como estaba).
    static Use(id) {
        if id = this.MonId
            return true
        if !this.Parked.Has(id)
            return false
        cur := Map()
        for name in this.CtxFields
            cur[name] := this.%name%
        next := this.Parked[id]
        this.Parked.Delete(id)
        this.Parked[this.MonId] := cur
        for name, value in next
            this.%name% := value
        return true
    }

    static UseMain() => this.Use(this.MainId)

    ; Cambia al contexto del monitor que contiene el punto (false si ese monitor no tiene zonas).
    static UseAt(x, y) {
        id := this.MonitorIdAt(x, y)
        return id != "" && this.Use(id)
    }

    static MonitorIdAt(x, y) {
        Loop MonitorGetCount() {
            MonitorGet(A_Index, &l, &t, &r, &b)
            if x >= l && x < r && y >= t && y < b
                return MonitorGetName(A_Index)
        }
        return ""
    }

    ; Perfil activo de un monitor con zonas ("" si no tiene).
    static ProfileOf(id) {
        if id = this.MonId
            return this.ProfileName
        return this.Parked.Has(id) ? this.Parked[id]["ProfileName"] : ""
    }

    ; ¿Algún monitor con zonas reparte la pantalla? (la restauración de tamaños sirve para todos)
    static AnyZoned() {
        if this.Zoned
            return true
        for _, c in this.Parked
            if c["Profiles"][c["ProfileName"]].Has("B")
                return true
        return false
    }

    ; ¿Se puede cargar zones.ini sin errores? Si falla, deja todo como estaba y devuelve el motivo;
    ; si va bien devuelve "" y conserva el perfil activo (la recarga automática solo continúa si es válido).
    static TryLoad() {
        names := ["ProfileOrder", "GameZoneOf", "Profiles", "ProfileName", "MonW", "MonH", "MonLeft", "MonTop", "MonId"
            , "MainId", "Parked", "DesignW", "DesignH", "DimOpacity", "SnapHalves"
            , "RestoreOnLeave", "SnapEnabled", "SnapKey", "WatcherEnabled", "WatcherInterval", "ExcludeProcesses"
            , "ExcludeClasses", "GameProcesses"]
        old := Map()
        for name in names
            old[name] := this.%name%
        try {
            this.Load()
        } catch Error as e {
            for name, value in old
                this.%name% := value
            return e.Message
        }
        if old["MainId"] = this.MainId && this.Profiles.Has(old["ProfileName"])      ; el mismo monitor conserva su perfil; otro monitor, el suyo
            this.ProfileName := old["ProfileName"]
        return ""
    }

    ; Vuelve a leer las zonas de todos los perfiles sin tocar el resto del estado
    ; (así un cambio hecho en zones.ini se ve sin recargar el motor). Si el archivo
    ; está mal, se queda lo que había.
    static ReloadProfiles() {
        if this.MonId != this.MainId                  ; solo se relee el ini del monitor principal
            return
        old := [this.Profiles, this.ProfileOrder, this.GameZoneOf]
        try {
            this._LoadProfiles()
            if !this.Profiles.Has(this.ProfileName)
                throw Error("falta el perfil activo")
        } catch {
            this.Profiles := old[1], this.ProfileOrder := old[2], this.GameZoneOf := old[3]
        }
    }

    ; Todas las secciones [Profile.xxx] son perfiles.
    static _LoadProfiles() {
        this.Profiles := Map()
        this.ProfileOrder := []
        this.GameZoneOf := Map()
        for section in StrSplit(IniRead(this.IniPath), "`n", "`r") {
            if SubStr(section, 1, 8) != "Profile."
                continue
            name := SubStr(section, 9)
            zones := Map("A", this._ReadZone(section, "A"))
            for key in ["B", "C", "D", "E", "F"] {          ; A, B, C… seguidas (hasta 6); sin B = perfil de pantalla normal, sin zonas
                if IniRead(this.IniPath, section, key, "") = ""
                    break
                zones[key] := this._ReadZone(section, key)
            }
            this.Profiles[name] := zones
            gz := StrUpper(IniRead(this.IniPath, section, "GameZone", "auto"))      ; zona del modo juego de este perfil (por defecto, la de la ventana)
            this.GameZoneOf[name] := (gz = "AUTO") ? "auto" : (zones.Has(gz) ? gz : "auto")
            this.ProfileOrder.Push(name)
        }
    }

    static _LoadOptions() {
        ; Vigilante de maximizado
        this.WatcherEnabled := IniRead(this.IniPath, "Watcher", "Enabled", 1) = 1
        this.WatcherInterval := Max(50, Integer(IniRead(this.IniPath, "Watcher", "IntervalMs", 150)))
        ; Encaje al arrastrar
        this.RestoreOnLeave := IniRead(this.IniPath, "General", "RestoreOnLeave", 1) = 1
        this.SnapHalves := IniRead(this.IniPath, "Snap", "Halves", 0) = 1
        ; Capa oscura
        this.DimOpacity := Integer(IniRead(this.IniPath, "Dim", "Opacity", 85))
        if this.DimOpacity < 0 || this.DimOpacity > 100
            throw Error("[Dim] Opacity debe estar entre 0 y 100")
        ; Encajar al arrastrar
        this.SnapEnabled := IniRead(this.IniPath, "Snap", "Enabled", 1) = 1
        this.SnapKey := IniRead(this.IniPath, "Snap", "Key", "Shift")
        if !(this.SnapKey = "Shift" || this.SnapKey = "Ctrl" || this.SnapKey = "Alt")
            throw Error("[Snap] Key debe ser Shift, Ctrl o Alt (es '" this.SnapKey "')")
        this.ExcludeProcesses := this._ReadList("Exclusions", "Processes")
        this.ExcludeClasses := this._ReadList("Exclusions", "Classes")
        raw := IniRead(this.IniPath, "Exclusions", "Games", "RainbowSix.exe")     ; sin la clave: solo Siege
        this.GameProcesses := []
        for item in StrSplit(raw, ",", " `t")
            if item != ""
                this.GameProcesses.Push(item)
    }

    ; Lista separada por comas -> array (vacío si no hay nada).
    static _ReadList(section, key) {
        raw := IniRead(this.IniPath, section, key, "")
        list := []
        for item in StrSplit(raw, ",", " `t")
            if item != ""
                list.Push(item)
        return list
    }

    ; Último perfil usado (guardado en last-profile.txt para recuperarlo al reiniciar). "" si no hay.
    static LastProfile(id := "") {
        if id != ""
            try return Trim(FileRead(DataDir "\monitors\" this.Slug(id) ".last", "UTF-8"), " `t`r`n")
        if id = "" || id = this.MainId
            try return Trim(FileRead(DataDir "\last-profile.txt", "UTF-8"), " `t`r`n")
        return ""
    }

    ; Activa un perfil por nombre. Devuelve false si no existe.
    static SetProfile(name) {
        if !this.Profiles.Has(name)
            return false
        this.ProfileName := name
        try {
            DirCreate(DataDir "\monitors")
            FileOpen(DataDir "\monitors\" this.Slug(this.MonId) ".last", "w", "UTF-8-RAW").Write(name)
            if this.MonId = this.MainId
                FileOpen(DataDir "\last-profile.txt", "w", "UTF-8-RAW").Write(name)
        }
        return true
    }

    ; Pasa al siguiente perfil (cíclico) y devuelve su nombre.
    static NextProfile() {
        names := []
        for name, _ in this.Profiles
            names.Push(name)
        for i, name in names {
            if name = this.ProfileName {
                this.ProfileName := names[Mod(i, names.Length) + 1]
                break
            }
        }
        return this.ProfileName
    }

    ; Zonas del perfil activo.
    static Zones => this.Profiles[this.ProfileName]

    ; ¿El perfil activo reparte la pantalla en zonas? (el perfil «normal» no)
    static Zoned => this.Zones.Has("B")

    ; Zonas del perfil activo ordenadas de izquierda a derecha.
    static ZonesByX() {
        list := []
        for _, z in this.Zones
            list.Push(z)
        Loop list.Length - 1 {                       ; ordenación por inserción (son 3 como mucho)
            i := A_Index + 1, z := list[i], j := i - 1
            while j >= 1 && (list[j].X > z.X || (list[j].X = z.X && list[j].Y > z.Y)) {
                list[j + 1] := list[j]
                j--
            }
            list[j + 1] := z
        }
        return list
    }

    ; Lee "x,y,w,h" de una sección y comprueba que cabe en el monitor.
    static _ReadZone(section, key) {
        raw := IniRead(this.IniPath, section, key, "")
        parts := StrSplit(raw, ",", " `t")
        if parts.Length != 4
            throw Error("[" section "] " key "='" raw "' no tiene el formato x,y,ancho,alto")
        for p in parts {
            if !IsInteger(p)
                throw Error("[" section "] " key ": '" p "' no es un número entero")
        }
        z := Zone(key, Integer(parts[1]), Integer(parts[2]), Integer(parts[3]), Integer(parts[4]))
        if z.W <= 0 || z.H <= 0 || z.X < 0 || z.Y < 0 || z.Right > this.DesignW || z.Bottom > this.DesignH
            throw Error("[" section "] zona " key " se sale del monitor (" this.DesignW "x" this.DesignH ")")
        ; Las zonas del .ini son relativas al monitor: se escalan a su tamaño real (si es el mismo, no cambia nada)
        ; y se desplazan a su posición en el escritorio, así que el resto del motor trabaja con coordenadas absolutas.
        sx := this.MonW / this.DesignW, sy := this.MonH / this.DesignH
        x0 := Round(z.X * sx), x1 := Round(z.Right * sx), y0 := Round(z.Y * sy), y1 := Round(z.Bottom * sy)
        return Zone(key, this.MonLeft + x0, this.MonTop + y0, x1 - x0, y1 - y0)
    }

    ; Busca el monitor elegido en [Monitor] Id (nombre de Windows, p. ej. \\.\DISPLAY2). Sin Id, o si ya no está
    ; conectado, se usa el principal.
    static _ResolveMonitor(id) {
        idx := MonitorGetPrimary()
        if id != "" {
            found := false
            Loop MonitorGetCount() {
                if MonitorGetName(A_Index) = id {
                    idx := A_Index, found := true
                    break
                }
            }
            if !found
                try Log("El monitor «" id "» no está conectado: se usa el principal", "WARN")
        }
        MonitorGet(idx, &l, &t, &r, &b)
        this.MonLeft := l, this.MonTop := t, this.MonW := r - l, this.MonH := b - t
        this.MonId := MonitorGetName(idx)
    }

    ; ¿Está este punto del escritorio dentro del monitor elegido?
    static OnMonitor(x, y) => x >= this.MonLeft && x < this.MonLeft + this.MonW && y >= this.MonTop && y < this.MonTop + this.MonH
}
