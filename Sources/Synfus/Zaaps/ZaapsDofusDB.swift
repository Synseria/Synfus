import Foundation

/// La liste des zaaps depuis l'API de DofusDB, au clic « Mettre à jour » et au
/// démarrage quand elle a plus de `peremption` : les repères de carte nommés
/// « Zaap » (`hints`), nommés d'après leur sous-zone (`subareas`). Le décodage
/// et la péremption sont purs, le réseau n'est qu'autour.
enum ZaapsDofusDB {
    struct Repere: Decodable {
        let x: Int
        let y: Int
        let worldMapId: Int
        let subareaId: Int
    }

    struct SousZone: Decodable {
        let id: Int
        let name: DofusDB.Noms
    }

    enum Echec: LocalizedError {
        /// Moins de zaaps que cela : une réponse tronquée, pas la carte du jeu.
        case listeSuspecte(Int)

        var errorDescription: String? {
            switch self {
            case .listeSuspecte(let nombre): return L("zaap.maj.suspecte", nombre)
            }
        }
    }

    static let minimumPlausible = 20

    /// Jamais téléchargée, ou trop vieille.
    static func aRafraichir(releve: ReleveZaaps?, maintenant: Date) -> Bool {
        DofusDB.perimee(depuis: releve?.date, maintenant: maintenant)
    }

    /// Le seul chemin qui remplace la liste : en cas d'échec, l'ancienne reste.
    @MainActor
    static func mettreAJour(_ prefs: Preferences) async throws {
        let zaaps = try await telecharger()
        prefs.zaapsDofusDB = ReleveZaaps(date: Date(), zaaps: zaaps)
    }

    static func telecharger() async throws -> [Zaap] {
        let reperes: [Repere] = try await DofusDB.toutes("hints", [URLQueryItem(name: "name.fr", value: "Zaap")])
        let ids = Array(Set(reperes.map(\.subareaId))).sorted()
        var sousZones: [SousZone] = []
        for debut in stride(from: 0, to: ids.count, by: DofusDB.parPage) {
            let lot = ids[debut..<min(debut + DofusDB.parPage, ids.count)]
            sousZones += try await DofusDB.toutes("subareas", lot.map { URLQueryItem(name: "id[$in][]", value: "\($0)") })
        }
        let zaaps = assembler(reperes: reperes, sousZones: sousZones)
        guard zaaps.count >= minimumPlausible else { throw Echec.listeSuspecte(zaaps.count) }
        return zaaps
    }

    /// Un zaap par case, nommé par sa sous-zone en fr, en et es.
    static func assembler(reperes: [Repere], sousZones: [SousZone]) -> [Zaap] {
        let noms = Dictionary(sousZones.map { ($0.id, $0.name) }, uniquingKeysWith: { premier, _ in premier })
        var vus: Set<String> = []
        return reperes.compactMap { repere in
            let traduits = noms[repere.subareaId]?.parLangue ?? [:]
            let zaap = Zaap(repere.x, repere.y, monde: repere.worldMapId,
                            noms: traduits.isEmpty ? ["fr": "Zaap"] : traduits)
            return vus.insert(zaap.cle).inserted ? zaap : nil
        }
    }
}
