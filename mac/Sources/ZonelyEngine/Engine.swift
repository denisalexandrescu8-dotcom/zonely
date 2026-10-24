import AppKit
import ZonelyCore

/// El motor de macOS. Fase 1: lee la configuración, atiende las órdenes del panel y publica su estado,
/// igual que el motor de Windows. La colocación de ventanas, los atajos y el resto llegan en las fases siguientes.
final class Engine {
    private(set) var config: Config?
    private(set) var configError: String?
    private(set) var state = EngineState(profile: "normal", watcher: true, snap: true)
    private let version = Paths.appVersion()
    private var timer: Timer?
    private var ticks = 0

    /// Cambia el estado «Pausar atajos» (lo marca el menú de la barra).
    var paused: Bool {
        get { state.paused }
        set { state.paused = newValue; writeState() }
    }

    func start() {
        Paths.ensureDirectories()
        if let screen = NSScreen.main {
            let size = screen.frame.size
            DefaultIni.createIfMissing(width: Int(size.width), height: Int(size.height))
        }
        _ = Ipc.takeCommands()                        // descarta órdenes viejas
        reloadConfig()
        Log.write("Motor iniciado v\(version) · perfil \(state.profile)")
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.tick() }
    }

    /// Relee zones.ini. Si está mal escrito, se queda lo que había y se anota el motivo.
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
        Ipc.write(Ipc.hotkeysData(HotkeyTable.resolve(overrides: config?.hotkeyOverrides ?? [:])), name: "hotkeys.json")
        writeState()
    }

    private func tick() {
        ticks += 1
        let commands = Ipc.takeCommands()
        for command in commands { apply(command) }
        if !commands.isEmpty || ticks % 8 == 0 { writeState() }   // latido cada 2 s: el panel sabe que seguimos vivos
    }

    private func apply(_ command: Command) {
        switch command {
        case .profile(let name):
            guard config?.profile(named: name) != nil else { return }
            state.profile = name
            Log.write("Perfil: \(name) (desde el panel)")
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
