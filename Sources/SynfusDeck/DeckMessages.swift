import Foundation

// Le contrat avec Synfus — miroir de DeckProtocol.swift côté app. Les deux
// binaires ne partagent pas de code : ce JSON est l'interface. Synfus
// compose ; le plugin reçoit une page par taille de grille et la rend.

struct DeckKey: Codable, Equatable, Sendable {
    let keyCode: UInt32
    /// Modificateurs au format Carbon : cmdKey 1<<8, shiftKey 1<<9,
    /// optionKey 1<<11, controlKey 1<<12.
    let modifiers: UInt32
}

struct DeckPerso: Codable, Equatable, Sendable {
    let nom: String
    let classe: String?
    let icone: String?
}

/// Une touche du jeu à frapper **ou** une commande à renvoyer à Synfus.
struct DeckAction: Codable, Equatable, Sendable {
    let touche: DeckKey?
    let commande: String?
    let nom: String
}

struct DeckTouche: Codable, Equatable, Sendable {
    let index: Int
    let role: String?
    let icone: String?
    let iconeLong: String?
    let iconeTresLong: String?
    let symbole: String?
    let titre: String
    let attenuee: Bool
    let court: DeckAction?
    let long: DeckAction?
    let tresLong: DeckAction?
    let progressif: Bool
}

struct DeckPage: Codable, Equatable, Sendable {
    let type: String
    let version: Int
    let colonnes: Int
    let lignes: Int
    let dofusDevant: Bool
    let perso: DeckPerso?
    let touches: [DeckTouche]
    let appuiLongMs: Int
    let appuiTresLongMs: Int
}

struct DeckCommand: Codable, Sendable {
    let type: String
    var slot: Int? = nil
    var colonnes: Int? = nil
    var lignes: Int? = nil
}

// Ce que le logiciel Stream Deck envoie et reçoit — le sous-ensemble utile.

struct StreamDeckEvent: Decodable {
    struct Coordinates: Decodable { let column: Int; let row: Int }
    struct Payload: Decodable { let coordinates: Coordinates? }
    struct Size: Decodable { let columns: Int; let rows: Int }
    struct DeviceInfo: Decodable { let size: Size? }
    let event: String
    let action: String?
    let context: String?
    let device: String?
    let payload: Payload?
    let deviceInfo: DeviceInfo?
}

/// Le nom du profil livré avec le plugin (manifest `Profiles`), vers lequel
/// on bascule quand Dofus passe devant.
enum BundledProfile {
    static let name = "Synfus"
}

enum ActionID {
    static let prefix = "fr.synseria.synfus."
    /// La touche **dynamique** : sa position est son identité, Synfus décide
    /// de tout ce qu'elle montre et fait.
    static let touche = prefix + "touche"

    /// Les actions **classiques**, posées par rôle n'importe où sur n'importe
    /// quel profil : chacune suit la touche de ce rôle dans la page composée
    /// — les « Sort » dans leur ordre de lecture, les autres par leur nom.
    static let roles: [String: String] = [
        prefix + "sort": "sort",
        prefix + "perso-suivant": "persoSuivant",
        prefix + "perso-precedent": "persoPrecedent",
        prefix + "perso-actif": "persoActif",
        prefix + "barre-suivante": "barreSuivante",
        prefix + "fin-de-tour": "finDeTour",
        prefix + "corps-a-corps": "corpsACorps",
        prefix + "menu": "menu",
        prefix + "suivi": "commande:suivi",
    ]
}
