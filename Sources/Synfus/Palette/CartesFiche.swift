/// Les actions d'une fiche dépliée sous une ligne de la palette, en cartes
/// que le clavier atteint : ↓ entre dans les rangées, ←/→ passe d'une carte à
/// l'autre, ↵ la fait. Pur.
enum ActionFiche: Hashable, Sendable {
    /// Copie le trajet jusqu'à l'entrée du donjon.
    case entree(Lieu)
    /// Ouvre la page du donjon sur Dofus pour les noobs, par son nom français.
    case guide(String)
    /// Déplie où trouver la clef.
    case clef(objet: Int)
    case monstres
    case succes

    /// Déplie quelque chose sous sa rangée plutôt que d'agir.
    var sePlie: Bool {
        switch self {
        case .entree, .guide: return false
        case .clef, .monstres, .succes: return true
        }
    }
}

struct CartesFiche: Equatable, Sendable {
    struct Position: Hashable, Sendable {
        var rangee: Int
        var colonne: Int
    }

    /// De haut en bas ; une rangée peut être vide (détail pas encore là) :
    /// le clavier la saute, la vue garde sa place.
    let rangees: [[ActionFiche]]

    static let vide = CartesFiche(rangees: [])

    /// La fiche d'un donjon : y aller (entrée, guide, clefs), puis ce qui se
    /// déplie (les monstres hors boss, les succès) une fois le détail là.
    static func donjon(entree: Lieu?, guide: String?, detail: DetailDonjon?) -> CartesFiche {
        let aller = [entree.map(ActionFiche.entree), guide.map(ActionFiche.guide)].compactMap(\.self)
            + (detail?.clefs.map { ActionFiche.clef(objet: $0.objet) } ?? [])
        var deplier: [ActionFiche] = []
        if let detail {
            if detail.monstres.contains(where: { !$0.boss }) { deplier.append(.monstres) }
            if !detail.succes.isEmpty { deplier.append(.succes) }
        }
        return CartesFiche(rangees: [aller, deplier])
    }

    func action(_ position: Position?) -> ActionFiche? {
        guard let position, rangees.indices.contains(position.rangee),
              rangees[position.rangee].indices.contains(position.colonne) else { return nil }
        return rangees[position.rangee][position.colonne]
    }

    /// Ce qu'un second ↵ sur la ligne dépliée fait : aller à l'entrée.
    var parDefaut: ActionFiche? {
        rangees.joined().first { if case .entree = $0 { return true } else { return false } }
    }

    /// ↓ depuis la ligne (`nil`) ou une carte : la rangée pleine suivante, à
    /// la colonne la plus proche ; `nil`, on sort de la fiche par le bas.
    func dessous(_ position: Position?) -> Position? {
        let depart = position.map { $0.rangee + 1 } ?? 0
        guard let rangee = rangees.indices.dropFirst(depart).first(where: { !rangees[$0].isEmpty }) else { return nil }
        return Position(rangee: rangee, colonne: min(position?.colonne ?? 0, rangees[rangee].count - 1))
    }

    /// ↑ : la rangée pleine précédente ; `nil`, retour à la ligne.
    func dessus(_ position: Position) -> Position? {
        guard let rangee = rangees.indices.prefix(position.rangee).last(where: { !rangees[$0].isEmpty }) else { return nil }
        return Position(rangee: rangee, colonne: min(position.colonne, rangees[rangee].count - 1))
    }

    /// ↑ depuis la ligne d'après : la dernière rangée pleine.
    var derniere: Position? {
        rangees.indices.last { !rangees[$0].isEmpty }.map { Position(rangee: $0, colonne: 0) }
    }

    /// ←/→ dans la rangée, sans en sortir.
    func laterale(_ position: Position, _ pas: Int) -> Position {
        guard rangees.indices.contains(position.rangee), !rangees[position.rangee].isEmpty else { return position }
        let colonne = min(max(position.colonne + pas, 0), rangees[position.rangee].count - 1)
        return Position(rangee: position.rangee, colonne: colonne)
    }

    /// La position encore atteignable une fois les rangées changées (le
    /// détail arrive, la palette se rouvre) ; `nil` : la ligne.
    func valide(_ position: Position?) -> Position? {
        guard let position, rangees.indices.contains(position.rangee), !rangees[position.rangee].isEmpty else { return nil }
        return Position(rangee: position.rangee, colonne: min(position.colonne, rangees[position.rangee].count - 1))
    }
}
