import Foundation

/// Une séance à l'atelier : la dernière lecture, l'issue de chaque fusion
/// vue (deux lectures qui diffèrent) et leur compte. Un autre objet posé
/// sur l'atelier — aucune ligne commune, ou un jet max qui change — repart
/// de zéro. Pur.
struct SuiviFM: Equatable, Sendable {
    private(set) var atelier: AtelierFM?
    private(set) var derniere: FusionFM?
    private(set) var comptes: [FusionFM.Issue: Int] = [:]

    /// Une lecture de l'atelier ; rend l'issue d'une fusion si elle en montre une.
    @discardableResult
    mutating func lu(_ nouveau: AtelierFM, catalogue: CatalogueFM) -> FusionFM? {
        defer { atelier = nouveau }
        guard let avant = atelier else { return nil }
        guard Self.memeObjet(avant.objet, nouveau.objet) else {
            derniere = nil
            comptes = [:]
            return nil
        }
        guard let fusion = FusionFM.constater(avant: avant.objet.valeurs, apres: nouveau.objet.valeurs, catalogue: catalogue,
                                              reliquatAvant: avant.reliquat, reliquatApres: nouveau.reliquat)
        else { return nil }
        derniere = fusion
        comptes[fusion.issue, default: 0] += 1
        return fusion
    }

    /// Une ligne au moins en commun, et les jets max lus des deux côtés égaux.
    static func memeObjet(_ a: ObjetFM, _ b: ObjetFM) -> Bool {
        let communes = a.lignes.compactMap { ligne in b.ligne(ligne.effet).map { (ligne, $0) } }
        return !communes.isEmpty && communes.allSatisfy { $0.max == nil || $1.max == nil || $0.max == $1.max }
    }
}
