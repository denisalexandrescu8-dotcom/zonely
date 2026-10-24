import AppKit
import ZonelyCore

/// Aplicación de barra de menús (sin icono en el Dock): el icono de Zonely y un menú con lo básico.
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let engine = Engine()
    private var statusItem: NSStatusItem?
    private var pauseItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine.onConfigLoaded = { [weak self] in self?.applyMenuBarVisibility() }
        engine.start()
        buildMenu()
        applyMenuBarVisibility()
    }

    /// Ajustes → Barra de menús: muestra u oculta el icono sin parar el motor (los atajos siguen funcionando).
    private func applyMenuBarVisibility() {
        statusItem?.isVisible = engine.config?.menuBarIcon ?? true
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
        let open = NSMenuItem(title: "Abrir Zonely", action: #selector(openPanel(_:)), keyEquivalent: "")
        open.target = self
        menu.addItem(open)
        menu.addItem(.separator())

        // Perfiles: el submenú se rellena cada vez que se abre (ver menuNeedsUpdate), así siempre refleja zones.ini.
        let profilesItem = NSMenuItem(title: "Perfiles", action: nil, keyEquivalent: "")
        let profilesMenu = NSMenu(title: "Perfiles")
        profilesMenu.delegate = self
        profilesItem.submenu = profilesMenu
        menu.addItem(profilesItem)
        menu.addItem(.separator())

        let pause = NSMenuItem(title: "Pausar atajos", action: #selector(togglePause(_:)), keyEquivalent: "")
        pause.target = self
        menu.addItem(pause)
        pauseItem = pause

        let login = NSMenuItem(title: "Abrir al iniciar sesión", action: #selector(toggleLoginItem(_:)), keyEquivalent: "")
        login.target = self
        login.state = LoginItem.isEnabled() ? .on : .off
        menu.addItem(login)

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

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Perfiles" else { return }
        menu.removeAllItems()
        for profile in engine.config?.profiles ?? [] {
            let item = NSMenuItem(title: profile.name, action: #selector(pickProfile(_:)), keyEquivalent: "")
            item.target = self
            item.state = profile.name == engine.currentProfileName ? .on : .off
            menu.addItem(item)
        }
    }

    @objc private func pickProfile(_ sender: NSMenuItem) {
        engine.setProfile(sender.title, origin: "selector")      // «selector»: enseña el aviso de perfil aplicado
    }

    /// Abre (o trae al frente) el panel: la aplicación Zonely.app que contiene este motor.
    @objc private func openPanel(_ sender: NSMenuItem) {
        guard let executable = Bundle.main.executablePath, let range = executable.range(of: ".app/") else {
            Hud.showText("Abre Zonely desde la carpeta Aplicaciones")
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: String(executable[..<range.upperBound])))
    }

    @objc private func togglePause(_ sender: NSMenuItem) {
        engine.paused.toggle()
        sender.state = engine.paused ? .on : .off
        statusItem?.button?.toolTip = engine.paused ? "Zonely (atajos en pausa)" : "Zonely"
    }

    @objc private func toggleLoginItem(_ sender: NSMenuItem) {
        if LoginItem.isEnabled() {
            LoginItem.disable()
        } else if let executable = Bundle.main.executablePath {
            LoginItem.enable(executable: executable)
        }
        sender.state = LoginItem.isEnabled() ? .on : .off
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
