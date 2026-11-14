import AppKit
import Carbon.HIToolbox

/// Raccourcis globaux via `RegisterEventHotKey`.
///
/// C'est volontairement l'API Carbon et pas un `CGEventTap` : elle n'observe pas
/// la frappe, elle réserve une combinaison auprès du système. L'app ne voit donc
/// jamais ce que l'utilisateur tape ailleurs, et aucune permission de saisie
/// n'est requise.
@MainActor
final class HotKeyManager: ObservableObject {
    static let shared = HotKeyManager()

    /// Ce qu'un raccourci déclenche. `release` n'est renseigné que pour les
    /// raccourcis « à maintenir » — l'aperçu d'ensemble, aujourd'hui.
    private struct Action {
        let press: () -> Void
        let release: (() -> Void)?
    }

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: Action] = [:]
    private var handler: EventHandlerRef?
    private var nextID: UInt32 = 1

    /// Combinaisons refusées par le système, en général parce qu'une autre app
    /// les a déjà réservées. On les remonte à l'UI pour le signaler.
    ///
    /// `@Published` et non un simple stockage : l'avertissement des réglages se
    /// lit sur cette liste, et sans publication il n'apparaissait — ou ne
    /// disparaissait — qu'au prochain redessin que quelque chose d'autre
    /// provoquait.
    @Published private(set) var rejected: [HotKey] = []

    private init() {}

    /// Réenregistre tout depuis les préférences. Appelé au lancement, après
    /// chaque modification d'un raccourci et quand l'effectif change de taille.
    func rebind() {
        unregisterAll()
        let prefs = Preferences.shared

        // Un emplacement par perso de l'effectif, pas plus : ⌘6 n'est pas
        // confisqué aux autres apps tant qu'il n'y a pas de sixième perso.
        for (slot, hotKey) in prefs.hotKeys.prefix(WindowManager.shared.effectif.count).enumerated() {
            guard let hotKey else { continue }
            register(hotKey) {
                UsageStore.shared.compter(.basculeRaccourci)
                WindowManager.shared.focus(slot: slot)
            }
        }
        // Un geste par raccourci, une ligne chacun : celui qu'on ajoute ne
        // s'oublie pas ici.
        let gestes: [(HotKey?, () -> Void)] = [
            (prefs.cycleNext, {
                UsageStore.shared.compter(.rotationRaccourci)
                WindowManager.shared.cycle(by: 1)
            }),
            (prefs.cyclePrevious, {
                UsageStore.shared.compter(.rotationRaccourci)
                WindowManager.shared.cycle(by: -1)
            }),
            (prefs.toggleAutoFocus, {
                Preferences.shared.basculerPassageAuto()
                FloatingBarController.shared.flashAutoFocusState()
            }),
            (prefs.toggleBar, { FloatingBarController.shared.toggle() }),
            (prefs.arrangeHotKey, { Task { await WindowArranger.shared.appliquerDerniere() } }),
            (prefs.sessionHotKey, { WindowManager.shared.lancerSession() }),
            (prefs.equipeSuivanteHotKey, { WindowManager.shared.equipeSuivante() }),
            (prefs.inviteHotKey, { InvitationClipboard.shared.copierSuivante() }),
            (prefs.paletteHotKey, { PalettePanel.shared.basculer() }),
            (prefs.zaapHotKey, { ZaapClipboard.shared.optimiser() }),
            (prefs.chasseHotKey, { ChassePanel.shared.basculer() }),
            (prefs.quetesHotKey, { QuetePanel.shared.basculer() }),
            (prefs.bossHotKey, { BossPanel.shared.basculer() }),
        ]
        for (hotKey, geste) in gestes {
            if let hotKey { register(hotKey, action: geste) }
        }
        // Le seul à maintenir : l'aperçu d'ensemble tant que la touche reste enfoncée.
        if let preview = prefs.previewHotKey {
            register(preview) {
                PreviewPanelController.shared.showGrid(WindowManager.shared.effectif)
            } onRelease: {
                PreviewPanelController.shared.hide()
            }
        }
    }

    @discardableResult
    func register(
        _ hotKey: HotKey,
        action: @escaping () -> Void,
        onRelease: (() -> Void)? = nil
    ) -> Bool {
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

        refs.append(ref)
        actions[id] = Action(press: action, release: onRelease)
        return true
    }

    func unregisterAll() {
        for ref in refs { UnregisterEventHotKey(ref) }
        refs.removeAll()
        actions.removeAll()
        rejected.removeAll()
    }

    fileprivate func perform(id: UInt32, released: Bool) {
        guard let action = actions[id] else { return }
        released ? action.release?() : action.press()
    }

    private func installHandlerIfNeeded() {
        guard handler == nil else { return }
        // Deux types d'évènement : l'appui, et le relâchement dont dépendent les
        // raccourcis à maintenir. Carbon n'émet pas de répétition automatique,
        // un appui prolongé ne donne donc bien qu'un « pressed » et un « released ».
        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                          eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                          eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventCallback, 2, &specs, nil, &handler)
    }
}

/// Constante de fichier plutôt que membre statique : le callback C ci-dessous
/// s'exécute hors du main actor et ne peut donc pas lire un membre isolé.
private let synfusSignature: OSType = 0x53_59_4E_46  // 'SYNF'

/// Callback C : il ne peut rien capturer, d'où le passage par le singleton.
private func hotKeyEventCallback(
    _: EventHandlerCallRef?,
    _ event: EventRef?,
    _: UnsafeMutableRawPointer?
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
    let released = GetEventKind(event) == UInt32(kEventHotKeyReleased)
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            HotKeyManager.shared.perform(id: id, released: released)
        }
    }
    return noErr
}
