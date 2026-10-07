import Foundation

/// Les quêtes depuis l'API de DofusDB, téléchargées par Synfus à la première
/// recherche puis tous les 30 jours, gardées sur le disque. Une page de
/// quêtes porte déjà ses étapes, objectifs et cartes ; restent à nommer les
/// objets, monstres et PNJ cités, et à situer les PNJ de départ.
enum QuetesDofusDB {
    struct QueteAPI: Decodable, Sendable {
        struct Depart: Decodable, Sendable {
            let mapId: Int
            let npcId: Int
        }

        let id: Int
        let name: DofusDB.Noms
        let levelMin: Int?
        let stepIds: [Int]?
        let startPosition: [Depart]?
        let steps: [EtapeAPI]?
    }

    struct EtapeAPI: Decodable, Sendable {
        let id: Int
        let name: DofusDB.Noms
        let objectives: [ObjectifAPI]?
    }

    struct ObjectifAPI: Decodable, Sendable {
        struct Coordonnees: Decodable, Sendable {
            let x: Int
            let y: Int
        }

        struct Carte: Decodable, Sendable {
            let posX: Int
            let posY: Int
        }

        struct Parametres: Decodable, Sendable {
            let parameter0: Int?
            let parameter1: Int?
            let parameter2: Int?
        }

        let className: String
        let text: DofusDB.Noms
        let coords: Coordonnees?
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
    }

    struct CarteAPI: Decodable, Sendable {
        let id: Int
        let posX: Int
        let posY: Int
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
        AnkamaAssets.supportDirectory.appending(path: "Quetes.json", directoryHint: .notDirectory)
    }

    static func gardees() -> Quetes? {
        guard let donnees = try? Data(contentsOf: fichier) else { return nil }
        return try? JSONDecoder().decode(Quetes.self, from: donnees)
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
        async let objets: [Nomme] = parIdentifiants("items", renvois.objets)
        async let monstres: [Nomme] = parIdentifiants("monsters", renvois.monstres)
        async let pnjs: [Nomme] = parIdentifiants("npcs", renvois.pnjs.union(departs.map(\.npcId)))
        async let cartes: [CarteAPI] = parIdentifiants("map-positions", Set(departs.map(\.mapId)))
        return try await assembler(quetes: quetes, objets: objets, monstres: monstres, pnjs: pnjs,
                                   cartes: cartes, date: maintenant)
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

    static func assembler(quetes: [QueteAPI], objets: [Nomme], monstres: [Nomme], pnjs: [Nomme],
                          cartes: [CarteAPI], date: Date) -> Quetes {
        let positionsDeCarte = Dictionary(cartes.map { ($0.id, PNJ.Position(x: $0.posX, y: $0.posY)) },
                                          uniquingKeysWith: { a, _ in a })
        var positions: [Int: [PNJ.Position]] = [:]
        func situer(_ pnj: Int, _ position: PNJ.Position?) {
            guard let position, !(positions[pnj]?.contains(position) ?? false) else { return }
            positions[pnj, default: []].append(position)
        }
        let modeles = quetes.map { api -> Quete in
            for depart in api.startPosition ?? [] { situer(depart.npcId, positionsDeCarte[depart.mapId]) }
            let ordre = api.stepIds ?? []
            let etapes = (api.steps ?? [])
                .sorted { (ordre.firstIndex(of: $0.id) ?? .max) < (ordre.firstIndex(of: $1.id) ?? .max) }
                .map { etape in
                    EtapeQuete(noms: etape.name.parLangue, objectifs: (etape.objectives ?? []).map { objectif in
                        let position = objectif.position
                        if let pnj = objectif.pnj { situer(pnj, position) }
                        return ObjectifQuete(textes: objectif.text.parLangue, x: position?.x, y: position?.y,
                                             objet: objectif.aRamener?.objet, quantite: objectif.aRamener?.quantite)
                    })
                }
            return Quete(id: api.id, noms: api.name.parLangue, niveau: api.levelMin ?? 0, etapes: etapes)
        }
        func noms(_ liste: [Nomme]) -> [String: [String: String]] {
            Dictionary(liste.map { (String($0.id), $0.name.parLangue) }, uniquingKeysWith: { a, _ in a })
        }
        let situes = pnjs.compactMap { pnj in
            positions[pnj.id].map { PNJ(id: pnj.id, noms: pnj.name.parLangue, positions: $0) }
        }
        return Quetes(date: date, quetes: modeles, pnjs: situes, objets: noms(objets),
                      monstres: noms(monstres), nomsPNJ: noms(pnjs))
    }

    private static func parIdentifiants<Element: Decodable & Sendable>(_ chemin: String, _ ids: Set<Int>) async throws -> [Element] {
        let ids = ids.sorted()
        var elements: [Element] = []
        for debut in stride(from: 0, to: ids.count, by: DofusDB.parPage) {
            let lot = ids[debut..<min(debut + DofusDB.parPage, ids.count)]
            elements += try await DofusDB.toutes(chemin, lot.map { URLQueryItem(name: "id[$in][]", value: "\($0)") }
                + [URLQueryItem(name: "$select[]", value: "id"), URLQueryItem(name: "$select[]", value: "name"),
                   URLQueryItem(name: "$select[]", value: "posX"), URLQueryItem(name: "$select[]", value: "posY")])
        }
        return elements
    }
}
