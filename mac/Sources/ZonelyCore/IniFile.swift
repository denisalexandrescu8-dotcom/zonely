import Foundation

/// Lector de `zones.ini` (solo lectura: la escritura la hace el panel, que conserva los comentarios).
/// Ignora líneas vacías y comentarios (`;` o `#` al principio) y los comentarios al final de un valor (` ;`).
public struct IniFile {
    public private(set) var sections: [String: [String: String]] = [:]
    public private(set) var sectionOrder: [String] = []

    public init(text: String) {
        var current: String?
        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix(";") || line.hasPrefix("#") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = String(line.dropFirst().dropLast())
                current = name
                if sections[name] == nil {
                    sections[name] = [:]
                    sectionOrder.append(name)
                }
                continue
            }
            guard let section = current, let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces)
            var value = String(line[line.index(after: eq)...])
            if let comment = value.range(of: " ;") { value = String(value[..<comment.lowerBound]) }
            sections[section]?[key] = value.trimmingCharacters(in: .whitespaces)
        }
    }

    public init(contentsOf url: URL) throws {
        self.init(text: try String(contentsOf: url, encoding: .utf8))
    }

    public func value(_ section: String, _ key: String) -> String? {
        sections[section]?[key]
    }

    public func string(_ section: String, _ key: String, default fallback: String) -> String {
        let v = value(section, key) ?? ""
        return v.isEmpty ? fallback : v
    }

    public func int(_ section: String, _ key: String, default fallback: Int) -> Int {
        Int(value(section, key) ?? "") ?? fallback
    }

    public func bool(_ section: String, _ key: String, default fallback: Bool) -> Bool {
        guard let v = value(section, key), let n = Int(v) else { return fallback }
        return n == 1
    }

    /// Lista separada por comas (vacía si no hay nada).
    public func list(_ section: String, _ key: String) -> [String] {
        (value(section, key) ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
