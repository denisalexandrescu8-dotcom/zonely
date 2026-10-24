import Foundation

/// Registro de actividad en `logs/gestor.log`, con el mismo formato que el motor de Windows:
/// `2026-10-24 12:00:00 [motor] INFO mensaje`.
public enum Log {
    private static let queue = DispatchQueue(label: "zonely.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    public static func write(_ message: String, level: String = "INFO", source: String = "motor") {
        let clean = message.replacingOccurrences(of: "\n", with: " ").replacingOccurrences(of: "\r", with: " ")
        queue.sync {
            let line = "\(formatter.string(from: Date())) [\(source)] \(level) \(clean)\n"
            Paths.ensureDirectories()
            guard let data = line.data(using: .utf8) else { return }
            if let handle = try? FileHandle(forWritingTo: Paths.logFile) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: Paths.logFile)
            }
        }
    }
}
