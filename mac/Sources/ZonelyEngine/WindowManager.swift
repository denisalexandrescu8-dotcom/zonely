import AppKit
import ZonelyCore

/// Coloca las ventanas en las zonas: el equivalente de lib/Zones.ahk, GameMode.ahk y Restore.ahk (a mano) en Windows.
final class WindowManager {
    private unowned let engine: Engine

    private struct Saved {
        let window: ForeignWindow
        let frame: CGRect
    }

    private var undoStack: [Saved] = []          // posiciones anteriores (máx. 20)
    private var originals: [Saved] = []          // tamaño que tenía cada ventana antes de entrar en una zona
    private var gameMode: [Saved] = []           // ventanas en «modo juego» y cómo estaban

    init(engine: Engine) {
        self.engine = engine
    }

    // MARK: - Acciones de los atajos

    /// Ejecuta la acción de un atajo (los ids son los mismos que en Windows).
    func perform(_ id: String) {
        switch id {
        case "ZoneMaximize": withWindow { w, f in self.place(w, self.rect(of: self.zoneName(of: f)), from: f) }
        case "MoveToA": withWindow { w, f in self.place(w, self.rect(of: self.neighbour(of: f, -1)), from: f) }
        case "MoveToB": withWindow { w, f in self.place(w, self.rect(of: self.neighbour(of: f, 1)), from: f) }
        case "HalfTop": withWindow { w, f in self.placeHalf(w, f, top: true) }
        case "HalfBottom": withWindow { w, f in self.placeHalf(w, f, top: false) }
        case "CenterA": withWindow { w, f in self.center(w, f, self.neighbour(of: f, -1)) }
        case "CenterB": withWindow { w, f in self.center(w, f, self.neighbour(of: f, 1)) }
        case "GameMode": withWindow { w, f in self.toggleGameMode(w, f, keepSize: false) }
        case "GameModeKeep": withWindow { w, f in self.toggleGameMode(w, f, keepSize: true) }
        case "RestoreOriginal": withWindow { w, f in self.restoreOriginal(w, f) }
        case "Undo": undo()
        case "SwitchProfile": engine.togglePicker()
        case "ToggleWatcher": engine.toggleWatcher()
        case "ToggleDim": Hud.showText("La capa oscura todavía no está disponible en macOS")
        default: break
        }
    }

    // MARK: - Geometría

