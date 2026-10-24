# Historial de versiones

## 0.31.0
- **Manual rehecho** con la interfaz nueva: capturas nuevas del panel (con datos de ejemplo), selector de perfiles y aviso, sección de instalación, carpeta de datos `%APPDATA%\Zonely` y la lista de juegos `Games=`. Se quitan el registro y la depuración del panel, que ya no se ven en la versión instalada.
- **Licencia GPL-2.0** (`LICENSE`) y `THIRD_PARTY.md` con las licencias de los componentes que se usan.
- **Cambio:** el icono de la aplicación pasa a `assets/zonely.ico`.

## 0.30.0
- **Nuevo:** instalador de Windows (`dist/installer/Zonely-Setup-<versión>.exe`, ~116 MB). Instala por usuario (sin administrador), compila el motor a `ZonelyEngine.exe` (no hace falta tener AutoHotkey), crea los accesos «Zonely» en el menú Inicio y el escritorio, arranca el motor con Windows y quita los accesos antiguos de «Gestor de zonas». Los datos de `%APPDATA%\Zonely` no se borran al desinstalar. Se genera con `scripts/build-installer.ps1`.
- En la versión instalada el panel arranca el motor compilado y no se ve el apartado Registro.

## 0.29.0
- **Cambio:** los datos del usuario (`zones.ini`, registro e ipc) pasan a `%APPDATA%\Zonely`, fuera de la carpeta de la aplicación, para que actualizar o reinstalar nunca los pise. En el primer arranque se copia el `zones.ini` de la carpeta de la aplicación (la configuración de fábrica o la que ya tenías). El `zones.ini` de la carpeta del proyecto queda solo como plantilla. `ZONELY_DATA` cambia la carpeta (pruebas).
- **Cambio:** el apartado **Registro** (registro de actividad y depuración) solo aparece en desarrollo; en la versión instalada no se ve. `ZONELY_DEV=1` lo fuerza.

## 0.28.0
- **Cambio:** esquinas mucho más redondeadas, al estilo Apple. En el panel, tarjetas de 24 px, miniaturas, botones, campos y filas con radios mayores y esquinas continuas («squircle»); las cápsulas y los interruptores siguen siendo redondos. En el selector de Win+Alt+P y el aviso de perfil, filas de 20 px, botones, miniaturas y zonas con esquinas más suaves (cada zona como una pequeña baldosa).

## 0.27.0
- **Cambio:** vuelve la barra de desplazamiento del panel, ahora con el estilo de la app: fina, con el pulgar redondeado y flotando sin tocar el borde, en gris azulado oscuro y azul al pasar el ratón. Se aplica también a las barras internas (registro).

## 0.26.0
- **Cambio:** el selector de Win+Alt+P y el aviso de cambio de perfil se parecen más al panel: las miniaturas son las mismas (fondo casi negro, cada zona con relleno translúcido, borde y letra de su color), y las filas, los botones y el icono tienen las esquinas redondeadas. El perfil «Normal» se dibuja como zona A completa, como en el panel.

## 0.25.0
- **Nuevo:** al cambiar de perfil con Win+Alt+P aparece un aviso breve («Perfil aplicado» + miniatura y nombre) abajo en el centro; no roba el foco, deja pasar el ratón y se desvanece solo en unos 2 segundos.
- **Cambio:** la barra de desplazamiento principal del panel se oculta (se sigue desplazando con la rueda y el teclado); las internas, como la del registro, son finas y oscuras.
- **Nuevo:** la tipografía Inter va incluida con el panel (`panel/fonts/`, licencia SIL OFL), así que ya no depende de que esté instalada.

## 0.24.0
- **Arreglo:** el selector de perfiles (Win+Alt+P) de la 0.21 no respondía a los clics: un fondo del tamaño de toda la ventana quedaba por encima de las filas y se comía todos los clics. Ahora el fondo es el de la propia ventana (el borde de 1 px lo dibuja Windows).
- **Cambio:** la aplicación pasa a llamarse **Zonely** (panel, bandeja, avisos, manual de uso, README y accesos directos; el desinstalador también quita los antiguos «Gestor de zonas»).
- **Cambio:** paleta de marca en el panel, el selector, el encaje con Shift y el manual (A azul `#3B82F6`, B violeta `#8B5CF6`, C rosa `#F472B6`), logotipo de tres bloques en la barra lateral y lema «Your screen. Your way.». Los accesos directos usan el icono de Zonely.

