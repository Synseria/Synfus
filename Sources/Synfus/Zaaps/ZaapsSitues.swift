/// Les zaaps actifs rangés une fois sur le réseau des sous-zones, par carte du
/// jeu et par sous-zone : le choix du zaap d'une cible (`ItineraireZaap.zaap(vers:)`),
/// refait pour chaque entrée de la palette et chaque coût, n'y lit que des dictionnaires.
struct ZaapsSitues: Sendable {
    let liste: [Zaap]
    let reseau: ReseauSousZones
    private let parCarte: [Int: Zaap]
    private let parSousZone: [Int: [Zaap]]

    static let vide = ZaapsSitues([], reseau: .vide)

    init(_ zaaps: [Zaap], reseau: ReseauSousZones) {
        liste = zaaps
        self.reseau = reseau
        parCarte = Dictionary(zaaps.compactMap { zaap in zaap.idCarte.map { ($0, zaap) } },
                              uniquingKeysWith: { premier, _ in premier })
        var parSousZone: [Int: [Zaap]] = [:]
        for zaap in zaaps {
            guard let sousZone = reseau.sousZone(du: zaap) else { continue }
            parSousZone[sousZone, default: []].append(zaap)
        }
        self.parSousZone = parSousZone
    }

    /// La zone du zaap (`ReseauSousZones.zone`).
    func zone(de zaap: Zaap) -> Int? { reseau.sousZone(du: zaap).flatMap(reseau.zone) }

    /// Le zaap actif posé sur cette carte du jeu (`Zaap.idCarte`).
    func zaap(carte: Int) -> Zaap? { parCarte[carte] }

    /// Les zaaps actifs du Monde des Douze dans cette sous-zone, dans l'ordre de `liste`.
    func zaaps(dans sousZone: Int) -> [Zaap] { parSousZone[sousZone] ?? [] }
}
