import Foundation

/// Une séance à l'atelier, pour un perso : la dernière lecture sûre, l'issue
/// de chaque fusion vue et leur compte. Une lecture n'est sûre que confirmée
/// par la suivante, identique : une lecture prise pendant l'animation du jeu,
/// ou un chiffre mal lu, n'invente pas de fusion. Les jets max lus restent
/// connus pour la séance : une case min/max mal lue n'en fait pas une exo.
/// Un autre objet — aucune ligne commune, ou un jet max qui change — repart
/// de zéro. Pur.
struct SuiviFM: Equatable, Sendable {
    private(set) var atelier: AtelierFM?
    private(set) var derniere: FusionFM?
    private(set) var comptes: [FusionFM.Issue: Int] = [:]
    /// Change à chaque nouvel objet posé sur l'atelier.
    private(set) var objet = 0
    /// La lecture vue une fois, en attente de confirmation.
    private var brouillon: AtelierFM?
    /// Les jets max de l'objet, par effet, lus pendant la séance.
    private var maxConnus: [Int: Int] = [:]

    /// Une lecture de l'atelier ; rend l'issue d'une fusion si elle en montre une.
    @discardableResult
    mutating func lu(_ lecture: AtelierFM, catalogue: CatalogueFM) -> FusionFM? {
        let complete = completer(lecture)
        guard let brouillon, Self.memesValeurs(brouillon, complete) else {
            self.brouillon = complete
            return nil
        }
        self.brouillon = complete
        defer {
            atelier = complete
            for ligne in complete.objet.lignes { if let max = ligne.max { maxConnus[ligne.effet] = max } }
        }
        guard let avant = atelier, !Self.memesValeurs(avant, complete) else { return nil }
        guard Self.memeObjet(avant.objet, complete.objet) else {
            derniere = nil
            comptes = [:]
            maxConnus = [:]
            objet += 1
            return nil
        }
        guard let fusion = FusionFM.constater(avant: avant.objet, apres: complete.objet, catalogue: catalogue,
                                              reliquatAvant: avant.reliquat, reliquatApres: complete.reliquat)
        else { return nil }
        derniere = fusion
        comptes[fusion.issue, default: 0] += 1
        return fusion
    }

    /// Les jets max manquants repris de ceux déjà lus.
    private func completer(_ lecture: AtelierFM) -> AtelierFM {
        let lignes = lecture.objet.lignes.map { ligne -> ObjetFM.Ligne in
            guard ligne.max == nil, let max = maxConnus[ligne.effet] else { return ligne }
            return ObjetFM.Ligne(effet: ligne.effet, valeur: ligne.valeur, max: max)
        }
        return AtelierFM(objet: ObjetFM(lignes: lignes), inconnues: lecture.inconnues, reliquat: lecture.reliquat,
                         historique: lecture.historique, cadre: lecture.cadre)
    }

    /// Deux lectures qui disent la même chose de l'objet.
    static func memesValeurs(_ a: AtelierFM, _ b: AtelierFM) -> Bool {
        a.objet == b.objet && a.reliquat == b.reliquat
    }

    /// Une ligne au moins en commun, et les jets max lus des deux côtés égaux.
    static func memeObjet(_ a: ObjetFM, _ b: ObjetFM) -> Bool {
        let communes = a.lignes.compactMap { ligne in b.ligne(ligne.effet).map { (ligne, $0) } }
        return !communes.isEmpty && communes.allSatisfy { $0.max == nil || $1.max == nil || $0.max == $1.max }
    }
}
