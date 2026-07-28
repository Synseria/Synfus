import AppKit
import Carbon.HIToolbox

/// Raccourcis globaux via `RegisterEventHotKey`.
///
/// C'est volontairement l'API Carbon et pas un `CGEventTap` : elle n'observe pas
/// la frappe, elle réserve une combinaison auprès du système. L'app ne voit donc
/// jamais ce que l'utilisateur tape ailleurs, et aucune permission de saisie
/// n'est requise.
@MainActor
final class HotKeyManager {
    static let shared = HotKeyManager()

    private struct Entry {
        let ref: EventHotKeyRef
        let id: UInt32
    }

    private var entries: [Entry] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// Combinaisons refusées par le système, en général parce qu'une autre app
    /// les a déjà réservées. On les remonte à l'UI pour le signaler.
    private(set) var rejected: [HotKey] = []

    private init() {}

    /// Réenregistre tout depuis les préférences. Appelé au lancement et après
    /// chaque modification d'un raccourci.
    func rebind() {
        unregisterAll()
        let prefs = Preferences.shared

        for (slot, hotKey) in prefs.hotKeys.enumerated() {
            guard let hotKey else { continue }
            register(hotKey) {
                WindowManager.shared.focus(slot: slot)
            }
        }
        if let next = prefs.cycleNext {
            register(next) { WindowManager.shared.cycle(by: 1) }
        }
        if let previous = prefs.cyclePrevious {
            register(previous) { WindowManager.shared.cycle(by: -1) }
        }
        if let toggle = prefs.toggleAutoFocus {
            register(toggle) {
                let prefs = Preferences.shared
                prefs.attentionAction = prefs.attentionAction == .focus ? .highlight : .focus
                FloatingBarController.shared.flashAutoFocusState()
            }
        }
    }

    @discardableResult
    func register(_ hotKey: HotKey, action: @escaping () -> Void) -> Bool {
        installHandlerIfNeeded()

        let id = nextID
        nextID += 1

        var ref: EventHotKeyRef?
        let eventID = EventHotKeyID(signature: synfusSignature, id: id)
        let status = RegisterEventHotKey(
            hotKey.keyCode,
            hotKey.modifiers,
            eventID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref else {
            rejected.append(hotKey)
            return false
        }

        entries.append(Entry(ref: ref, id: id))
        actions[id] = action
        return true
    }

    func unregisterAll() {
        for entry in entries { UnregisterEventHotKey(entry.ref) }
        entries.removeAll()
        actions.removeAll()
        rejected.removeAll()
    }

    fileprivate func perform(id: UInt32) {
        actions[id]?()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventCallback, 1, &spec, nil, &handler)
    }
}

/// Constante de fichier plutôt que membre statique : le callback C ci-dessous
/// s'exécute hors du main actor et ne peut donc pas lire un membre isolé.
private let synfusSignature: OSType = 0x53_59_4E_46  // 'SYNF'

/// Callback C : il ne peut rien capturer, d'où le passage par le singleton.
private func hotKeyEventCallback(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    var eventID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &eventID
    )
    guard status == noErr, eventID.signature == synfusSignature else { return status }

    let id = eventID.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            HotKeyManager.shared.perform(id: id)
        }
    }
    return noErr
}
