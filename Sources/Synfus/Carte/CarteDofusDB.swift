import Foundation

/// La carte depuis l'API de DofusDB : les repères (`hints`), nommés par leur
/// sous-zone (`subareas`) et leur zone (`areas`), et les cases du Monde des
/// Douze (`map-positions`) qui situent chaque sous-zone. Gardée sur le disque ;
/// l'assemblage est pur, le réseau n'est qu'autour.
enum CarteDofusDB {
    struct Repere: Decodable {
        let id: Int
        let x: Int
        let y: Int
        let mapId: Int
        let worldMapId: Int
        let categoryId: Int
        let subareaId: Int
        let name: DofusDB.Noms
    }

    struct SousZone: Decodable {
        let id: Int
        let areaId: Int
        let name: DofusDB.Noms
        /// 0 quand la sous-zone n'en a pas.
        let associatedZaapMapId: Int?
        let neighbors: [Int]?

        static let champs = ["id", "areaId", "name", "associatedZaapMapId", "neighbors"]
    }

    struct Zone: Decodable {
        let id: Int
        let name: DofusDB.Noms
    }

    /// Une carte du jeu et sa case ; plusieurs cartes partagent une case
    /// (intérieurs, étages, cartes refaites).
    struct Case: Decodable, Sendable {
        let id: Int
        let posX: Int
        let posY: Int
        let subAreaId: Int
        /// Celle que la carte du monde montre à cette case.
        let hasPriorityOnWorldmap: Bool?

        static let champs = ["id", "posX", "posY", "subAreaId", "hasPriorityOnWorldmap"]
    }

    enum Echec: LocalizedError {
        case listeSuspecte(Int)
        case casesSuspectes(Int)

        var errorDescription: String? {
            switch self {
            case .listeSuspecte(let nombre): return L("carte.maj.suspecte", nombre)
            case .casesSuspectes(let nombre): return L("carte.maj.casesSuspectes", nombre)
            }
        }
    }