    private var usable: CGRect {
        guard let screen = NSScreen.screens.first else { return CGRect(x: 0, y: 0, width: 1920, height: 1080) }
        return Geometry.usableRect(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }

    private var profile: Profile? {
        engine.config?.profile(named: engine.currentProfileName)
    }

    private func rect(of zoneName: String) -> CGRect {
        guard let config = engine.config, let zone = profile?.zones[zoneName] else { return usable }
        return Geometry.rect(of: zone, monitorWidth: config.monitorWidth, monitorHeight: config.monitorHeight, in: usable)
    }

    private func zoneName(of frame: CGRect) -> String {
        guard let config = engine.config, let profile = profile else { return "A" }
        return Geometry.zoneName(containing: frame, profile: profile, monitorWidth: config.monitorWidth,
                                 monitorHeight: config.monitorHeight, usable: usable)
    }

    private func neighbour(of frame: CGRect, _ direction: Int) -> String {
        guard let profile = profile else { return "A" }
        return Geometry.neighbour(of: zoneName(of: frame), direction: direction, profile: profile)
    }

    // MARK: - Ventana activa

    /// Ejecuta algo con la ventana activa si se puede gestionar; si no, avisa.
    private func withWindow(_ body: (ForeignWindow, CGRect) -> Void) {
        guard Accessibility.isTrusted(prompt: false) else {
            Hud.showText("Falta el permiso de Accesibilidad (menú de Zonely)")
            Accessibility.openSettings()
            return
        }
        guard profile?.isZoned == true else {
            Hud.showText("El perfil «\(engine.currentProfileName)» no tiene zonas")
            return
        }
        guard let window = Accessibility.focusedWindow(), let frame = window.frame else {
            Hud.showText("No hay ventana gestionable")
            return
        }
        body(window, frame)
    }

    // MARK: - Colocar

    /// Coloca la ventana. Si estaba en pantalla completa nativa, sale de ella antes (tarda una animación).
    private func place(_ window: ForeignWindow, _ target: CGRect, from current: CGRect, record: Bool = true) {
        if window.isFullScreen {
            window.setFullScreen(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.place(window, target, from: window.frame ?? current, record: record)
            }
            return
        }
        if record {
            push(&undoStack, Saved(window: window, frame: current), limit: 20)
            noteOriginal(window, current)
        }
        window.setFrame(target)
        if let result = window.frame, !Geometry.matches(result, target, tolerance: 3) {
            Log.write("No respeta la zona: \(window.processName) · pedido \(Int(target.minX)),\(Int(target.minY)) \(Int(target.width))x\(Int(target.height)) · obtenido \(Int(result.minX)),\(Int(result.minY)) \(Int(result.width))x\(Int(result.height))", level: "WARN")
        }
    }

    private func placeHalf(_ window: ForeignWindow, _ current: CGRect, top: Bool) {
        let halves = Geometry.halves(of: rect(of: "B"))
        place(window, top ? halves.top : halves.bottom, from: current)
    }

    /// Centra la ventana en una zona sin cambiarle el tamaño.
    private func center(_ window: ForeignWindow, _ current: CGRect, _ zone: String) {
        place(window, Geometry.centered(size: current.size, in: rect(of: zone)), from: current)
    }

    // MARK: - Modo juego (en macOS: llenar la zona del juego; no se pueden quitar los bordes)

    private func toggleGameMode(_ window: ForeignWindow, _ current: CGRect, keepSize: Bool) {
        if let i = gameMode.firstIndex(where: { $0.window.sameWindow(as: window) }) {
            let saved = gameMode.remove(at: i)
            window.setFrame(saved.frame)
            Hud.showText("Ventana restaurada")
            Log.write("Modo juego OFF: \(window.processName)")
            return
        }
        gameMode.append(Saved(window: window, frame: current))
        var zone = profile?.gameZone ?? "auto"
        if zone == "auto" { zone = zoneName(of: current) }
        let target = keepSize ? Geometry.centered(size: current.size, in: rect(of: zone)) : rect(of: zone)
        place(window, target, from: current, record: false)
        Hud.showText(keepSize ? "Modo juego (tamaño conservado)" : "Modo juego")
        Log.write("Modo juego ON: \(window.processName) -> zona \(zone)")
    }

    // MARK: - Restaurar y deshacer

    private func noteOriginal(_ window: ForeignWindow, _ frame: CGRect) {
        guard !originals.contains(where: { $0.window.sameWindow(as: window) }) else { return }
        push(&originals, Saved(window: window, frame: frame), limit: 50)
    }

    private func restoreOriginal(_ window: ForeignWindow, _ current: CGRect) {
        guard let saved = originals.first(where: { $0.window.sameWindow(as: window) }) else {
            Hud.showText("No tengo guardado el tamaño original de esta ventana")
            return
        }
        // Recupera el tamaño de antes de entrar en la zona, dejando la ventana donde está (sin salirse del área útil).
        var target = CGRect(origin: current.origin, size: saved.frame.size)
        let area = usable
        target.origin.x = min(max(target.minX, area.minX), max(area.minX, area.maxX - target.width))
        target.origin.y = min(max(target.minY, area.minY), max(area.minY, area.maxY - target.height))
        place(window, target, from: current, record: false)
        originals.removeAll { $0.window.sameWindow(as: window) }
    }

    private func undo() {
        guard Accessibility.isTrusted(prompt: false) else { return }
        while let saved = undoStack.popLast() {
            guard saved.window.frame != nil else { continue }          // la ventana ya no existe
            saved.window.setFrame(saved.frame)
            Hud.showText("Colocación deshecha")
            return
        }
        Hud.showText("Nada que deshacer")
    }

    private func push(_ stack: inout [Saved], _ item: Saved, limit: Int) {
        stack.append(item)
        if stack.count > limit { stack.removeFirst(stack.count - limit) }
    }
}
