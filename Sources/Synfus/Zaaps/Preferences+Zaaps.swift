/// Les zaaps tels que les réglages les composent — le seul endroit qui
/// assemble base, ajouts et choix.
extension Preferences {
    var zaapsDeBase: [Zaap] { CarteStore.shared.carte.zaaps }

    var zaapsConnus: [Zaap] { CatalogueZaaps.tous(base: zaapsDeBase, ajoutes: zaapsAjoutes) }

    var zaapsActifs: [Zaap] {
        CatalogueZaaps.actifs(base: zaapsDeBase, ajoutes: zaapsAjoutes, choix: zaapsChoix)
    }

    var zaapsFavorisConnus: [Zaap] { CatalogueZaaps.favoris(zaapsFavoris, parmi: zaapsConnus) }

    /// Un favori, zaap (`Zaap.cle`) ou lieu (`Lieu.cle`) : chacun sa liste,
    /// un seul chemin pour les tenir.
    func estFavori(_ cle: String) -> Bool {
        (cle.hasPrefix(Lieu.prefixeCle) ? lieuxFavoris : zaapsFavoris).contains(cle)
    }

    func basculerFavori(_ cle: String) {
        if cle.hasPrefix(Lieu.prefixeCle) {
            if lieuxFavoris.contains(cle) { lieuxFavoris.removeAll { $0 == cle } } else { lieuxFavoris.append(cle) }
        } else {
            if zaapsFavoris.contains(cle) { zaapsFavoris.removeAll { $0 == cle } } else { zaapsFavoris.append(cle) }
        }
    }
}
