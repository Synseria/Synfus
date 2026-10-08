import Foundation

/// Monstres, butins et recettes depuis l'API de DofusDB, à la demande : un
/// monstre ou un objet à la fois, jamais la base entière — des dizaines de
/// milliers de fiches, pour en lire quelques-unes par quête. Ce qui est lu
/// se garde sur le disque (`CacheOuTrouver`) ; l'assemblage est pur.
enum OuTrouverDofusDB {
    struct MonstreAPI: Decodable, Sendable {
        struct Butin: Decodable, Sendable {
            let objectId: Int
            let percentDropForGrade5: Double?
            /// Les butins à condition (niveau du perso…) n'ont qu'une fourchette.
            let maxPercentDrop: Double?
        }

        let id: Int
        let name: DofusDB.Noms
        let subareas: [Int]?
        let drops: [Butin]?

        static let champs = ["id", "name", "subareas"]
        /// Des butins, les seuls champs lus : la liste entière pèse dix fois plus.
        static let champsButins = ["drops.objectId", "drops.percentDropForGrade5", "drops.maxPercentDrop"]
    }

    struct SousZoneAPI: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
        /// -1, ou 0, hors donjon.
        let dungeonId: Int?

        static let champs = ["id", "name", "dungeonId"]
    }

    struct DonjonAPI: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
        let entranceMapId: Int?
        let subarea: Int?
        let monsters: [Int]?

        static let champs = ["id", "name", "entranceMapId", "subarea", "monsters"]
    }

    /// DofusDB joint d'office à la recette ses ingrédients et son métier.
    struct RecetteAPI: Decodable, Sendable {
        struct Nomme: Decodable, Sendable {
            let id: Int
            let name: DofusDB.Noms
        }

        let resultLevel: Int?
        let ingredientIds: [Int]?
        let quantities: [Int]?
        let ingredients: [Nomme]?
        let job: Nomme?

        static let champs = ["resultId", "resultLevel", "ingredientIds", "quantities", "jobId"]
    }

    enum Echec: Error {
        case monstreInconnu(Int)
    }

    // MARK: - Réseau

    static func monstre(_ id: Int) async throws -> FicheMonstre {
        let monstres: [MonstreAPI] = try await DofusDB.toutes(
            "monsters", [URLQueryItem(name: "id", value: "\(id)")] + DofusDB.selection(MonstreAPI.champs))
        guard let monstre = monstres.first else { throw Echec.monstreInconnu(id) }
        let (sousZones, donjons) = try await repaires(de: [monstre])
        return fiche(monstre, sousZones: sousZones, donjons: donjons)
    }

    /// Les monstres qui le lâchent et sa recette : une requête chacun, puis
    /// les sous-zones et donjons de tous les monstres ensemble.
    static func objet(_ id: Int) async throws -> SourcesObjet {
        async let monstres: [MonstreAPI] = DofusDB.toutes(
            "monsters", [URLQueryItem(name: "drops.objectId", value: "\(id)")]
                + DofusDB.selection(MonstreAPI.champs + MonstreAPI.champsButins))
        async let recettes: [RecetteAPI] = DofusDB.toutes(
            "recipes", [URLQueryItem(name: "resultId", value: "\(id)")] + DofusDB.selection(RecetteAPI.champs))
        let lacheurs = try await monstres
        let (sousZones, donjons) = try await repaires(de: lacheurs)
        return assembler(objet: id, monstres: lacheurs, sousZones: sousZones, donjons: donjons,
                         recette: try await recettes.first)
    }

    private static func repaires(de monstres: [MonstreAPI]) async throws -> ([SousZoneAPI], [DonjonAPI]) {
        async let sousZones: [SousZoneAPI] = DofusDB.parIdentifiants(
            "subareas", monstres.flatMap { $0.subareas ?? [] }, DofusDB.selection(SousZoneAPI.champs))
        async let donjons: [DonjonAPI] = DofusDB.parIdentifiants(
            "dungeons", monstres.map(\.id), champ: "monsters", DofusDB.selection(DonjonAPI.champs))
        return (try await sousZones, try await donjons)
    }

    // MARK: - Assemblage

    /// Ses sous-zones dans l'ordre de DofusDB, puis ses donjons ; une
    /// sous-zone de donjon cède la place au donjon, que son repère situe —
    /// les salles n'ont pas de case sur la carte du monde.
    static func fiche(_ monstre: MonstreAPI, sousZones: [SousZoneAPI], donjons: [DonjonAPI]) -> FicheMonstre {
        let sesDonjons = donjons.filter { $0.monsters?.contains(monstre.id) ?? false }
        let sallesDeDonjon = Set(sesDonjons.compactMap(\.subarea))
        let parId = Dictionary(sousZones.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let zones = (monstre.subareas ?? []).compactMap { id -> RepaireMonstre? in
            guard !sallesDeDonjon.contains(id), let sousZone = parId[id] else { return nil }
            return RepaireMonstre(genre: .sousZone, id: id, noms: sousZone.name.parLangue, entree: nil)
        }
        let salles = sesDonjons.map {
            RepaireMonstre(genre: .donjon, id: $0.id, noms: $0.name.parLangue, entree: $0.entranceMapId)
        }
        return FicheMonstre(id: monstre.id, noms: monstre.name.parLangue, repaires: zones + salles)
    }

    /// Les lâcheurs du plus généreux au moins généreux ; la recette, ses
    /// ingrédients dans l'ordre et aux quantités de DofusDB.
    static func assembler(objet: Int, monstres: [MonstreAPI], sousZones: [SousZoneAPI], donjons: [DonjonAPI],
                          recette: RecetteAPI?) -> SourcesObjet {
        let lacheurs = monstres.map { monstre in
            let butin = monstre.drops?.first { $0.objectId == objet }
            let taux = max(butin?.percentDropForGrade5 ?? 0, butin?.maxPercentDrop ?? 0)
            return SourcesObjet.Lacheur(monstre: fiche(monstre, sousZones: sousZones, donjons: donjons), taux: taux)
        }
        .enumerated()
        .sorted { $0.element.taux != $1.element.taux ? $0.element.taux > $1.element.taux : $0.offset < $1.offset }
        .map(\.element)
        return SourcesObjet(lacheurs: lacheurs, recette: recette.map(Self.recette))
    }

    private static func recette(_ api: RecetteAPI) -> SourcesObjet.Recette {
        let noms = Dictionary((api.ingredients ?? []).map { ($0.id, $0.name.parLangue) }, uniquingKeysWith: { a, _ in a })
        let ingredients = zip(api.ingredientIds ?? [], api.quantities ?? []).map { id, quantite in
            SourcesObjet.Ingredient(noms: noms[id] ?? ["fr": "#\(id)"], quantite: quantite)
        }
        return SourcesObjet.Recette(metier: api.job?.name.parLangue ?? [:], niveau: api.resultLevel ?? 0,
                                    ingredients: ingredients)
    }
}

