# Zonely

**Your screen. Your way.** · [Leer en español](README.es.md)

Zonely splits a big monitor into independent **zones** and puts your windows in them: the game on the left, Discord, a browser or OBS on the right — as if you had two monitors. Built for ultrawide screens, but it works on any monitor: on first run Zonely calculates the profiles for your primary monitor, and you can edit the zones afterwards.

![Zonely control panel](manual/img/panel.png)

> **Status:** Windows is the mature version; the **macOS (Apple Silicon) version is brand new and experimental**. Early software — expect rough edges. Issues and pull requests are welcome.

## Features
- **Several monitors** — choose which one the zones apply to (Monitor selected, bottom-left of the panel).
- **Zones and profiles** — «ultrawide» (3440 + 1680), «dual» (2560 + 2560), «centrado» (16:9 in the middle with a zone on each side) and «normal» (no zones: Zonely leaves your windows alone). Edit the zones in the panel.
- **Profile picker** (`Win+Alt+P`) with a small confirmation toast when you switch.
- **Snap by dragging** — hold `Shift` while dragging a window and drop it on a zone (optional top/bottom halves).
- **Maximize watcher** — a window maximized across the whole monitor goes back to its zone (with an exclusion list).
- **Restore on leave** — take a window out of a zone and it gets its original size back.
- **Game mode** — borderless window in the zone you choose, or keep the game's own size and center it.
- **Dim layer** — darkens the other zone (pure black: pixels off on an OLED) without blocking the mouse.
- **Games list** — processes in `Games=` (Rainbow Six Siege by default) are never moved or resized automatically.
- Every shortcut can be changed in the panel.

<p>
<img src="manual/img/selector.png" alt="Profile picker" width="46%">
<img src="manual/img/atajos.png" alt="Shortcuts" width="46%">
</p>

## Install (Windows 10/11)
1. Download `Zonely-Setup-<version>.exe` from the [Releases](../../releases) page and run it.
2. Windows may show «Windows protected your PC»: click **More info → Run anyway**. The installer is **not code-signed** yet (certificates cost money), so SmartScreen warns about unknown publishers. You can check the SHA-256 listed in the release notes.
3. Follow the wizard. When it finishes, the engine starts (it also starts with Windows) and the panel opens.

Your settings live in `%APPDATA%\Zonely` (`zones.ini`, logs), so updating or reinstalling never overwrites them. Uninstalling does not delete them either.

**Updates:** Zonely updates itself. A few minutes after it starts, and then every 6 hours, the engine launches a window-less check in the background: if there is a new version on GitHub it downloads it, verifies its SHA-256, installs it and restarts the engine, without asking or showing anything (on macOS it replaces `Zonely.app`, and macOS may ask for the Accessibility permission again). You can turn this off in *Settings → Updates → Update automatically*; then Zonely shows a question when there is a new version (once per version). The *Check now* button is always there. There is no «reload» button to press: changes to `zones.ini` are picked up automatically.

A full illustrated guide (Spanish for now) is in [`manual/index.html`](manual/index.html) and in the **Manual** section of the panel.

## Install (macOS, Apple Silicon)
1. **Easiest, with no security warning:** paste this in Terminal. It downloads the latest release with `curl`, checks its SHA-256 and copies Zonely to Applications. Files downloaded with `curl` are not flagged as «quarantined», so macOS opens the app straight away (you can read the script first: [`scripts/install-mac.sh`](scripts/install-mac.sh)).
   ```bash
   curl -fsSL https://raw.githubusercontent.com/denisalexandrescu8-dotcom/zonely/main/scripts/install-mac.sh | bash
   ```
   Or download `Zonely-<version>-mac-arm64.dmg` from [Releases](../../releases), open it and drag **Zonely** to Applications.
