import Foundation

// Le contrat avec Synfus — miroir de DeckProtocol.swift côté app. Les deux
// binaires ne partagent pas de code : ce JSON est l'interface.

struct DeckKey: Codable, Equatable, Sendable {
    let keyCode: UInt32
    /// Modificateurs au format Carbon : cmdKey 1<<8, shiftKey 1<<9,
    /// optionKey 1<<11, controlKey 1<<12.
    let modifiers: UInt32
}

struct DeckCell: Codable, Equatable, Sendable {
    let position: Int
    let sortId: Int?
    let nom: String?
    let icone: String?
    let touche: DeckKey?
}

struct DeckPerso: Codable, Equatable, Sendable {
    let nom: String
    let classe: String?
    let icone: String?
}

struct DeckState: Codable, Equatable, Sendable {
    let type: String
    let version: Int
    let dofusDevant: Bool
    let perso: String?
    let classe: String?
    let persoActif: DeckPerso?
    let persoSuivant: DeckPerso?
    let persoPrecedent: DeckPerso?
    let barre: Int
    let barres: Int
    let enCombat: Bool?
    let finDeTour: DeckKey?
    let corpsACorps: DeckKey?
    let cases: [DeckCell]
    let commandes: [DeckGameCommand]
}

struct DeckGameCommand: Codable, Equatable, Sendable {
    let id: String
    let nom: String
    let symbole: String
    let touche: DeckKey?
}

struct DeckCommand: Codable, Sendable {
    let type: String
    let slot: Int?
}

// Ce que le logiciel Stream Deck envoie et reçoit — le sous-ensemble utile.

struct StreamDeckEvent: Decodable {
    struct Coordinates: Decodable { let column: Int; let row: Int }
    struct Payload: Decodable { let coordinates: Coordinates? }
    let event: String
    let action: String?
    let context: String?
    let device: String?
    let payload: Payload?
}

/// Le nom du profil livré avec le plugin (manifest `Profiles`), vers lequel
/// on bascule quand Dofus passe devant.
enum BundledProfile {
    static let name = "Synfus"
}

enum ActionID {
    static let prefix = "fr.synseria.synfus."
    static let sort = prefix + "sort"
    static let persoSuivant = prefix + "perso-suivant"
    static let persoPrecedent = prefix + "perso-precedent"
    static let barreSuivante = prefix + "barre-suivante"
    static let finDeTour = prefix + "fin-de-tour"
    static let corpsACorps = prefix + "corps-a-corps"
    static let persoActif = prefix + "perso-actif"
    static let menu = prefix + "menu"
    static let suivi = prefix + "suivi"
}
