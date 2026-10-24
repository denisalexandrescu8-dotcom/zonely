import AppKit
import ApplicationServices

/// Una ventana de otra aplicación, manejada con la API de Accesibilidad.
struct ForeignWindow {
    let element: AXUIElement
    let app: NSRunningApplication

    var processName: String { app.localizedName ?? app.bundleIdentifier ?? "?" }

    /// Posición y tamaño actuales (coordenadas de Accesibilidad: origen arriba a la izquierda de la pantalla principal).
    var frame: CGRect? {
        var pos: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &pos) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let posValue = pos, let sizeValue = size else { return nil }
        var point = CGPoint.zero
        var dims = CGSize.zero
        guard AXValueGetValue(posValue as! AXValue, .cgPoint, &point),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &dims) else { return nil }
        return CGRect(origin: point, size: dims)
    }

    /// Coloca la ventana. Se hace en tres pasos (posición, tamaño, posición) porque algunas apps ajustan el tamaño al moverse.
    @discardableResult
    func setFrame(_ rect: CGRect) -> Bool {
        var origin = rect.origin
        var dims = rect.size
        guard let posValue = AXValueCreate(.cgPoint, &origin), let sizeValue = AXValueCreate(.cgSize, &dims) else { return false }
        let a = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        let b = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let c = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, posValue)
        return a == .success && b == .success && c == .success
    }

    var isFullScreen: Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXFullScreen" as CFString, &value) == .success, let v = value else { return false }
        return (v as? Bool) ?? false
    }

    @discardableResult
    func setFullScreen(_ on: Bool) -> Bool {
        AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, (on ? kCFBooleanTrue : kCFBooleanFalse) as CFTypeRef) == .success
    }

    var isMinimized: Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXMinimizedAttribute as CFString, &value) == .success, let v = value else { return false }
        return (v as? Bool) ?? false
    }

    func sameWindow(as other: ForeignWindow) -> Bool {
        CFEqual(element, other.element)
    }
}

enum Accessibility {
    /// ¿Tiene Zonely el permiso de Accesibilidad? Con `prompt` pide el permiso al sistema si falta.
    static func isTrusted(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([key: prompt] as CFDictionary)
    }

    /// Abre el panel de Accesibilidad de Ajustes del Sistema.
    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// La ventana en primer plano de la aplicación activa (nunca una ventana de Zonely).
    static func focusedWindow() -> ForeignWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        let application = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let window = value else { return nil }
        return ForeignWindow(element: window as! AXUIElement, app: app)
    }
}
