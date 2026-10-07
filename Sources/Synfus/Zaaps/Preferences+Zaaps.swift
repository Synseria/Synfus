/// Les zaaps tels que les réglages les composent — le seul endroit qui
/// assemble base, ajouts et choix.
extension Preferences {
    var zaapsDeBase: [Zaap] { CarteStore.shared.carte.zaaps }

    var zaapsConnus: [Zaap] { CatalogueZaaps.tous(base: zaapsDeBase, ajoutes: zaapsAjoutes) }

    var zaapsActifs: [Zaap] {
        CatalogueZaaps.actifs(base: zaapsDeBase, ajoutes: zaapsAjoutes, choix: zaapsChoix)
    }

    var zaapsFavorisConnus: [Zaap] { CatalogueZaaps.favoris(zaapsFavoris, parmi: zaapsConnus) }
}
