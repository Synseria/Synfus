import Foundation

/// L'issue d'une rune, déduite de deux lectures de la table des effets — la
/// couleur de l'historique est moins sûre, et la rune posée ne se lit pas.
/// L'ordre dans lequel le jeu choisit les lignes perdues n'est pas publié :
/// il se constate. Pur.
struct FusionFM: Equatable, Sendable {
    enum Issue: Hashable, Sendable {
        /// La rune passe, rien n'est perdu.
        case succesCritique
        /// La rune passe, l'objet (ou le puits) perd environ son poids.
        case succesNeutre
        /// La rune ne passe pas, l'objet (ou le puits) perd environ son poids.
        case echec
    }

    let issue: Issue
    /// Les points gagnés, par effet : la ligne visée, ou l'exo ajoutée.
    let gains: [Int: Int]
    /// Les points perdus, par effet.
    let pertes: [Int: Int]
    /// Le poids des pertes sur les lignes.
    let poidsPerdu: Double

    /// Compare deux lectures de la table. La table défile : seules comptent
    /// les lignes vues dans les deux. Une ligne apparue n'est un gain que si
    /// aucune n'a disparu, qu'elle n'a ni min ni max (une exo) et que sa valeur
    /// est la puissance d'une rune : sinon c'est une ligne revenue dans la vue
    /// (curseur, infobulle, lecture manquée). Une rune ne monte qu'une ligne, de
    /// sa puissance : sinon ce n'est pas une fusion qu'on sache lire. Le reliquat qui baisse sans
    /// ligne perdue : le puits a payé, succès neutre — ou échec, si rien ne
    /// monte. `nil` : pas une fusion.
    static func constater(avant: ObjetFM, apres: ObjetFM, catalogue: CatalogueFM,
                          reliquatAvant: Double? = nil, reliquatApres: Double? = nil) -> FusionFM? {
        let (va, vb) = (avant.valeurs, apres.valeurs)
        var gains: [Int: Int] = [:]
        var pertes: [Int: Int] = [:]
        for effet in Set(va.keys).intersection(vb.keys) {
            let ecart = (vb[effet] ?? 0) - (va[effet] ?? 0)
            if ecart > 0 { gains[effet] = ecart }
            if ecart < 0 { pertes[effet] = -ecart }
        }
        if Set(va.keys).isSubset(of: vb.keys) {
            let apparues = apres.lignes.filter { va[$0.effet] == nil }
            if apparues.count == 1, let exo = apparues.first, exo.exo,
               catalogue.runes[exo.effet]?.contains(where: { $0.puissance == exo.valeur }) == true {
                gains[exo.effet] = exo.valeur
            }
        }
        // Une rune ajoute sa puissance : un autre gain, ce sont plusieurs runes
        // entre deux lectures (« Fusionner tout »), qu'on ne sait pas démêler.
        guard gains.count <= 1, gains.allSatisfy({ gain in
            catalogue.runes[gain.key]?.contains { $0.puissance == gain.value } == true
        }) else { return nil }
        let poidsPerdu = pertes.reduce(0.0) { $0 + Double($1.value) * (catalogue.effets[$1.key]?.poids ?? 0) }
        let puitsEntame = reliquatAvant.flatMap { avant in reliquatApres.map { $0 < avant } } ?? false
        let issue: Issue
        if !gains.isEmpty {
            issue = poidsPerdu > 0 || puitsEntame ? .succesNeutre : .succesCritique
        } else if poidsPerdu > 0 || puitsEntame {
            issue = .echec
        } else {
            return nil
        }
        return FusionFM(issue: issue, gains: gains, pertes: pertes, poidsPerdu: poidsPerdu)
    }
}
