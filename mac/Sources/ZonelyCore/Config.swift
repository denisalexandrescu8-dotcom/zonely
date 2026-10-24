import Foundation

/// Una zona rectangular, en píxeles del monitor (origen arriba a la izquierda).
public struct Zone: Equatable {
    public let name: String
    public let x: Int
    public let y: Int
    public let w: Int
    public let h: Int

    public init(name: String, x: Int, y: Int, w: Int, h: Int) {
        self.name = name
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    public var right: Int { x + w }
    public var bottom: Int { y + h }
}

/// Un perfil: sus zonas A, B (y C). Sin B es un perfil de pantalla normal, sin zonas.
public struct Profile: Equatable {
    public let name: String
    public let zones: [String: Zone]
    /// Zona del modo juego: "A", "B", "C" o "auto" (la zona donde esté la ventana).
    public let gameZone: String

    public init(name: String, zones: [String: Zone], gameZone: String = "auto") {
        self.name = name
        self.zones = zones
        self.gameZone = gameZone
    }

    public var isZoned: Bool { zones["B"] != nil }
}

public struct ConfigError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

/// Configuración leída de `zones.ini` (el mismo archivo y formato que usa el motor de Windows).
public struct Config {
    public var monitorWidth: Int
    public var monitorHeight: Int
    public var language: String             // [General] Language: auto, es, en, fr, de, pt o it
    public var monitorId: String            // pantalla elegida ([Monitor] Id, número de pantalla de macOS); vacío = la principal
    public var profiles: [Profile]
    public var startProfile: String
    public var restoreOnLeave: Bool
    /// Solo macOS: ¿se enseña el icono de Zonely en la barra de menús? (`[General] MenuBarIcon`, por defecto sí)
    public var menuBarIcon: Bool
    public var fullScreenToZone: Bool       // el vigilante saca de la pantalla completa nativa (botón verde) y coloca la ventana en su zona
    public var watcherEnabled: Bool
    public var watcherIntervalMs: Int
    public var snapEnabled: Bool
    public var snapKey: String
    public var snapHalves: Bool
    public var dimOpacity: Int
    public var excludeProcesses: [String]
    public var excludeClasses: [String]
    public var gameProcesses: [String]
    /// Atajos que el usuario ha cambiado: id → atajo en formato AutoHotkey (`^!z`).
    public var hotkeyOverrides: [String: String]

    public init(ini: IniFile) throws {
        monitorWidth = ini.int("Monitor", "Width", default: 1920)
        monitorHeight = ini.int("Monitor", "Height", default: 1080)
        monitorId = ini.string("Monitor", "Id", default: "")
        language = ini.string("General", "Language", default: "auto")

        var found: [Profile] = []
        for section in ini.sectionOrder where section.hasPrefix("Profile.") {
            let name = String(section.dropFirst("Profile.".count))
            var zones: [String: Zone] = [:]
            guard let a = try Config.readZone(ini, section, "A", monitorWidth, monitorHeight) else {
                throw ConfigError("[\(section)] no tiene la zona A")
            }
            zones["A"] = a
            for key in ["B", "C", "D", "E", "F"] {            // A, B, C… seguidas (hasta 6); sin B = pantalla normal, sin zonas
                guard let zone = try Config.readZone(ini, section, key, monitorWidth, monitorHeight) else { break }
                zones[key] = zone
            }
            let gz = ini.string(section, "GameZone", default: "auto").uppercased()
            found.append(Profile(name: name, zones: zones, gameZone: (gz == "AUTO" || zones[gz] == nil) ? "auto" : gz))
        }
        if found.isEmpty { throw ConfigError("zones.ini no define ningún perfil [Profile.xxx]") }
        profiles = found

        let wanted = ini.string("General", "Profile", default: "normal")
        startProfile = found.contains(where: { $0.name == wanted }) ? wanted : found[0].name
        restoreOnLeave = ini.bool("General", "RestoreOnLeave", default: true)
        menuBarIcon = ini.bool("General", "MenuBarIcon", default: true)
        fullScreenToZone = ini.bool("General", "FullScreenToZone", default: true)
        watcherEnabled = ini.bool("Watcher", "Enabled", default: true)
        watcherIntervalMs = max(50, ini.int("Watcher", "IntervalMs", default: 150))
        snapEnabled = ini.bool("Snap", "Enabled", default: true)
        let key = ini.string("Snap", "Key", default: "Shift")
        snapKey = ["Shift", "Ctrl", "Alt"].contains(key) ? key : "Shift"
        snapHalves = ini.bool("Snap", "Halves", default: false)
        dimOpacity = min(100, max(0, ini.int("Dim", "Opacity", default: 85)))
        excludeProcesses = ini.list("Exclusions", "Processes")
        excludeClasses = ini.list("Exclusions", "Classes")
        gameProcesses = ini.value("Exclusions", "Games") == nil ? ["RainbowSix.exe"] : ini.list("Exclusions", "Games")
        hotkeyOverrides = ini.sections["Hotkeys"] ?? [:]
    }

    public static func load(from url: URL = Paths.iniURL) throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else { throw ConfigError("No encuentro \(url.path)") }
        return try Config(ini: try IniFile(contentsOf: url))
    }

    public func profile(named name: String) -> Profile? {
        profiles.first { $0.name == name }
    }

    /// Lee "x,y,ancho,alto" de una sección. Devuelve nil si la clave no existe o está vacía.
    private static func readZone(_ ini: IniFile, _ section: String, _ key: String, _ monW: Int, _ monH: Int) throws -> Zone? {
        guard let raw = ini.value(section, key), !raw.isEmpty else { return nil }
        let parts = raw.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 4, let x = Int(parts[0]), let y = Int(parts[1]), let w = Int(parts[2]), let h = Int(parts[3]) else {
            throw ConfigError("[\(section)] \(key)='\(raw)' no tiene el formato x,y,ancho,alto")
        }
        if w <= 0 || h <= 0 || x < 0 || y < 0 || x + w > monW || y + h > monH {
            throw ConfigError("[\(section)] zona \(key) se sale del monitor (\(monW)x\(monH))")
        }
        return Zone(name: key, x: x, y: y, w: w, h: h)
    }
}
