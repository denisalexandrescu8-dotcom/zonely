# Manual de Zonely

Zonely divide un monitor en zonas para colocar y ordenar ventanas. Este manual está en GitHub para consultarlo desde cualquier navegador; el panel de escritorio se centra en las zonas, los atajos y los ajustes.

- [Descargar la última versión](https://github.com/denisalexandrescu8-dotcom/zonely/releases/latest)
- [Avisar de un problema o pedir una mejora](https://github.com/denisalexandrescu8-dotcom/zonely/issues)

## Primeros pasos

### Windows 10 y 11

1. Descarga `Zonely-Setup-<versión>.exe` desde [Releases](https://github.com/denisalexandrescu8-dotcom/zonely/releases/latest) y ejecuta el instalador.
2. El instalador no está firmado. Si SmartScreen muestra «Windows protegió su PC», elige **Más información → Ejecutar de todas formas**.
3. Al terminar, Zonely inicia el motor y abre el panel. El motor puede seguir funcionando aunque cierres el panel.

### macOS con Apple Silicon

La forma sencilla es abrir Terminal y ejecutar el instalador oficial:

```bash
curl -fsSL https://raw.githubusercontent.com/denisalexandrescu8-dotcom/zonely/main/scripts/install-mac.sh | bash
```

El script descarga la versión más reciente, comprueba su SHA-256 y copia Zonely a Aplicaciones. También puedes descargar el `.dmg` desde [Releases](https://github.com/denisalexandrescu8-dotcom/zonely/releases/latest) y arrastrar Zonely a Aplicaciones.

El `.dmg` no está notarizado. Si macOS lo bloquea, abre **Ajustes del Sistema → Privacidad y seguridad** y permite abrir Zonely. Para mover y redimensionar ventanas de otras aplicaciones, concede a **ZonelyEngine** el permiso de **Accesibilidad**. El acceso a ese panel también está disponible desde el icono de Zonely en la barra de menús.

## Colocar tu primera ventana

1. En **Zonas**, elige el monitor en la esquina inferior izquierda.
2. Selecciona un perfil. `Ultrawide` deja una zona ancha y otra lateral; `Dual` divide el monitor en dos; `Centrado` sitúa una zona 16:9 entre dos laterales; `Normal` desactiva las zonas.
3. Selecciona una ventana y usa uno de los atajos de movimiento que aparecen en **Atajos**. También puedes mantener la tecla de encaje mientras arrastras la ventana hasta una zona.
4. Para que Zonely deje de organizar las ventanas de ese monitor, selecciona el perfil `Normal`.

Los perfiles se guardan por monitor. En **Zonas → Editar**, puedes ajustar las divisiones, crear perfiles, duplicarlos, cambiarles el nombre y eliminarlos. La vista previa muestra el tamaño de cada zona. El ajuste **Modo juego** permite elegir una zona distinta para cada perfil.

## Mover ventanas

### Atajos

Los atajos se pueden cambiar en **Atajos**. De fábrica usan `Win+Alt` en Windows y `Control+Opción` (`⌃⌥`) en macOS. Las acciones de zona izquierda/derecha avanzan entre las zonas disponibles. Las acciones de mitad superior/inferior usan la zona derecha (zona B).

| Acción | Windows | macOS |
|---|---|---|
| Llenar la zona actual | `Win+Alt+Z` | `⌃⌥Z` |
| Mover a la zona izquierda / derecha | `Win+Alt+←` / `→` | `⌃⌥←` / `→` |
| Mitad superior / inferior de la zona B | `Win+Alt+↑` / `↓` | `⌃⌥↑` / `↓` |
| Modo juego: llenar la zona elegida | `Win+Alt+G` | `⌃⌥G` |
| Modo juego: conservar el tamaño | `Win+Alt+Mayús+G` | `⌃⌥⇧G` |
| Centrar en una zona sin cambiar el tamaño | `Win+Alt+Mayús+←` / `→` | `⌃⌥⇧←` / `→` |
| Deshacer la última colocación | `Win+Alt+Retroceso` | `⌃⌥⌫` |
| Recuperar el tamaño original | `Win+Alt+Q` | `⌃⌥Q` |
| Elegir un perfil | `Win+Alt+P` | `⌃⌥P` |
| Activar o desactivar el vigilante | `Win+Alt+W` | `⌃⌥W` |
| Alternar la capa oscura | `Win+Alt+O` | `⌃⌥O` |
| Depurar la ventana activa | `Win+Alt+D` | — |

### Encajar al arrastrar

En **Ajustes → Comportamiento de ventanas**, activa **Encajar arrastrando** y elige `Shift`, `Ctrl` o `Alt` (`Opción` en Mac). Mantén esa tecla mientras arrastras una ventana y suéltala sobre la zona deseada. **Elegir mitades** permite soltar arriba o abajo en la zona B; si está apagado, se coloca en la zona entera.

### Recuperar y deshacer

Con **Recuperar tamaño** activado, Zonely devuelve la ventana a su tamaño anterior cuando la sacas de una zona. **Deshacer** revierte la última colocación. Los cambios hechos con el ratón al redimensionar una ventana se conservan como su tamaño personal.

## Ajustes

- **Idioma:** cambia el idioma del panel, de los avisos y de los menús. En modo automático se usa el idioma del sistema.
- **Vigilante:** cuando una ventana de una zona se maximiza para ocupar todo el monitor, intenta devolverla a su zona. Puedes excluir procesos o clases de ventana para que se maximicen libremente.
- **Animar al colocar:** suaviza el movimiento hacia la zona. Se desactiva cuando el sistema tiene activada la opción de reducir movimiento.
- **Barra de menús (macOS):** muestra u oculta el icono de Zonely en la barra de menús. Los atajos continúan disponibles aunque se oculte.
- **Modo juego:** elige por perfil la zona a usar o deja `Auto` para respetar la zona donde ya está la ventana. En Windows el modo juego puede quitar los bordes; macOS conserva los bordes de las aplicaciones.
- **Lista de juegos:** los procesos de `Games=` en `zones.ini` quedan fuera del encaje automático, del vigilante y de la recuperación de tamaño. Por defecto, la lista incluye `RainbowSix.exe`; edítala si quieres añadir o quitar juegos.
- **Capa oscura:** atenúa las zonas que no están activas con negro ajustable. No bloquea el ratón; en una pantalla OLED, el negro puede apagar esos píxeles.
- **Actualizaciones:** Zonely busca versiones nuevas y, por defecto, las instala en segundo plano. Si desactivas la actualización automática, te pregunta antes de instalar. **Buscar ahora** inicia una comprobación inmediata.

## Solución de problemas

- **Un atajo no responde:** confirma que el motor esté activo, revisa el atajo en **Atajos** y comprueba que otra aplicación o el sistema no lo esté usando.
- **Una ventana no se mueve en Mac:** concede a `ZonelyEngine` permiso de Accesibilidad en Ajustes del Sistema y vuelve a abrir el panel si macOS lo solicita.
- **Una ventana no se mueve en Windows:** una aplicación ejecutada como administrador puede requerir que Zonely también se ejecute con privilegios de administrador.
- **El vigilante corrige una aplicación que no quieres limitar:** añade su proceso o clase a **Ajustes → Exclusiones del vigilante**. En Windows, `Win+Alt+D` muestra datos de la ventana activa.
- **Un juego no encaja:** prueba el modo ventana o ventana sin bordes. Los juegos en pantalla completa exclusiva controlan su propio modo de visualización; ciertos sistemas anti-cheat también pueden impedir cambios en la ventana.
- **Necesitas compartir un problema:** abre la vista **Registro**, copia el registro y adjúntalo al crear un [issue](https://github.com/denisalexandrescu8-dotcom/zonely/issues). El registro puede contener nombres de procesos y ventanas.

## Datos y configuración

Zonely mantiene los ajustes y los registros fuera de la carpeta de instalación, así que actualizar o reinstalar no los elimina.

- **Windows:** `%APPDATA%\Zonely` (normalmente `C:\Users\<usuario>\AppData\Roaming\Zonely`).
- **macOS:** `~/Library/Application Support/Zonely`.

`zones.ini` guarda perfiles, monitor, opciones y atajos. La mayoría de estos ajustes se editan desde el panel. La lista de cambios está en [`CHANGELOG.md`](../CHANGELOG.md) y el código fuente en el [repositorio de Zonely](https://github.com/denisalexandrescu8-dotcom/zonely).
