import AppKit
import ZonelyCore

/// Pantallas y la elegida para las zonas, en las coordenadas que usa la API de Accesibilidad
/// (origen arriba a la izquierda de la pantalla principal, «y» hacia abajo).
enum Screens {
    /// `[Monitor] Id` de zones.ini; vacío (o una pantalla que ya no está) = la principal.
    static var selectedId = ""

    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 1080
    }

    /// Identificador estable de una pantalla (el número de pantalla de macOS).
    static func id(of screen: NSScreen) -> String {
        let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return number.map { String($0.uint32Value) } ?? ""
    }

    /// La pantalla a la que se aplican las zonas.
    static var selected: NSScreen? {
        NSScreen.screens.first { id(of: $0) == selectedId } ?? NSScreen.screens.first
    }

    /// Área útil de la pantalla elegida (sin la barra de menús ni el Dock).
    static var usable: CGRect {
        guard let screen = selected else { return CGRect(x: 0, y: 0, width: 1920, height: 1080) }
        return usable(of: screen)
    }

    static func usable(of screen: NSScreen) -> CGRect {
        Geometry.axRect(fromAppKit: screen.visibleFrame, primaryHeight: primaryHeight)
    }

    /// Área útil de la pantalla que contiene el punto (la elegida si no cae en ninguna).
    static func usable(containing point: CGPoint) -> CGRect {
        for screen in NSScreen.screens where Geometry.axRect(fromAppKit: screen.frame, primaryHeight: primaryHeight).contains(point) {
            return usable(of: screen)
        }
        return usable
    }

    /// ¿Está el punto (en coordenadas de Accesibilidad) en la pantalla elegida?
    static func onSelected(_ point: CGPoint) -> Bool {
        guard let screen = selected else { return true }
        return Geometry.axRect(fromAppKit: screen.frame, primaryHeight: primaryHeight).contains(point)
    }

    /// Identificador de la pantalla que contiene el punto (coordenadas de Accesibilidad); nil si no cae en ninguna.
    static func id(containing point: CGPoint) -> String? {
        NSScreen.screens.first { Geometry.axRect(fromAppKit: $0.frame, primaryHeight: primaryHeight).contains(point) }.map { id(of: $0) }
    }

    /// Nombre de la pantalla (el que le da macOS), solo si hay más de una conectada.
    static func name(of id: String) -> String? {
        guard NSScreen.screens.count > 1 else { return nil }
        return NSScreen.screens.first { Screens.id(of: $0) == id }?.localizedName
    }

    /// Posición del cursor (origen arriba a la izquierda de la pantalla principal).
    static var mouse: CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }

    /// Pantallas conectadas, para el selector del panel (`state.json`). Tamaño en puntos, como las zonas.
    static func list() -> [[String: Any]] {
        NSScreen.screens.enumerated().map { index, screen in
            let frame = Geometry.axRect(fromAppKit: screen.frame, primaryHeight: primaryHeight)
            return ["id": id(of: screen), "name": screen.localizedName, "x": Int(frame.minX), "y": Int(frame.minY),
                    "w": Int(frame.width), "h": Int(frame.height), "primary": index == 0]
        }
    }
}
