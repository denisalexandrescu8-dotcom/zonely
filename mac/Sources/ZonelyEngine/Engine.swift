import AppKit
import ZonelyCore

/// El motor de macOS. Fase 2: además de atender al panel y publicar su estado, registra los atajos globales,
/// coloca las ventanas en las zonas y enseña el selector de perfiles. El encaje con Mayús, el vigilante y la
/// capa oscura llegan en la fase 3.
final class Engine {
    /// Configuración del monitor en uso. Cada monitor con zonas tiene su propio conjunto de perfiles y su perfil activo:
    /// `config` y `state.profile` son los del monitor en uso (`inMonitor`), y fuera de eso los del monitor principal.
    private(set) var config: Config?
    private var mainConfig: Config?
    private var mainId = ""                                   // monitor elegido en el panel ([Monitor] Id de zones.ini)
    private var currentId = ""                                // monitor cuyo contexto está en `config` ahora mismo
    private var mainProfile = "normal"
    private var others: [String: MonitorSet] = [:]            // los demás monitores con zonas (monitors/<monitor>.ini)
    private(set) var configError: String?

    private struct MonitorSet {
        var width: Int
        var height: Int
        var profiles: [Profile]
        var profile: String
    }
    private(set) var state = EngineState(profile: "normal", watcher: true, snap: true)
    private let version = Paths.appVersion()
    private var timer: Timer?
    private var ticks = 0
    private let hotkeys = HotkeyCenter()
    private let picker = ProfilePicker()
    private lazy var windows = WindowManager(engine: self)
    private lazy var dim = DimController(engine: self)
    private lazy var snap = SnapController(engine: self, windows: windows)
    private var watcherTimer: Timer?
    private var tickInterval: TimeInterval = 1.0
    private var watchUntil = Date.distantPast        // hasta cuándo se atiende al panel deprisa
    private var lastBeat = Date.distantPast
    private var lastAccessibilityWarning = Date.distantPast
    private var mouseUpMonitor: Any?
    private var appChangeObserver: NSObjectProtocol?
    private let updates = BackgroundUpdates()

    var currentProfileName: String { state.profile }

    /// Se llama cada vez que se (re)lee zones.ini; la barra de menús lo usa para mostrar u ocultar el icono.
    var onConfigLoaded: (() -> Void)?

    /// Cambia el estado «Pausar atajos» (lo marca el menú de la barra).
    var paused: Bool {
        get { state.paused }
        set { state.paused = newValue; writeState() }
    }

    /// Inicio con el sistema: la primera vez que arranca el motor instalado se activa (se puede quitar desde el menú);
    /// después, solo se corrige la ruta si la app se ha movido o actualizado. Desde el código (`swift run`) no se toca.
    private func configureLoginItem() {
        guard let executable = Bundle.main.executablePath, executable.contains(".app/Contents/") else { return }
        let marker = Paths.dataDir.appendingPathComponent(".autostart-configured")
        if FileManager.default.fileExists(atPath: marker.path) {
            LoginItem.refresh(executable: executable)
        } else {
            LoginItem.enable(executable: executable)
            try? Data().write(to: marker)
        }
    }

