import Foundation

/// Les zaaps proposés : la liste de base (DofusDB si mise à jour, intégrée
/// sinon), les ajouts à la main, et les choix d'activation. Pur.
enum CatalogueZaaps {
    /// Hors du Monde des Douze, un zaap partage ses coordonnées avec un coin
    /// d'Amakna : le proposer pour un `/travel` y enverrait à tort.
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
        guard let position, !ItineraireZaap.horsDuMondeDesDouze(position.zone),
              zaap.monde == Zaap.mondeDesDouze
        else { return nil }
        return ItineraireZaap.distance((position.x, position.y), (zaap.x, zaap.y))
    }

    /// Du plus proche au plus loin ; ceux sans distance ferment la marche dans
    /// leur ordre, et sans position tout garde l'ordre donné.
    static func parDistance(_ zaaps: [Zaap], depuis position: PositionCarte?) -> [Zaap] {
        zaaps.enumerated()
            .sorted { a, b in
                switch (distance(de: a.element, depuis: position), distance(de: b.element, depuis: position)) {
                case let (da?, db?) where da != db: return da < db
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.offset < b.offset
                }
            }
            .map(\.element)
    }
}
