// swift-tools-version:5.9
import PackageDescription

// Motor de Zonely para macOS (en Swift). El panel de control es el mismo de Windows (Electron, carpeta panel/):
// panel y motor se hablan por los mismos ficheros (zones.ini, ipc/state.json, ipc/cmd.txt, ipc/hotkeys.json).
let package = Package(
    name: "Zonely",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ZonelyEngine", targets: ["ZonelyEngine"]),
    ],
    targets: [
        // Lógica sin interfaz: rutas, lector de zones.ini, configuración, IPC. Se prueba en CI.
        .target(name: "ZonelyCore"),
        // Programa de la barra de menús: usa ZonelyCore y AppKit.
        .executableTarget(name: "ZonelyEngine", dependencies: ["ZonelyCore"]),
        .testTarget(name: "ZonelyCoreTests", dependencies: ["ZonelyCore"]),
    ]
)
