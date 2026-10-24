#Requires AutoHotkey v2.0
; ============================================================
;  Updates.ahk - Actualizaciones en segundo plano
;  El motor (siempre en marcha) lanza «Zonely.exe --background-update» a los pocos minutos de arrancar y cada 6 horas.
;  Ese proceso no tiene ventana: mira si hay una versión nueva en GitHub, la descarga, la instala y vuelve a arrancar el motor.
;  Si [General] AutoUpdate=0, se cierra sin hacer nada (entonces se pregunta al abrir el panel).
;  Solo existe en la versión instalada: desde el código no hay Zonely.exe junto a la carpeta resources.
; ============================================================

PanelExe() => A_ScriptDir "\..\Zonely.exe"

StartBackgroundUpdates() {
    if !FileExist(PanelExe())
        return
    SetTimer(FirstBackgroundUpdate, -120000)
}

FirstBackgroundUpdate() {
    BackgroundUpdate()
    SetTimer(BackgroundUpdate, 6 * 3600 * 1000)
}

BackgroundUpdate() {
    try Run('"' PanelExe() '" --background-update', A_ScriptDir, "Hide")
    catch Error as e
        Log("No pude lanzar la comprobación de actualizaciones: " e.Message, "WARN")
}
