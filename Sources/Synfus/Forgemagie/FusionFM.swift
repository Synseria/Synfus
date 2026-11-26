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
    /// les lignes vues dans les deux, plus une ligne apparue quand aucune n'a
    /// disparu (une exo). Le reliquat qui baisse sans ligne perdue : le puits
    /// a payé, c'est un succès neutre — ou un échec, si rien ne monte. `nil` :
    /// rien n'a changé.
    static func constater(avant: [Int: Int], apres: [Int: Int], catalogue: CatalogueFM,
                          reliquatAvant: Double? = nil, reliquatApres: Double? = nil) -> FusionFM? {
        var gains: [Int: Int] = [:]
        var pertes: [Int: Int] = [:]
        for effet in Set(avant.keys).intersection(apres.keys) {
            let ecart = (apres[effet] ?? 0) - (avant[effet] ?? 0)
            if ecart > 0 { gains[effet] = ecart }
            if ecart < 0 { pertes[effet] = -ecart }
        }
        if Set(avant.keys).isSubset(of: apres.keys) {
            for effet in Set(apres.keys).subtracting(avant.keys) where (apres[effet] ?? 0) > 0 {
                gains[effet] = apres[effet]
            }
        }
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
