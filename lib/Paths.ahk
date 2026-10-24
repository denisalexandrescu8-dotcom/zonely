#Requires AutoHotkey v2.0
; ============================================================
;  Paths.ahk - Dónde se guardan los datos del usuario
;  Los ajustes (zones.ini), el registro (logs) y la comunicación con el panel (ipc)
;  viven en %APPDATA%\Zonely, no junto a la aplicación: así una actualización o un
;  instalador nuevo nunca los pisa. En el primer arranque se crea zones.ini a partir de
;  zones.template.ini, con los perfiles calculados para el monitor principal.
;  ZONELY_DATA cambia la carpeta (pruebas).
; ============================================================

DataDir := EnvGet("ZONELY_DATA") != "" ? EnvGet("ZONELY_DATA") : A_AppData "\Zonely"
try DirCreate(DataDir)
if !FileExist(DataDir "\zones.ini")
    CreateDefaultIni(DataDir "\zones.ini")

; Perfiles de fábrica para un monitor de w × h píxeles (zonas mínimas de 400 px).
; La misma regla está en panel/main.js (defaultProfiles): si cambias una, cambia la otra.
DefaultProfilesText(w, h) {
    minZone := 400
    out := ""
    uw := Round(h * 43 / 18)                                   ; pantalla 21:9 (3440×1440) + columna
    if uw >= minZone && w - uw >= minZone
        out .= "[Profile.ultrawide]`n; A = pantalla 21:9 a la izquierda, B = columna a la derecha`nA=0,0," uw "," h "`nB=" uw ",0," (w - uw) "," h "`n`n"
    half := w // 2
    if half >= minZone
        out .= "[Profile.dual]`n; Dos mitades iguales`nA=0,0," half "," h "`nB=" half ",0," (w - half) "," h "`n`n"
    c := Round(h * 16 / 9)                                     ; pantalla 16:9 en el centro
    side := (w - c) // 2
    if side >= minZone
        out .= "[Profile.centrado]`n; Pantalla 16:9 en el centro (A) y una zona a cada lado (B derecha, C izquierda)`nA=" side ",0," c "," h "`nB=" (side + c) ",0," (w - side - c) "," h "`nC=0,0," side "," h "`n`n"
    out .= "[Profile.normal]`n; Pantalla normal: sin zonas (no hay B). Ni atajos de colocación, ni encaje, ni vigilante.`nA=0,0," w "," h "`n"
    return out
}

; Crea zones.ini desde la plantilla con el tamaño del monitor principal.
CreateDefaultIni(path) {
    tpl := A_ScriptDir "\zones.template.ini"
    if !FileExist(tpl)
        return
    MonitorGet(MonitorGetPrimary(), &l, &t, &r, &b)
    w := r - l, h := b - t
    txt := FileRead(tpl, "UTF-8")
    txt := StrReplace(txt, "{{WIDTH}}", w)
    txt := StrReplace(txt, "{{HEIGHT}}", h)
    txt := StrReplace(txt, "{{PROFILES}}", DefaultProfilesText(w, h))
    try {
        f := FileOpen(path, "w", "UTF-8-RAW")
        f.Write(txt)
        f.Close()
    }
}
