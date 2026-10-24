# Zonely

**Your screen. Your way.** · [Read in English](README.md)

Zonely divide un monitor grande en **zonas** independientes y coloca tus ventanas en ellas: el juego a la izquierda, y Discord, el navegador u OBS a la derecha, como si tuvieras dos monitores. Pensado para pantallas ultrawide, pero sirve con cualquier monitor: la primera vez, Zonely calcula los perfiles para tu monitor principal y después puedes editar las zonas.

![Panel de control de Zonely](manual/img/panel.png)

> **Estado:** solo Windows por ahora. Software joven, que su autor usa a diario: puede tener asperezas. Las incidencias y los *pull requests* son bienvenidos.

## Qué hace
- **Zonas y perfiles** — «ultrawide» (3440 + 1680), «dual» (2560 + 2560), «centrado» (16:9 en el centro y una zona a cada lado) y «normal» (sin zonas: Zonely no toca tus ventanas). Las zonas se editan en el panel.
- **Selector de perfiles** (`Win+Alt+P`) con un aviso breve al cambiar.
- **Encajar arrastrando** — mantén `Shift` mientras arrastras una ventana y suéltala sobre una zona (mitades arriba/abajo opcionales).
- **Vigilante de maximizado** — una ventana maximizada a todo el monitor vuelve a su zona (con lista de exclusiones).
- **Recuperar tamaño** — si sacas una ventana de su zona, recupera su tamaño original.
- **Modo juego** — ventana sin bordes en la zona que elijas, o conserva el tamaño del juego y lo centra.
- **Capa oscura** — oscurece la otra zona (negro puro: píxeles apagados en un OLED) sin bloquear el ratón.
- **Lista de juegos** — los procesos de `Games=` (Rainbow Six Siege por defecto) nunca se mueven ni se redimensionan solos.
- Todos los atajos se pueden cambiar desde el panel.

<p>
<img src="manual/img/selector.png" alt="Selector de perfiles" width="46%">
<img src="manual/img/atajos.png" alt="Atajos" width="46%">
</p>

## Instalar (Windows 10/11)
1. Descarga `Zonely-Setup-<versión>.exe` desde la página de [Releases](../../releases) y ejecútalo.
2. Windows puede mostrar «Windows protegió su PC»: pulsa **Más información → Ejecutar de todas formas**. El instalador **aún no está firmado** (los certificados cuestan dinero), por eso SmartScreen avisa de editor desconocido. Puedes comprobar el SHA-256 que figura en las notas de la versión.
3. Sigue el asistente. Al terminar arranca el motor (también arranca con Windows) y se abre el panel.

Tus ajustes viven en `%APPDATA%\Zonely` (`zones.ini`, registros): actualizar o reinstalar nunca los pisa, y desinstalar tampoco los borra.

La guía ilustrada completa está en [`manual/index.html`](manual/index.html) y tras el botón **Manual** del panel.

## Atajos de fábrica
| Atajo | Acción |
|---|---|
| `Win+Alt+Z` | Llenar la zona actual |
| `Win+Alt+←` / `→` | Mover a la zona de la izquierda / derecha |
| `Win+Alt+↑` / `↓` | Mitad superior / inferior (zona B) |
| `Shift` + arrastrar | Encajar en una zona |
| `Win+Alt+G` | Modo juego (sin bordes en la zona) / restaurar |
| `Win+Alt+Mayús+G` | Modo juego conservando el tamaño interior |
| `Win+Alt+Mayús+←` / `→` | Centrar en la zona A / B sin cambiar el tamaño |
| `Win+Alt+Retroceso` | Deshacer la última colocación |
| `Win+Alt+Q` | Devolver la ventana a su tamaño original |
| `Win+Alt+P` | Elegir perfil |
| `Win+Alt+W` | Activar/desactivar el vigilante |
| `Win+Alt+O` | Capa oscura sobre la zona que no está activa |
| `Win+Alt+D` | Ventana de depuración de la ventana activa |

## Cómo funciona
Dos piezas que hablan por dos ficheros pequeños (sin red):
- el **motor** — un script de [AutoHotkey v2](https://www.autohotkey.com/) (compilado a `ZonelyEngine.exe` en el instalador) que mueve las ventanas, escucha los atajos y trabaja en segundo plano;
- el **panel** — una app [Electron](https://www.electronjs.org/) para ver el estado y cambiar ajustes. Se puede cerrar: el motor sigue funcionando.

## Limitaciones
- Los juegos en **pantalla completa exclusiva** deciden su propio tamaño; Zonely no puede meterlos en una zona. Usa el modo *sin bordes* o *ventana* del juego.
- El **anti-cheat estricto** (Vanguard, FACEIT, BattlEye en algunos juegos…) puede bloquear cualquier cambio en la ventana del juego. Zonely no intenta saltárselo.
- Las ventanas de programas ejecutados **como administrador** no se pueden mover si el motor no está elevado.

## Ejecutar desde el código
Necesitas [AutoHotkey v2](https://www.autohotkey.com/) y [Node.js](https://nodejs.org/).

```bash
cd panel
npm install
npm start
```

Después, doble clic en `ZoneManager.ahk` para lanzar el motor (o el botón **Iniciar motor** del panel).

## Construir el instalador
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1 -Ahk2Exe C:\ruta\Ahk2Exe.exe
```
Compila el motor con [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases) y lo empaqueta todo con electron-builder en `dist\installer\`. Requiere AutoHotkey v2 y `npm install` dentro de `panel/`. El historial de cambios está en [`CHANGELOG.md`](CHANGELOG.md).

## Licencia
Zonely es software libre bajo la **GNU GPL, versión 2** ([`LICENSE`](LICENSE)). Puedes usarlo, estudiarlo, modificarlo y compartirlo; si distribuyes una versión modificada, debes publicarla con su código fuente bajo la misma licencia. El motor lleva dentro el intérprete de AutoHotkey (GPL v2), y por eso todo el proyecto usa esa licencia. Las licencias de terceros están en [`THIRD_PARTY.md`](THIRD_PARTY.md).