## 0.23.0
- **Cambio:** el icono de la bandeja del sistema es ahora el de Zonely (tres bloques) en lugar de la «H» verde de AutoHotkey, y al pasar el ratón muestra «Zonely». La ventana del panel usa el mismo icono.
- **Nuevo:** `assets/zonely.ico` (16–256 px) y el script `scripts/make-icon.ps1` que lo genera.

## 0.22.0
- **Cambio:** las ventanas colocadas en una zona quedan pegadas al borde superior: se oculta la línea de 1 px que Windows 11 dibuja alrededor de la ventana (se recupera al devolverla a su tamaño original, al deshacer o al salir del modo juego).

## 0.21.0
- **Cambio:** el selector de perfiles (Win+Alt+P) se rediseña: ventana redondeada sin barra de título, una fila por perfil con su miniatura, el reparto en px y en %, botón «Aplicar»/«Aplicado» y marca «Activo ahora». Se cierra con Esc o con la X.
- **Cambio:** la pestaña Ajustes pasa a tarjetas de dos columnas con filas icono · texto · interruptor. Las opciones del panel derecho (vigilante, encaje con Shift, elegir mitades, recuperar tamaño) se mueven a la tarjeta «Comportamiento de ventanas»; la vista Zonas ocupa todo el ancho.

## 0.20.0
- **Cambio:** el panel se rediseña con barra lateral (Zonas, Atajos, Ajustes, Registro), cabecera con el estado del motor y un panel derecho con las opciones rápidas (vigilante, encaje con Shift, elegir mitades, recuperar tamaño). Mismas funciones que antes, repartidas por vistas, con acento azul y ventana más grande por defecto (1280×800).

## 0.19.0
- **Nuevo:** animaciones sutiles en el panel: las secciones aparecen escalonadas, las tarjetas de perfil reaccionan al pasar el ratón y al pulsar, los interruptores rebotan al cambiar, el punto de «Motor activo» respira, las zonas del monitor destellan al cambiar de perfil y la fila de un atajo parpadea en verde al guardarlo. Se desactivan solas si Windows tiene «reducir animaciones».

## 0.18.0
- **Nuevo:** lista de juegos (`Games=` en `[Exclusions]` de `zones.ini`, por defecto `RainbowSix.exe`) que el encaje con Shift, el vigilante y la restauración de tamaño ignoran por completo. Antes, un juego en marcha podía ser movido o redimensionado (p. ej. al cambiar de perfil) y perder la captura del ratón.

## 0.17.0
- **Nuevo:** Win+Alt+Q devuelve la ventana activa a su tamaño original (el que tenía antes de entrar en una zona), aunque se haya movido o redimensionado muchas veces. Se puede cambiar en la tarjeta de atajos.

## 0.16.0
- **Nuevo:** la zona del modo juego es configurable por perfil (tarjeta «Modo juego» del panel o `GameZone=A|B|C|auto` en `zones.ini`). Por defecto es «auto»: la zona en la que ya está la ventana.
- El selector de perfiles relee las zonas de `zones.ini` cada vez que se abre y se abre siempre en el centro de la pantalla; el panel también.

## 0.15.0
- **Nuevo:** perfil «centrado»: pantalla 16:9 (2560×1440) en el centro (zona A) y dos zonas laterales con lo que sobra (B a la derecha, C a la izquierda). Los perfiles pueden tener hasta tres zonas (`C=` opcional en `zones.ini`).
- **Cambio:** el selector de Win+Alt+P ahora son tarjetas con el dibujo de las zonas de cada perfil; un clic aplica el perfil al instante (ya no hay botón Aplicar).
- Win+Alt+Izq/Der y Mayús+Izq/Der pasan a «la zona vecina de la izquierda/derecha» (igual que antes con dos zonas). Encaje con Shift, capa oscura y panel (dibujo, tarjetas, botón de atenuar zona C) soportan la zona C.

