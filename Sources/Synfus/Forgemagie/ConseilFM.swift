import Foundation

/// Les runes à poser pour approcher la cible de jet — le jet parfait (chaque
/// ligne à son max) ou le jet voulu —, chacune avec un score de 0 à 100 et
/// ses raisons. Aucune formule de probabilité n'est publique : le score
/// assemble les règles connues (recherche, `docs/plans/forgemagie-recherche.md`)
/// et les seuls chiffres sourcés, ceux de la 1.27. Pur.
enum ConseilFM {
    struct Proposition: Equatable, Sendable {
        let rune: CatalogueFM.Rune
        /// De 0 à 100 : plus haut, plus conseillée.
        let score: Int
        /// La valeur de la ligne après un succès.
        let apres: Int
        let raisons: [Raison]
    }

    enum Raison: Equatable, Sendable {
        /// Comble `points` des `manque` points qui séparent la ligne de sa cible.
        case comble(points: Int, manque: Int)
        /// Dépasse la cible d'autant de points.
        case depasse(Int)
        /// Le rang de la rune convient à la valeur de la ligne ; sinon trop lourde, ou trop légère.
        case palier(PalierRune)
        /// La ligne est à 80 % de son jet max ou plus : chaque rune y passe moins bien.
        case procheDuMax
        /// La perte probable d'un échec est couverte par le reliquat.
        case reliquatCouvre
        /// Passe le jet max : un over, qui passe mal et puise dans le reliquat.
        case over
    }

    /// Un over coûte : la rune passe rarement en critique au-delà du max, et le
    /// dépassement puise dans le reliquat ou les autres lignes.
    static let facteurOver = 0.6

    enum PalierRune: Equatable, Sendable { case adapte, tropLourde, tropLegere }

    /// Les pondérations du score : avancer vers la cible d'abord, sans la
    /// dépasser, au bon palier, en risquant peu ; à mérite égal, les lignes
    /// lourdes d'abord (les guides : on les finit avant que des pertes ne les
    /// entament, les légères servent ensuite de tampon).
    static let poidsProgres = 0.35
    static let poidsJustesse = 0.25
    static let poidsPalier = 0.15
    static let poidsRisque = 0.10
    static let poidsPrecieux = 0.15

    /// Une rune passe bien tant que la ligne reste sous environ 20 fois son
    /// poids : rune simple jusqu'à 20, Pa jusqu'à 60, Ra au-delà (Force).
    static let facteurPalier = 20.0

    /// Le succès critique, d'après les relevés de la 1.27 : 66 % loin du max,
    /// jusqu'à 34 % au max, 15 % au-delà (over).
    static func probabiliteCritique(ratio: Double) -> Double {
        if ratio < 0.8 { return 0.66 }
        if ratio <= 1 { return 0.66 - (ratio - 0.8) / 0.2 * 0.32 }
        return 0.15
    }

    /// Les propositions, la meilleure d'abord, `nombre` au plus, une par ligne
    /// (sa meilleure rune). Une ligne à sa cible ou au-delà n'en a pas ; une
    /// rune qui passerait le plafond over + exo non plus.
    static func propositions(objet: ObjetFM, cible: (ObjetFM.Ligne) -> Int, reliquat: Double?,
                             catalogue: CatalogueFM, nombre: Int = 5) -> [Proposition] {
        var resultat: [Proposition] = []
        for ligne in objet.lignes {
            let manque = cible(ligne) - ligne.valeur
            guard manque > 0, let effet = catalogue.effets[ligne.effet], let runes = catalogue.runes[ligne.effet], !runes.isEmpty
            else { continue }
            let attendu = palierAttendu(valeur: ligne.valeur, poidsParPoint: effet.poids, runes: runes)
            let ratio = Double(ligne.valeur) / Double(max(ligne.max ?? ligne.valeur, 1))
            let pCritique = probabiliteCritique(ratio: ratio)
            for (rang, rune) in runes.enumerated() {
                let apres = ligne.valeur + rune.puissance
                if let max = ligne.max, apres > max, objet.depasseraitPlafond(rune, catalogue) { continue }
                let utile = min(rune.puissance, manque)
                let depasse = max(0, rune.puissance - manque)
                let progres = Double(utile) / Double(manque)
                let justesse = 1 - Double(depasse) / Double(rune.puissance)
                let ecartPalier = abs(rang - attendu)
                let adequation = max(0.3, 1 - 0.35 * Double(ecartPalier))
                // La perte probable d'une rune qui ne passe pas en critique, moins ce que le reliquat absorbe.
                let perte = rune.poids * (1 - (ligne.max.map { apres > $0 } == true ? probabiliteCritique(ratio: 1.01) : pCritique))
                let perteNette = max(0, perte - (reliquat ?? 0))
                let risque = perteNette / (perteNette + 5)
                let precieux = min(1, log10(1 + effet.poids) / 2)
                let over = ligne.max.map { apres > $0 } ?? false
                let valeur = (poidsProgres * progres + poidsJustesse * justesse + poidsPalier * adequation
                    + poidsRisque * (1 - risque) + poidsPrecieux * precieux) * (over ? facteurOver : 1)
                var raisons: [Raison] = [.comble(points: utile, manque: manque)]
                if depasse > 0 { raisons.append(.depasse(depasse)) }
                raisons.append(.palier(ecartPalier == 0 ? .adapte : rang > attendu ? .tropLourde : .tropLegere))
                if ratio >= 0.8 { raisons.append(.procheDuMax) }
                if perte > 0, perteNette == 0 { raisons.append(.reliquatCouvre) }
                if over { raisons.append(.over) }
                resultat.append(Proposition(rune: rune, score: Int((valeur * 100).rounded()), apres: apres, raisons: raisons))
            }
        }
        let parLigne = Dictionary(grouping: resultat, by: \.rune.effet).values.compactMap { propositions in
            propositions.max { ($0.score, $0.rune.poids) < ($1.score, $1.rune.poids) }
        }
        return Array(parLigne.sorted { ($0.score, $0.rune.poids) > ($1.score, $1.rune.poids) }.prefix(nombre))
    }

    /// Le rang de rune que la valeur de la ligne appelle : le plus lourd dont
    /// le rang précédent est déjà dépassé (la ligne pèse plus de 20 fois son poids).
    static func palierAttendu(valeur: Int, poidsParPoint: Double, runes: [CatalogueFM.Rune]) -> Int {
        let poidsLigne = Double(valeur) * poidsParPoint
        var rang = 0
        while rang + 1 < runes.count, poidsLigne >= facteurPalier * runes[rang].poids { rang += 1 }
        return rang
    }
}
