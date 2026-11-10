import Foundation

/// L'almanax d'un jour : l'offrande à porter au temple et le bonus du jour,
/// tels que DofusDB les donne (`almanax?date=AAAA-MM-JJ`). Pur : le jour du
/// jeu, la réponse lue, le texte nettoyé.
struct Almanax: Codable, Equatable, Sendable {
    /// Le Sanctuaire de l'Almanax, où rendre l'offrande : son repère DofusDB
    /// (`Lieu.id`), en Plaine des Porkass.
    static let sanctuaire = 3218

    struct Offrande: Codable, Equatable, Sendable {
        let objet: Int
        let noms: [String: String]
        let quantite: Int
        /// L'`iconId` de DofusDB (`DofusDB.imageObjet`), jamais l'image elle-même.
        let icone: Int?
    }

    /// Une autre forme (ancienne) ne se relit pas : le jour se redemande.
    static let formatActuel = 1
    var format = Almanax.formatActuel
    /// `AAAA-MM-JJ`, à l'heure du jeu (`jour(de:)`).
    let jour: String
    let offrandes: [Offrande]
    let bonus: [String: String]
    let description: [String: String]

    /// L'almanax change à minuit, heure des serveurs : celle de Paris.
    static func jour(de date: Date) -> String {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        let composantes = calendrier.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", composantes.year ?? 0, composantes.month ?? 0, composantes.day ?? 0)
    }

    /// Le texte du jeu sans sa mise en forme : les balises tombent, un renvoi
    /// `{{monsterRace,229::Firefoux}}` garde son libellé.
    static func nettoyer(_ texte: String) -> String {
        var propre = texte.replacingOccurrences(of: "<[^>]*>", with: "", options: .regularExpression)
        propre = propre.replacingOccurrences(of: #"\{\{[^}]*?::([^}]*)\}\}"#, with: "$1", options: .regularExpression)
        propre = propre.replacingOccurrences(of: #"\{\{[^}]*\}\}"#, with: "", options: .regularExpression)
        propre = propre.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        return propre.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - DofusDB

    struct API: Decodable, Sendable {
        struct Objet: Decodable, Sendable {
            let id: Int
            let name: DofusDB.Noms
            let iconId: Int?
        }

        let name: DofusDB.Noms?
        let desc: DofusDB.Noms?
        let itemIds: [Int]?
        let quantities: [Int]?
        let items: [Objet]?
    }

    /// Les objets dans l'ordre d'`itemIds`, chacun sa quantité ; un objet que
    /// la réponse ne joint pas garde son identifiant pour nom.
    init(_ api: API, jour: String) {
        self.jour = jour
        let objets = Dictionary((api.items ?? []).map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        offrandes = zip(api.itemIds ?? [], api.quantities ?? []).map { id, quantite in
            Offrande(objet: id, noms: objets[id]?.name.parLangue ?? ["fr": "#\(id)"], quantite: quantite,
                     icone: objets[id]?.iconId)
        }
        bonus = (api.name?.parLangue ?? [:]).mapValues(Self.nettoyer)
        description = (api.desc?.parLangue ?? [:]).mapValues(Self.nettoyer)
    }

    static func telecharger(_ jour: String) async throws -> Almanax {
        Almanax(try await DofusDB.reponse("almanax", [URLQueryItem(name: "date", value: jour)]), jour: jour)
    }

    // MARK: - Disque

    /// `~/Library/Application Support/Synfus/Almanax.json` : le dernier jour lu.
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Almanax.json", directoryHint: .notDirectory)
    }

    static func relire(_ donnees: Data?) -> Almanax? {
        guard let donnees, let almanax = try? JSONDecoder().decode(Almanax.self, from: donnees),
              almanax.format == formatActuel
        else { return nil }
        return almanax
    }

    static func gardee() -> Almanax? { relire(try? Data(contentsOf: fichier)) }

    func garder() throws {
        try FileManager.default.createDirectory(at: Self.fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.fichier, options: .atomic)
    }
}
