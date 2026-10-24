import AppKit
import ZonelyCore

/// Ventanas translúcidas que dejan pasar el ratón: sirven para la capa oscura y para las zonas del encaje.
enum Overlay {
    static func makePanel(color: NSColor) -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = color
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        return panel
    }

    /// Coloca el panel sobre un rectángulo dado en coordenadas de Accesibilidad.
    static func place(_ panel: NSPanel, axRect: CGRect) {
        panel.setFrame(Geometry.appKitRect(fromAX: axRect, primaryHeight: Screens.primaryHeight), display: true)
        panel.orderFrontRegardless()
    }
}

/// Capa oscura: un velo negro sobre las zonas indicadas (`state.dim`, p. ej. «B» o «A+C»), con la opacidad `state.dimLevel`.
final class DimController {
    private unowned let engine: Engine
    private var panels: [String: NSPanel] = [:]

    init(engine: Engine) {
        self.engine = engine
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            self?.update()
        }
    }

    func update() {
        guard let config = engine.config, let profile = config.profile(named: engine.state.profile), profile.isZoned else {
            hideAll()
            return
        }
        let wanted = engine.state.dim.split(separator: "+").map(String.init).filter { profile.zones[$0] != nil }
        for (name, panel) in panels where !wanted.contains(name) { panel.orderOut(nil) }
        let veil = NSColor.black.withAlphaComponent(CGFloat(engine.state.dimLevel) / 100)
        for name in wanted {
            guard let zone = profile.zones[name] else { continue }
            let panel: NSPanel
            if let existing = panels[name] {
                panel = existing
            } else {
                panel = Overlay.makePanel(color: veil)
                panels[name] = panel
            }
            panel.backgroundColor = veil
            Overlay.place(panel, axRect: Geometry.rect(of: zone, monitorWidth: config.monitorWidth,
                                                       monitorHeight: config.monitorHeight, in: Screens.usable))
        }
    }

    private func hideAll() {
        for panel in panels.values { panel.orderOut(nil) }
    }
}