2. If you used the `.dmg` from the browser: the app is **not notarized** (that needs a paid Apple Developer account), so macOS blocks it the first time. Open **System Settings → Privacy & Security**, scroll down to the message about Zonely and click **Open Anyway**.
3. Zonely needs the **Accessibility** permission to move other apps' windows: System Settings → Privacy & Security → Accessibility → enable *ZonelyEngine*. The menu-bar icon has a shortcut to that pane.
4. Shortcuts on macOS are **⌃⌥ + key** (e.g. ⌃⌥Z), editable in the panel. Game mode fills the zone (macOS cannot remove another app's window borders). Settings live in `~/Library/Application Support/Zonely`.

There is a macOS user guide in [`manual/mac.html`](manual/mac.html) (Spanish for now), also in the **Manual** section of the panel.

## Default shortcuts (macOS)
| Shortcut | Action |
|---|---|
| `⌃⌥Z` | Fill the current zone |
| `⌃⌥←` / `→` | Move to the left / right zone |
| `⌃⌥↑` / `↓` | Top / bottom half (zone B) |
| `⇧` + drag | Snap to a zone |
| `⌃⌥G` | Game mode (fill the game zone) / restore |
| `⌃⌥⇧G` | Game mode keeping the window's size |
| `⌃⌥⇧←` / `→` | Center in the left / right zone without resizing |
| `⌃⌥⌫` | Undo the last placement |
| `⌃⌥Q` | Back to the window's original size |
| `⌃⌥P` | Profile picker |
| `⌃⌥W` | Toggle the maximize watcher |
| `⌃⌥O` | Dim the zones that are not active |

## Default shortcuts (Windows)
| Shortcut | Action |
|---|---|
| `Win+Alt+Z` | Fill the current zone |
| `Win+Alt+←` / `→` | Move to the left / right zone |
| `Win+Alt+↑` / `↓` | Top / bottom half (zone B) |
| `Shift` + drag | Snap to a zone |
| `Win+Alt+G` | Game mode (borderless in the zone) / restore |
| `Win+Alt+Shift+G` | Game mode keeping the window's inner size |
| `Win+Alt+Shift+←` / `→` | Center in zone A / B without resizing |
| `Win+Alt+Backspace` | Undo the last placement |
| `Win+Alt+Q` | Back to the window's original size |
| `Win+Alt+P` | Profile picker |
| `Win+Alt+W` | Toggle the maximize watcher |
| `Win+Alt+O` | Dim the zone that is not active |
| `Win+Alt+D` | Debug window for the active window |

## How it works
Two pieces talk through two small files (no network):
- the **engine** — an [AutoHotkey v2](https://www.autohotkey.com/) script (compiled to `ZonelyEngine.exe` in the installer) that moves windows, listens to shortcuts and runs in the background;
- the **panel** — an [Electron](https://www.electronjs.org/) app to see the state and change settings. You can close it; the engine keeps working.

## Limitations
- **Exclusive fullscreen** games decide their own size; Zonely cannot put them in a zone. Use *borderless* / *windowed* mode in the game.
- **Strict anti-cheat** (Vanguard, FACEIT, BattlEye in some games…) may block any change to a game window. Zonely does not try to bypass it.
- Windows of programs run **as administrator** cannot be moved unless the engine is elevated too.

## Run from source
You need [AutoHotkey v2](https://www.autohotkey.com/) and [Node.js](https://nodejs.org/).

```bash
cd panel
npm install
npm start
```

Then double-click `ZoneManager.ahk` to start the engine (or use the **Engine** switch in the panel's Settings).

## Build the installer
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-installer.ps1 -Ahk2Exe C:\path\to\Ahk2Exe.exe
```
It compiles the engine with [Ahk2Exe](https://github.com/AutoHotkey/Ahk2Exe/releases) and packages everything with electron-builder into `dist\installer\`. Needs AutoHotkey v2 and `npm install` inside `panel/`. See [`CHANGELOG.md`](CHANGELOG.md) for the history.

## License
Zonely is free software under the **GNU GPL v2** ([`LICENSE`](LICENSE)). You can use, study, modify and share it; if you distribute a modified version, you must publish it with its source code under the same license. The engine bundles the AutoHotkey interpreter (GPL v2), which is why the whole project uses that license. Third-party licenses are listed in [`THIRD_PARTY.md`](THIRD_PARTY.md).
