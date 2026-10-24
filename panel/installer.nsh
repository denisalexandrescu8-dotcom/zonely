; Personalización del instalador de Zonely (electron-builder, NSIS). Se instala por usuario, sin administrador.
; El motor (ZonelyEngine.exe) vive junto al panel y arranca con Windows.

!macro customInit
  ; Si el motor está en marcha, se cierra para poder reemplazar sus archivos al actualizar.
  nsExec::Exec 'taskkill /F /IM ZonelyEngine.exe'
!macroend

!macro customInstall
  ; Arranque automático del motor con Windows.
  CreateShortCut "$SMSTARTUP\Zonely (motor).lnk" "$INSTDIR\resources\ZonelyEngine.exe" "" "$INSTDIR\resources\assets\zonely.ico"
  ; Accesos de la versión antigua («Gestor de zonas»), si existían.
  Delete "$SMPROGRAMS\Gestor de zonas.lnk"
  Delete "$SMSTARTUP\Gestor de zonas (motor).lnk"
  ; Arranca el motor ahora, sin esperar al próximo inicio de sesión.
  Exec '"$INSTDIR\resources\ZonelyEngine.exe"'
!macroend

!macro customUnInit
  nsExec::Exec 'taskkill /F /IM ZonelyEngine.exe'
!macroend

!macro customUnInstall
  Delete "$SMSTARTUP\Zonely (motor).lnk"
  ; Los datos del usuario (%APPDATA%\Zonely: ajustes y registro) NO se borran al desinstalar.
!macroend
