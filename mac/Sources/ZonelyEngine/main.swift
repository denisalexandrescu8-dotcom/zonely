import AppKit

// Programa de barra de menús: sin icono en el Dock ni ventana principal.
let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
