#Requires AutoHotkey v2.0
; ============================================================
;  Log.ahk - Versión y registro de actividad / errores
;  Escribe en logs\gestor.log (también lo usa el panel). Si pasa algo
;  raro, ese archivo dice qué fue. Se rota al pasar de 1 MB.
; ============================================================

#Include %A_LineFile%\..\Paths.ahk      ; DataDir: dónde se guardan los datos del usuario

LogDir := DataDir "\logs"
LogFile := LogDir "\gestor.log"
AppVersion := "?"
try AppVersion := Trim(FileRead(A_ScriptDir "\version.txt"), " `t`r`n")

; Anota una línea con fecha. level: INFO | WARN | ERROR
Log(msg, level := "INFO") {
    try {
        DirCreate(LogDir)
        FileAppend(FormatTime(, "yyyy-MM-dd HH:mm:ss") " [motor] " level " " msg "`n", LogFile, "UTF-8")
    }
}

; Al arrancar: si el registro pesa más de 1 MB, se guarda como .old y se empieza uno nuevo.
LogRotate() {
    try {
        if FileExist(LogFile) && FileGetSize(LogFile) > 1048576
            FileMove(LogFile, LogDir "\gestor.old.log", 1)
    }
}

; Los errores no esperados se anotan y NO muestran el diálogo bloqueante: aparece un aviso breve.
LogUnhandled(e, mode) {
    Log(e.Message " | en " e.What " | " e.File ":" e.Line (e.Extra != "" ? " | " e.Extra : ""), "ERROR")
    try Notify(T("Error interno: mira el registro del panel"), 3000)
    return 1
}

LogRotate()
OnError(LogUnhandled)
