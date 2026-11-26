import Foundation

/// L'issue d'une rune, déduite de deux lectures de la table des effets — la
/// couleur de l'historique est moins sûre — et le puits (« reliquat ») qui
/// s'en déduit. L'ordre dans lequel le jeu choisit les lignes perdues n'est
/// pas publié et les sources se contredisent : il se constate, jamais ne se
/// suppose. Pur.
struct FusionFM: Equatable, Sendable {
    enum Issue: Equatable, Sendable {
        /// La rune passe, rien n'est perdu.
        case succesCritique
        /// La rune passe, l'objet (ou le puits) perd environ son poids.
        case succesNeutre
        /// La rune ne passe pas, l'objet (ou le puits) perd environ son poids.
        case echec
    }

    let issue: Issue
    /// Les points gagnés par la ligne visée.
    let gain: Int
    /// Les points perdus par ligne, la ligne visée comprise si elle a baissé.
    let pertes: [Int: Int]
    /// Le poids des pertes sur les lignes.
    let poidsPerdu: Double

    /// Compare les valeurs par effet avant et après la rune. Le reliquat lu de
    /// part et d'autre départage un succès qui ne baisse aucune ligne : le
    /// puits a payé, c'est un succès neutre.
    static func constater(avant: [Int: Int], apres: [Int: Int], rune: CatalogueFM.Rune, catalogue: CatalogueFM,
                          reliquatAvant: Double? = nil, reliquatApres: Double? = nil) -> FusionFM {
        let gain = (apres[rune.effet] ?? 0) - (avant[rune.effet] ?? 0)
        var pertes: [Int: Int] = [:]
        for effet in Set(avant.keys).union(apres.keys) {
            let baisse = (avant[effet] ?? 0) - (apres[effet] ?? 0)
            if baisse > 0 { pertes[effet] = baisse }
        }
        let poidsPerdu = pertes.reduce(0.0) { $0 + Double($1.value) * (catalogue.effets[$1.key]?.poids ?? 0) }
        let puitsEntame = reliquatAvant.flatMap { avant in reliquatApres.map { $0 < avant } } ?? false
        let issue: Issue
        if gain <= 0 {
            issue = .echec
        } else if poidsPerdu > 0 || puitsEntame {
            issue = .succesNeutre
        } else {
            issue = .succesCritique
        }
        return FusionFM(issue: issue, gain: gain, pertes: pertes, poidsPerdu: poidsPerdu)
    }

    /// Le puits après la rune : un succès critique n'y touche pas ; sinon la
    /// perte due vaut le poids de la rune, payée d'abord par le puits, et ce
    /// que les lignes ont perdu au-delà s'y ajoute. Jamais sous zéro,
    /// décimales gardées.
    func puits(apres puits: Double, rune: CatalogueFM.Rune) -> Double {
        guard issue != .succesCritique else { return puits }
        return Swift.max(0, puits + poidsPerdu - rune.poids)
    }
}
