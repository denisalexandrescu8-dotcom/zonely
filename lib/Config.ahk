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

    ; Carga el .ini completo. Lanza Error con mensaje claro si algo no cuadra.
    static Load() {
        if !FileExist(this.IniPath)
            throw Error("No encuentro " this.IniPath)

        this.DesignW := Integer(IniRead(this.IniPath, "Monitor", "Width", 5120))
        this.DesignH := Integer(IniRead(this.IniPath, "Monitor", "Height", 1440))
        this._ResolveMonitor(IniRead(this.IniPath, "Monitor", "Id", ""))

        this._LoadProfiles()
        if this.Profiles.Count = 0
            throw Error("zones.ini no define ningún perfil [Profile.xxx]")

        this.ProfileName := IniRead(this.IniPath, "General", "Profile", "ultrawide")
        last := this.LastProfile()                         ; el último perfil usado gana sobre el del .ini
        if last != "" && this.Profiles.Has(last)
            this.ProfileName := last
        if !this.Profiles.Has(this.ProfileName)
            throw Error("El perfil '" this.ProfileName "' no existe en zones.ini")
        this._LoadOptions()
    }

    ; ¿Se puede cargar zones.ini sin errores? Si falla, deja todo como estaba y devuelve el motivo;
    ; si va bien devuelve "" y conserva el perfil activo (la recarga automática solo continúa si es válido).
    static TryLoad() {
        names := ["ProfileOrder", "GameZoneOf", "Profiles", "ProfileName", "MonW", "MonH", "MonLeft", "MonTop", "MonId"
            , "DesignW", "DesignH", "DimOpacity", "SnapHalves"
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
        if this.Profiles.Has(old["ProfileName"])
            this.ProfileName := old["ProfileName"]
        return ""
    }

    ; Vuelve a leer las zonas de todos los perfiles sin tocar el resto del estado
    ; (así un cambio hecho en zones.ini se ve sin recargar el motor). Si el archivo
    ; está mal, se queda lo que había.
    static ReloadProfiles() {
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
    static LastProfile() {
        try return Trim(FileRead(DataDir "\last-profile.txt", "UTF-8"), " `t`r`n")
        return ""
    }

    ; Activa un perfil por nombre. Devuelve false si no existe.
    static SetProfile(name) {
        if !this.Profiles.Has(name)
            return false
        this.ProfileName := name
        try {
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
