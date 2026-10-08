import Foundation

/// Les quêtes depuis l'API de DofusDB, téléchargées par Synfus à la première
/// recherche puis tous les 30 jours, gardées sur le disque. Une page de
/// quêtes porte déjà ses étapes, objectifs, cartes et récompenses ; restent à
/// nommer les objets, monstres, PNJ, émotes et titres cités, et à situer les
/// PNJ de départ.
enum QuetesDofusDB {
    struct QueteAPI: Decodable, Sendable {
        struct Depart: Decodable, Sendable {
            let mapId: Int
            let npcId: Int
        }

        struct Besoins: Decodable, Sendable {
            let quests: [Int]?
        }

        let id: Int
        let name: DofusDB.Noms
        let levelMin: Int?
        let isPartyQuest: Bool?
        let isDungeonQuest: Bool?
        let stepIds: [Int]?
        let startPosition: [Depart]?
        let need: Besoins?
        let startCriterion: String?
        let steps: [EtapeAPI]?
    }

    struct EtapeAPI: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
        let description: DofusDB.Noms?
        let optimalLevel: Int?
        let duration: Double?
        let rewards: [RecompenseAPI]?
        let objectives: [ObjectifAPI]?

        /// Une étape répétable a une récompense par tranche de niveau : celle
        /// du niveau optimal (une borne à -1 est ouverte).
        var recompense: RecompenseAPI? {
            let niveau = optimalLevel ?? 0
            return rewards?.first { recompense in
                let (minimum, maximum) = (recompense.levelMin ?? -1, recompense.levelMax ?? -1)
                return (minimum < 0 || minimum <= niveau) && (maximum < 0 || niveau <= maximum)
            } ?? rewards?.first
        }

