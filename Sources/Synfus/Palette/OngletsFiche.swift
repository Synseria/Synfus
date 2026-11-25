/// La fiche d'un donjon dépliée sous sa ligne de la palette : des actions en
/// boutons sur la ligne, des onglets dessous dont un seul se montre. ←/→
/// changent d'onglet, ← sur le premier replie, ↵ fait l'action principale. Pur.
enum ActionFiche: Hashable, Sendable {
    /// Copie le trajet jusqu'à l'entrée du donjon : l'action principale.
    case entree(Lieu)
    /// Ouvre la page du donjon sur Dofus pour les noobs, par son nom français.
    case guide(String)
    /// Ouvre l'aide au combat contre ce boss du donjon.
    case aide(CibleBoss)
}

enum OngletFiche: Hashable, Sendable {
    /// La fiche de combat de chaque boss ; pendant le téléchargement du détail, son attente.
    case boss
    case conseils
    case monstres
    case succes
    /// Où trouver cette clef.
    case clef(objet: Int)
}

struct OngletsFiche: Equatable, Sendable {
    let actions: [ActionFiche]
    /// Seulement ceux qui ont un contenu, dans l'ordre du sélecteur.
    let onglets: [OngletFiche]

    enum Sortie: Equatable, Sendable {
        case onglet(OngletFiche)
        case replier
    }

    static let vide = OngletsFiche(actions: [], onglets: [])

    /// L'entrée, l'aide au combat de chaque boss, le guide ; les boss en premier onglet — le détail attendu
    /// compris —, les conseils, ce qu'on croise dedans, chaque clef pour finir.
    static func donjon(entree: Lieu?, boss: [CibleBoss], guide: String?, conseils: Bool, detail: DetailDonjon?) -> OngletsFiche {
        let actions = [entree.map(ActionFiche.entree)].compactMap(\.self) + boss.map(ActionFiche.aide)
            + [guide.map(ActionFiche.guide)].compactMap(\.self)
        var onglets: [OngletFiche] = []
        if detail?.monstres.contains(where: \.boss) ?? true { onglets.append(.boss) }
        if conseils { onglets.append(.conseils) }
        if let detail {
            if detail.monstres.contains(where: { !$0.boss }) { onglets.append(.monstres) }
            if !detail.succes.isEmpty { onglets.append(.succes) }
            onglets += detail.clefs.map { .clef(objet: $0.objet) }
        }
        return OngletsFiche(actions: actions, onglets: onglets)
    }

    /// Ce que ↵ fait sur la fiche ouverte ; `nil` : sans entrée connue, ↵ replie.
    var principale: ActionFiche? {
        actions.first { if case .entree = $0 { true } else { false } }
    }

    /// L'onglet voulu s'il est encore là, le premier sinon. Le modèle tient un onglet, pas un rang : ceux
    /// qui arrivent après l'ouverture (détail, conseils) ne le déplacent pas.
    func courant(_ voulu: OngletFiche?) -> OngletFiche? {
        voulu.flatMap { onglets.contains($0) ? $0 : nil } ?? onglets.first
    }

    /// ←/→ : l'onglet d'à côté, borné à droite ; ← sur le premier replie la fiche. `nil` : → sans onglet.
    func lateral(depuis voulu: OngletFiche?, _ pas: Int) -> Sortie? {
        guard let courant = courant(voulu), let rang = onglets.firstIndex(of: courant) else { return pas < 0 ? .replier : nil }
        if pas < 0, rang == 0 { return .replier }
        let vise = DispositionGroupe.horizontale.voisin(depuis: rang, parmi: onglets.count, pas < 0 ? .gauche : .droite) ?? rang
        return .onglet(onglets[vise])
    }
}
