import AppKit
import ZonelyCore

/// Coloca las ventanas en las zonas y las vigila: el equivalente de lib/Zones.ahk, GameMode.ahk, Restore.ahk
/// y Watcher.ahk en Windows.
final class WindowManager {
    private unowned let engine: Engine

    private struct Saved {
        let window: ForeignWindow
        let frame: CGRect
    }

    /// Una ventana colocada en una zona: su tamaño de antes y la zona donde quedó (para «recuperar tamaño al salir»).
    private struct Tracked {
        let window: ForeignWindow
        let size: CGSize
        var zone: CGRect?
        var pending = 0
    }

    private var undoStack: [Saved] = []              // posiciones anteriores (máx. 20)
    private var tracked: [Tracked] = []              // tamaño original de cada ventana colocada
    private var gameMode: [Saved] = []               // ventanas en «modo juego» y cómo estaban
    private var lastNormal: Saved?                   // última posición de la ventana activa sin maximizar (para el vigilante)
    private var fixes: [(window: ForeignWindow, count: Int, since: Date)] = []
    private var ignored: [ForeignWindow] = []        // ventanas que se pelean con el vigilante: se dejan en paz
    private var moves: [Move] = []                // animaciones en curso
    private var leavingFullScreen: [ForeignWindow] = []   // ventanas que están saliendo de la pantalla completa nativa (dura una animación)

    init(engine: Engine) {
        self.engine = engine
    }

    /// Una ventana deslizándose de un sitio a otro.
    private final class Move {
        let window: ForeignWindow
        let from: CGRect
        let to: CGRect
        let start = Date()
        var timer: Timer?
        init(window: ForeignWindow, from: CGRect, to: CGRect) {
            self.window = window
            self.from = from
            self.to = to
        }
    }

    /// Mientras alguna ventana se está animando, el vigilante espera (vería la ventana a medio camino).
    var isAnimating: Bool { !moves.isEmpty }

