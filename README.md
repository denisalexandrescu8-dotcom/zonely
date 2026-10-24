# Zonely

Divide un monitor 5120×1440 en zonas independientes (por ejemplo, el juego a la izquierda y tus apps a la derecha). Las medidas viven en `zones.ini`.

**Dónde se guardan tus datos:** `%APPDATA%\Zonely` (`zones.ini`, `logs`, `ipc`). El `zones.ini` de la carpeta del proyecto es solo la plantilla que se copia la primera vez. Para cambiar un ajuste a mano, edita el de `%APPDATA%\Zonely`.

Tiene dos piezas: el **motor** (AutoHotkey v2, siempre en segundo plano, hace todo el trabajo) y el **panel** (Electron, la interfaz para ver y cambiar ajustes; se puede cerrar).

## Instalar y arrancar
1. Instala AutoHotkey v2: `winget install AutoHotkey.AutoHotkey` (o desde https://www.autohotkey.com).
2. Doble clic en `ZoneManager.ahk` para lanzar el motor.
3. Para que el motor arranque con Windows y tener el panel en el menú Inicio: `powershell -ExecutionPolicy Bypass -File scripts\install-startup.ps1` (se quita con `scripts\uninstall-startup.ps1`).
4. El panel se abre desde el menú Inicio («Zonely»). Requiere haber ejecutado `npm install` una vez dentro de `panel/`.

**Manual de uso con gráficos:** `manual/index.html` (también desde el botón *Manual* del panel).

## Atajos
Se pueden cambiar desde el panel (tarjeta «Atajos de teclado») o en la sección `[Hotkeys]` de `zones.ini`. Los de fábrica:
| Atajo | Acción |
|---|---|
| Win+Alt+Z | Llenar la zona actual |
| Win+Alt+Izq / Der | Mover a la zona de la izquierda / derecha |
| Win+Alt+Arriba / Abajo | Mitad superior / inferior (solo zona B) |
| Shift + arrastrar | Encajar en la zona izquierda o derecha (mitades opcionales) |
| Win+Alt+G | Modo juego (sin bordes en la zona A) / restaurar |
| Win+Alt+Mayús+G | Modo juego conservando el tamaño interior |
| Win+Alt+Mayús+Izq / Der | Centrar en la zona A / B sin cambiar el tamaño |
| Win+Alt+Retroceso | Deshacer la última colocación |
| Win+Alt+Q | Devolver la ventana activa a su tamaño original (el de antes de entrar en una zona) |
| Win+Alt+P | Elegir perfil (abre un selector) |
| Win+Alt+W | Activar/desactivar el vigilante de maximizado |
| Win+Alt+O | Capa oscura sobre la zona que no es la de la ventana activa |
| Win+Alt+D | Ventana de depuración de la ventana activa |

## Qué hace
- **Zonas y perfiles**: «ultrawide» (3440 + 1680) y «dual» (2560 + 2560), «centrado» (16:9 en el centro y una zona a cada lado) y «normal» (pantalla completa, sin zonas: el gestor no toca nada); las zonas se ajustan en el editor del panel.
- **Vigilante**: si una ventana se maximiza a los 5120 px, vuelve a su zona (con lista de exclusiones).
- **Encajar arrastrando**: mantén Shift mientras arrastras. Por defecto solo izquierda o derecha, enteras; con «Permitir elegir mitades» también arriba/abajo en la zona B.
- **Al salir de una zona**: si una ventana colocada en una zona se saca de ella, recupera el tamaño que tenía antes de entrar (se desactiva en el panel o con `RestoreOnLeave=0`).
- **Modo juego**: quita los bordes y deja la ventana en la zona A, o conserva su tamaño interior y la centra.
- **Capa oscura**: atenúa una zona.
- **Depuración y registro**: qué mide de verdad una ventana, y `logs/gestor.log` con lo que ha hecho el programa.

## Limitaciones
- Pantalla completa exclusiva y juegos con anti-cheat pueden ignorar o bloquear los cambios.
- Ventanas de programas ejecutados como administrador no se pueden mover desde un script sin elevar.

## Instalador de Windows
`powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1` compila el motor (Ahk2Exe) y empaqueta el panel (electron-builder) en `dist\installer\Zonely-Setup-<versión>.exe`.
Requisitos: AutoHotkey v2, [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases) (`-Ahk2Exe <ruta>` o variable `AHK2EXE`) y `npm install` dentro de `panel/`.
El instalador es por usuario (no pide administrador) y no está firmado: Windows SmartScreen avisará al ejecutarlo hasta que se firme con un certificado de código.

## Licencia
Zonely es software libre bajo la **GNU GPL, versión 2** (ver `LICENSE`). Puedes usarlo, estudiarlo, modificarlo y compartirlo; si distribuyes una versión modificada, debes publicarla con el código fuente bajo la misma licencia. Las licencias de los componentes de terceros están en `THIRD_PARTY.md`.
