import Foundation

/// L'almanax d'un jour : l'offrande à porter au temple et le bonus du jour,
/// tels que DofusDB les donne (`almanax?date=AAAA-MM-JJ`). Pur : le jour du
/// jeu, la semaine qui vient, la réponse lue, le texte nettoyé.
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
    static let formatActuel = 2
    var format = Almanax.formatActuel
    /// `AAAA-MM-JJ`, à l'heure du jeu (`jour(de:)`).
    let jour: String
    let offrandes: [Offrande]
    let bonus: [String: String]
    let description: [String: String]

    /// Les jours montrés : aujourd'hui et les six suivants.
    static let joursMontres = 7

    private static var calendrier: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris") ?? .gmt
        return calendrier
    }

    /// L'almanax change à minuit, heure des serveurs : celle de Paris.
    static func jour(de date: Date) -> String {
        let composantes = calendrier.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", composantes.year ?? 0, composantes.month ?? 0, composantes.day ?? 0)
    }

    /// Le jour du jeu de `date` et les suivants, un par jour de Paris.
    static func semaine(depuis date: Date) -> [String] {
        (0..<joursMontres).compactMap { calendrier.date(byAdding: .day, value: $0, to: date) }.map(jour(de:))
    }

    /// Les jours attendus que l'on n'a pas encore : ce que l'ouverture de la palette ou l'entrée de
    /// la vue redemande, le septième jour du lendemain comme un jour qui a échoué.
    static func manquants(_ attendus: [String], connus: Set<String>) -> [String] {
        attendus.filter { !connus.contains($0) }
    }

    /// Midi, heure de Paris, d'un jour `AAAA-MM-JJ` : une date que l'affichage ne ramène pas à la veille.
    static func date(de jour: String) -> Date? {
        let parties = jour.split(separator: "-").compactMap { Int($0) }
        guard parties.count == 3 else { return nil }
        return calendrier.date(from: DateComponents(year: parties[0], month: parties[1], day: parties[2], hour: 12))
    }

    @MainActor private static var formateurs: [Langue: DateFormatter] = [:]

    /// « lun. 16 nov. », dans la langue de l'interface ; un formateur par langue, coûteux à créer.
    @MainActor
    static func libelle(du jour: String, _ langue: Langue) -> String {
        guard let date = date(de: jour) else { return jour }
        let format = formateurs[langue] ?? {
            let neuf = DateFormatter()
            neuf.locale = Locale(identifier: langue.rawValue)
            neuf.timeZone = calendrier.timeZone
            neuf.setLocalizedDateFormatFromTemplate("EEE d MMM")
            formateurs[langue] = neuf
            return neuf
        }()
        return format.string(from: date)
    }

    /// Le nom de l'offrande du jour (la première : DofusDB n'en donne qu'une).
    func nomOffrande(_ langue: Langue) -> String? {
        offrandes.first.flatMap { Lieu.traduit($0.noms, langue) }
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

    /// `~/Library/Application Support/Synfus/Almanax.json` : les jours de la semaine déjà lus.
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Almanax.json", directoryHint: .notDirectory)
    }

    /// Les jours d'une autre forme (ancienne) ne se relisent pas : ils se redemandent.
    static func relire(_ donnees: Data?) -> [Almanax] {
        guard let donnees, let jours = try? JSONDecoder().decode([Almanax].self, from: donnees) else { return [] }
        return jours.filter { $0.format == formatActuel }
    }

    static func gardes() -> [Almanax] { relire(try? Data(contentsOf: fichier)) }

    static func garder(_ jours: [Almanax]) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(jours).write(to: fichier, options: .atomic)
    }
}
