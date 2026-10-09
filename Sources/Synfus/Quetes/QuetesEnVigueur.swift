/// Un jeu de quêtes prêt à servir, bâti hors du fil principal (`QuetesStore`) :
/// ses index et les fiches déjà montrées, dans une langue. Un autre jeu ou une
/// autre langue est un autre `QuetesEnVigueur`, publié d'un coup : une fiche
/// gardée ne survit pas au jeu qui l'a faite. Pur.
struct QuetesEnVigueur: Sendable {
    let quetes: Quetes
    let langue: Langue
    private let parId: [Int: Quete]
    /// Triées une fois pour les onglets des réglages : par niveau, par nom.
    let quetesTriees: [Quete]
    let pnjsTries: [PNJ]
    /// Le panneau redemande sa fiche à chaque rendu ; la faire résout tous
    /// les renvois et cherche les suivantes parmi toutes les quêtes.
    private var fiches: [Int: FicheQuete] = [:]

    init(_ quetes: Quetes, langue: Langue) {
        self.quetes = quetes
        self.langue = langue
        parId = Dictionary(quetes.quetes.map { ($0.id, $0) }, uniquingKeysWith: { premiere, _ in premiere })
        quetesTriees = quetes.quetes.sorted {
            ($0.niveau, Lieu.traduit($0.noms, langue) ?? "") < ($1.niveau, Lieu.traduit($1.noms, langue) ?? "")
        }
        pnjsTries = quetes.pnjs.sorted {
            (Lieu.traduit($0.noms, langue) ?? "").localizedStandardCompare(Lieu.traduit($1.noms, langue) ?? "")
                == .orderedAscending
        }
    }

    /// Une quête par son identifiant, sans parcourir les deux mille.
    mutating func fiche(_ id: Int) -> FicheQuete? {
        if let gardee = fiches[id] { return gardee }
        guard let quete = parId[id] else { return nil }
        let fiche = quetes.fiche(quete, en: langue)
        fiches[id] = fiche
        return fiche
    }

    func nom(_ id: Int) -> String? {
        parId[id].flatMap { Lieu.traduit($0.noms, langue) }
    }
}
