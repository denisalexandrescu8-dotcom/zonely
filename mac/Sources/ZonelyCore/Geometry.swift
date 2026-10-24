import CoreGraphics
import Foundation

/// Geometría de zonas, sin AppKit para poder probarla en CI.
/// Todas las coordenadas son las de la API de Accesibilidad: origen arriba a la izquierda de la pantalla
/// principal, y la «y» crece hacia abajo.
public enum Geometry {
    /// Área útil de la pantalla principal (sin la barra de menús ni el Dock), en coordenadas de Accesibilidad.
    /// `frame` y `visibleFrame` son los de `NSScreen` (origen abajo a la izquierda).
    public static func usableRect(frame: CGRect, visibleFrame: CGRect) -> CGRect {
        CGRect(x: visibleFrame.minX - frame.minX,
               y: frame.maxY - visibleFrame.maxY,
               width: visibleFrame.width,
               height: visibleFrame.height)
    }

    /// Pasa un rectángulo de AppKit (origen abajo a la izquierda de la pantalla principal) a coordenadas de Accesibilidad
    /// (origen arriba a la izquierda de la pantalla principal). Sirve para cualquier pantalla, no solo la principal.
    public static func axRect(fromAppKit rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    /// Convierte una zona de `zones.ini` (píxeles del monitor de referencia) a un rectángulo del área útil real.
    /// Así las zonas valen aunque la pantalla no mida lo mismo que cuando se escribieron (y respetan la barra de menús).
    public static func rect(of zone: Zone, monitorWidth: Int, monitorHeight: Int, in usable: CGRect) -> CGRect {
        let sx = usable.width / CGFloat(max(1, monitorWidth))
        let sy = usable.height / CGFloat(max(1, monitorHeight))
        let x0 = (usable.minX + CGFloat(zone.x) * sx).rounded()
        let y0 = (usable.minY + CGFloat(zone.y) * sy).rounded()
        let x1 = (usable.minX + CGFloat(zone.right) * sx).rounded()
        let y1 = (usable.minY + CGFloat(zone.bottom) * sy).rounded()
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    /// Zonas de un perfil de izquierda a derecha.
    public static func zonesByX(_ profile: Profile) -> [Zone] {
        profile.zones.values.sorted { $0.x != $1.x ? $0.x < $1.x : $0.y < $1.y }
    }

    /// Nombre de la zona que contiene el centro de la ventana; si cae en un hueco o fuera, la más cercana (A si no hay ninguna),
    /// como `ZoneOf` en Windows.
    public static func zoneName(containing window: CGRect, profile: Profile, monitorWidth: Int, monitorHeight: Int, usable: CGRect) -> String {
        let cx = window.midX, cy = window.midY
        var best = "A"
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for zone in zonesByX(profile) {
            let r = rect(of: zone, monitorWidth: monitorWidth, monitorHeight: monitorHeight, in: usable)
            let dx = max(r.minX - cx, 0, cx - r.maxX), dy = max(r.minY - cy, 0, cy - r.maxY)
            if dx == 0 && dy == 0 { return zone.name }
            let d = dx * dx + dy * dy
            if d < bestDistance { bestDistance = d; best = zone.name }
        }
        return best
    }

    /// Zona vecina en una dirección (-1 izquierda, +1 derecha), sin salirse de los extremos.
    public static func neighbour(of name: String, direction: Int, profile: Profile) -> String {
        let ordered = zonesByX(profile)
        guard let i = ordered.firstIndex(where: { $0.name == name }) else { return ordered.first?.name ?? "A" }
        let j = min(ordered.count - 1, max(0, i + direction))
        return ordered[j].name
    }

    /// Mitad de arriba y de abajo de un rectángulo.
    public static func halves(of r: CGRect) -> (top: CGRect, bottom: CGRect) {
        let half = (r.height / 2).rounded()
        return (CGRect(x: r.minX, y: r.minY, width: r.width, height: half),
                CGRect(x: r.minX, y: r.minY + half, width: r.width, height: r.height - half))
    }

    /// Rectángulo de un tamaño dado centrado en otro (sin salirse por la izquierda/arriba).
    public static func centered(size: CGSize, in r: CGRect) -> CGRect {
        CGRect(x: r.minX + max(0, ((r.width - size.width) / 2).rounded()),
               y: r.minY + max(0, ((r.height - size.height) / 2).rounded()),
               width: size.width, height: size.height)
    }

    /// ¿Dos rectángulos coinciden con una tolerancia (en puntos)? La usa la comprobación tras colocar.
    public static func matches(_ a: CGRect, _ b: CGRect, tolerance: CGFloat = 2) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
