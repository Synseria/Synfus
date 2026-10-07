import Foundation

/// La liste des zaaps depuis l'API de DofusDB, au seul clic « Mettre à jour » :
/// les repères de carte nommés « Zaap » (`hints`), nommés d'après leur
/// sous-zone (`subareas`). Le décodage est pur, le réseau n'est qu'autour.
enum ZaapsDofusDB {
    struct Page<Element: Decodable>: Decodable {
        let total: Int
        let data: [Element]
    }

    struct Repere: Decodable {
        let x: Int
        let y: Int
        let worldMapId: Int
        let subareaId: Int
    }

    struct SousZone: Decodable {
        struct Noms: Decodable {
            let fr: String?
            let en: String?
            let es: String?
        }
        let id: Int
        let name: Noms
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
    private static let api = URL(string: "https://api.dofusdb.fr")!
    /// Le plafond de page de l'API.
    private static let parPage = 50

    static func telecharger() async throws -> [Zaap] {
        let reperes: [Repere] = try await toutes("hints", [URLQueryItem(name: "name.fr", value: "Zaap")])
        let ids = Array(Set(reperes.map(\.subareaId))).sorted()
        var sousZones: [SousZone] = []
        for debut in stride(from: 0, to: ids.count, by: parPage) {
            let lot = ids[debut..<min(debut + parPage, ids.count)]
            sousZones += try await toutes("subareas", lot.map { URLQueryItem(name: "id[$in][]", value: "\($0)") })
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
            let nom = noms[repere.subareaId]
            let traduits = ["fr": nom?.fr, "en": nom?.en, "es": nom?.es].compactMapValues { $0 }
            let zaap = Zaap(repere.x, repere.y, monde: repere.worldMapId,
                            noms: traduits.isEmpty ? ["fr": "Zaap"] : traduits)
            return vus.insert(zaap.cle).inserted ? zaap : nil
        }
    }

    private static func toutes<Element: Decodable>(_ chemin: String, _ filtres: [URLQueryItem]) async throws -> [Element] {
        var elements: [Element] = []
        while true {
            var url = URLComponents(url: api.appending(path: chemin), resolvingAgainstBaseURL: false)!
            url.queryItems = filtres + [URLQueryItem(name: "$limit", value: "\(parPage)"),
                                        URLQueryItem(name: "$skip", value: "\(elements.count)")]
            let (donnees, reponse) = try await URLSession.shared.data(from: url.url!)
            if let http = reponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let page = try JSONDecoder().decode(Page<Element>.self, from: donnees)
            elements += page.data
            if page.data.isEmpty || elements.count >= page.total { return elements }
        }
    }
}
