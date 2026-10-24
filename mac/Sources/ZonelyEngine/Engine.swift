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

    var currentProfileName: String { state.profile }

    /// Cambia el estado «Pausar atajos» (lo marca el menú de la barra).
    var paused: Bool {
        get { state.paused }
        set { state.paused = newValue; writeState() }
    }

    func start() {
        Paths.ensureDirectories()
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Relee zones.ini y vuelve a registrar los atajos. Si el archivo está mal, se queda lo que había y se anota el motivo.
    func reloadConfig() {
        do {
            let loaded = try Config.load()
            config = loaded
            configError = nil
            if loaded.profile(named: state.profile) == nil || ticks == 0 { state.profile = loaded.startProfile }
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
    }

    // MARK: - Acciones que usan los atajos y el menú

    /// Cambia de perfil. Con origen «selector» (⌃⌥P) enseña el aviso de «Perfil aplicado».
    func setProfile(_ name: String, origin: String) {
        guard let profile = config?.profile(named: name) else { return }
        state.profile = name
        Log.write("Perfil: \(name) (\(origin))")
        writeState()
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

    // MARK: - Panel

    private func tick() {
        ticks += 1
        let commands = Ipc.takeCommands()
        for command in commands { apply(command) }
        if !commands.isEmpty || ticks % 8 == 0 { writeState() }   // latido cada 2 s: el panel sabe que seguimos vivos
    }

    private func apply(_ command: Command) {
        switch command {
        case .profile(let name): setProfile(name, origin: "desde el panel")
        case .watcher(let on): state.watcher = on
        case .snap(let on): state.snap = on
        case .halves(let on): config?.snapHalves = on
        case .restore(let on): config?.restoreOnLeave = on
        case .dim(let zone): state.dim = zone
        case .dimLevel(let level): state.dimLevel = level
        case .watch: break
        case .reload:
            Log.write("Recargando")
            reloadConfig()
        }
    }

    private func writeState() {
        Ipc.write(Ipc.stateData(version: version, state: state), name: "state.json")
    }
}
