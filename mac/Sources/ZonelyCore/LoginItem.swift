import Darwin
import Foundation

/// Inicio con el sistema mediante un LaunchAgent del usuario (`~/Library/LaunchAgents/com.zonely.engine.plist`).
/// Es el equivalente del acceso directo en la carpeta de inicio de Windows.
public enum LoginItem {
    public static let label = "com.zonely.engine"

    public static var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(label).plist")
    }

    /// Contenido del .plist. La ruta del ejecutable se escapa para XML.
    public static func plistText(executable: String) -> String {
        let escaped = executable
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(label)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(escaped)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>ProcessType</key>
            <string>Interactive</string>
        </dict>
        </plist>

        """
    }

    public static func isEnabled() -> Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    /// Activa el inicio con el sistema para ese ejecutable.
    @discardableResult
    public static func enable(executable: String) -> Bool {
        let url = plistURL
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? plistText(executable: executable).write(to: url, atomically: true, encoding: .utf8)) != nil
    }

    public static func disable() {
        try? FileManager.default.removeItem(at: plistURL)
    }

    /// Si el inicio con el sistema está activo pero apunta a otra ruta (la app se movió o se actualizó), lo corrige.
    public static func refresh(executable: String) {
        guard isEnabled(), let current = try? String(contentsOf: plistURL, encoding: .utf8),
              current != plistText(executable: executable) else { return }
        enable(executable: executable)
    }
}

/// Solo una instancia del motor a la vez: un bloqueo de archivo que dura lo que dure el proceso.
public enum SingleInstance {
    private static var descriptor: Int32 = -1

    /// Devuelve false si ya hay otra instancia con el bloqueo.
    public static func acquire(lockFile: URL) -> Bool {
        let fd = open(lockFile.path, O_CREAT | O_RDWR, 0o644)
        if fd < 0 { return true }                                    // sin poder bloquear, mejor arrancar que no hacerlo
        if flock(fd, LOCK_EX | LOCK_NB) != 0 {
            close(fd)
            return false
        }
        descriptor = fd
        return true
    }
}
