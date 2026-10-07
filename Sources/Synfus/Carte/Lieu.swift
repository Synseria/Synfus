/// Un repère de la carte du jeu — zaap, banque, hôtel de vente, atelier,
/// donjon, transport… — tel que DofusDB le donne (`hints`), avec sa zone et sa
/// sous-zone. Des coordonnées et des noms, aucun visuel du jeu.
struct Lieu: Codable, Hashable, Sendable {
    /// L'identifiant du repère chez DofusDB, stable d'une liste à l'autre.
    let id: Int
    let x: Int
    let y: Int
    /// La carte du monde (`worldMapId`), cf. `Zaap.monde`.
    let monde: Int
    /// La catégorie DofusDB (`categoryId`), cf. `CategorieLieu`.
    let categorie: Int
    /// Par code de langue, comme tous les noms ci-dessous.
    let noms: [String: String]
    let zone: [String: String]
    let sousZone: [String: String]

    /// Ce qui identifie un lieu dans les réglages (étiquettes, favoris) ; le
    /// préfixe le distingue d'une `Zaap.cle`.
    var cle: String { Self.prefixeCle + "\(id)" }
    static let prefixeCle = "lieu:"

    var estZaap: Bool { noms[Langue.fr.rawValue] == "Zaap" }

    func nom(en langue: Langue) -> String { Self.traduit(noms, langue) ?? "\(x),\(y)" }
    func zone(en langue: Langue) -> String? { Self.traduit(zone, langue) }
    func sousZone(en langue: Langue) -> String? { Self.traduit(sousZone, langue) }

    /// Dans la langue, sinon en français, sinon dans l'une des autres.
    static func traduit(_ noms: [String: String], _ langue: Langue) -> String? {
        noms[langue.rawValue] ?? noms[Langue.fr.rawValue] ?? noms.values.min()
    }
}

/// Les catégories de repères de DofusDB que Synfus sait nommer ; une autre
/// reste un lieu, simplement sans nom de catégorie.
enum CategorieLieu: Int, CaseIterable, Sendable {
    case temple = 1
    case hotelDeVente = 2
    case atelier = 3
    case divers = 4
    case donjon = 6
    case transport = 9
}
