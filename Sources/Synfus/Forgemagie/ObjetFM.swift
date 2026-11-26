import Foundation

/// Un objet sur l'établi de forgemagie : ses lignes, leur jet naturel, et ce
/// que pèsent leurs dépassements. Une ligne en malus garde l'effet positif,
/// à valeur négative (« -10 Chance » : Chance à −10). Pur.
struct ObjetFM: Equatable, Sendable {
    struct Ligne: Equatable, Sendable {
        let effet: Int
        var valeur: Int
        /// Le jet max naturel ; `nil` pour une exo, ou une case mal lue.
        let max: Int?
        /// Une ligne que l'objet n'a pas de base : ni min ni max (« - »).
        var exo = false
    }

    var lignes: [Ligne]

    /// La somme over + exo d'une ligne ne dépasse pas ce poids (101 Force,
    /// 505 Vitalité, 1 PA), sauf jet naturel déjà au-dessus.
    static let plafondOverExo = 101.0

    func ligne(_ effet: Int) -> Ligne? { lignes.first { $0.effet == effet } }

    /// Les valeurs par effet : ce que deux lectures de la table comparent.
    var valeurs: [Int: Int] { Dictionary(lignes.map { ($0.effet, $0.valeur) }, uniquingKeysWith: { premiere, _ in premiere }) }

    /// Le poids de l'objet : chaque point pèse le poids de sa caractéristique.
    func poids(_ catalogue: CatalogueFM) -> Double {
        lignes.reduce(0) { $0 + Double($1.valeur) * (catalogue.effets[$1.effet]?.poids ?? 0) }
    }

    /// Le poids des jets max naturels : au-delà, chaque rune est plus risquée.
    func poidsMax(_ catalogue: CatalogueFM) -> Double {
        lignes.reduce(0) { $0 + Double($1.max ?? 0) * (catalogue.effets[$1.effet]?.poids ?? 0) }
    }

    /// Ce qu'une ligne pèse au-dessus de son jet max naturel, entière pour une
    /// exo ; `nil` quand son max n'a pas été lu.
    static func poidsOverExo(valeur: Int, max: Int?, exo: Bool, poids: Double) -> Double? {
        guard exo || max != nil else { return nil }
        return Double(Swift.max(0, valeur - (exo ? 0 : max ?? 0))) * poids
    }

    /// Ce que pèse le dépassement de la ligne ; `nil` sans max lu.
    func poidsOverExo(_ ligne: Ligne, _ catalogue: CatalogueFM) -> Double? {
        catalogue.effets[ligne.effet].flatMap { Self.poidsOverExo(valeur: ligne.valeur, max: ligne.max, exo: ligne.exo, poids: $0.poids) }
    }

    /// La rune ferait-elle passer la ligne au-delà du plafond over + exo ?
    func depasseraitPlafond(_ rune: CatalogueFM.Rune, _ catalogue: CatalogueFM) -> Bool {
        guard let poids = catalogue.effets[rune.effet]?.poids else { return false }
        let ligne = ligne(rune.effet)
        // Une rune sur une ligne absente l'ajoute : une exo.
        let exo = ligne?.exo ?? true
        guard let avant = Self.poidsOverExo(valeur: ligne?.valeur ?? 0, max: ligne?.max, exo: exo, poids: poids),
              let apres = Self.poidsOverExo(valeur: (ligne?.valeur ?? 0) + rune.puissance, max: ligne?.max, exo: exo, poids: poids)
        else { return false }
        return apres > Self.plafondOverExo && apres > avant
    }
}