    /// Desliza la ventana hasta `to` en unos 0,17 s (con frenada suave al final) y llama a `done` cuando ha llegado.
    /// Sin animación (apagada, «Reducir movimiento» del sistema o un cambio mínimo) se coloca de golpe.
    private func animate(_ window: ForeignWindow, from: CGRect, to: CGRect, done: @escaping () -> Void) {
        for m in moves where m.window.sameWindow(as: window) { m.timer?.invalidate() }
        moves.removeAll { $0.window.sameWindow(as: window) }
        let distance = abs(to.minX - from.minX) + abs(to.minY - from.minY) + abs(to.width - from.width) + abs(to.height - from.height)
        guard engine.config?.animateWindows ?? true, distance > 24, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            window.setFrame(to)
            done()
            return
        }
        let move = Move(window: window, from: from, to: to)
        moves.append(move)
        let duration = 0.17
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let t = min(1, Date().timeIntervalSince(move.start) / duration)
            if t >= 1 {
                move.timer?.invalidate()
                self.moves.removeAll { $0 === move }
                window.setFrame(to)                                     // el último paso, completo (posición, tamaño, posición)
                done()
                return
            }
            let e = 1 - pow(1 - t, 3)                                   // frenada suave
            func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * CGFloat(e) }
            window.setFrameStep(CGRect(x: mix(from.minX, to.minX), y: mix(from.minY, to.minY),
                                       width: mix(from.width, to.width), height: mix(from.height, to.height)))
        }
        RunLoop.main.add(timer, forMode: .common)
        move.timer = timer
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
        case "ToggleDim": engine.toggleDim()
        default: break
        }
    }

    // MARK: - Geometría

    private var profile: Profile? {
        engine.config?.profile(named: engine.currentProfileName)
    }

    private func rect(of zoneName: String) -> CGRect {
        guard let config = engine.config, let zone = profile?.zones[zoneName] else { return Screens.usable }
        return Geometry.rect(of: zone, monitorWidth: config.monitorWidth, monitorHeight: config.monitorHeight, in: Screens.usable)
    }

    private func zoneName(of frame: CGRect) -> String {
        guard let config = engine.config, let profile = profile else { return "A" }
        return Geometry.zoneName(containing: frame, profile: profile, monitorWidth: config.monitorWidth,
                                 monitorHeight: config.monitorHeight, usable: Screens.usable)
    }

    private func neighbour(of frame: CGRect, _ direction: Int) -> String {
        guard let profile = profile else { return "A" }
        return Geometry.neighbour(of: zoneName(of: frame), direction: direction, profile: profile)
    }

    /// Zona de la ventana activa (A si no hay ninguna): la usa la capa oscura para saber cuál dejar sin velo.
    func activeZoneName() -> String {
        guard Accessibility.isTrusted(prompt: false), let frame = Accessibility.focusedWindow()?.frame else { return "A" }
        return zoneName(of: frame)
    }

    // MARK: - Juegos y exclusiones

    private func names(of window: ForeignWindow) -> [String] {
        [window.app.localizedName, window.app.bundleIdentifier, window.app.executableURL?.lastPathComponent].compactMap { $0 }
    }

    /// Los juegos de `Games=` nunca se tocan solos (vigilante, encaje, recuperar tamaño); los atajos que pulsas tú sí funcionan.
    func isGame(_ window: ForeignWindow) -> Bool {
        NameMatch.matches(candidates: names(of: window), list: engine.config?.gameProcesses ?? [])
    }

    private func isExcluded(_ window: ForeignWindow) -> Bool {
        isGame(window) || NameMatch.matches(candidates: names(of: window), list: engine.config?.excludeProcesses ?? [])
    }

    // MARK: - Ventana activa

    /// Ejecuta algo con la ventana activa si se puede gestionar; si no, avisa.
    private func withWindow(_ body: (ForeignWindow, CGRect) -> Void) {
        guard Accessibility.isTrusted(prompt: false) else {
            Hud.showText(tr("Falta el permiso de Accesibilidad (menú de Zonely)"))
            Accessibility.openSettings()
            return
        }
        guard profile?.isZoned == true else {
            Hud.showText(tr("El perfil «{name}» no tiene zonas", ["name": engine.currentProfileName]))
            return
        }
        guard let window = Accessibility.focusedWindow(), let frame = window.frame else {
            Hud.showText(tr("No hay ventana gestionable"))
            return
        }
        body(window, frame)
    }

    // MARK: - Colocar

    /// Coloca la ventana. Si estaba en pantalla completa nativa, sale de ella antes (tarda una animación).
    /// Con `record` apunta el tamaño original y la posición anterior (para recuperar el tamaño y deshacer).
    func place(_ window: ForeignWindow, _ target: CGRect, from current: CGRect, record: Bool = true) {
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
        // Mientras se desliza ya cuenta como «dentro de la zona» (así no se confunde con haberse salido).
        if record, let i = tracked.firstIndex(where: { $0.window.sameWindow(as: window) }) {
            tracked[i].zone = target
            tracked[i].pending = 0
        }
        animate(window, from: window.frame ?? current, to: target) { [weak self] in
            self?.settle(window, target: target, record: record)
        }
    }

    /// Comprueba cómo ha quedado la ventana. Muchas apps (navegadores, editores) terminan de cambiar de tamaño unos
    /// instantes después, así que se mira otra vez: si la app no puede ser tan pequeña, esa zona más grande es la suya.
    private func settle(_ window: ForeignWindow, target: CGRect, record: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self = self, let result = window.frame else { return }
            if !Geometry.matches(result, target, tolerance: 3) {
                Log.write("No respeta la zona: \(window.processName) · pedido \(Int(target.minX)),\(Int(target.minY)) \(Int(target.width))x\(Int(target.height)) · obtenido \(Int(result.minX)),\(Int(result.minY)) \(Int(result.width))x\(Int(result.height))", level: "WARN")
            }
            guard record, let i = self.tracked.firstIndex(where: { $0.window.sameWindow(as: window) }) else { return }
            self.tracked[i].zone = target.union(result)
            self.tracked[i].pending = 0
        }
    }

    /// Encaje arrastrando (con la tecla): coloca la ventana en el rectángulo elegido.
    func snap(_ window: ForeignWindow, to target: CGRect) {
        guard let frame = window.frame else { return }
        place(window, target, from: frame)
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
            Hud.showText(tr("Ventana restaurada"))
            Log.write("Modo juego OFF: \(window.processName)")
            return
        }
        gameMode.append(Saved(window: window, frame: current))
        var zone = profile?.gameZone ?? "auto"
        if zone == "auto" { zone = zoneName(of: current) }
        let target = keepSize ? Geometry.centered(size: current.size, in: rect(of: zone)) : rect(of: zone)
        place(window, target, from: current, record: false)
        Hud.showText(keepSize ? tr("Modo juego (tamaño conservado)") : tr("Modo juego"))
        Log.write("Modo juego ON: \(window.processName) -> zona \(zone)")
    }

    // MARK: - Restaurar y deshacer

    private func noteOriginal(_ window: ForeignWindow, _ frame: CGRect) {
        guard !tracked.contains(where: { $0.window.sameWindow(as: window) }) else { return }
        // Si ya llena una zona, ese no es su tamaño de antes (p. ej. se colocó en una zona antes de arrancar Zonely): apuntarlo
        // haría que «recuperar tamaño» la dejara igual.
        if let profile = profile, profile.zones.values.contains(where: { Geometry.matches(frame, rect(of: $0.name), tolerance: 6) }) {
            Log.write("Tamaño original no apuntado (la ventana ya llena una zona): (window.processName)")
            return
        }
        Log.write("Tamaño original apuntado: \(window.processName) \(Int(frame.width))x\(Int(frame.height))")
        tracked.append(Tracked(window: window, size: frame.size, zone: nil))
        if tracked.count > 50 { tracked.removeFirst(tracked.count - 50) }
    }

    private func restoreOriginal(_ window: ForeignWindow, _ current: CGRect) {
        guard let entry = tracked.first(where: { $0.window.sameWindow(as: window) }) else {
            Hud.showText(tr("No tengo guardado el tamaño original de esta ventana"))
            return
        }
        returnToOriginalSize(entry, from: current, followCursor: false)
    }

    /// Devuelve la ventana a su tamaño de antes de entrar en una zona. Con `followCursor` queda donde está el cursor
    /// (proporcionalmente, como al soltar una ventana arrastrada); si no, se queda donde está.
    private func returnToOriginalSize(_ entry: Tracked, from current: CGRect, followCursor: Bool) {
        let size = entry.size
        var origin = current.origin
        let cursor = Screens.mouse
        if followCursor, current.contains(cursor) {
            origin.x = cursor.x - ((cursor.x - current.minX) / max(1, current.width)) * size.width
        } else if followCursor {
            origin.x = current.midX - size.width / 2
        }
        let area = Screens.usable(containing: CGPoint(x: origin.x + size.width / 2, y: current.midY))     // la pantalla donde queda la ventana
        origin.x = min(max(origin.x, area.minX), max(area.minX, area.maxX - size.width))
        origin.y = min(max(origin.y, area.minY), max(area.minY, area.maxY - size.height))
        let destination = CGRect(origin: origin, size: size)
        tracked.removeAll { $0.window.sameWindow(as: entry.window) }
        animate(entry.window, from: current, to: destination) {}
        Log.write("Tamaño original restaurado al salir de la zona: \(entry.window.processName) \(Int(size.width))x\(Int(size.height))")
    }

    private func undo() {
        guard Accessibility.isTrusted(prompt: false) else { return }
        while let saved = undoStack.popLast() {
            guard saved.window.frame != nil else { continue }          // la ventana ya no existe
            animate(saved.window, from: saved.window.frame ?? saved.frame, to: saved.frame) {}
            Hud.showText(tr("Colocación deshecha"))
            return
        }
        Hud.showText(tr("Nada que deshacer"))
    }

    private func push(_ stack: inout [Saved], _ item: Saved, limit: Int) {
        stack.append(item)
        if stack.count > limit { stack.removeFirst(stack.count - limit) }
    }

    // MARK: - Vigilante y «recuperar tamaño» (se llama cada pocos cientos de milisegundos)

    func watcherTick() {
        guard !isAnimating else { return }                  // una ventana se está deslizando: se mira cuando llegue
        guard Accessibility.isTrusted(prompt: false) else {
            lastNormal = nil
            return
        }
        // La ventana activa se vigila con las zonas de su monitor; recuperar el tamaño sirve para todos.
        let center = (Accessibility.focusedWindow()?.frame).map { CGPoint(x: $0.midX, y: $0.midY) }
        engine.inMonitor(at: center) { () -> Void in
            guard profile?.isZoned == true else {
                lastNormal = nil
                return
            }
            if engine.state.watcher { fixMaximized() }
        }
        if (engine.config?.restoreOnLeave ?? true) && engine.anyZoned { restoreWindowsThatLeftTheirZone() }
    }

    /// Si la ventana activa se ha maximizado (ocupa toda el área útil), vuelve a su zona.
    private func fixMaximized() {
        guard let window = Accessibility.focusedWindow(), !isExcluded(window), let frame = window.frame,
              !window.isMinimized else {
            lastNormal = nil
            return
        }
        if window.isFullScreen {                                    // el botón verde: pantalla completa nativa (otro Space)
            fixFullScreen(window, frame)
            return
        }
        guard Geometry.isMaximized(frame, in: Screens.usable) else {
            lastNormal = Saved(window: window, frame: frame)
            return
        }
        if ignored.contains(where: { $0.sameWindow(as: window) }) { return }
        guard registerFix(window) else { return }
        var zone = "A"
        var before = frame
        if let last = lastNormal, last.window.sameWindow(as: window) {
            zone = zoneName(of: last.frame)
            before = last.frame
        }
        Log.write("Vigilante: \(window.processName) estaba maximizada")
        place(window, rect(of: zone), from: before)
    }

    /// Pantalla completa nativa (botón verde): se sale de ella y la ventana vuelve a su zona. Se puede apagar en Ajustes
    /// (para ver vídeo a pantalla completa, por ejemplo). `place` ya sabe salir de la pantalla completa; aquí solo se evita
    /// repetirlo mientras dura la animación.
    private func fixFullScreen(_ window: ForeignWindow, _ frame: CGRect) {
        guard engine.config?.fullScreenToZone ?? true else { return }
        if leavingFullScreen.contains(where: { $0.sameWindow(as: window) }) { return }
        if ignored.contains(where: { $0.sameWindow(as: window) }) { return }
        guard registerFix(window) else { return }
        leavingFullScreen.append(window)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            self?.leavingFullScreen.removeAll { $0.sameWindow(as: window) }
        }
        var zone = "A"
        var before = frame
        if let last = lastNormal, last.window.sameWindow(as: window) {
            zone = zoneName(of: last.frame)
            before = last.frame
        }
        Log.write("Vigilante: \(window.processName) entró en pantalla completa; vuelve a su zona")
        place(window, rect(of: zone), from: before)
    }

    /// Anti-bucle: si una app se vuelve a maximizar sola más de 4 veces en 3 segundos, se deja en paz.
    private func registerFix(_ window: ForeignWindow) -> Bool {
        let now = Date()
        let i = fixes.firstIndex { $0.window.sameWindow(as: window) }
        var entry = i.map { fixes[$0] } ?? (window: window, count: 0, since: now)
        if now.timeIntervalSince(entry.since) > 3 { entry = (window: window, count: 0, since: now) }
        entry.count += 1
        if let i = i { fixes[i] = entry } else { fixes.append(entry) }
        if fixes.count > 30 { fixes.removeFirst() }
        if entry.count > 4 {
            ignored.append(window)
            Hud.showText(tr("El vigilante ignora esta ventana (se maximiza sola)"))
            Log.write("Vigilante: se ignora \(window.processName) (se maximiza sola)", level: "WARN")
            return false
        }
        return true
    }

    /// Una ventana colocada en una zona que se saca de ella recupera el tamaño que tenía antes de entrar.
    private func restoreWindowsThatLeftTheirZone() {
        guard NSEvent.pressedMouseButtons == 0 else { return }        // se está arrastrando o pulsando: se espera
        for i in tracked.indices.reversed() {
            guard i < tracked.count, let zone = tracked[i].zone else { continue }
            let window = tracked[i].window
            guard let frame = window.frame else {                       // la ventana ya no existe
                tracked.remove(at: i)
                continue
            }
            if isGame(window) || window.isFullScreen || window.isMinimized
                || Geometry.isMaximized(frame, in: Screens.usable(containing: CGPoint(x: frame.midX, y: frame.midY)))
                || gameMode.contains(where: { $0.window.sameWindow(as: window) }) {
                tracked[i].pending = 0
                continue
            }
            if Geometry.isOutside(frame, of: zone) {
                tracked[i].pending += 1
                if tracked[i].pending >= 2 { returnToOriginalSize(tracked[i], from: frame, followCursor: true) }
            } else {
                tracked[i].pending = 0
            }
        }
    }
}
