import AppKit
import ZonelyCore

/// Datos de la pantalla principal en las coordenadas que usa la API de Accesibilidad.
enum Screens {
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 1080
    }

    /// Área útil de la pantalla principal (sin la barra de menús ni el Dock).
    static var usable: CGRect {
        guard let screen = NSScreen.screens.first else { return CGRect(x: 0, y: 0, width: 1920, height: 1080) }
        return Geometry.usableRect(frame: screen.frame, visibleFrame: screen.visibleFrame)
    }

    /// Posición del cursor (origen arriba a la izquierda de la pantalla principal).
    static var mouse: CGPoint {
        let p = NSEvent.mouseLocation
        return CGPoint(x: p.x, y: primaryHeight - p.y)
    }
}