    func start() {
        Paths.ensureDirectories()
        configureLoginItem()
        if let screen = NSScreen.screens.first {
            let size = screen.frame.size
            DefaultIni.createIfMissing(width: Int(size.width), height: Int(size.height))
        }
        _ = Ipc.takeCommands()                        // descarta órdenes viejas
        hotkeys.onAction = { [weak self] id in
            guard let self = self, !self.state.paused else { return }
            // Cada acción actúa sobre el monitor de la ventana activa; el selector, el del cursor; el vigilante y la capa oscura
            // son del monitor principal.
            let point: CGPoint? = ["ToggleDim", "ToggleWatcher", "SwitchProfile"].contains(id) ? nil
                : (Accessibility.focusedWindow()?.frame).map { CGPoint(x: $0.midX, y: $0.midY) }
            self.inMonitor(at: point) { self.windows.perform(id) }
        }
        reloadConfig()
        if !Accessibility.isTrusted(prompt: true) {
            Log.write("Falta el permiso de Accesibilidad: Zonely no puede mover ventanas hasta que se conceda", level: "WARN")
        }
        Log.write("Motor iniciado v\(version) · perfil \(state.profile)")
        scheduleTick(every: 1.0)
        // Ahorro de batería: el vigilante no sondea las ventanas a cada rato. En reposo mira una vez por segundo (con margen
        // para que macOS agrupe los despertares) y reacciona al momento a lo que puede cambiar una ventana: soltar el ratón
        // (botón verde, arrastrar, redimensionar) o cambiar de aplicación. Tras cada uno hace unas cuantas comprobaciones
        // seguidas, para pillar el final de la animación de maximizar.
        let watcher = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in self?.windows.watcherTick() }
        watcher.tolerance = 0.4
        RunLoop.main.add(watcher, forMode: .common)
        watcherTimer = watcher
        mouseUpMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in self?.watchBurst() }
        appChangeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.watchBurst() }
        snap.start()
        dim.update()
        updates.start()
    }

    /// Relee zones.ini y vuelve a registrar los atajos. Si el archivo está mal, se queda lo que había y se anota el motivo.
    func reloadConfig() {
        iniStamp = iniModified()
        do {
            let loaded = try Config.load()
            let previousMain = mainId
            config = loaded
            mainConfig = loaded
            configError = nil
            Screens.selectedId = loaded.monitorId
            mainId = Screens.selected.map { Screens.id(of: $0) } ?? loaded.monitorId
            currentId = mainId
            Strings.language = Strings.resolve(chosen: loaded.language)
            // Cada monitor conserva su perfil: solo si sigue siendo el mismo monitor se mantiene el que estaba activo;
            // si no, el último que se usó en ese monitor.
            if loaded.profile(named: state.profile) == nil || ticks == 0 || previousMain != mainId {
                let last = lastProfile(of: mainId, fallback: Paths.lastProfileURL)
                state.profile = loaded.profile(named: last) != nil ? last : loaded.startProfile
            }
            mainProfile = state.profile
            loadOthers(loaded)
            if ticks == 0 {
                state.watcher = loaded.watcherEnabled
                state.snap = loaded.snapEnabled
                state.dimLevel = loaded.dimOpacity
            }
        } catch {
            configError = String(describing: error)
            Log.write("Configuración no válida: \(error)", level: "ERROR")
        }
        let registered = hotkeys.register(HotkeyTable.resolve(overrides: config?.hotkeyOverrides ?? [:]))
        for row in registered where !row.error.isEmpty {
            Log.write("Atajo «\(row.def.label)» (\(row.key)): \(row.error)", level: "WARN")
        }
        Ipc.write(Ipc.hotkeysData(registered), name: "hotkeys.json")
        writeState()
        dim.update()
        onConfigLoaded?()
    }

    // MARK: - Acciones que usan los atajos y el menú

    /// Cambia de perfil. Con origen «selector» (⌃⌥P) enseña el aviso de «Perfil aplicado».
    func setProfile(_ name: String, origin: String) {
        guard let profile = config?.profile(named: name) else { return }
        state.profile = name
        try? FileManager.default.createDirectory(at: Paths.monitorsDir, withIntermediateDirectories: true)
        try? name.write(to: Paths.lastProfileURL(forMonitor: currentId), atomically: true, encoding: .utf8)   // se recupera al reiniciar
        if currentId == mainId {
            try? name.write(to: Paths.lastProfileURL, atomically: true, encoding: .utf8)
            mainProfile = name
            if !profile.isZoned { state.dim = "" }              // sin zonas no hay nada que atenuar
        }
        Log.write("Perfil: \(name) (\(origin))" + (Screens.name(of: currentId).map { " · \($0)" } ?? ""))
        writeState()
        if currentId == mainId { dim.update() }
        if origin == "selector", let config = config {
            Hud.showProfile(profile, monitorWidth: config.monitorWidth, monitorName: Screens.name(of: currentId))
        }
    }

    /// Sin el permiso de Accesibilidad nada de lo que mueve ventanas funciona. Se avisa como mucho una vez cada 30 s.
    func warnNoAccessibility() {
        guard Date().timeIntervalSince(lastAccessibilityWarning) > 30 else { return }
        lastAccessibilityWarning = Date()
        Hud.showText(tr("Falta el permiso de Accesibilidad (menú de Zonely)"))
        Log.write("Falta el permiso de Accesibilidad: no se puede encajar ni colocar ventanas", level: "WARN")
    }

    func togglePicker() {
        if picker.isOpen { picker.close(); return }
        // El selector cambia el perfil del monitor donde está el cursor.
        _ = useMonitor(at: Screens.mouse)
        defer { useMain() }
        guard let config = config else { return }
        let id = currentId
        picker.show(profiles: config.profiles, current: state.profile, monitorWidth: config.monitorWidth,
                    monitorName: Screens.name(of: id)) { [weak self] name in
            guard let self = self else { return }
            self.inMonitor(id: id) { self.setProfile(name, origin: "selector") }
        }
    }

    func toggleWatcher() {
        state.watcher.toggle()
        writeState()
        Hud.showText(state.watcher ? tr("Vigilante activado") : tr("Vigilante desactivado"))
    }

    /// Capa oscura (⌃⌥O): la apaga si estaba encendida; si no, oscurece todas las zonas menos la de la ventana activa.
    func toggleDim() {
        guard let profile = config?.profile(named: state.profile), profile.isZoned else {
            Hud.showText(tr("El perfil «{name}» no tiene zonas", ["name": state.profile]))
            return
        }
        state.dim = state.dim.isEmpty ? Geometry.otherZones(than: windows.activeZoneName(), in: profile) : ""
        writeState()
        dim.update()
    }

    // MARK: - zones.ini cambiado (a mano o desde el panel): se recarga solo

    private var iniStamp: Date?

    private func iniModified() -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: Paths.iniURL.path))?[.modificationDate] as? Date
    }

    /// Si el archivo es válido, se aplica; si no, `reloadConfig` conserva la configuración anterior y lo anota en el registro.
    private func checkIniChanged() {
        guard iniModified() != iniStamp else { return }
        Log.write("zones.ini ha cambiado: recargando")
        reloadConfig()
    }

    // MARK: - Panel

    private func scheduleTick(every interval: TimeInterval) {
        timer?.invalidate()
        tickInterval = interval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.tick() }
        t.tolerance = interval * 0.3
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Varias comprobaciones del vigilante seguidas (ver `start`): la ventana puede tardar unos cientos de ms en terminar de moverse.
    private func watchBurst() {
        for delay in [0.0, 0.12, 0.3, 0.6, 1.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in self?.windows.watcherTick() }
        }
    }

    private func tick() {
        ticks += 1
        // Con el panel abierto (manda «watch» cada pocos segundos) se atiende cada 250 ms; en reposo, cada segundo.
        let want: TimeInterval = Date() < watchUntil ? 0.25 : 1.0
        if want != tickInterval { scheduleTick(every: want) }
        let commands = Ipc.takeCommands()
        for command in commands { apply(command) }
        let now = Date()
        if !commands.isEmpty || now.timeIntervalSince(lastBeat) >= 2 {
            lastBeat = now
            writeState()                                           // latido cada 2 s: el panel sabe que seguimos vivos
            if commands.isEmpty { checkIniChanged() }
        }
    }

    private func apply(_ command: Command) {
        switch command {
        case .profile(let name): setProfile(name, origin: "desde el panel")
        case .watcher(let on): state.watcher = on
        case .snap(let on): state.snap = on
        case .halves(let on): config?.snapHalves = on; mainConfig?.snapHalves = on
        case .restore(let on): config?.restoreOnLeave = on; mainConfig?.restoreOnLeave = on
        case .dim(let zone):
            state.dim = zone
            dim.update()
        case .dimLevel(let level):
            state.dimLevel = level
            dim.update()
        case .watch:
            watchUntil = Date().addingTimeInterval(15)             // el panel está mirando: se atiende más deprisa
            if tickInterval != 0.25 { scheduleTick(every: 0.25) }
        case .reload:
            Log.write("Recargando")
            reloadConfig()
        case .quit:
            Log.write("Motor detenido (desde el panel)")
            NSApp.terminate(nil)
        }
    }

    private func writeState() {
        let selected = mainId
        let monitors = Screens.list().map { entry -> [String: Any] in
            var entry = entry
            if let id = entry["id"] as? String { entry["profile"] = profileName(ofMonitor: id) }
            return entry
        }
        Ipc.write(Ipc.stateData(version: version, state: mainState, monitor: selected, monitors: monitors), name: "state.json")
    }

    // MARK: - Un contexto por monitor

    /// El estado como lo ve el panel: el del monitor elegido (aunque justo haya otro en uso).
    private var mainState: EngineState {
        var s = state
        s.profile = currentId == mainId ? state.profile : mainProfile
        return s
    }

    private func profileName(ofMonitor id: String) -> String {
        if id == currentId { return state.profile }
        if id == mainId { return mainProfile }
        return others[id]?.profile ?? ""
    }

    /// ¿Algún monitor con zonas reparte la pantalla?
    var anyZoned: Bool {
        if mainConfig?.profile(named: mainProfile)?.isZoned == true { return true }
        return others.values.contains { set in set.profiles.first { $0.name == set.profile }?.isZoned == true }
    }

    private func lastProfile(of id: String, fallback: URL?) -> String {
        for url in [Paths.lastProfileURL(forMonitor: id), fallback].compactMap({ $0 }) {
            if let text = try? String(contentsOf: url, encoding: .utf8) {
                let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
        }
        return ""
    }

    /// Lee monitors/*.ini: los monitores conectados, distintos del elegido, que tienen su propio conjunto de perfiles.
    private func loadOthers(_ main: Config) {
        others = [:]
        let files = (try? FileManager.default.contentsOfDirectory(at: Paths.monitorsDir, includingPropertiesForKeys: nil)) ?? []
        for url in files where url.pathExtension == "ini" {
            guard let c = try? Config.load(from: url), !c.monitorId.isEmpty, c.monitorId != mainId,
                  NSScreen.screens.contains(where: { Screens.id(of: $0) == c.monitorId }) else { continue }
            let last = lastProfile(of: c.monitorId, fallback: nil)
            others[c.monitorId] = MonitorSet(width: c.monitorWidth, height: c.monitorHeight, profiles: c.profiles,
                                             profile: c.profile(named: last) != nil ? last : c.startProfile)
        }
    }

    /// Pasa al contexto de ese monitor. false si no tiene zonas (y todo queda como estaba).
    @discardableResult
    private func useMonitor(id: String) -> Bool {
        if id == currentId { return true }
        guard let main = mainConfig else { return false }
        if id == mainId {
            others[currentId]?.profile = state.profile
            config = main
            state.profile = mainProfile
            Screens.selectedId = mainId
            currentId = mainId
            return true
        }
        guard let set = others[id] else { return false }
        if currentId == mainId { mainProfile = state.profile } else { others[currentId]?.profile = state.profile }
        var c = main
        c.monitorId = id
        c.monitorWidth = set.width
        c.monitorHeight = set.height
        c.profiles = set.profiles
        config = c
        state.profile = set.profile
        Screens.selectedId = id
        currentId = id
        return true
    }

    @discardableResult
    private func useMonitor(at point: CGPoint) -> Bool {
        guard let id = Screens.id(containing: point) else { return false }
        return useMonitor(id: id)
    }

    private func useMain() { _ = useMonitor(id: mainId) }

    /// Ejecuta algo con el contexto del monitor que contiene el punto (si tiene zonas; si no, con el del principal) y
    /// después vuelve al principal.
    func inMonitor<T>(at point: CGPoint?, _ body: () -> T) -> T {
        if let point = point { _ = useMonitor(at: point) }
        defer { useMain() }
        return body()
    }

    func inMonitor<T>(id: String, _ body: () -> T) -> T {
        _ = useMonitor(id: id)
        defer { useMain() }
        return body()
    }

    /// Identificador del monitor en uso (para recordar dónde se empezó algo, como un arrastre).
    var monitorInUse: String { currentId }
}
