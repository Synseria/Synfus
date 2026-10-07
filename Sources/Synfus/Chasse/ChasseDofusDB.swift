import Foundation

/// Le réseau de la chasse, autour du pur : la liste des indices, gardée sur
/// le disque, et la requête d'une étape — jamais faite d'elle-même, seulement
/// à l'action de l'utilisateur.
enum ChasseDofusDB {
    /// Un indice tel que l'API le donne.
    struct IndiceAPI: Decodable {
        let id: Int
        let name: DofusDB.Noms

        var indice: Indice { Indice(id: id, noms: name.parLangue) }
    }

    /// La liste gardée sur le disque, datée pour sa péremption.
    struct Releve: Codable, Equatable, Sendable {
        let date: Date
        let indices: [Indice]
    }

    enum Echec: LocalizedError {
        /// Moins d'indices que cela : une réponse tronquée.
        case listeSuspecte(Int)

        var errorDescription: String? {
            switch self {
            case .listeSuspecte(let nombre): return L("chasse.indices.suspecte", nombre)
            }
        }
    }

    static let minimumPlausible = 50

    /// `~/Library/Application Support/Synfus/IndicesChasse.json`
    private static var fichier: URL {
        AnkamaAssets.supportDirectory.appending(path: "IndicesChasse.json", directoryHint: .notDirectory)
    }

    private static func lire() -> Releve? {
        guard let donnees = try? Data(contentsOf: fichier) else { return nil }
        return try? JSONDecoder().decode(Releve.self, from: donnees)
    }

    private static func ecrire(_ releve: Releve) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(releve).write(to: fichier, options: .atomic)
    }

    /// La liste du disque si elle est fraîche (et que l'on ne `force` pas) ;
    /// sinon téléchargée et gardée. Un échec rend la liste du disque, aussi
    /// vieille soit-elle, et ne lève que s'il n'y en a aucune — ou si l'on
    /// `force`, pour dire pourquoi.
    static func indices(forcer: Bool = false, maintenant: Date = Date()) async throws -> Releve {
        let garde = lire()
        if let garde, !forcer, !DofusDB.perimee(depuis: garde.date, maintenant: maintenant) { return garde }
        do {
            let releve = Releve(date: maintenant, indices: try await telechargerIndices())
            try? ecrire(releve)
            return releve
        } catch {
            if let garde, !forcer { return garde }
            throw error
        }
    }

    private static func telechargerIndices() async throws -> [Indice] {
        let indices = (try await DofusDB.toutes("point-of-interest", []) as [IndiceAPI]).map(\.indice)
        guard indices.count >= minimumPlausible else { throw Echec.listeSuspecte(indices.count) }
        return indices
    }

    /// Les cartes de `direction` qui portent des indices, jusqu'à la portée.
    static func cartes(depuis x: Int, _ y: Int, direction: Direction) async throws -> [EtapeChasse.Carte] {
        let page: DofusDB.Page<EtapeChasse.Carte> = try await DofusDB.page("treasure-hunt", [
            URLQueryItem(name: "x", value: "\(x)"),
            URLQueryItem(name: "y", value: "\(y)"),
            URLQueryItem(name: "direction", value: "\(direction.rawValue)"),
            URLQueryItem(name: "$limit", value: "\(DofusDB.parPage)"),
        ])
        return page.data
    }
}
