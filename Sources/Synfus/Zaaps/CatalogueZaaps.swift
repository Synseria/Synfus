import Foundation

/// Les zaaps proposés : la liste de base (DofusDB si mise à jour, intégrée
/// sinon), les ajouts à la main, et les choix d'activation. Pur.
enum CatalogueZaaps {
    /// Le `/zaap x,y` du jeu ne lit ses coordonnées que sur la carte du Monde
    /// des Douze : celui d'une autre carte du monde — Incarnam, ou une couche
    /// à part comme la Canopée d'Otomaï — y est refusé, faute de zaap à ces
    /// coordonnées. Il reste à cocher à la main.
    static func actifParDefaut(_ zaap: Zaap) -> Bool {
        zaap.monde == Zaap.mondeDesDouze
    }

    static func estActif(_ zaap: Zaap, choix: [String: Bool]) -> Bool {
        choix[zaap.cle] ?? actifParDefaut(zaap)
    }

    /// La base puis les ajouts ; un ajout qui reprend un zaap de la base ne
    /// le double pas.
    static func tous(base: [Zaap], ajoutes: [Zaap]) -> [Zaap] {
        let connus = Set(base.map(\.cle))
        return base + ajoutes.filter { !connus.contains($0.cle) }
    }

    static func actifs(base: [Zaap], ajoutes: [Zaap], choix: [String: Bool]) -> [Zaap] {
        tous(base: base, ajoutes: ajoutes).filter { estActif($0, choix: choix) }
    }

    /// Les favoris dans l'ordre choisi ; une clé qui ne désigne plus aucun zaap
    /// connu (ajout supprimé, liste DofusDB changée) est sautée.
    static func favoris(_ cles: [String], parmi connus: [Zaap]) -> [Zaap] {
        let parCle = Dictionary(connus.map { ($0.cle, $0) }, uniquingKeysWith: { premier, _ in premier })
        return cles.compactMap { parCle[$0] }
    }

    /// Les cartes à traverser jusqu'au zaap — `nil` quand le nombre ne veut
    /// rien dire : position inconnue ou hors du Monde des Douze, zaap sur une
    /// autre carte du monde.
    static func distance(de zaap: Zaap, depuis position: PositionCarte?) -> Int? {
        ItineraireZaap.aPied(depuis: position, vers: (zaap.x, zaap.y), dansLesDouze: zaap.monde == Zaap.mondeDesDouze)
    }

    /// Du plus proche au plus loin ; ceux sans distance ferment la marche dans
    /// leur ordre, et sans position tout garde l'ordre donné. Chaque distance
    /// est comptée une fois, pas à chaque comparaison.
    static func parDistance(_ zaaps: [Zaap], depuis position: PositionCarte?) -> [Zaap] {
        zaaps.enumerated()
            .map { (rang: $0.offset, zaap: $0.element, distance: distance(de: $0.element, depuis: position)) }
            .sorted { a, b in
                switch (a.distance, b.distance) {
                case let (da?, db?) where da != db: return da < db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.rang < b.rang
                }
            }
            .map(\.zaap)
    }

    /// Un favori et la ligne qui le dit : la même au clic droit de la palette et dans le menu.
    struct LigneFavori: Equatable {
        let zaap: Zaap
        let titre: String
    }

    /// Du plus proche au plus loin, chaque ligne avec ses cartes quand elles ont un sens.
    static func lignesFavoris(_ zaaps: [Zaap], depuis position: PositionCarte?, langue: Langue) -> [LigneFavori] {
        parDistance(zaaps, depuis: position).map { zaap in
            let coordonnees = Coordonnees.texte(zaap.x, zaap.y)
            let titre = distance(de: zaap, depuis: position).map {
                L("barre.zaap.favori", nombre: $0, zaap.nom(en: langue), coordonnees, $0)
            } ?? L("barre.zaap.favoriSansDistance", zaap.nom(en: langue), coordonnees)
            return LigneFavori(zaap: zaap, titre: titre)
        }
    }
}
