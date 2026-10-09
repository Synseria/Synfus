/// Les zaaps tels que les réglages les composent — le seul endroit qui
/// assemble base, ajouts et choix.
extension Preferences {
    var zaapsDeBase: [Zaap] { CarteStore.shared.zaaps }

    var zaapsConnus: [Zaap] { CatalogueZaaps.tous(base: zaapsDeBase, ajoutes: zaapsAjoutes) }

    var zaapsActifs: [Zaap] {
        CatalogueZaaps.actifs(base: zaapsDeBase, ajoutes: zaapsAjoutes, choix: zaapsChoix)
    }

    var zaapsFavorisConnus: [Zaap] { CatalogueZaaps.favoris(zaapsFavoris, parmi: zaapsConnus) }

    /// Un favori, zaap (`Zaap.cle`), lieu (`Lieu.cle`) ou PNJ (`PNJ.cle`) :
    /// chacun sa liste, un seul chemin pour les tenir.
    func estFavori(_ cle: String) -> Bool {
        self[keyPath: Self.favoris(cle)].contains(cle)
    }

    func basculerFavori(_ cle: String) {
        let liste = Self.favoris(cle)
        if self[keyPath: liste].contains(cle) { self[keyPath: liste].removeAll { $0 == cle } } else { self[keyPath: liste].append(cle) }
    }

    /// Tous les favoris, pour la palette.
    var favoris: Set<String> { Set(zaapsFavoris + lieuxFavoris + pnjsFavoris) }

    private static func favoris(_ cle: String) -> ReferenceWritableKeyPath<Preferences, [String]> {
        if cle.hasPrefix(Lieu.prefixeCle) { return \.lieuxFavoris }
        if cle.hasPrefix(PNJ.prefixeCle) { return \.pnjsFavoris }
        return \.zaapsFavoris
    }
}
