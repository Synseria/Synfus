import Foundation

/// Le contrat entre Synfus et le plugin SynfusDeck : du JSON, une ligne par
/// message, sur un socket Unix. Ce fichier est la référence — le plugin,
/// binaire séparé, décode ces mêmes champs.
///
/// Tout est **descriptif**. Synfus pousse `DeckState` ; le plugin ne peut
/// demander que ce que la barre flottante sait faire (`DeckCommand`). Aucune
/// frappe, aucun chemin, aucune exécution ne passe par ici.
enum DeckProtocol {
    static let version = 1
}

/// Une touche à frapper, telle que le plugin la posera : keycode de position
/// et modificateurs au format Carbon (`controlKey`, `shiftKey`…).
struct DeckKey: Codable, Equatable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    init(_ hotKey: HotKey) {
        keyCode = hotKey.keyCode
        modifiers = hotKey.modifiers
    }
}

/// Une case de la barre affichée.
struct DeckCell: Codable, Equatable, Sendable {
    /// 1…10.
    let position: Int
    let sortId: Int?
    let nom: String?
    /// PNG en base64, ou rien si l'icône n'est pas connue.
    let icone: String?
    let touche: DeckKey?
}

/// Un perso, tel que le Stream Deck le montre : son nom, sa classe, l'emblème.
struct DeckPerso: Codable, Equatable, Sendable {
    let nom: String
    let classe: String?
    /// PNG en base64 de l'emblème de classe, s'il y en a un.
    let icone: String?
}

/// Ce que le Stream Deck doit montrer, à cet instant.
struct DeckState: Codable, Equatable, Sendable {
    var type = "etat"
    var version = DeckProtocol.version
    /// Un client Dofus est-il au premier plan ? Sinon, les sorts sont grisés.
    let dofusDevant: Bool
    let perso: String?
    let classe: String?
    /// Le perso devant, et ceux vers lesquels « suivant » et « précédent »
    /// mèneraient — une touche montre ce qu'elle fait.
    let persoActif: DeckPerso?
    let persoSuivant: DeckPerso?
    let persoPrecedent: DeckPerso?
    /// Barre affichée, 1-based, et nombre de barres.
    let barre: Int
    let barres: Int
    /// `nil` tant que la détection de combat n'a pas de verdict.
    let enCombat: Bool?
    let finDeTour: DeckKey?
    let corpsACorps: DeckKey?
    let cases: [DeckCell]
    /// Les commandes du jeu derrière la touche « Menu », dans l'ordre.
    let commandes: [DeckGameCommand]
}

/// Une commande du jeu telle que le plugin la dessine : nom, symbole SF, touche.
struct DeckGameCommand: Codable, Equatable, Sendable {
    let id: String
    let nom: String
    let symbole: String
    let touche: DeckKey?
}

/// Ce que le plugin peut demander.
struct DeckCommand: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case persoSuivant, persoPrecedent, perso, barreSuivante, barrePrecedente
        /// Ramène Dofus devant — le perso actif, ou le premier — sans changer de perso.
        case activer
    }
    let type: Kind
    /// Pour `perso` : l'emplacement, 0-based.
    let slot: Int?
}
