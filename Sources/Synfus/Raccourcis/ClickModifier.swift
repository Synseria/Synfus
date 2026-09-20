import AppKit

/// La touche à tenir pendant un clic sur le jeu pour que Synfus passe au perso
/// suivant une fois le clic relâché.
///
/// **Le jeu reçoit le clic avec la touche dessus** — Synfus observe, il ne
/// réécrit rien. C'est ce qui a fait écarter ⌘ comme défaut : mesuré en jeu,
/// un ⌘-clic déplace le perso mais ne parle plus aux PNJ, le client ne le
/// traite pas comme un clic ordinaire. `fn` est le défaut parce que c'est la
/// seule touche qui ne veut rien dire pour le jeu ni pour macOS sur un clic.
/// Les autres restent proposées — un clavier sans `fn`, une habitude — en
/// sachant que ⇧ et ⌥ ont un sens dans Dofus et que ⌃-clic est un clic droit
/// pour macOS. Le diagnostic des réglages dit ce que macOS voit.
enum ClickModifier: String, Codable, CaseIterable, Identifiable {
    case fn
    case control
    case option
    case shift
    case command

    var id: String { rawValue }

    /// Libellé des réglages : le symbole, puis le nom — « fn » n'a pas de
    /// symbole, macOS le marque 🌐 sur les claviers récents.
    var label: String {
        switch self {
        case .fn: return "fn (🌐)"
        case .control: return "⌃ " + L("touche.controle")
        case .option: return "⌥ " + L("touche.option")
        case .shift: return "⇧ " + L("touche.majuscule")
        case .command: return "⌘ " + L("touche.commande")
        }
    }

    /// Rendu court, pour une phrase : « fn-clic », « ⌥-clic ».
    var symbol: String {
        switch self {
        case .fn: return "fn"
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .fn: return .function
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        case .command: return .command
        }
    }

    /// Les touches qu'un clic peut porter. Le verrouillage des majuscules n'en
    /// est pas une — c'est un état, pas un doigt posé —, et les drapeaux de
    /// pavé numérique ou d'aide ne concernent pas la souris.
    static let observed: NSEvent.ModifierFlags = [.function, .control, .option, .shift, .command]

    /// Vrai si cette touche est tenue, et elle seule. Un clic qui en porte
    /// une autre en plus — ⇧fn-clic — garde le sens que le jeu lui donne, et
    /// Synfus ne bouge pas : une combinaison inattendue n'est pas un ordre.
    func isHeldAlone(in flags: NSEvent.ModifierFlags) -> Bool {
        flags.intersection(Self.observed) == flag
    }

    /// Les touches tenues pendant un clic, pour le diagnostic des réglages —
    /// c'est ainsi qu'on vérifie que macOS voit bien `fn` sur ce clavier-là.
    static func describe(_ flags: NSEvent.ModifierFlags) -> String {
        let held = allCases.filter { flags.contains($0.flag) }
        return held.isEmpty ? L("touche.aucune") : held.map(\.symbol).joined()
    }
}