    /// `~/Library/Application Support/Synfus/Carte.json`
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Carte.json", directoryHint: .notDirectory)
    }

    static func locale() -> Carte {
        retenue(gardee: try? Data(contentsOf: fichier), integree: Carte.integree)
    }

    /// La plus récente de la carte gardée et de la carte intégrée : une mise à
    /// jour de Synfus peut apporter une liste plus fraîche que le disque. Une
    /// carte gardée d'un format antérieur (sans sous-zones) ne se décode pas :
    /// l'intégrée la remplace, jusqu'au prochain téléchargement qui l'écrase.
    static func retenue(gardee donnees: Data?, integree: Carte) -> Carte {
        guard let donnees,
              let gardee = try? JSONDecoder().decode(Carte.self, from: donnees),
              gardee.date > integree.date
        else { return integree }
        return gardee
    }

    static func garder(_ carte: Carte) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(carte).write(to: fichier, options: .atomic)
    }

    /// Les cases d'abord, en parallèle : huit mille cartes, cent soixante pages.
    static func telecharger(maintenant: Date = Date()) async throws -> Carte {
        let reperes: [Repere] = try await DofusDB.toutes("hints", [])
        let cases: [Case] = try await DofusDB.toutesEnParallele(
            "map-positions", [URLQueryItem(name: "worldMap", value: "\(Zaap.mondeDesDouze)")] + DofusDB.selection(Case.champs))
        let sousZones: [SousZone] = try await parIdentifiants(
            "subareas", reperes.map(\.subareaId) + cases.map(\.subAreaId), DofusDB.selection(SousZone.champs))
        let zones: [Zone] = try await parIdentifiants("areas", sousZones.map(\.areaId))
        let carte = assembler(date: maintenant, reperes: reperes, sousZones: sousZones, zones: zones, cases: cases)
        guard carte.lieux.count >= Carte.minimumPlausible else { throw Echec.listeSuspecte(carte.lieux.count) }
        guard carte.cases.count >= Carte.minimumCasesPlausible else { throw Echec.casesSuspectes(carte.cases.count) }
        return carte
    }

    /// Les lieux dans l'ordre de DofusDB, un repère sans sous-zone connue
    /// gardant des noms de zone vides ; les sous-zones, toutes celles du Monde
    /// des Douze — même celles qu'aucune case ne montre (intérieurs) ou qui
    /// manquent aux cases (l'Arche de Vili) : un zaap peut s'y trouver.
    static func assembler(date: Date, reperes: [Repere], sousZones: [SousZone], zones: [Zone], cases: [Case]) -> Carte {
        let sousZone = Dictionary(sousZones.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })
        let zone = Dictionary(zones.map { ($0.id, $0.name.parLangue) }, uniquingKeysWith: { premier, _ in premier })
        let lieux = reperes.map { repere in
            let sz = sousZone[repere.subareaId]
            return Lieu(id: repere.id, x: repere.x, y: repere.y, monde: repere.worldMapId,
                        idCarte: repere.mapId, idSousZone: repere.subareaId,
                        categorie: repere.categoryId, noms: repere.name.parLangue,
                        zone: sz.flatMap { zone[$0.areaId] } ?? [:], sousZone: sz?.name.parLangue ?? [:])
        }
        let parCase = sousZoneParCase(cases)
        let retenues = Set(cases.map(\.subAreaId))
            .union(reperes.filter { $0.worldMapId == Zaap.mondeDesDouze }.map(\.subareaId))
        return Carte(date: date, lieux: lieux, sousZones: graphe(retenues, sousZones), cases: parCase)
    }

    /// La sous-zone que montre chaque case : celle des cartes prioritaires sur
    /// la carte du monde (à défaut, de toutes), la plus fréquente ; à égalité,
    /// celle de la plus petite carte — un choix stable d'un relevé à l'autre.
    static func sousZoneParCase(_ cases: [Case]) -> [String: Int] {
        Dictionary(grouping: cases) { Carte.cle($0.posX, $0.posY) }.mapValues { memeCase in
            let prioritaires = memeCase.filter { $0.hasPriorityOnWorldmap == true }
            let parSousZone = Dictionary(grouping: prioritaires.isEmpty ? memeCase : prioritaires, by: \.subAreaId)
            return parSousZone.min { a, b in
                a.value.count != b.value.count ? a.value.count > b.value.count
                    : a.value.map(\.id).min()! < b.value.map(\.id).min()!
            }!.key
        }
    }

    /// Les sous-zones retenues, leurs voisines rendues symétriques — DofusDB en
    /// oublie dans un sens sur deux, et un chemin se parcourt dans les deux —
    /// et bornées aux retenues.
    static func graphe(_ retenues: Set<Int>, _ sousZones: [SousZone]) -> [SousZoneCarte] {
        var voisines: [Int: Set<Int>] = [:]
        for sz in sousZones where retenues.contains(sz.id) {
            for voisine in sz.neighbors ?? [] where voisine != sz.id && retenues.contains(voisine) {
                voisines[sz.id, default: []].insert(voisine)
                voisines[voisine, default: []].insert(sz.id)
            }
        }
        let parId = Dictionary(sousZones.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })
        return retenues.sorted().map { id in
            let zaap = parId[id]?.associatedZaapMapId
            return SousZoneCarte(id: id, zaap: zaap == 0 ? nil : zaap, voisines: (voisines[id] ?? []).sorted())
        }
    }

    /// `--exporter-carte` : télécharge la carte et l'écrit, triée et lisible
    /// pour que son diff se relise, puis quitte.
    @MainActor
    static func exporterLigneDeCommande(vers url: URL) -> Never {
        Task {
            do {
                let carte = try await telecharger()
                let encodeur = JSONEncoder()
                encodeur.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let triee = Carte(date: carte.date, lieux: carte.lieux.sorted { $0.id < $1.id },
                                  sousZones: carte.sousZones, cases: carte.cases)
                try encodeur.encode(triee).write(to: url, options: .atomic)
                print("\(triee.lieux.count) lieux, dont \(triee.zaaps.count) zaaps ; \(triee.cases.count) cases, "
                      + "\(triee.sousZones.count) sous-zones → \(url.path)")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Échec : \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }

    private static func parIdentifiants<Element: Decodable>(
        _ chemin: String, _ ids: [Int], _ filtres: [URLQueryItem] = []
    ) async throws -> [Element] {
        let ids = Array(Set(ids)).sorted()
        var elements: [Element] = []
        for debut in stride(from: 0, to: ids.count, by: DofusDB.parPage) {
            let lot = ids[debut..<min(debut + DofusDB.parPage, ids.count)]
            elements += try await DofusDB.toutes(chemin, filtres + lot.map { URLQueryItem(name: "id[$in][]", value: "\($0)") })
        }
        return elements
    }
}
