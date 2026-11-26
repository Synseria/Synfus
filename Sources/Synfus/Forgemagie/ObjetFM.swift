import Foundation

/// Un objet sur l'établi de forgemagie : ses lignes, leur jet naturel, et ce
/// que pèsent leurs dépassements. Une ligne en malus garde l'effet positif,
/// à valeur négative (« -10 Chance » : Chance à −10). Pur.
struct ObjetFM: Equatable, Sendable {
    struct Ligne: Equatable, Sendable {
        let effet: Int
        var valeur: Int
        /// Le jet max naturel ; `nil` pour une exo, ligne que l'objet n'a pas de base.
        let max: Int?
    }

    var lignes: [Ligne]

    /// La somme over + exo d'une ligne ne dépasse pas ce poids (101 Force,
    /// 505 Vitalité, 1 PA), sauf jet naturel déjà au-dessus.
    static let plafondOverExo = 101.0

    func ligne(_ effet: Int) -> Ligne? { lignes.first { $0.effet == effet } }

    /// Le poids de l'objet : chaque point pèse le poids de sa caractéristique.
    func poids(_ catalogue: CatalogueFM) -> Double {
        lignes.reduce(0) { $0 + Double($1.valeur) * (catalogue.effets[$1.effet]?.poids ?? 0) }
    }

    /// Le poids des jets max naturels : au-delà, chaque rune est plus risquée.
    func poidsMax(_ catalogue: CatalogueFM) -> Double {
        lignes.reduce(0) { $0 + Double($1.max ?? 0) * (catalogue.effets[$1.effet]?.poids ?? 0) }
    }

    /// Ce qu'une ligne pèse au-dessus de son jet max naturel, ou entière pour une exo.
    static func poidsOverExo(valeur: Int, max: Int?, poids: Double) -> Double {
        Double(Swift.max(0, valeur - (max ?? 0))) * poids
    }

    /// La rune ferait-elle passer la ligne au-delà du plafond over + exo ?
    func depasseraitPlafond(_ rune: CatalogueFM.Rune, _ catalogue: CatalogueFM) -> Bool {
        guard let poids = catalogue.effets[rune.effet]?.poids else { return false }
        let ligne = ligne(rune.effet)
        let max = ligne?.max
        let avant = Self.poidsOverExo(valeur: ligne?.valeur ?? 0, max: max, poids: poids)
        let apres = Self.poidsOverExo(valeur: (ligne?.valeur ?? 0) + rune.puissance, max: max, poids: poids)
        return apres > Self.plafondOverExo && apres > avant
    }
}
