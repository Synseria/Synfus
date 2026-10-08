/// Une sous-zone du Monde des Douze telle que DofusDB la décrit : le zaap que
/// le jeu lui associe et celles qu'elle touche.
struct SousZoneCarte: Codable, Equatable, Sendable {
    let id: Int
    /// La carte du zaap associé (`associatedZaapMapId`, cf. `Lieu.idCarte`).
    let zaap: Int?
    /// Triées ; symétriques, quoi qu'en dise DofusDB.
    let voisines: [Int]
}

/// Les sous-zones indexées une fois, à chaque nouvelle carte : la réécriture
/// d'un `/travel` collé n'y fait que lire des dictionnaires.
struct ReseauSousZones: Sendable {
    private let parCase: [String: Int]
    private let zaapDe: [Int: Int]
    private let voisinesDe: [Int: [Int]]

    static let vide = ReseauSousZones(.vide)

    init(_ carte: Carte) {
        parCase = carte.cases
        zaapDe = Dictionary(carte.sousZones.compactMap { sz in sz.zaap.map { (sz.id, $0) } },
                            uniquingKeysWith: { premier, _ in premier })
        voisinesDe = Dictionary(carte.sousZones.map { ($0.id, $0.voisines) }, uniquingKeysWith: { premier, _ in premier })
    }

    /// `nil` hors du Monde des Douze relevé.
    func sousZone(_ x: Int, _ y: Int) -> Int? { parCase[Carte.cle(x, y)] }

    func zaapAssocie(_ sousZone: Int) -> Int? { zaapDe[sousZone] }

    func voisines(_ sousZone: Int) -> [Int] { voisinesDe[sousZone] ?? [] }
}
