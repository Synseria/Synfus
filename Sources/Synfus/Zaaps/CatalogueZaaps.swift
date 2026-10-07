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
}

/// La liste téléchargée de DofusDB, et quand.
struct ReleveZaaps: Codable, Equatable, Sendable {
    let date: Date
    let zaaps: [Zaap]
}