## 0.14.0
- **Nuevo:** perfil «normal» (pantalla completa, sin zonas): sin atajos de colocación, encaje, vigilante ni capa oscura. Un perfil sin zona B en `zones.ini` se trata así.
- **Cambio:** Win+Alt+P abre un selector con la lista de perfiles (flechas + Intro, doble clic, Esc) en vez de ir rotando.
- Restaurar el tamaño original al salir de una zona es más rápido (comprobación cada 40 ms).

## 0.13.0
- **Nuevo:** tarjeta «Atajos de teclado» en el panel: cada atajo se puede cambiar (modificadores + tecla), restablecer o devolver todos a los de fábrica. Se guardan en `[Hotkeys]` de `zones.ini` y el motor se recarga solo.
- Los atajos ahora se registran dinámicamente desde `lib/Hotkeys.ahk`; los no válidos o duplicados vuelven al de fábrica con aviso en el registro y en el panel.
- Arreglo: ya no salta un error si la ventana se cierra a mitad de colocarla.

## 0.12.0
- **Simplificación:** se quitan del motor y del panel la ventana objetivo y la lista de ventanas, las capas por zona, la autocolocación (reglas), el bloqueo del cursor y los perfiles por juego. Se conservan zonas y perfiles, vigilante y exclusiones, encaje con Shift, modo juego, capa oscura, editor de zonas, depuración y registro.
- **Nuevo:** al salirse de una zona, la ventana recupera el tamaño que tenía antes de entrar (`[General] RestoreOnLeave`, interruptor «Al salir de una zona»).
- **Cambio:** al arrastrar con Shift, por defecto solo se puede elegir la zona izquierda o la derecha, enteras; elegir mitades pasa a ser opcional (`[Snap] Halves`, interruptor «Permitir elegir mitades»).
- Monitor virtual desinstalado del equipo y su código eliminado del proyecto (sigue en el historial de Git).
## 0.11.0
- Perfiles por juego (`games.txt`): al abrirse un juego se aplica su perfil de zonas, modo de ventana, bloqueo de cursor y atenuación; al cerrarlo se restaura todo. Botones «Jugar» y «Aplicar ahora», e importación de la biblioteca de Steam desde el panel.

## 0.10.0
- Bloqueo del cursor en la ventana de juego (Win+Alt+L, interruptor en el panel y opción automática con el modo juego); se libera al cambiar de ventana.
- Arreglo: los atajos Win+Alt+1..9 de las capas no se registraban (código situado tras la primera definición de atajo).
- Arreglo: «elegir ventana objetivo» desde el panel no tenía efecto en el motor.
- Los avisos del analizador de AutoHotkey ya no abren diálogos que bloquean el arranque.

## 0.9.0
- Modo juego «conservar tamaño» (Win+Alt+Mayús+G): quita bordes sin cambiar el tamaño interior del juego y lo centra en la zona A. Para juegos como Rainbow Six Siege en ventana a 2560x1440.

## 0.8.0
- Centrar una ventana en una zona sin cambiar su tamaño (Win+Alt+Mayús+←/→ y botones del panel), para juegos como Rainbow Six Siege que no admiten el tamaño de la zona.

## 0.7.0
- Deshacer la última colocación: Win+Alt+Retroceso y botón en el panel.
- El modo juego conserva su estado al recargar el motor y se restaura al salir de él.

## 0.6.0
- Registro de actividad y errores (`logs/gestor.log`), visible en el panel.
- Número de versión en el panel y el motor.
- Aviso en el registro cuando una ventana no respeta el tamaño de su zona.

## 0.5.0
- Manual de uso con gráficos (`manual/index.html`) y botón «Manual» en el panel.
- Arranque con Windows (`scripts/install-startup.ps1`).
- Capas por zona (Win+Alt+1..9), autocolocación (`rules.txt`) y capa oscura (Win+Alt+O).

## 0.4.0
- Panel de control (Electron): zonas, perfiles, ventana objetivo, lista de ventanas, depuración.
- Encaje arrastrando con Shift.

## 0.1.0 – 0.3.0
- Motor AutoHotkey: zonas desde `zones.ini`, atajos, modo juego, vigilante de maximizado, depuración y bandeja.
