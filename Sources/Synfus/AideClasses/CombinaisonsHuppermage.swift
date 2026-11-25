// Les combinaisons élémentaires de l'Huppermage (Dofus 3, données du client par DofusDB : sorts
// 13702 à 13707, table 13671) et la règle qui montre leur aide.

/// Une cible qui porte deux états élémentaires différents déclenche leur combinaison, qui les
/// consomme ; l'ordre ne compte pas, un même élément deux fois ne fait rien.
enum CombinaisonsHuppermage {
    typealias Element = FicheCombat.Element

    /// Les quatre éléments qui portent un état, dans l'ordre du tableau.
    static let elements: [Element] = [.feu, .eau, .terre, .air]

    enum Combinaison: CaseIterable, Sendable {
        case eruption, enlisement, carbonisation, ebullition, cristallisation, assechement

        /// Les deux états qui la déclenchent.
        var paire: Set<Element> {
            switch self {
            case .eruption: [.terre, .feu]
            case .enlisement: [.terre, .eau]
            case .carbonisation: [.feu, .air]
            case .ebullition: [.eau, .feu]
            case .cristallisation: [.eau, .air]
            case .assechement: [.air, .terre]
            }
        }
    }

    /// Ce que produit `nouveau` posé sur une cible qui porte `porte` ; `nil` pour le même élément
    /// (ou le neutre, qui ne porte pas d'état).
    static func combinaison(_ porte: Element, _ nouveau: Element) -> Combinaison? {
        guard porte != nouveau else { return nil }
        return Combinaison.allCases.first { $0.paire == [porte, nouveau] }
    }

    /// L'aide se montre devant un Huppermage en combat, réglage allumé, Dofus devant.
    static func montree(reglage: Bool, classe: String?, enCombat: Bool, dofusDevant: Bool) -> Bool {
        reglage && dofusDevant && enCombat && classe == cleClasse
    }

    /// La clé de la classe (`DofusClass.cle`), quelle que soit la langue du titre.
    static let cleClasse = "huppermage"
}
