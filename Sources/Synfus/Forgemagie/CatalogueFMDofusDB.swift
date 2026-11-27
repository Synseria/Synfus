import Foundation

/// Les runes de forgemagie et le poids de leurs effets, depuis DofusDB : les
/// runes (`items`, type 78), puis leurs effets (`effects`) par lots
/// d'identifiants. Gardés sur le disque, retéléchargés tous les 30 jours.
enum CatalogueFMDofusDB {
    struct Gardees: Codable {
        static let formatActuel = 2
        let format: Int
        let date: Date
        let effets: [CatalogueFM.EffetDofusDB]
        let runes: [CatalogueFM.ObjetDofusDB]
    }

    /// Le type d'objet « rune de forgemagie ».
    static let typeRune = 78
    /// Moins de runes ou d'effets : une réponse tronquée, la précédente est gardée.
    static let minimumPlausible = 80
    static let effetsPlausibles = 40

    enum Echec: Error { case listeSuspecte(Int) }

    /// `~/Library/Application Support/Synfus/Forgemagie.json`
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Forgemagie.json", directoryHint: .notDirectory)
    }

    static func gardees() -> Gardees? {
        guard let donnees = try? Data(contentsOf: fichier),
              let gardees = try? JSONDecoder().decode(Gardees.self, from: donnees),
              gardees.format == Gardees.formatActuel
        else { return nil }
        return gardees
    }

    static func garder(_ gardees: Gardees) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(gardees).write(to: fichier, options: .atomic)
    }

    static func telecharger(maintenant: Date = Date()) async throws -> Gardees {
        let runes: [CatalogueFM.ObjetDofusDB] = try await DofusDB.toutes(
            "items", [URLQueryItem(name: "typeId", value: "\(typeRune)")] + DofusDB.selection(CatalogueFM.ObjetDofusDB.champs))
        guard runes.count >= minimumPlausible else { throw Echec.listeSuspecte(runes.count) }
        let ids = runes.compactMap { $0.effects?.first?.effectId }
        let effets: [CatalogueFM.EffetDofusDB] = try await DofusDB.parIdentifiants(
            "effects", ids, DofusDB.selection(CatalogueFM.EffetDofusDB.champs))
        guard effets.count >= effetsPlausibles else { throw Echec.listeSuspecte(effets.count) }
        return Gardees(format: Gardees.formatActuel, date: maintenant, effets: effets, runes: runes)
    }
}
