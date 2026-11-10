/// Les actions d'une fiche dépliée sous une ligne de la palette, en cartes
/// que le clavier atteint : ↓ entre dans la rangée, ←/→ passe d'une carte à
/// l'autre, ↵ la fait. Pur.
enum ActionFiche: Hashable, Sendable {
    /// Copie le trajet jusqu'à l'entrée du donjon.
    case entree(Lieu)
    /// Ouvre la page du donjon sur Dofus pour les noobs, par son nom français.
    case guide(String)
    /// Déplie où trouver la clef.
    case clef(objet: Int)
    /// Déplie les conseils tactiques de Dofus pour les noobs.
    case conseils
    case monstres
    case succes

    /// Déplie quelque chose sous la rangée plutôt que d'agir.
    var sePlie: Bool {
        switch self {
        case .entree, .guide: return false
        case .clef, .conseils, .monstres, .succes: return true
        }
    }
}

/// Une seule rangée, que la vue replie sur plusieurs lignes au besoin : ←/→
/// la parcourent d'un bout à l'autre, ↑/↓ y entrent et en sortent.
struct CartesFiche: Equatable, Sendable {
    let actions: [ActionFiche]

    static let vide = CartesFiche(actions: [])

    /// La fiche d'un donjon : y aller d'abord (entrée, guide, clefs) — l'entrée
    /// en tête, où arrive le clavier —, puis ce qui se déplie une fois là.
    static func donjon(entree: Lieu?, guide: String?, detail: DetailDonjon?, conseils: Bool) -> CartesFiche {
        var actions = [entree.map(ActionFiche.entree), guide.map(ActionFiche.guide)].compactMap(\.self)
        actions += detail?.clefs.map { .clef(objet: $0.objet) } ?? []
        if conseils { actions.append(.conseils) }
        if let detail {
            if detail.monstres.contains(where: { !$0.boss }) { actions.append(.monstres) }
            if !detail.succes.isEmpty { actions.append(.succes) }
        }
        return CartesFiche(actions: actions)
    }

    /// La première carte, où arrivent ↓ depuis la ligne, ↑ depuis la ligne
    /// d'après et le dépliage ; `nil` : aucune.
    var premiere: ActionFiche? { actions.first }

    /// ←/→, sans sortir de la rangée.
    func laterale(_ carte: ActionFiche, _ pas: Int) -> ActionFiche {
        guard let index = actions.firstIndex(of: carte) else { return carte }
        return actions[min(max(index + pas, 0), actions.count - 1)]
    }

    /// La carte si elle est encore là (la palette rouverte, le détail
    /// changé) ; `nil` : retour à la ligne. Le clavier tient une carte, pas
    /// un rang : celles qui arrivent après l'ouverture ne le déplacent pas.
    func valide(_ carte: ActionFiche?) -> ActionFiche? {
        carte.flatMap { actions.contains($0) ? $0 : nil }
    }
}
