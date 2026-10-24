import Foundation

/// Órdenes que el panel escribe en `ipc/cmd.txt` (una por línea). Mismo protocolo que en Windows.
public enum Command: Equatable {
    case profile(String)
    case watcher(Bool)
    case snap(Bool)
    case halves(Bool)
    case restore(Bool)
    case dim(String)        // "" = apagada, "A", "B", "A+C"…
    case dimLevel(Int)
    case watch
    case reload
}

/// Estado que el motor publica en `ipc/state.json`.
public struct EngineState: Equatable {
    public var profile: String
    public var watcher: Bool
    public var snap: Bool
    public var dim: String
    public var dimLevel: Int
    public var paused: Bool

    public init(profile: String, watcher: Bool, snap: Bool, dim: String = "", dimLevel: Int = 85, paused: Bool = false) {
        self.profile = profile
        self.watcher = watcher
        self.snap = snap
        self.dim = dim
        self.dimLevel = dimLevel
        self.paused = paused
    }
}

public enum Ipc {
    /// Interpreta el contenido de cmd.txt. Las líneas desconocidas se ignoran.
    public static func parse(_ text: String) -> [Command] {
        var result: [Command] = []
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            let name = parts[0].lowercased()
            let arg = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
            switch name {
            case "profile": result.append(.profile(arg))
            case "watcher": result.append(.watcher(arg == "on"))
            case "snap": result.append(.snap(arg == "on"))
            case "halves": result.append(.halves(arg == "on"))
            case "restore": result.append(.restore(arg == "on"))
            case "dim":
                let valid = arg.range(of: "^[ABC](\\+[ABC])*$", options: .regularExpression) != nil
                result.append(.dim(valid ? arg : ""))
            case "dimlevel":
                if let n = Int(arg) { result.append(.dimLevel(min(100, max(0, n)))) }
            case "watch": result.append(.watch)
            case "reload": result.append(.reload)
            default: break
            }
        }
        return result
    }

    /// Lee y borra `ipc/cmd.txt`.
    public static func takeCommands() -> [Command] {
        let url = Paths.ipcDir.appendingPathComponent("cmd.txt")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        try? FileManager.default.removeItem(at: url)
        return parse(text)
    }

    /// JSON de `state.json`. `ts` en segundos Unix: el panel lo usa para saber que el motor sigue vivo.
    public static func stateData(version: String, state: EngineState, now: Date = Date()) -> Data {
        let object: [String: Any] = [
            "ts": Int(now.timeIntervalSince1970),
            "version": version,
            "profile": state.profile,
            "watcher": state.watcher,
            "snap": state.snap,
            "dim": state.dim,
            "dimLevel": state.dimLevel,
            "target": NSNull(),
            "paused": state.paused,
        ]
        return (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }

    /// JSON de `hotkeys.json`.
    public static func hotkeysData(_ rows: [HotkeyRow]) -> Data {
        let array: [[String: String]] = rows.map {
            ["id": $0.def.id, "label": $0.def.label, "default": $0.def.defaultKey, "key": $0.key, "error": $0.error]
        }
        return (try? JSONSerialization.data(withJSONObject: array)) ?? Data("[]".utf8)
    }

    /// Escribe un JSON en `ipc/` de forma atómica (el panel nunca lo lee a medias).
    public static func write(_ data: Data, name: String) {
        Paths.ensureDirectories()
        try? data.write(to: Paths.ipcDir.appendingPathComponent(name), options: .atomic)
    }
}
