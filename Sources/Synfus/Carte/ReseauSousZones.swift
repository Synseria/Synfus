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
    /// L'index inverse : où chercher un monstre, c'est la case de sa sous-zone
    /// la plus proche du perso (`OuTrouver`).
    private let casesDe: [Int: [(x: Int, y: Int)]]

    static let vide = ReseauSousZones(.vide)

    init(_ carte: Carte) {
        parCase = carte.cases
        var casesDe: [Int: [(x: Int, y: Int)]] = [:]
        for (cle, sousZone) in carte.cases {
            let parties = cle.split(separator: ",")
            guard parties.count == 2, let x = Int(parties[0]), let y = Int(parties[1]) else { continue }
            casesDe[sousZone, default: []].append((x, y))
        }
        // L'ordre d'un dictionnaire change d'un lancement à l'autre : trié, le
        // choix d'une case à égalité reste le même.
        self.casesDe = casesDe.mapValues { $0.sorted { ($0.x, $0.y) < ($1.x, $1.y) } }
        zaapDe = Dictionary(carte.sousZones.compactMap { sz in sz.zaap.map { (sz.id, $0) } },
                            uniquingKeysWith: { premier, _ in premier })
        voisinesDe = Dictionary(carte.sousZones.map { ($0.id, $0.voisines) }, uniquingKeysWith: { premier, _ in premier })
    }

    /// `nil` hors du Monde des Douze relevé.
    func sousZone(_ x: Int, _ y: Int) -> Int? { parCase[Carte.cle(x, y)] }

    func zaapAssocie(_ sousZone: Int) -> Int? { zaapDe[sousZone] }

    func voisines(_ sousZone: Int) -> [Int] { voisinesDe[sousZone] ?? [] }

    /// Les cases relevées de la sous-zone ; aucune hors du Monde des Douze
    /// ou pour une sous-zone que la carte du monde ne montre pas (intérieurs).
    func cases(_ sousZone: Int) -> [(x: Int, y: Int)] { casesDe[sousZone] ?? [] }

    /// La sous-zone est-elle du Monde des Douze ? Ses coordonnées, sinon,
    /// recoupent celles d'Amakna sans en être (Incarnam, les dimensions divines…).
    func estDuMondeDesDouze(_ sousZone: Int) -> Bool { voisinesDe[sousZone] != nil }

    /// La carte est lue : avant, aucune sous-zone ne dit son monde.
    var estLu: Bool { !voisinesDe.isEmpty }

    /// Une case est-elle hors du Monde des Douze, d'après sa sous-zone ? Sans
    /// sous-zone, ou la carte pas encore lue, rien ne le dit : non.
    func horsDesDouze(_ sousZone: Int?) -> Bool {
        guard let sousZone, estLu else { return false }
        return !estDuMondeDesDouze(sousZone)
    }
}
