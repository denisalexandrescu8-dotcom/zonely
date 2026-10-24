import Foundation

/// Un atajo ya interpretado: modificadores y código de tecla virtual de macOS (los `kVK_*` de Carbon).
public struct HotkeyCombo: Equatable {
    public var control: Bool
    public var option: Bool
    public var shift: Bool
    public var command: Bool
    public var keyCode: UInt32

    public init(control: Bool, option: Bool, shift: Bool, command: Bool, keyCode: UInt32) {
        self.control = control
        self.option = option
        self.shift = shift
        self.command = command
        self.keyCode = keyCode
    }
}

public enum KeyCodes {
    /// Teclas por nombre (en minúsculas) → código de tecla virtual de macOS (distribución ANSI/ISO; son posiciones físicas).
    static let table: [String: UInt32] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13,
        "e": 14, "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "9": 25, "7": 26,
        "8": 28, "0": 29, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37, "j": 38, "k": 40, "n": 45, "m": 46,
        "enter": 36, "tab": 48, "space": 49, "backspace": 51, "esc": 53, "delete": 117, "insert": 114,
        "home": 115, "end": 119, "pgup": 116, "pgdn": 121,
        "left": 123, "right": 124, "down": 125, "up": 126,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97, "f7": 98, "f8": 100, "f9": 101, "f10": 109,
        "f11": 103, "f12": 111, "f13": 105, "f14": 107, "f15": 113, "f16": 106, "f17": 64, "f18": 79, "f19": 80, "f20": 90,
        "numpad0": 82, "numpad1": 83, "numpad2": 84, "numpad3": 85, "numpad4": 86, "numpad5": 87, "numpad6": 88,
        "numpad7": 89, "numpad8": 91, "numpad9": 92,
    ]

    /// Interpreta un atajo en formato AutoHotkey (`^!+Left`). Devuelve nil si no es válido o la tecla no existe en el Mac
    /// (por ejemplo F21–F24).
    public static func parse(_ text: String) -> HotkeyCombo? {
        guard HotkeyTable.isValid(text) else { return nil }
        let mods = text.prefix(while: { "#!^+".contains($0) })
        let key = String(text.dropFirst(mods.count)).lowercased()
        guard let code = table[key] else { return nil }
        return HotkeyCombo(control: mods.contains("^"), option: mods.contains("!"), shift: mods.contains("+"),
                           command: mods.contains("#"), keyCode: code)
    }
}
