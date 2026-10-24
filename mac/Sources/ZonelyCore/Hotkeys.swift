import Foundation

/// Una acción con atajo. El formato del atajo es el mismo que usa el panel y `zones.ini`:
/// `#` = Win/Comando, `!` = Alt/Opción, `^` = Ctrl, `+` = Mayús, y después la tecla (z, Left, F5, BackSpace…).
public struct HotkeyDef: Equatable {
    public let id: String
    public let label: String
    public let defaultKey: String

    public init(id: String, label: String, defaultKey: String) {
        self.id = id
        self.label = label
        self.defaultKey = defaultKey
    }
}

/// Fila de `ipc/hotkeys.json`: lo que se ha registrado de verdad y el motivo si falló.
public struct HotkeyRow: Equatable {
    public let def: HotkeyDef
    public let key: String
    public let error: String

    public init(def: HotkeyDef, key: String, error: String) {
        self.def = def
        self.key = key
        self.error = error
    }
}

public enum HotkeyTable {
    /// Mismas acciones y etiquetas que en Windows. Atajos de fábrica en macOS: Control + Opción (⌃⌥) + la tecla,
    /// porque ⌘⌥ choca con atajos del sistema.
    public static let all: [HotkeyDef] = [
        HotkeyDef(id: "ZoneMaximize", label: "Llenar la zona actual", defaultKey: "^!z"),
        HotkeyDef(id: "MoveToA", label: "Mover a la zona de la izquierda", defaultKey: "^!Left"),
        HotkeyDef(id: "MoveToB", label: "Mover a la zona de la derecha", defaultKey: "^!Right"),
        HotkeyDef(id: "HalfTop", label: "Mitad superior (zona B)", defaultKey: "^!Up"),
        HotkeyDef(id: "HalfBottom", label: "Mitad inferior (zona B)", defaultKey: "^!Down"),
        HotkeyDef(id: "GameMode", label: "Modo juego (llenar la zona del juego)", defaultKey: "^!g"),
        HotkeyDef(id: "GameModeKeep", label: "Modo juego conservando el tamaño", defaultKey: "^!+g"),
        HotkeyDef(id: "CenterA", label: "Centrar en la zona izquierda sin cambiar el tamaño", defaultKey: "^!+Left"),
        HotkeyDef(id: "CenterB", label: "Centrar en la zona derecha sin cambiar el tamaño", defaultKey: "^!+Right"),
        HotkeyDef(id: "RestoreOriginal", label: "Devolver la ventana a su tamaño original", defaultKey: "^!q"),
        HotkeyDef(id: "Undo", label: "Deshacer la última colocación", defaultKey: "^!BackSpace"),
        HotkeyDef(id: "SwitchProfile", label: "Elegir perfil (abre un selector)", defaultKey: "^!p"),
        HotkeyDef(id: "ToggleWatcher", label: "Activar/desactivar el vigilante", defaultKey: "^!w"),
        HotkeyDef(id: "ToggleDim", label: "Capa oscura sobre la otra zona", defaultKey: "^!o"),
    ]

    /// ¿Tiene sentido como atajo? Al menos un modificador (# ! ^ +) y una tecla conocida.
    public static func isValid(_ s: String) -> Bool {
        let mods = s.prefix(while: { "#!^+".contains($0) })
        guard (1...4).contains(mods.count) else { return false }
        let key = String(s.dropFirst(mods.count)).lowercased()
        if key.count == 1, key.first!.isLetter || key.first!.isNumber { return true }
        if let n = Int(key.dropFirst()), key.hasPrefix("f"), (1...24).contains(n) { return true }
        if let n = Int(key.dropFirst(6)), key.hasPrefix("numpad"), (0...9).contains(n) { return true }
        return ["left", "right", "up", "down", "backspace", "space", "tab", "enter", "esc", "delete", "insert",
                "home", "end", "pgup", "pgdn"].contains(key)
    }

    /// Atajo efectivo de cada acción: el del usuario si es válido y no choca con otro; si no, el de fábrica.
    public static func resolve(overrides: [String: String]) -> [HotkeyRow] {
        var used: [String: String] = [:]
        var rows: [HotkeyRow] = []
        for def in all {
            var key = overrides[def.id] ?? def.defaultKey
            var error = ""
            if !isValid(key) {
                error = "Atajo no válido: \(key)"
                key = def.defaultKey
            }
            if let other = used[key.lowercased()] {
                error = "Choca con «\(other)»"
                key = def.defaultKey
            }
            used[key.lowercased()] = def.label
            rows.append(HotkeyRow(def: def, key: key, error: error))
        }
        return rows
    }
}
