/// Une liste d'un onglet de données, triée, et les textes de recherche de
/// chaque élément normalisés selon la règle de la palette
/// (`RecherchePalette.Champs`). Rien n'est recalculé tant que la source ne
/// change pas, et les champs attendent la première lettre tapée : ouvrir
/// l'onglet ne normalise rien, une frappe ne fait que comparer des mots.
/// Gardée d'une ouverture de l'onglet à l'autre (`ListesReglages`).
@MainActor
final class ListeCherchable<Element> {
    private var source: AnyHashable?
    private var tries: [Element] = []
    private var champs: [RecherchePalette.Champs]?

    /// `trier` ne repasse que pour une nouvelle `source`, `champs` qu'au
    /// premier filtre sur elle.
    func elements(source: AnyHashable, filtre: String, trier: () -> [Element],
                  champs: (Element) -> RecherchePalette.Champs) -> [Element] {
        if source != self.source {
            self.source = source
            tries = trier()
            self.champs = nil
        }
        let mots = RecherchePalette.mots(filtre)
        guard !mots.isEmpty else { return tries }
        let prets = self.champs ?? tries.map(champs)
        self.champs = prets
        return zip(tries, prets).compactMap { element, champs in champs.garde(mots) ? element : nil }
    }
}

/// Les listes des onglets de données, une par onglet.
@MainActor
enum ListesReglages {
    static let zaaps = ListeCherchable<Zaap>()
    static let lieux = ListeCherchable<Lieu>()
    static let quetes = ListeCherchable<Quete>()
    static let pnjs = ListeCherchable<PNJ>()
}
