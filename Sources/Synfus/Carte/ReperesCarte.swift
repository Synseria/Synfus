/// Les repères de la carte rangés une fois par carte, pour situer un repaire
/// (`OuTrouver.situer`) sans parcourir les huit cents ni normaliser leurs noms
/// à chaque rendu. À clé égale, le premier dans l'ordre de la carte. Pur.
struct ReperesCarte: Sendable {
    private let parId: [Int: Lieu]
    private let parSousZone: [Int: Lieu]
    private let donjonsParCarte: [Int: Lieu]
    private let donjonsParNom: [String: Lieu]

    init(_ lieux: [Lieu]) {
        func premiers<Cle: Hashable>(_ paires: [(Cle, Lieu)]) -> [Cle: Lieu] {
            Dictionary(paires, uniquingKeysWith: { premier, _ in premier })
        }
        parId = premiers(lieux.map { ($0.id, $0) })
        parSousZone = premiers(lieux.map { ($0.idSousZone, $0) })
        let donjons = lieux.filter { $0.categorie == CategorieLieu.donjon.rawValue }
        donjonsParCarte = premiers(donjons.map { ($0.idCarte, $0) })
        donjonsParNom = premiers(donjons.compactMap { donjon in
            donjon.noms[Langue.fr.rawValue].map { (RecherchePalette.normaliser($0), donjon) }
        })
    }

    /// Par son identifiant DofusDB (`Lieu.id`), stable d'une carte à l'autre.
    func lieu(id: Int) -> Lieu? { parId[id] }

    /// Un repère de la sous-zone : il situe celles que la carte du monde ne
    /// montre pas (intérieurs, autres mondes).
    func lieu(sousZone: Int) -> Lieu? { parSousZone[sousZone] }

    func donjon(carte: Int) -> Lieu? { donjonsParCarte[carte] }

    /// Par son nom français, sans casse ni accents.
    func donjon(nom: String) -> Lieu? { donjonsParNom[RecherchePalette.normaliser(nom)] }
}
