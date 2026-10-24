import Foundation

/// Crea `zones.ini` la primera vez, a partir de `zones.template.ini` y con los perfiles calculados
/// para el monitor principal. La misma regla está en lib/Paths.ahk (Windows) y panel/main.js:
/// si cambias una, cambia las tres.
public enum DefaultIni {
    /// Perfiles de fábrica para un monitor de w × h píxeles (zonas mínimas de 400 px).
    public static func profilesText(width w: Int, height h: Int) -> String {
        let minZone = 400
        var out = ""
        let uw = Int((Double(h) * 43.0 / 18.0).rounded())                       // pantalla 21:9 (3440×1440) + columna
        if uw >= minZone && w - uw >= minZone {
            out += "[Profile.ultrawide]\n; A = pantalla 21:9 a la izquierda, B = columna a la derecha\nA=0,0,\(uw),\(h)\nB=\(uw),0,\(w - uw),\(h)\n\n"
        }
        let half = w / 2
        if half >= minZone {
            out += "[Profile.dual]\n; Dos mitades iguales\nA=0,0,\(half),\(h)\nB=\(half),0,\(w - half),\(h)\n\n"
        }
        let c = Int((Double(h) * 16.0 / 9.0).rounded())                         // pantalla 16:9 en el centro
        let side = (w - c) / 2
        if side >= minZone {
            out += "[Profile.centrado]\n; Pantalla 16:9 en el centro (A) y una zona a cada lado (B derecha, C izquierda)\nA=\(side),0,\(c),\(h)\nB=\(side + c),0,\(w - side - c),\(h)\nC=0,0,\(side),\(h)\n\n"
        }
        out += "[Profile.normal]\n; Pantalla normal: sin zonas (no hay B). Ni atajos de colocación, ni encaje, ni vigilante.\nA=0,0,\(w),\(h)\n"
        return out
    }

    /// Texto completo de zones.ini para un monitor de w × h, a partir del texto de la plantilla.
    public static func render(template: String, width: Int, height: Int) -> String {
        template
            .replacingOccurrences(of: "{{WIDTH}}", with: String(width))
            .replacingOccurrences(of: "{{HEIGHT}}", with: String(height))
            .replacingOccurrences(of: "{{PROFILES}}", with: profilesText(width: width, height: height))
    }

    /// Crea zones.ini si no existe. `width`/`height`: tamaño del monitor principal.
    @discardableResult
    public static func createIfMissing(width: Int, height: Int, at url: URL = Paths.iniURL) -> Bool {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) { return false }
        guard let tpl = Paths.bundledFile("zones.template.ini"),
              let text = try? String(contentsOf: tpl, encoding: .utf8) else { return false }
        let ini = render(template: text, width: width, height: height)
        try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        return (try? ini.write(to: url, atomically: true, encoding: .utf8)) != nil
    }
}
