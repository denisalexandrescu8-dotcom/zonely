// Genera las tablas de textos de los motores a partir de i18n/engine.js:
//   lib/Strings.ahk                              (motor de Windows, AutoHotkey)
//   mac/Sources/ZonelyCore/Strings.swift         (motor de macOS)
// Uso:  node scripts/gen-strings.js
const fs = require('fs');
const path = require('path');
const { ORDER, ROWS } = require('../i18n/engine.js');
const root = path.join(__dirname, '..');

for (const row of ROWS) {
  if (row.length !== ORDER.length) throw new Error(`Fila incompleta: ${row[0]}`);
  const vars = (s) => (s.match(/\{\w+\}/g) || []).sort().join();
  for (const cell of row.slice(1)) if (vars(cell) !== vars(row[0])) throw new Error(`Datos distintos en «${row[0]}»`);
}

// ---- AutoHotkey v2 ----
const ahk = (s) => s.replace(/`/g, '``').replace(/"/g, '`"');
let a = `#Requires AutoHotkey v2.0
; ============================================================
;  Strings.ahk - Textos del motor en cada idioma. GENERADO por scripts/gen-strings.js desde i18n/engine.js: no editar a mano.
;  T("texto en español", "dato", valor, ...) devuelve el texto en el idioma elegido ([General] Language de zones.ini; auto = el del sistema).
; ============================================================

#Include %A_LineFile%\\..\\Paths.ahk      ; DataDir

StringsTable := Map(
`;
ORDER.slice(1).forEach((code, i) => {
  a += `    "${code}", Map(\n`;
  const lines = ROWS.map((r) => `        "${ahk(r[0])}", "${ahk(r[i + 1])}"`);
  a += lines.join(',\n') + `\n    )${i < ORDER.length - 2 ? ',' : ''}\n`;
});
a += `)

; Idioma de los textos: el de zones.ini o, en automático, el de Windows (A_Language es el LCID en hexadecimal).
ResolveLanguage() {
    chosen := "auto"
    try chosen := IniRead(DataDir "\\zones.ini", "General", "Language", "auto")
    if chosen != "auto" && StringsTable.Has(chosen) || chosen = "es"
        return chosen
    switch Integer("0x" A_Language) & 0x3FF {      ; identificador del idioma principal
        case 0x0A: return "es"
        case 0x0C: return "fr"
        case 0x07: return "de"
        case 0x16: return "pt"
        case 0x10: return "it"
        default: return "en"
    }
}
Language := ResolveLanguage()

T(text, vars*) {
    out := text
    if StringsTable.Has(Language) && StringsTable[Language].Has(text)
        out := StringsTable[Language][text]
    i := 1
    while i < vars.Length {
        out := StrReplace(out, "{" vars[i] "}", vars[i + 1])
        i += 2
    }
    return out
}
`;
fs.writeFileSync(path.join(root, 'lib', 'Strings.ahk'), a, 'utf8');

// ---- Swift ----
const sw = (s) => s.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
let s = `import Foundation

/// Textos del motor de macOS en cada idioma. GENERADO por scripts/gen-strings.js desde i18n/engine.js: no editar a mano.
/// \`tr("texto en español", ["dato": valor])\` devuelve el texto en el idioma elegido ([General] Language; auto = el del sistema).
public enum Strings {
    public static var language = "es"

    /// Idioma que toca: el elegido en zones.ini o, en automático, el primero de los idiomas preferidos del sistema.
    public static func resolve(chosen: String, system: [String] = Locale.preferredLanguages) -> String {
        let supported = ["es", "en", "fr", "de", "pt", "it"]
        if supported.contains(chosen) { return chosen }
        let first = (system.first ?? "en").prefix(2).lowercased()
        return supported.contains(first) ? first : "en"
    }

    public static func text(_ key: String, _ vars: [String: String] = [:]) -> String {
        var out = table[language]?[key] ?? key
        for (name, value) in vars { out = out.replacingOccurrences(of: "{\\(name)}", with: value) }
        return out
    }

    static let table: [String: [String: String]] = [
`;
ORDER.slice(1).forEach((code, i) => {
  s += `        "${code}": [\n`;
  s += ROWS.map((r) => `            "${sw(r[0])}": "${sw(r[i + 1])}"`).join(',\n') + `\n        ]${i < ORDER.length - 2 ? ',' : ''}\n`;
});
s += `    ]
}

/// Atajo: texto traducido (la clave es el texto en español).
public func tr(_ key: String, _ vars: [String: String] = [:]) -> String {
    Strings.text(key, vars)
}
`;
fs.writeFileSync(path.join(root, 'mac', 'Sources', 'ZonelyCore', 'Strings.swift'), s, 'utf8');
console.log(`Generado: ${ROWS.length} textos × ${ORDER.length - 1} idiomas`);
