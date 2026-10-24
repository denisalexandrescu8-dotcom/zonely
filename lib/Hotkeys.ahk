#Requires AutoHotkey v2.0
; ============================================================
;  Hotkeys.ahk - Atajos de teclado configurables
;  Cada acción tiene un atajo por defecto; zones.ini ([Hotkeys]) puede cambiarlo.
;  Formato AutoHotkey: # = Win, ! = Alt, ^ = Ctrl, + = Mayús, y después la tecla (z, Left, F5...).
;  Se registran con Hotkey() al arrancar (los atajos "estáticos" bloquearían el resto del arranque).
;  Escribe ipc\hotkeys.json con lo registrado, para que el panel lo muestre y detecte errores.
; ============================================================

; id, etiqueta, atajo por defecto, qué hace
HotkeyTable := [
    ["ZoneMaximize", "Llenar la zona actual",                     "#!z",          () => ZoneMaximize()],
    ["MoveToA",      "Mover a la zona de la izquierda",           "#!Left",       () => MoveStep(-1)],
    ["MoveToB",      "Mover a la zona de la derecha",             "#!Right",      () => MoveStep(1)],
    ["HalfTop",      "Mitad superior (zona B)",                   "#!Up",         () => SnapHalf(true)],
    ["HalfBottom",   "Mitad inferior (zona B)",                   "#!Down",       () => SnapHalf(false)],
    ["GameMode",     "Modo juego (sin bordes, en la zona del juego)",      "#!g",          () => ToggleGameMode()],
    ["GameModeKeep", "Modo juego conservando el tamaño",          "#!+g",         () => ToggleGameMode(0, true)],
    ["CenterA",      "Centrar en la zona izquierda sin cambiar el tamaño", "#!+Left", () => CenterStep(-1)],
    ["CenterB",      "Centrar en la zona derecha sin cambiar el tamaño", "#!+Right", () => CenterStep(1)],
    ["RestoreOriginal", "Devolver la ventana a su tamaño original",  "#!q",          () => RestoreActive()],
    ["Undo",         "Deshacer la última colocación",             "#!BackSpace",  () => UndoPlacement()],
    ["SwitchProfile", "Elegir perfil (abre un selector)",           "#!p",          () => ShowProfilePicker()],
    ["ToggleWatcher", "Activar/desactivar el vigilante",          "#!w",          () => ToggleWatcher()],
    ["ToggleDim",    "Capa oscura sobre la otra zona",            "#!o",          () => ToggleDim()],
    ["ToggleDebug",  "Ventana de depuración",                     "#!d",          () => ToggleDebug()],
]

; ¿Tiene sentido como atajo? Al menos un modificador (# ! ^ +) y una tecla conocida.
HotkeyValid(s) {
    if !RegExMatch(s, "^([#!^+]{1,4})(.+)$", &m)
        return false
    return RegExMatch(m[2], "i)^([a-z0-9]|F([1-9]|1\d|2[0-4])|Numpad[0-9]|Left|Right|Up|Down|BackSpace|Space|Tab|Enter|Esc|Delete|Insert|Home|End|PgUp|PgDn)$")
}

; Activa un atajo concreto. Devuelve "" si todo va bien o el motivo del fallo.
RegHotkey(key, cb) {
    try {
        Hotkey(key, (*) => cb())
        return ""
    } catch Error as e {
        return e.Message
    }
}

; Lee zones.ini, registra todos los atajos y publica el resultado en ipc\hotkeys.json.
RegisterHotkeys() {
    used := Map()
    json := "["
    for i, d in HotkeyTable {
        id := d[1], def := d[3]
        key := Trim(IniRead(Config.IniPath, "Hotkeys", id, def))
        err := ""
        if !HotkeyValid(key)
            err := "combinación no válida: " key
        else if used.Has(key)
            err := "repetida (ya la usa «" used[key] "»)"
        if err = "" {
            err := RegHotkey(key, d[4])
        }
        if err != "" && key != def && !used.Has(def) && RegHotkey(def, d[4]) = "" {
            Log("Atajo «" id "»: " err " → se usa el de por defecto " def, "WARN")
            key := def, err := "usa el de por defecto: " err
        } else if err != "" {
            Log("Atajo «" id "» sin registrar: " err, "WARN")
        }
        if err = "" || InStr(err, "usa el de por defecto")
            used[key] := d[2]
        json .= (i > 1 ? "," : "") '{"id":"' id '","label":"' JsonStr(d[2]) '","default":"' def '","key":"' key '","error":"' JsonStr(err) '"}'
    }
    WriteJson("hotkeys.json", json "]")
}