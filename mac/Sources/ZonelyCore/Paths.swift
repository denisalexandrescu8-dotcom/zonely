import Foundation

/// Dónde se guardan los datos del usuario: `~/Library/Application Support/Zonely`
/// (`zones.ini`, `logs`, `ipc`). `ZONELY_DATA` cambia la carpeta (pruebas).
/// Es el equivalente de `%APPDATA%\Zonely` en Windows (lib/Paths.ahk).
public enum Paths {
    public static var dataDir: URL {
        if let custom = ProcessInfo.processInfo.environment["ZONELY_DATA"], !custom.isEmpty {
            return URL(fileURLWithPath: custom, isDirectory: true)
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Zonely", isDirectory: true)
    }

    public static var iniURL: URL { dataDir.appendingPathComponent("zones.ini") }
    public static var ipcDir: URL { dataDir.appendingPathComponent("ipc", isDirectory: true) }
    public static var logDir: URL { dataDir.appendingPathComponent("logs", isDirectory: true) }
    public static var logFile: URL { logDir.appendingPathComponent("gestor.log") }

    /// Crea las carpetas de datos si no existen.
    public static func ensureDirectories() {
        let fm = FileManager.default
        for dir in [dataDir, ipcDir, logDir] {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    /// Busca un archivo que viaja con la aplicación (`version.txt`, `zones.template.ini`):
    /// junto al ejecutable y, si no está, en las carpetas superiores (para ejecutar desde el código).
    public static func bundledFile(_ name: String) -> URL? {
        let fm = FileManager.default
        var dir = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0]))
            .resolvingSymlinksInPath().deletingLastPathComponent()
        for _ in 0..<8 {
            let candidate = dir.appendingPathComponent(name)
            if fm.fileExists(atPath: candidate.path) { return candidate }
            let resources = dir.deletingLastPathComponent().appendingPathComponent("Resources").appendingPathComponent(name)
            if fm.fileExists(atPath: resources.path) { return resources }
            let parent = dir.deletingLastPathComponent()
            if parent.path == dir.path { break }
            dir = parent
        }
        return nil
    }

    /// Versión de la aplicación (`version.txt`), o "?" si no se encuentra.
    public static func appVersion() -> String {
        guard let url = bundledFile("version.txt"), let text = try? String(contentsOf: url, encoding: .utf8) else { return "?" }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
