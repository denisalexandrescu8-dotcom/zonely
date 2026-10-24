import AppKit
import ZonelyCore

/// Encajar arrastrando: mientras arrastras una ventana y mantienes la tecla (Mayús por defecto) se dibujan las zonas;
/// al soltar, la ventana encaja en la resaltada. Detección por sondeo cada 30 ms: no instala ningún gancho de ratón.
final class SnapController {
    private unowned let engine: Engine
    private unowned let windows: WindowManager
    private var timer: Timer?

    private var wasDown = false
    private var window: ForeignWindow?
    private var startOrigin = CGPoint.zero
    private var dragging = false
    private var target: (zone: String, rect: CGRect)?
    private var zonePanels: [String: NSPanel] = [:]
    private var highlight: NSPanel?

    init(engine: Engine, windows: WindowManager) {
        self.engine = engine
        self.windows = windows
    }

    func start() {
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)           // también mientras el ratón arrastra
        timer = t
    }

    private var snapFlag: NSEvent.ModifierFlags {
        switch engine.config?.snapKey ?? "Shift" {
        case "Ctrl": return .control
        case "Alt": return .option
        default: return .shift
        }
    }

    private func tick() {
        guard engine.state.snap, !engine.state.paused, engine.config != nil, Accessibility.isTrusted(prompt: false) else {
            if wasDown || window != nil { reset() }
            return
        }
        let down = NSEvent.pressedMouseButtons & 1 != 0
        if down && !wasDown {
            begin()
        } else if down && window != nil {
            drag()
        } else if !down && wasDown {
            end()
        }
        wasDown = down
    }

    /// Botón recién pulsado: se mira qué ventana hay debajo del cursor.
    private func begin() {
        dragging = false
        window = nil
        guard engine.config?.profile(named: engine.state.profile)?.isZoned == true,
              let found = Accessibility.window(at: Screens.mouse), !windows.isGame(found), let frame = found.frame else { return }
        window = found
        startOrigin = frame.origin
    }

    /// Botón mantenido: si la ventana se ha movido es un arrastre; con la tecla pulsada se enseñan las zonas.
    private func drag() {
        guard let window = window, let frame = window.frame else { reset(); return }
        if !dragging, abs(frame.minX - startOrigin.x) > 6 || abs(frame.minY - startOrigin.y) > 6 { dragging = true }
        guard dragging else { return }
        if NSEvent.modifierFlags.contains(snapFlag) { updateOverlay() } else { hideOverlay() }
    }

    /// Botón soltado: si se estaba enseñando una zona, la ventana encaja en ella.
    private func end() {
        if dragging, let window = window, let target = target { windows.snap(window, to: target.rect) }
        reset()
    }

    private func reset() {
        hideOverlay()
        wasDown = false
        window = nil
        dragging = false
        target = nil
    }

    // MARK: - Zonas dibujadas

    private func updateOverlay() {
        guard let config = engine.config, let profile = config.profile(named: engine.state.profile) else { return }
        guard Screens.onSelected(Screens.mouse) else {          // el cursor está en otra pantalla: nada que encajar
            hideOverlay()
            target = nil
            return
        }
        let usable = Screens.usable
        target = Geometry.snapTarget(at: Screens.mouse, profile: profile, monitorWidth: config.monitorWidth,
                                     monitorHeight: config.monitorHeight, usable: usable, halves: config.snapHalves)
        for zone in profile.zones.values {
            let panel: NSPanel
            if let existing = zonePanels[zone.name] {
                panel = existing
            } else {
                panel = Overlay.makePanel(color: Palette.zone(zone.name).withAlphaComponent(0.18))
                zonePanels[zone.name] = panel
            }
            Overlay.place(panel, axRect: Geometry.rect(of: zone, monitorWidth: config.monitorWidth,
                                                       monitorHeight: config.monitorHeight, in: usable))
        }
        for (name, panel) in zonePanels where profile.zones[name] == nil { panel.orderOut(nil) }
        if let target = target {
            let panel = highlight ?? Overlay.makePanel(color: NSColor.white.withAlphaComponent(0.32))
            highlight = panel
            Overlay.place(panel, axRect: target.rect)
        }
    }

    private func hideOverlay() {
        for panel in zonePanels.values { panel.orderOut(nil) }
        highlight?.orderOut(nil)
    }
}