        var recompenses: RecompensesEtape {
            guard let recompense else { return .aucune }
            let niveau = optimalLevel ?? 0, duree = duration ?? 0
            return RecompensesEtape(
                niveau: niveau,
                experience: RecompensesEtape.experience(niveau: niveau, duree: duree, ratio: recompense.experienceRatio ?? 0),
                kamas: RecompensesEtape.kamas(niveau: niveau, duree: duree, ratio: recompense.kamasRatio ?? 0),
                objets: (recompense.itemsReward ?? []).compactMap { paire in
                    guard paire.count == 2, paire[1] > 0 else { return nil }
                    return RecompensesEtape.Objet(objet: paire[0], quantite: paire[1])
                },
                emotes: recompense.emotesReward ?? [], titres: recompense.titlesReward ?? [])
        }
    }

    struct RecompenseAPI: Decodable, Sendable {
        let levelMin: Int?
        let levelMax: Int?
        let experienceRatio: Double?
        let kamasRatio: Double?
        /// Des paires `[objet, quantité]`.
        let itemsReward: [[Int]]?
        let emotesReward: [Int]?
        let titlesReward: [Int]?
    }

    struct ObjectifAPI: Decodable, Sendable {
        struct Coordonnees: Decodable, Sendable {
            let x: Int
            let y: Int
        }

        struct Carte: Decodable, Sendable {
            let posX: Int
            let posY: Int
            let subAreaId: Int?
        }

        struct Parametres: Decodable, Sendable {
            let parameter0: Int?
            let parameter1: Int?
            let parameter2: Int?
        }

        let id: Int
        let className: String
        let text: DofusDB.Noms
        let coords: Coordonnees?
        let mapId: Int?
        let map: Carte?
        let parameters: Parametres?

        var position: PNJ.Position? {
            if let coords { return PNJ.Position(x: coords.x, y: coords.y) }
            return map.map { PNJ.Position(x: $0.posX, y: $0.posY) }
        }

        /// Le PNJ chez qui l'objectif mène, s'il y en a un.
        var pnj: Int? {
            className.hasSuffix("ToNpcData") || className == "QuestObjectiveGoToNpcData" ? parameters?.parameter0 : nil
        }

        var aRamener: (objet: Int, quantite: Int)? {
            guard className == "QuestObjectiveBringItemToNpcData",
                  let objet = parameters?.parameter1, let quantite = parameters?.parameter2, quantite > 0
            else { return nil }
            return (objet, quantite)
        }
    }

    struct Nomme: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
        /// Pour un objet : son type (`item-types`).
        var typeId: Int?
    }

    /// Un titre : DofusDB le donne au masculin et au féminin.
    struct TitreAPI: Decodable, Sendable {
        let id: Int
        let nameMale: DofusDB.Noms
    }

    /// Un type d'objet et sa grande famille (« Ressource », « Consommable »…).
    struct TypeObjetAPI: Decodable, Sendable {
        struct Famille: Decodable, Sendable {
            let id: Int
            let name: DofusDB.Noms
        }

        let id: Int
        let superType: Famille?
    }

    struct CarteAPI: Decodable, Sendable {
        let id: Int
        let posX: Int
        let posY: Int
        let subAreaId: Int?
    }

    struct SousZoneAPI: Decodable, Sendable {
        let id: Int
        let areaId: Int
        let name: DofusDB.Noms
    }

    enum Echec: LocalizedError {
        case listeSuspecte(Int)

        var errorDescription: String? {
            switch self {
            case .listeSuspecte(let nombre): return L("quetes.maj.suspecte", nombre)
            }
        }
    }

    /// `~/Library/Application Support/Synfus/Quetes.json`
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Quetes.json", directoryHint: .notDirectory)
    }

    /// `nil` aussi pour un fichier d'une autre forme : il se retélécharge.
    static func gardees() -> Quetes? {
        guard let donnees = try? Data(contentsOf: fichier) else { return nil }
        return relire(donnees)
    }

    static func relire(_ donnees: Data) -> Quetes? {
        guard let quetes = try? JSONDecoder().decode(Quetes.self, from: donnees),
              quetes.format == Quetes.formatActuel
        else { return nil }
        return quetes
    }

    static func garder(_ quetes: Quetes) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(quetes).write(to: fichier, options: .atomic)
    }

    static func telecharger(maintenant: Date = Date()) async throws -> Quetes {
        let quetes: [QueteAPI] = try await DofusDB.toutesEnParallele("quests", [])
        guard quetes.count >= Quetes.minimumPlausible else { throw Echec.listeSuspecte(quetes.count) }
        let objectifs = quetes.flatMap { ($0.steps ?? []).flatMap { $0.objectives ?? [] } }
        let renvois = renvois(objectifs)
        let departs = quetes.flatMap { $0.startPosition ?? [] }
        let recompenses = quetes.flatMap { ($0.steps ?? []).map(\.recompenses) }
        async let objets: [Nomme] = parIdentifiants("items", renvois.objets.union(recompenses.flatMap { $0.objets.map(\.objet) }))
        async let emotes: [Nomme] = parIdentifiants("emoticons", Set(recompenses.flatMap(\.emotes)))
        async let titres: [TitreAPI] = parIdentifiants("titles", Set(recompenses.flatMap(\.titres)))
        async let monstres: [Nomme] = parIdentifiants("monsters", renvois.monstres)
        async let pnjs: [Nomme] = parIdentifiants("npcs", renvois.pnjs.union(departs.map(\.npcId)))
        let cartes: [CarteAPI] = try await parIdentifiants("map-positions", Set(departs.map(\.mapId)))
        let idsSousZones = Set(objectifs.compactMap { $0.map?.subAreaId } + cartes.compactMap(\.subAreaId))
        let sousZones: [SousZoneAPI] = try await parIdentifiants("subareas", idsSousZones)
        let zones: [Nomme] = try await parIdentifiants("areas", Set(sousZones.map(\.areaId)))
        let types: [TypeObjetAPI] = try await DofusDB.toutes("item-types", [])
        let metiers: [Nomme] = try await DofusDB.toutes("jobs", DofusDB.selection(["id", "name"]))
        let camps: [Nomme] = try await DofusDB.toutes("alignment-sides", DofusDB.selection(["id", "name"]))
        let cites = Cites(objets: try await objets, monstres: try await monstres, pnjs: try await pnjs,
                          cartes: cartes, sousZones: sousZones, zones: zones, types: types,
                          emotes: try await emotes, titres: try await titres, metiers: metiers, camps: camps)
        return assembler(quetes: quetes, cites: cites, date: maintenant)
    }

    /// Les identifiants cités : par les paramètres, et par les renvois du texte.
    static func renvois(_ objectifs: [ObjectifAPI]) -> (objets: Set<Int>, monstres: Set<Int>, pnjs: Set<Int>) {
        var objets: Set<Int> = [], monstres: Set<Int> = [], pnjs: Set<Int> = []
        for objectif in objectifs {
            if let ramener = objectif.aRamener { objets.insert(ramener.objet) }
            if let pnj = objectif.pnj { pnjs.insert(pnj) }
            _ = Quetes.resoudre(objectif.text.fr ?? "") { genre, id in
                guard let id = Int(id) else { return nil }
                switch genre {
                case "item": objets.insert(id)
                case "monster": monstres.insert(id)
                case "npc": pnjs.insert(id)
                default: break
                }
                return nil
            }
        }
        return (objets, monstres, pnjs)
    }

    /// Ce que les quêtes citent, téléchargé à part : leurs noms, cartes et zones.
    struct Cites {
        var objets: [Nomme] = []
        var monstres: [Nomme] = []
        var pnjs: [Nomme] = []
        var cartes: [CarteAPI] = []
        var sousZones: [SousZoneAPI] = []
        var zones: [Nomme] = []
        var types: [TypeObjetAPI] = []
        var emotes: [Nomme] = []
        var titres: [TitreAPI] = []
        var metiers: [Nomme] = []
        var camps: [Nomme] = []
    }

    static func assembler(quetes: [QueteAPI], cites: Cites, date: Date) -> Quetes {
        let (objets, monstres, pnjs) = (cites.objets, cites.monstres, cites.pnjs)
        let (cartes, sousZones, zones, types) = (cites.cartes, cites.sousZones, cites.zones, cites.types)
        let carteParId = Dictionary(cartes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        /// Par PNJ, par case : la carte, la sous-zone et les quêtes qui l'y placent.
        var vus: [Int: [PNJ.Position: (carte: Int?, sousZone: Int?, quetes: Set<Int>)]] = [:]
        var ordre: [Int: [PNJ.Position]] = [:]
        func situer(_ pnj: Int, _ position: PNJ.Position?, carte: Int?, _ sousZone: Int?, _ quete: Int) {
            guard let position else { return }
            if vus[pnj]?[position] == nil { ordre[pnj, default: []].append(position) }
            let deja = vus[pnj]?[position]
            vus[pnj, default: [:]][position] = (deja?.carte ?? carte, deja?.sousZone ?? sousZone,
                                                (deja?.quetes ?? []).union([quete]))
        }
        let modeles = quetes.map { api -> Quete in
            for depart in api.startPosition ?? [] {
                let carte = carteParId[depart.mapId]
                situer(depart.npcId, carte.map { PNJ.Position(x: $0.posX, y: $0.posY) }, carte: carte?.id,
                       carte?.subAreaId, api.id)
            }
            let ordre = api.stepIds ?? []
            let etapes = (api.steps ?? [])
                .sorted { (ordre.firstIndex(of: $0.id) ?? .max) < (ordre.firstIndex(of: $1.id) ?? .max) }
                .map { etape in
                    let objectifs = (etape.objectives ?? []).map { objectif in
                        let position = objectif.position
                        // Une carte que DofusDB ne connaît pas n'a pas de vue à montrer.
                        let carte = objectif.map == nil ? nil : objectif.mapId
                        if let pnj = objectif.pnj { situer(pnj, position, carte: carte, objectif.map?.subAreaId, api.id) }
                        return ObjectifQuete(id: objectif.id, textes: objectif.text.parLangue, x: position?.x, y: position?.y,
                                             carte: carte,
                                             objet: objectif.aRamener?.objet, quantite: objectif.aRamener?.quantite)
                    }
                    return EtapeQuete(noms: etape.name.parLangue, descriptions: etape.description?.parLangue ?? [:],
                                      objectifs: objectifs, recompenses: etape.recompenses)
                }
            return Quete(id: api.id, noms: api.name.parLangue, niveau: api.levelMin ?? 0,
                         groupe: api.isPartyQuest ?? false, donjon: api.isDungeonQuest ?? false,
                         prerequis: api.need?.quests ?? [], critere: api.startCriterion, etapes: etapes)
        }
        func noms(_ liste: [Nomme]) -> [String: [String: String]] {
            Dictionary(liste.map { (String($0.id), $0.name.parLangue) }, uniquingKeysWith: { a, _ in a })
        }
        let situes = pnjs.compactMap { pnj -> PNJ? in
            guard let positions = ordre[pnj.id], let releves = vus[pnj.id] else { return nil }
            let passages = positions.enumerated()
                .map { rang, position in
                    (rang, PNJ.Passage(position: position, carte: releves[position]?.carte,
                                       sousZone: releves[position]?.sousZone,
                                       quetes: releves[position]?.quetes.count ?? 0))
                }
                .sorted { $0.1.quetes != $1.1.quetes ? $0.1.quetes > $1.1.quetes : $0.0 < $1.0 }
                .map(\.1)
            return PNJ(id: pnj.id, noms: pnj.name.parLangue, passages: passages)
        }
        let nomsZones = noms(zones)
        let lieux = Dictionary(sousZones.map {
            (String($0.id), SousZoneNommee(noms: $0.name.parLangue, zone: nomsZones[String($0.areaId)] ?? [:]))
        }, uniquingKeysWith: { a, _ in a })
        let familleDuType = Dictionary(types.compactMap { type in type.superType.map { (type.id, $0) } },
                                       uniquingKeysWith: { a, _ in a })
        let famillesObjets = Dictionary(objets.compactMap { objet in
            objet.typeId.flatMap { familleDuType[$0] }.map { (String(objet.id), $0.id) }
        }, uniquingKeysWith: { a, _ in a })
        let familles = Dictionary(familleDuType.values.map { (String($0.id), $0.name.parLangue) },
                                  uniquingKeysWith: { a, _ in a })
        return Quetes(format: Quetes.formatActuel, date: date, quetes: modeles, pnjs: situes, objets: noms(objets),
                      monstres: noms(monstres), nomsPNJ: noms(pnjs), sousZones: lieux, famillesObjets: famillesObjets, familles: familles,
                      emotes: noms(cites.emotes),
                      titres: Dictionary(cites.titres.map { (String($0.id), $0.nameMale.parLangue) }, uniquingKeysWith: { a, _ in a }),
                      metiers: noms(cites.metiers), camps: noms(cites.camps))
    }

    private static func parIdentifiants<Element: Decodable & Sendable>(_ chemin: String, _ ids: Set<Int>) async throws -> [Element] {
        let ids = ids.sorted()
        var elements: [Element] = []
        for debut in stride(from: 0, to: ids.count, by: DofusDB.parPage) {
            let lot = ids[debut..<min(debut + DofusDB.parPage, ids.count)]
            elements += try await DofusDB.toutes(chemin, lot.map { URLQueryItem(name: "id[$in][]", value: "\($0)") }
                + [URLQueryItem(name: "$select[]", value: "id"), URLQueryItem(name: "$select[]", value: "name"),
                   URLQueryItem(name: "$select[]", value: "posX"), URLQueryItem(name: "$select[]", value: "posY"),
                   URLQueryItem(name: "$select[]", value: "subAreaId"), URLQueryItem(name: "$select[]", value: "areaId"),
                   URLQueryItem(name: "$select[]", value: "typeId"), URLQueryItem(name: "$select[]", value: "nameMale")])
        }
        return elements
    }
}
