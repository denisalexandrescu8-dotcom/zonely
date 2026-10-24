#Requires AutoHotkey v2.0
; ============================================================
;  Paths.ahk - Dónde se guardan los datos del usuario
;  Los ajustes (zones.ini), el registro (logs) y la comunicación con el panel (ipc)
;  viven en %APPDATA%\Zonely, no junto a la aplicación: así una actualización o un
;  instalador nuevo nunca los pisa. En el primer arranque se copia zones.ini de la
;  carpeta de la aplicación (la configuración de fábrica, o la tuya si ya existía).
;  ZONELY_DATA cambia la carpeta (pruebas).
; ============================================================

DataDir := EnvGet("ZONELY_DATA") != "" ? EnvGet("ZONELY_DATA") : A_AppData "\Zonely"
try DirCreate(DataDir)
if !FileExist(DataDir "\zones.ini") && FileExist(A_ScriptDir "\zones.ini")
    try FileCopy(A_ScriptDir "\zones.ini", DataDir "\zones.ini")