/// Ce que DofusDB a dit, daté : un monstre ou un objet relu dans trente jours
/// (`DofusDB.peremption`) se redemande.
struct CacheOuTrouver: Codable, Sendable {
    struct Entree<Valeur: Codable & Sendable>: Codable, Sendable {
        let date: Date
        let valeur: Valeur
    }

    /// Une autre forme (ancienne) ne se relit pas : tout se redemande.
    static let formatActuel = 1
    var format = CacheOuTrouver.formatActuel
    /// Par identifiant, en texte (clés JSON).
    var monstres: [String: Entree<FicheMonstre>] = [:]
    var objets: [String: Entree<SourcesObjet>] = [:]

    /// `~/Library/Application Support/Synfus/OuTrouver.json`
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "OuTrouver.json", directoryHint: .notDirectory)
    }

    static func relire(_ donnees: Data?) -> CacheOuTrouver {
        guard let donnees, let cache = try? JSONDecoder().decode(CacheOuTrouver.self, from: donnees),
              cache.format == formatActuel
        else { return CacheOuTrouver() }
        return cache
    }

    static func gardee() -> CacheOuTrouver { relire(try? Data(contentsOf: fichier)) }

    func garder() throws {
        try FileManager.default.createDirectory(at: Self.fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.fichier, options: .atomic)
    }
}
