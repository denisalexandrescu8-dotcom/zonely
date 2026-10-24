import AppKit
import ZonelyCore

// MARK: - Paleta (la misma que el panel y el selector de Windows)

extension NSColor {
    convenience init(hex: Int, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    /// Mezcla este color con otro: t = 0 es este color, t = 1 el otro (simula la transparencia del panel).
    func mixed(with other: NSColor, _ t: CGFloat) -> NSColor {
        blended(withFraction: t, of: other) ?? other
    }
}

enum Palette {
    static let background = NSColor(hex: 0x0B0F17)
    static let screen = NSColor(hex: 0x05070D)
    static let row = NSColor(hex: 0x151A24)
    static let rowActive = NSColor(hex: 0x10203F)
    static let line = NSColor(hex: 0x1F2739)
    static let monitorLine = NSColor(hex: 0x2A3350)
    static let accent = NSColor(hex: 0x3B82F6)
    static let text = NSColor(hex: 0xEEF0F7)
    static let muted = NSColor(hex: 0xA3A9BD)
    static let faint = NSColor(hex: 0x6E768C)
    static let button = NSColor(hex: 0x1A2133)

    static func zone(_ name: String) -> NSColor {
        switch name {
        case "B": return NSColor(hex: 0x8B5CF6)
        case "C": return NSColor(hex: 0xF472B6)
        case "D": return NSColor(hex: 0x22D3EE)
        case "E": return NSColor(hex: 0xF59E0B)
        case "F": return NSColor(hex: 0x34D399)
        default: return NSColor(hex: 0x3B82F6)
        }
    }
}

// MARK: - Miniatura del monitor (igual que las tarjetas del panel)

final class MiniMonitorView: NSView {
    private let zones: [Zone]
    private let monitorWidth: Int
    private let monitorHeight: Int

    init(zones: [Zone], monitorWidth: Int, monitorHeight: Int = 0) {
        self.zones = zones
        self.monitorWidth = max(1, monitorWidth)
        // Sin alto conocido se toma el de la zona más baja, como hasta ahora (las zonas ocupaban todo el alto).
        self.monitorHeight = monitorHeight > 0 ? monitorHeight : max(1, zones.map { $0.y + $0.h }.max() ?? 1)
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let outer = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        Palette.screen.setFill()
        outer.fill()
        Palette.monitorLine.setStroke()
        outer.lineWidth = 1
        outer.stroke()
        let fontSize: CGFloat = bounds.height > 40 ? 15 : 11
        for zone in zones {
            let x = bounds.width * CGFloat(zone.x) / CGFloat(monitorWidth)
            let w = bounds.width * CGFloat(zone.w) / CGFloat(monitorWidth)
            let y = bounds.height * CGFloat(zone.y) / CGFloat(monitorHeight)
            let h = bounds.height * CGFloat(zone.h) / CGFloat(monitorHeight)
            let r = NSRect(x: x + 2.5, y: y + 2.5, width: max(4, w - 5), height: max(4, h - 5))
            let color = Palette.zone(zone.name)
            let path = NSBezierPath(roundedRect: r, xRadius: 6, yRadius: 6)
            Palette.screen.mixed(with: color, 0.13).setFill()
            path.fill()
            Palette.screen.mixed(with: color, 0.4).setStroke()
            path.lineWidth = 1
            path.stroke()
            let text = NSAttributedString(string: zone.name, attributes: [
                .font: NSFont.systemFont(ofSize: fontSize, weight: .bold), .foregroundColor: color,
            ])
            let size = text.size()
            text.draw(at: NSPoint(x: r.midX - size.width / 2, y: r.midY - size.height / 2))
        }
    }
}

// MARK: - Avisos breves (HUD)

/// Fondo redondeado y oscuro de las tarjetas flotantes.
final class CardView: NSView {
    init(size: NSSize) {
        super.init(frame: NSRect(origin: .zero, size: size))
        wantsLayer = true
        layer?.backgroundColor = Palette.background.cgColor
        layer?.cornerRadius = 18
        layer?.borderWidth = 1
        layer?.borderColor = Palette.line.cgColor
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) no se usa") }
}

enum Hud {
    private static var panel: NSPanel?
    private static var generation = 0

    /// Mensaje corto de una línea (el equivalente de los tooltips de Windows).
    static func showText(_ text: String) {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = Palette.text
        label.sizeToFit()
        let size = NSSize(width: label.frame.width + 44, height: 48)
        let card = CardView(size: size)
        label.frame.origin = NSPoint(x: 22, y: (size.height - label.frame.height) / 2)
        card.addSubview(label)
        present(card, duration: 1.6)
    }

    /// «Perfil aplicado» con la miniatura del perfil y su nombre.
    static func showProfile(_ profile: Profile, monitorWidth: Int) {
        let size = NSSize(width: 340, height: 76)
        let card = CardView(size: size)
        let mini = MiniMonitorView(zones: Geometry.zonesByX(profile), monitorWidth: monitorWidth)
        mini.frame = NSRect(x: 18, y: (size.height - 32) / 2, width: 112, height: 32)
        card.addSubview(mini)

        let caption = NSTextField(labelWithString: "Perfil aplicado")
        caption.font = NSFont.systemFont(ofSize: 11)
        caption.textColor = Palette.muted
        caption.frame = NSRect(x: 148, y: 40, width: 180, height: 16)
        card.addSubview(caption)

        let name = NSTextField(labelWithString: profile.name.prefix(1).uppercased() + profile.name.dropFirst())
        name.font = NSFont.systemFont(ofSize: 18, weight: .semibold)
        name.textColor = Palette.text
        name.frame = NSRect(x: 148, y: 14, width: 180, height: 24)
        card.addSubview(name)
        present(card, duration: 1.7)
    }

    /// Muestra la tarjeta abajo en el centro, sin robar el foco ni bloquear el ratón, con fundido de entrada y de salida.
    private static func present(_ card: CardView, duration: TimeInterval) {
        generation += 1
        let mine = generation
        panel?.orderOut(nil)

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: card.frame.size), styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.level = .statusBar
        p.ignoresMouseEvents = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.contentView = card
        let area = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        p.setFrameOrigin(NSPoint(x: area.midX - card.frame.width / 2, y: area.minY + 90))
        p.alphaValue = 0
        p.orderFrontRegardless()
        panel = p

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            p.animator().alphaValue = 1
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            guard mine == generation else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                p.animator().alphaValue = 0
            }, completionHandler: {
                if mine == generation { p.orderOut(nil) }
            })
        }
    }
}
