import Carbon.HIToolbox
import ZonelyCore

/// Atajos globales con Carbon (`RegisterEventHotKey`): no piden ningún permiso y funcionan con cualquier app en primer plano.
final class HotkeyCenter {
    /// Para que la función C de Carbon encuentre el objeto (no puede capturar contexto).
    fileprivate static weak var current: HotkeyCenter?

    var onAction: ((String) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: String] = [:]
    private var handler: EventHandlerRef?

    init() {
        HotkeyCenter.current = self
        installHandler()
    }

    /// Registra los atajos (quitando los anteriores). Devuelve las filas con el motivo si alguno falló,
    /// para publicarlas en hotkeys.json y que el panel lo muestre.
    func register(_ rows: [HotkeyRow]) -> [HotkeyRow] {
        unregisterAll()
        var result: [HotkeyRow] = []
        for (index, row) in rows.enumerated() {
            guard let combo = KeyCodes.parse(row.key) else {
                result.append(HotkeyRow(def: row.def, key: row.key, error: row.error.isEmpty ? "Esa tecla no existe en el Mac" : row.error))
                continue
            }
            var modifiers: UInt32 = 0
            if combo.command { modifiers |= UInt32(cmdKey) }
            if combo.option { modifiers |= UInt32(optionKey) }
            if combo.control { modifiers |= UInt32(controlKey) }
            if combo.shift { modifiers |= UInt32(shiftKey) }
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(combo.keyCode, modifiers, EventHotKeyID(signature: OSType(0x5A4F4E59), id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr, let ref = ref {
                refs.append(ref)
                actions[id] = row.def.id
                result.append(row)
            } else {
                result.append(HotkeyRow(def: row.def, key: row.key, error: "No se pudo registrar: lo usa el sistema u otra app"))
            }
        }
        return result
    }

    func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        if let action = actions[id] { onAction?(action) }
    }

    private func installHandler() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                           nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            if status == noErr { HotkeyCenter.current?.fire(hotKeyID.id) }
            return noErr
        }, 1, &spec, nil, &handler)
    }
}
