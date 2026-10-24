import CoreGraphics
import Foundation

/// Coincidencia de nombres de procesos/aplicaciones con las listas de `zones.ini` (`Games=`, `Processes=`).
/// En Windows los nombres llevan `.exe` (`RainbowSix.exe`); en Mac se comparan sin `.exe` ni `.app`, sin distinguir mayúsculas.
public enum NameMatch {
    public static func normalize(_ name: String) -> String {
        var n = name.trimmingCharacters(in: .whitespaces).lowercased()
        for suffix in [".exe", ".app"] where n.hasSuffix(suffix) { n = String(n.dropLast(suffix.count)) }
        return n
    }

    /// ¿Alguno de los nombres de la aplicación (nombre visible, ejecutable, identificador) está en la lista?
    public static func matches(candidates: [String], list: [String]) -> Bool {
        let wanted = Set(list.map(normalize).filter { !$0.isEmpty })
        if wanted.isEmpty { return false }
        return candidates.contains { wanted.contains(normalize($0)) }
    }
}

public extension Geometry {
    /// Pasa un rectángulo de coordenadas de Accesibilidad (origen arriba a la izquierda) a las de AppKit (abajo a la izquierda).
    static func appKitRect(fromAX r: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: r.minX, y: primaryHeight - r.maxY, width: r.width, height: r.height)
    }

    /// ¿Una ventana ocupa (casi) toda el área útil? Es lo que hace «maximizar» (el botón verde con Opción, o el zoom).
    static func isMaximized(_ frame: CGRect, in usable: CGRect, coverage: CGFloat = 0.96) -> Bool {
        frame.width >= usable.width * coverage && frame.height >= usable.height * coverage
    }

    /// ¿Se ha salido la ventana de su zona (más allá de la tolerancia)?
    static func isOutside(_ frame: CGRect, of zone: CGRect, tolerance: CGFloat = 10) -> Bool {
        frame.minX < zone.minX - tolerance || frame.minY < zone.minY - tolerance
            || frame.maxX > zone.maxX + tolerance || frame.maxY > zone.maxY + tolerance
    }

    /// Zona (y su rectángulo) a la que encajaría una ventana soltada con el cursor en `point`, como el encaje de Windows:
    /// la zona cuyo borde izquierdo queda a la izquierda del cursor y, en la zona B con `halves`, el tercio superior = mitad
    /// de arriba, el inferior = mitad de abajo y el centro = zona entera.
    static func snapTarget(at point: CGPoint, profile: Profile, monitorWidth: Int, monitorHeight: Int, usable: CGRect, halves: Bool)
        -> (zone: String, rect: CGRect)? {
        let ordered = zonesByX(profile)
        guard var chosen = ordered.first else { return nil }
        for zone in ordered where point.x >= rect(of: zone, monitorWidth: monitorWidth, monitorHeight: monitorHeight, in: usable).minX {
            chosen = zone
        }
        var target = rect(of: chosen, monitorWidth: monitorWidth, monitorHeight: monitorHeight, in: usable)
        if chosen.name == "B" && halves && target.height > 0 {
            let rel = (point.y - target.minY) / target.height
            let (top, bottom) = Geometry.halves(of: target)
            if rel < 0.33 { target = top } else if rel > 0.67 { target = bottom }
        }
        return (chosen.name, target)
    }

    /// Zonas que hay que oscurecer cuando la ventana activa está en `active`: todas las demás, como «A+C».
    static func otherZones(than active: String, in profile: Profile) -> String {
        zonesByX(profile).map { $0.name }.filter { $0 != active }.sorted().joined(separator: "+")
    }
}
