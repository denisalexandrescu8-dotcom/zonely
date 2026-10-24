import AppKit
import ZonelyCore

/// Aplicación de barra de menús (sin icono en el Dock): el icono de Zonely y un menú con lo básico.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let engine = Engine()
    private var statusItem: NSStatusItem?
    private var pauseItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.start()
        buildMenu()
    }

    private func buildMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = NSImage(systemSymbolName: "rectangle.split.2x1", accessibilityDescription: "Zonely") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "Z"
            }
            button.toolTip = "Zonely"
        }

        let menu = NSMenu()
        let title = NSMenuItem(title: "Zonely \(Paths.appVersion())", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pausar atajos", action: #selector(togglePause(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        pauseItem = pause

        let reload = NSMenuItem(title: "Recargar zones.ini", action: #selector(reload(_:)), keyEquivalent: "")
        reload.target = self
        menu.addItem(reload)

        let access = NSMenuItem(title: "Permiso de Accesibilidad…", action: #selector(openAccessibility(_:)), keyEquivalent: "")
        access.target = self
        menu.addItem(access)

        let folder = NSMenuItem(title: "Abrir carpeta de datos", action: #selector(openDataFolder(_:)), keyEquivalent: "")
        folder.target = self
        menu.addItem(folder)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Salir", action: #selector(quit(_:)), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        item.menu = menu
        statusItem = item
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        engine.paused.toggle()
        sender.state = engine.paused ? .on : .off
        statusItem?.button?.toolTip = engine.paused ? "Zonely (atajos en pausa)" : "Zonely"
    }

    @objc private func reload(_ sender: NSMenuItem) {
        engine.reloadConfig()
    }

    @objc private func openAccessibility(_ sender: NSMenuItem) {
        if !Accessibility.isTrusted(prompt: true) { Accessibility.openSettings() }
    }

    @objc private func openDataFolder(_ sender: NSMenuItem) {
        NSWorkspace.shared.open(Paths.dataDir)
    }

    @objc private func quit(_ sender: NSMenuItem) {
        Log.write("Motor detenido (Salir)")
        NSApp.terminate(nil)
    }
}
