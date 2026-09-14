import Foundation

/// Le contrat entre Synfus et le plugin SynfusDeck : du JSON, une ligne par
/// message, sur un socket Unix. Ce fichier est la référence — le plugin,
/// binaire séparé, décode ces mêmes champs.
///
/// Tout est **descriptif**, et **Synfus compose** : il pousse une `DeckPage`
/// par taille de grille — pour chaque touche, l'image, le titre, ce qu'un
/// appui court et un appui long font. Le plugin ne décide de rien : il rend,
/// frappe la touche qu'on lui a donnée, ou renvoie la commande nommée. Il ne
/// peut demander que ce que la barre flottante sait faire (`DeckCommand`).
/// Aucune frappe, aucun chemin, aucune exécution ne passe par ici.
enum DeckProtocol {
    static let version = 2
}

/// Une touche à frapper, telle que le plugin la posera : keycode de position
/// et modificateurs au format Carbon (`controlKey`, `shiftKey`…).
struct DeckKey: Codable, Equatable, Hashable, Sendable {
    let keyCode: UInt32
    let modifiers: UInt32

    init(_ hotKey: HotKey) {
        keyCode = hotKey.keyCode
        modifiers = hotKey.modifiers
    }
}

/// Un perso, tel que le Stream Deck le montre : son nom, sa classe, l'emblème.
struct DeckPerso: Codable, Equatable, Sendable {
    let nom: String
    let classe: String?
    /// PNG en base64 de l'emblème de classe, s'il y en a un.
    let icone: String?
}

/// Ce qu'un appui fait : une touche du jeu **ou** une commande pour Synfus.
struct DeckAction: Codable, Equatable, Sendable {
    let touche: DeckKey?
    let commande: DeckCommand.Kind?
    /// Ce que c'est, en clair — pour le miroir des réglages.
    let nom: String

    static func frappe(_ key: HotKey, nom: String) -> DeckAction { DeckAction(touche: DeckKey(key), commande: nil, nom: nom) }
    static func commande(_ kind: DeckCommand.Kind, nom: String) -> DeckAction { DeckAction(touche: nil, commande: kind, nom: nom) }
}

/// Une touche de la grille, prête à dessiner.
struct DeckTouche: Codable, Equatable, Sendable {
    /// Ordre de lecture : ligne puis colonne, 0-based.
    let index: Int
    /// Ce que la touche est (`sort`, `persoSuivant`, `commande:suivi`…) :
    /// les actions classiques du plugin, posées par rôle, la retrouvent par là.
    let role: String?
    /// PNG en base64 — l'icône d'un sort, l'emblème d'un perso.
    let icone: String?
    /// L'icône du sort joué en appui long (vignette en bas à gauche) et en
    /// appui très long (en bas à droite).
    let iconeLong: String?
    let iconeTresLong: String?
    /// À défaut d'icône, un symbole SF.
    let symbole: String?
    let titre: String
    /// Atténuée : Dofus n'est pas devant, ou la touche n'a rien à faire.
    let attenuee: Bool
    let court: DeckAction?
    let long: DeckAction?
    let tresLong: DeckAction?
    /// Progressive : chaque niveau joue **à son seuil**, sans attendre le
    /// relâchement — le jeu montre la sélection du sort pendant qu'on tient,
    /// on lâche quand c'est le bon. Réservé aux touches dont tous les niveaux
    /// sélectionnent un sort : ailleurs, deux actions d'affilée se contrediraient.
    let progressif: Bool
}

/// Ce que le Stream Deck doit montrer, à cet instant, sur une grille donnée.
struct DeckPage: Codable, Equatable, Sendable {
    var type = "page"
    var version = DeckProtocol.version
    let colonnes: Int
    let lignes: Int
    /// Un client Dofus est-il au premier plan ? Sinon, rien n'est frappé :
    /// une pression ramène Dofus devant.
    let dofusDevant: Bool
    let perso: DeckPerso?
    let touches: [DeckTouche]
    /// Durées d'appui, en ms, à partir desquelles l'action longue puis la
    /// très longue s'appliquent.
    let appuiLongMs: Int
    let appuiTresLongMs: Int
}

/// Ce que le plugin peut envoyer.
struct DeckCommand: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case persoSuivant, persoPrecedent, perso
        case barreSuivante, barrePrecedente, barrePremiere
        /// Ouvre ou ferme le menu des commandes du jeu ; tourne ses pages.
        case menu, pageMenuSuivante
        /// Relit la barre de sorts du perso devant (reconnaissance à l'écran).
        case reconnaitre
        /// Ramène Dofus devant — le perso actif, ou le premier — sans changer de perso.
        case activer
        /// Le plugin annonce une grille : Synfus compose une page à sa taille.
        case appareil
    }
    let type: Kind
    /// Pour `perso` : l'emplacement, 0-based.
    var slot: Int?
    /// Pour `appareil`.
    var colonnes: Int?
    var lignes: Int?
}
