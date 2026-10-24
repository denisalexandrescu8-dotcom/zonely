import Foundation
import ZonelyCore

/// Actualizaciones en segundo plano: el motor lanza «Zonely --background-update» (el panel, sin ventana) a los pocos
/// minutos de arrancar y cada 6 horas. Ese proceso mira si hay una versión nueva en GitHub, la descarga, la instala
/// y vuelve a arrancar el motor; si `[General] AutoUpdate=0`, en vez de instalar pregunta una vez por versión. Solo existe en la app instalada.
final class BackgroundUpdates {
    private var first: Timer?
    private var periodic: Timer?

    /// El ejecutable del panel dentro de Zonely.app (el motor vive en Contents/Resources, el panel en Contents/MacOS).
    private var panelExecutable: URL? {
        guard let engine = Bundle.main.executablePath, engine.contains(".app/Contents/Resources/") else { return nil }
        let contents = URL(fileURLWithPath: engine).deletingLastPathComponent().deletingLastPathComponent()
        let panel = contents.appendingPathComponent("MacOS/Zonely")
        return FileManager.default.isExecutableFile(atPath: panel.path) ? panel : nil
    }

    func start() {
        guard panelExecutable != nil else { return }
        first = Timer.scheduledTimer(withTimeInterval: 120, repeats: false) { [weak self] _ in
            self?.run()
            self?.periodic = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.run() }
        }
    }

    private func run() {
        guard let executable = panelExecutable else { return }
        let process = Process()
        process.executableURL = executable
        process.arguments = ["--background-update"]
        do {
            try process.run()
        } catch {
            Log.write("No pude lanzar la comprobación de actualizaciones: \(error)", level: "WARN")
        }
    }
}
