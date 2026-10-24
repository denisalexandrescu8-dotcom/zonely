import AppKit
import ZonelyCore

/// Ventana sin bordes del selector de perfiles: acepta el teclado para cerrar con Esc.
final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { close() } else { super.keyDown(with: event) }       // Esc
    }
}

/// Una fila del selector: miniatura, nombre, reparto en puntos y en %, y el botón Aplicar. Un clic en cualquier parte la aplica.
final class PickerRowView: NSView {
    private let profile: Profile
    private let monitorWidth: Int
    private let isCurrent: Bool
    private let onSelect: () -> Void

    init(profile: Profile, monitorWidth: Int, isCurrent: Bool, size: NSSize, onSelect: @escaping () -> Void) {
        self.profile = profile
        self.monitorWidth = monitorWidth
        self.isCurrent = isCurrent
        self.onSelect = onSelect
        super.init(frame: NSRect(origin: .zero, size: size))
        let mini = MiniMonitorView(zones: Geometry.zonesByX(profile), monitorWidth: monitorWidth)
        mini.frame = NSRect(x: 16, y: (size.height - 65) / 2, width: 230, height: 65)
        addSubview(mini)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override var isFlipped: Bool { true }

    override func mouseDown(with event: NSEvent) { onSelect() }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }

    private func percent(_ w: Int) -> String {
        let v = (Double(w) / Double(max(1, monitorWidth)) * 1000).rounded() / 10
        return v == v.rounded() ? "\(Int(v)) %" : "\(v) %"
    }

    private func draw(_ text: String, at point: NSPoint, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
        NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color])
            .draw(at: point)
    }

    override func draw(_ dirtyRect: NSRect) {
        let border = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 20, yRadius: 20)
        (isCurrent ? Palette.rowActive : Palette.row).setFill()
        border.fill()
        (isCurrent ? Palette.accent : Palette.line).setStroke()
        border.lineWidth = isCurrent ? 2 : 1
        border.stroke()

        let zones = Geometry.zonesByX(profile)
        let name = profile.name.prefix(1).uppercased() + profile.name.dropFirst()
        let textX: CGFloat = 16 + 230 + 22
        draw(name, at: NSPoint(x: textX, y: 12), size: 17, weight: .semibold, color: Palette.text)
        if profile.isZoned {
            draw(zones.map { "\($0.w) px" }.joined(separator: " + "), at: NSPoint(x: textX, y: 38), size: 13, weight: .regular, color: Palette.muted)
            draw(zones.map { percent($0.w) }.joined(separator: "  +  "), at: NSPoint(x: textX, y: 58), size: 11, weight: .regular, color: Palette.faint)
        } else {
            draw(tr("Pantalla completa, sin zonas"), at: NSPoint(x: textX, y: 38), size: 13, weight: .regular, color: Palette.muted)
        }
        if isCurrent {
            draw("●  Activo ahora", at: NSPoint(x: textX, y: 76), size: 11, weight: .semibold, color: NSColor(hex: 0x5B9BFF))
        }

        let button = NSRect(x: bounds.width - 112 - 16, y: (bounds.height - 40) / 2, width: 112, height: 40)
        let buttonPath = NSBezierPath(roundedRect: button, xRadius: 14, yRadius: 14)
        (isCurrent ? Palette.accent : Palette.button).setFill()
        buttonPath.fill()
        let label = NSAttributedString(string: isCurrent ? tr("Aplicado") : tr("Aplicar"), attributes: [
            .font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: isCurrent ? NSColor.white : Palette.muted,
        ])
        let size = label.size()
        label.draw(at: NSPoint(x: button.midX - size.width / 2, y: button.midY - size.height / 2))
    }
}

/// Fondo del selector: título, subtítulo, la ✕ de cerrar y el pie.
final class PickerContentView: NSView {
    var onClose: (() -> Void)?
    var monitorName: String?
    private let closeRect = NSRect(x: 612, y: 22, width: 28, height: 28)

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 22, yRadius: 22)
        Palette.background.setFill()
        path.fill()
        Palette.line.setStroke()
        path.stroke()

        // Icono de Zonely: dos bloques a la izquierda y uno alto a la derecha.
        for (rect, color) in [(NSRect(x: 26, y: 25, width: 23, height: 17), 0x3B82F6), (NSRect(x: 26, y: 46, width: 23, height: 17), 0x6B76F6),
                              (NSRect(x: 53, y: 25, width: 17, height: 38), 0x8B5CF6)] {
            NSColor(hex: color).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6).fill()
        }
        NSAttributedString(string: tr("Elegir perfil"), attributes: [.font: NSFont.systemFont(ofSize: 22, weight: .semibold), .foregroundColor: Palette.text])
            .draw(at: NSPoint(x: 86, y: 20))
        NSAttributedString(string: monitorName.map { tr("Monitor: {name}", ["name": $0]) } ?? tr("Aplica una distribución de zonas a tu pantalla."), attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: Palette.muted])
            .draw(at: NSPoint(x: 86, y: 52))
        NSAttributedString(string: "✕", attributes: [.font: NSFont.systemFont(ofSize: 16), .foregroundColor: Palette.muted])
            .draw(at: NSPoint(x: closeRect.minX + 6, y: closeRect.minY + 3))
        NSAttributedString(string: tr("Esc para cerrar"), attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: Palette.faint])
            .draw(at: NSPoint(x: 24, y: bounds.height - 30))
    }

    override func mouseDown(with event: NSEvent) {
        if closeRect.insetBy(dx: -6, dy: -6).contains(convert(event.locationInWindow, from: nil)) { onClose?() }
    }
}

/// Selector de perfiles (⌃⌥P): una fila por perfil; un clic lo aplica.
final class ProfilePicker {
    private var panel: PickerPanel?

    var isOpen: Bool { panel?.isVisible ?? false }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }

    func show(profiles: [Profile], current: String, monitorWidth: Int, monitorName: String? = nil, onSelect: @escaping (String) -> Void) {
        close()
        let width: CGFloat = 660
        let rowHeight: CGFloat = 98
        let gap: CGFloat = 10
        let height = 92 + CGFloat(profiles.count) * (rowHeight + gap) + 40

        let content = PickerContentView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        content.onClose = { [weak self] in self?.close() }
        content.monitorName = monitorName
        for (i, profile) in profiles.enumerated() {
            let row = PickerRowView(profile: profile, monitorWidth: monitorWidth, isCurrent: profile.name == current,
                                    size: NSSize(width: width - 48, height: rowHeight)) { [weak self] in
                self?.close()
                onSelect(profile.name)
            }
            row.frame.origin = NSPoint(x: 24, y: 92 + CGFloat(i) * (rowHeight + gap))
            content.addSubview(row)
        }

        let p = PickerPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.borderless],
                            backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle]
        p.contentView = content
        let area = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        p.setFrameOrigin(NSPoint(x: area.midX - width / 2, y: area.midY - height / 2))
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
        panel = p
    }
}
