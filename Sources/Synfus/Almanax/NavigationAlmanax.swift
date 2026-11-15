/// Les flèches de la vue Almanax (pur) : la carte du jour, seule sur sa ligne, puis les six
/// suivantes trois par ligne.
enum NavigationAlmanax {
    private static let parLigne = 3

    /// La carte où mène une flèche ; `index` si elle n'en rejoint aucune.
    static func cible(depuis index: Int, colonne: Int, ligne: Int) -> Int {
        let dernier = Almanax.joursMontres - 1
        if ligne != 0 {
            if index == 0 { return ligne > 0 ? 1 : 0 }
            let cible = index + ligne * parLigne
            if cible < 1 { return 0 }
            return cible > dernier ? index : cible
        }
        guard index > 0 else { return 0 }
        let cible = index + colonne
        let memeLigne = cible >= 1 && cible <= dernier && (cible - 1) / parLigne == (index - 1) / parLigne
        return memeLigne ? cible : index
    }

    /// Les cartes sous lesquelles se déplie « Localiser » : la fin de la ligne de `index`.
    static func ligne(de index: Int) -> ClosedRange<Int> {
        guard index > 0 else { return 0...0 }
        let debut = 1 + (index - 1) / parLigne * parLigne
        return debut...min(debut + parLigne - 1, Almanax.joursMontres - 1)
    }
}
