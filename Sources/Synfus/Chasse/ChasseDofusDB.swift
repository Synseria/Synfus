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
        Ressources.dossierUtilisateur.appending(path: "IndicesChasse.json", directoryHint: .notDirectory)
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

    /// Les rayons de chasse gardés sur le disque : la clé « x,y,direction » mène
    /// aux cartes que DofusDB a rendues pour ce départ et cette direction. Le
    /// lien indice → carte n'existe que par cette requête calculée (x, y et
    /// direction obligatoires côté API) : le premier passage la télécharge, les
    /// suivants lisent le disque.
    struct CacheRayons: Codable, Sendable {
        let date: Date
        var rayons: [String: [EtapeChasse.Carte]]
    }

    private static var fichierRayons: URL {
        Ressources.dossierUtilisateur.appending(path: "RayonsChasse.json", directoryHint: .notDirectory)
    }

    private static func lireRayons() -> CacheRayons? {
        guard let donnees = try? Data(contentsOf: fichierRayons) else { return nil }
        return try? JSONDecoder().decode(CacheRayons.self, from: donnees)
    }

    private static func ecrire(_ cache: CacheRayons) throws {
        try FileManager.default.createDirectory(at: fichierRayons.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(cache).write(to: fichierRayons, options: .atomic)
    }

    /// Les cartes de `direction` qui portent des indices, jusqu'à la portée :
    /// le cache disque s'il est frais, sinon la requête DofusDB, remise en cache.
    static func cartes(depuis x: Int, _ y: Int, direction: Direction, maintenant: Date = Date()) async throws -> [EtapeChasse.Carte] {
        let cle = "\(x),\(y),\(direction.rawValue)"
        let garde = lireRayons()
        if let garde, !DofusDB.perimee(depuis: garde.date, maintenant: maintenant), let rayon = garde.rayons[cle] {
            return rayon
        }
        let page: DofusDB.Page<EtapeChasse.Carte> = try await DofusDB.page("treasure-hunt", [
            URLQueryItem(name: "x", value: "\(x)"),
            URLQueryItem(name: "y", value: "\(y)"),
            URLQueryItem(name: "direction", value: "\(direction.rawValue)"),
            URLQueryItem(name: "$limit", value: "\(DofusDB.parPage)"),
        ])
        var cache = garde ?? CacheRayons(date: maintenant, rayons: [:])
        if DofusDB.perimee(depuis: cache.date, maintenant: maintenant) { cache = CacheRayons(date: maintenant, rayons: [:]) }
        cache.rayons[cle] = page.data
        try? ecrire(cache)
        return page.data
    }
}
