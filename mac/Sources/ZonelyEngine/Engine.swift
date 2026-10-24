import AppKit
import ZonelyCore

/// El motor de macOS. Fase 2: además de atender al panel y publicar su estado, registra los atajos globales,
/// coloca las ventanas en las zonas y enseña el selector de perfiles. El encaje con Mayús, el vigilante y la
/// capa oscura llegan en la fase 3.
final class Engine {
    private(set) var config: Config?
    private(set) var configError: String?
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
            self.windows.perform(id)
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
            config = loaded
            configError = nil
            Screens.selectedId = loaded.monitorId
            if loaded.profile(named: state.profile) == nil || ticks == 0 {
                let last = (try? String(contentsOf: Paths.lastProfileURL, encoding: .utf8))?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                state.profile = loaded.profile(named: last) != nil ? last : loaded.startProfile
            }
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
        try? name.write(to: Paths.lastProfileURL, atomically: true, encoding: .utf8)   // se recupera al reiniciar
        if !profile.isZoned { state.dim = "" }                  // sin zonas no hay nada que atenuar
        Log.write("Perfil: \(name) (\(origin))")
        writeState()
        dim.update()
        if origin == "selector", let config = config { Hud.showProfile(profile, monitorWidth: config.monitorWidth) }
    }

    func togglePicker() {
        if picker.isOpen { picker.close(); return }
        guard let config = config else { return }
        picker.show(profiles: config.profiles, current: state.profile, monitorWidth: config.monitorWidth) { [weak self] name in
            self?.setProfile(name, origin: "selector")
        }
    }

    func toggleWatcher() {
        state.watcher.toggle()
        writeState()
        Hud.showText("Vigilante \(state.watcher ? "activado" : "desactivado")")
    }

    /// Capa oscura (⌃⌥O): la apaga si estaba encendida; si no, oscurece todas las zonas menos la de la ventana activa.
    func toggleDim() {
        guard let profile = config?.profile(named: state.profile), profile.isZoned else {
            Hud.showText("El perfil «\(state.profile)» no tiene zonas")
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
        case .halves(let on): config?.snapHalves = on
        case .restore(let on): config?.restoreOnLeave = on
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
        let selected = Screens.selected.map { Screens.id(of: $0) } ?? ""
        Ipc.write(Ipc.stateData(version: version, state: state, monitor: selected, monitors: Screens.list()), name: "state.json")
    }
}
