import Foundation

/// La carte depuis l'API de DofusDB : les repères (`hints`), nommés par leur
/// sous-zone (`subareas`) et leur zone (`areas`). Gardée sur le disque ;
/// l'assemblage est pur, le réseau n'est qu'autour.
enum CarteDofusDB {
    struct Repere: Decodable {
        let id: Int
        let x: Int
        let y: Int
        let worldMapId: Int
        let categoryId: Int
        let subareaId: Int
        let name: DofusDB.Noms
    }

    struct SousZone: Decodable {
        let id: Int
        let areaId: Int
        let name: DofusDB.Noms
    }

    struct Zone: Decodable {
        let id: Int
        let name: DofusDB.Noms
    }

    enum Echec: LocalizedError {
        case listeSuspecte(Int)

        var errorDescription: String? {
            switch self {
            case .listeSuspecte(let nombre): return L("carte.maj.suspecte", nombre)
            }
        }
    }

    /// `~/Library/Application Support/Synfus/Carte.json`
    private static var fichier: URL {
        AnkamaAssets.supportDirectory.appending(path: "Carte.json", directoryHint: .notDirectory)
    }

    /// La plus récente de la carte gardée et de la carte intégrée : une mise à
    /// jour de Synfus peut apporter une liste plus fraîche que le disque.
    static func locale() -> Carte {
        guard let donnees = try? Data(contentsOf: fichier),
              let gardee = try? JSONDecoder().decode(Carte.self, from: donnees),
              gardee.date > Carte.integree.date
        else { return Carte.integree }
        return gardee
    }

    static func garder(_ carte: Carte) throws {
        try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(carte).write(to: fichier, options: .atomic)
    }

    static func telecharger(maintenant: Date = Date()) async throws -> Carte {
        let reperes: [Repere] = try await DofusDB.toutes("hints", [])
        let sousZones: [SousZone] = try await parIdentifiants("subareas", reperes.map(\.subareaId))
        let zones: [Zone] = try await parIdentifiants("areas", sousZones.map(\.areaId))
        let carte = Carte(date: maintenant, lieux: assembler(reperes: reperes, sousZones: sousZones, zones: zones))
        guard carte.lieux.count >= Carte.minimumPlausible else { throw Echec.listeSuspecte(carte.lieux.count) }
        return carte
    }

    /// Dans l'ordre de DofusDB ; un repère sans sous-zone connue garde des
    /// noms de zone vides.
    static func assembler(reperes: [Repere], sousZones: [SousZone], zones: [Zone]) -> [Lieu] {
        let sousZone = Dictionary(sousZones.map { ($0.id, $0) }, uniquingKeysWith: { premier, _ in premier })
        let zone = Dictionary(zones.map { ($0.id, $0.name.parLangue) }, uniquingKeysWith: { premier, _ in premier })
        return reperes.map { repere in
            let sz = sousZone[repere.subareaId]
            return Lieu(id: repere.id, x: repere.x, y: repere.y, monde: repere.worldMapId,
                        categorie: repere.categoryId, noms: repere.name.parLangue,
                        zone: sz.flatMap { zone[$0.areaId] } ?? [:], sousZone: sz?.name.parLangue ?? [:])
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
                let triee = Carte(date: carte.date, lieux: carte.lieux.sorted { $0.id < $1.id })
                try encodeur.encode(triee).write(to: url, options: .atomic)
                print("\(triee.lieux.count) lieux, dont \(triee.zaaps.count) zaaps → \(url.path)")
                exit(0)
            } catch {
                FileHandle.standardError.write(Data("Échec : \(error.localizedDescription)\n".utf8))
                exit(1)
            }
        }
        dispatchMain()
    }

    private static func parIdentifiants<Element: Decodable>(_ chemin: String, _ ids: [Int]) async throws -> [Element] {
        let ids = Array(Set(ids)).sorted()
        var elements: [Element] = []
        for debut in stride(from: 0, to: ids.count, by: DofusDB.parPage) {
            let lot = ids[debut..<min(debut + DofusDB.parPage, ids.count)]
            elements += try await DofusDB.toutes(chemin, lot.map { URLQueryItem(name: "id[$in][]", value: "\($0)") })
        }
        return elements
    }
}
