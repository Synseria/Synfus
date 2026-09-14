import CoreGraphics
import Foundation
import Network

/// L'état du plugin : les touches présentes sur le Stream Deck, l'état reçu de
/// Synfus, et les deux liaisons. Tout sur le main actor — c'est un petit
/// programme, un seul fil suffit.
@MainActor
final class Plugin {
    static let shared = Plugin()

    /// Une touche visible sur l'appareil.
    struct Key {
        let context: String
        let action: String
        let column: Int
        let row: Int
    }

    private var keys: [String: Key] = [:]
    private var state: DeckState?
    private var elgato: ElgatoSocket?
    private var synfus: SynfusSocket?

    private static let socketPath = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appending(path: "Synfus/streamdeck.sock").path

    func start(port: Int, pluginUUID: String, registerEvent: String) async {
        let elgato = ElgatoSocket(port: port) { [weak self] event in self?.handle(event) }
        self.elgato = elgato
        await elgato.connect(registerEvent: registerEvent, uuid: pluginUUID)

        let synfus = SynfusSocket(path: Self.socketPath) { [weak self] state in
            self?.state = state
            self?.render()
        } onDisconnect: { [weak self] in
            self?.state = nil
            self?.render()
        }
        self.synfus = synfus
        synfus.connect()
    }

    // MARK: - Évènements Stream Deck

    private func handle(_ event: StreamDeckEvent) {
        guard let context = event.context, let action = event.action else { return }
        switch event.event {
        case "willAppear":
            let c = event.payload?.coordinates
            keys[context] = Key(context: context, action: action, column: c?.column ?? 0, row: c?.row ?? 0)
            render()
        case "willDisappear":
            keys[context] = nil
            render()
        case "keyDown":
            press(context)
        default:
            break
        }
    }

    /// Les touches « sort », dans l'ordre de lecture (ligne puis colonne) :
    /// la première est la case 1, la suivante la case 2… Aucune configuration :
    /// la disposition physique dit tout.
    private var sortKeys: [Key] {
        keys.values.filter { $0.action == ActionID.sort }.sorted { ($0.row, $0.column) < ($1.row, $1.column) }
    }

    private func press(_ context: String) {
        guard let key = keys[context] else { return }
        switch key.action {
        case ActionID.sort:
            guard let state, state.dofusDevant,
                  let index = sortKeys.firstIndex(where: { $0.context == context }),
                  index < state.cases.count,
                  let touche = state.cases[index].touche
            else { elgato?.showAlert(context); return }
            Keystroke.press(touche)
        case ActionID.finDeTour:
            guard let state, state.dofusDevant, let touche = state.finDeTour
            else { elgato?.showAlert(context); return }
            Keystroke.press(touche)
        case ActionID.persoSuivant: send("persoSuivant")
        case ActionID.persoPrecedent: send("persoPrecedent")
        case ActionID.barreSuivante: send("barreSuivante")
        default: break
        }
    }

    private func send(_ type: String) {
        guard let synfus, synfus.isConnected else {
            for key in keys.values { elgato?.showAlert(key.context) }
            return
        }
        synfus.send(DeckCommand(type: type, slot: nil))
    }

    // MARK: - Affichage

    /// Redessine toutes les touches d'après l'état courant. Sans Synfus, les
    /// touches le disent ; Dofus derrière une autre app, les sorts sont grisés.
    private func render() {
        guard let elgato else { return }
        let sorts = sortKeys
        for key in keys.values {
            switch key.action {
            case ActionID.sort:
                let index = sorts.firstIndex { $0.context == key.context } ?? 0
                let cell = state.flatMap { index < $0.cases.count ? $0.cases[index] : nil }
                if let cell, let icone = cell.icone {
                    elgato.setImage(key.context, base64PNG: icone)
                    elgato.setTitle(key.context, "")
                } else {
                    elgato.setImage(key.context, base64PNG: nil)
                    elgato.setTitle(key.context, cell?.nom ?? (state == nil ? "Synfus\nabsent" : "\(index + 1)"))
                }
                elgato.setState(key.context, state?.dofusDevant == true ? 0 : 1)
            case ActionID.persoSuivant, ActionID.persoPrecedent:
                elgato.setTitle(key.context, state?.perso ?? "Synfus\nabsent")
            case ActionID.barreSuivante:
                elgato.setTitle(key.context, state.map { "Barre \($0.barre)/\($0.barres)" } ?? "Synfus\nabsent")
            case ActionID.finDeTour:
                elgato.setTitle(key.context, state?.finDeTour == nil ? "Fin de tour\n(à régler)" : "Fin de tour")
                elgato.setState(key.context, state?.enCombat == false ? 1 : 0)
            default:
                break
            }
        }
    }
}

/// La frappe elle-même — le seul endroit du projet qui émet un évènement
/// clavier, et il est hors de Synfus. Appui puis relâchement, avec les
/// modificateurs du jeu ; rien n'est retenu ni répété.
enum Keystroke {
    static func press(_ key: DeckKey) {
        var flags: CGEventFlags = []
        if key.modifiers & (1 << 8) != 0 { flags.insert(.maskCommand) }
        if key.modifiers & (1 << 9) != 0 { flags.insert(.maskShift) }
        if key.modifiers & (1 << 11) != 0 { flags.insert(.maskAlternate) }
        if key.modifiers & (1 << 12) != 0 { flags.insert(.maskControl) }
        let code = CGKeyCode(key.keyCode)
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: false)
        else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        usleep(12_000)
        up.post(tap: .cghidEventTap)
    }
}
