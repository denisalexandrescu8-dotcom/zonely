import AppKit
import ZonelyCore

// Programa de barra de menús: sin icono en el Dock ni ventana principal. Solo puede haber uno en marcha
// (el panel intenta arrancarlo al abrirse; si ya hay uno, este termina sin hacer nada).
Paths.ensureDirectories()
guard SingleInstance.acquire(lockFile: Paths.dataDir.appendingPathComponent("engine.lock")) else { exit(0) }

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.delegate = appDelegate
application.setActivationPolicy(.accessory)
application.run()
