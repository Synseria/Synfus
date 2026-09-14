import Foundation

/// Ce qu'une touche du Stream Deck peut porter. **Synfus compose, le plugin
/// rend** : la disposition est décrite ici, en valeurs pures, et le plugin ne
/// connaît que des index de touches.
enum DeckSource: Codable, Equatable, Hashable, Sendable {
    /// Une case précise du profil du perso — n'importe quelle barre.
    case sort(barre: Int, position: Int)
    /// La case `position` de la barre **active** : ce que « barre suivante »
    /// fait tourner.
    case sortActif(position: Int)
    case persoSuivant, persoPrecedent, persoActif
    /// La page suivante / précédente / première — barre ou fenêtre selon le mode.
    case barreSuivante, barrePrecedente, barrePremiere
    case menu, finDeTour, corpsACorps
    /// Une commande du jeu, par son `GameCommand.id`.
    case commande(String)
    case vide

    var label: String {
        switch self {
        case .sort(let barre, let position): return "Barre \(barre + 1), case \(position + 1)"
        case .sortActif(let position): return "Case \(position + 1) de la barre active"
        case .persoSuivant: return "Perso suivant"
        case .persoPrecedent: return "Perso précédent"
        case .persoActif: return "Perso actif"
        case .barreSuivante: return "Barre suivante"
        case .barrePrecedente: return "Barre précédente"
        case .barrePremiere: return "Première barre"
        case .menu: return "Menu"
        case .finDeTour: return "Fin de tour"
        case .corpsACorps: return "Corps à corps"
        case .commande(let id): return "Commande « \(id) »"
        case .vide: return "Vide"
        }
    }

    /// Les sources qui affichent un sort — celles que le menu recouvre.
    var estUnSort: Bool {
        switch self {
        case .sort, .sortActif: return true
        default: return false
        }
    }
}

/// Une touche : ce qu'un appui court fait, et ce qu'un appui long fait —
/// rien, par défaut.
struct DeckTile: Codable, Equatable, Hashable, Sendable {
    var court: DeckSource
    var long: DeckSource?

    init(_ court: DeckSource, long: DeckSource? = nil) {
        self.court = court
        self.long = long
    }

    static let vide = DeckTile(.vide)
}

/// Une grille de touches, dans l'ordre de lecture (ligne puis colonne).
struct DeckLayout: Codable, Equatable, Hashable, Sendable {
    var colonnes: Int
    var lignes: Int
    var touches: [DeckTile]

    init(colonnes: Int, lignes: Int, touches: [DeckTile]) {
        self.colonnes = colonnes
        self.lignes = lignes
        self.touches = touches
        normalize()
    }

    /// La grille par défaut : celle de l'appareil de l'utilisateur.
    static let defaultColumns = 5
    static let defaultRows = 3

    subscript(row: Int, column: Int) -> DeckTile {
        get {
            guard (0..<lignes).contains(row), (0..<colonnes).contains(column) else { return .vide }
            return touches[row * colonnes + column]
        }
        set {
            guard (0..<lignes).contains(row), (0..<colonnes).contains(column) else { return }
            touches[row * colonnes + column] = newValue
        }
    }

    /// Autant de touches que de cases, jamais moins ni plus.
    mutating func normalize() {
        let count = max(0, colonnes * lignes)
        if touches.count < count { touches += Array(repeating: .vide, count: count - touches.count) }
        if touches.count > count { touches.removeLast(touches.count - count) }
    }

    /// La rangée de navigation, la même dans toutes les dispositions générées :
    /// barre ▶ (long : première) │ perso ▶ (long : ◀) │ menu │ suivi │ fin de
    /// tour (long : corps à corps). Tronquée ou complétée à la largeur.
    static func navigationRow(colonnes: Int) -> [DeckTile] {
        let row: [DeckTile] = [
            DeckTile(.barreSuivante, long: .barrePremiere),
            DeckTile(.persoSuivant, long: .persoPrecedent),
            DeckTile(.menu),
            DeckTile(.commande(GameCommands.suiviID)),
            DeckTile(.finDeTour, long: .corpsACorps),
        ]
        return Array(row.prefix(colonnes)) + Array(repeating: .vide, count: max(0, colonnes - row.count))
    }

    /// **Barre par barre** : la navigation en haut, puis les cases de la barre
    /// active dans l'ordre. Sur une grille d'une seule ligne, pas de navigation.
    static func parBarre(colonnes: Int, lignes: Int) -> DeckLayout {
        let sortRows = lignes > 1 ? lignes - 1 : lignes
        var tiles: [DeckTile] = lignes > 1 ? navigationRow(colonnes: colonnes) : []
        for i in 0..<(sortRows * colonnes) {
            tiles.append(i < SpellProfile.slotsPerBar ? DeckTile(.sortActif(position: i)) : .vide)
        }
        return DeckLayout(colonnes: colonnes, lignes: lignes, touches: tiles)
    }

    /// **Une barre par rangée** : la navigation en haut, puis chaque rangée
    /// montre une barre, par fenêtres de `colonnes` cases — 1-5 puis 6-10 puis
    /// 11-12 sur cinq colonnes. Deux rangées montrent les barres 1 et 2 ; la
    /// page suivante, une fois les fenêtres épuisées, passe aux barres suivantes.
    static func parRangee(colonnes: Int, lignes: Int, page: Int) -> DeckLayout {
        let sortRows = lignes > 1 ? lignes - 1 : lignes
        let windows = pagesParRangee(colonnes: colonnes)
        let groups = max(1, (SpellProfile.barCount + sortRows - 1) / sortRows)
        let page = page % max(1, windows * groups)
        let window = page % windows, group = page / windows
        var tiles: [DeckTile] = lignes > 1 ? navigationRow(colonnes: colonnes) : []
        for row in 0..<sortRows {
            let barre = group * sortRows + row
            for column in 0..<colonnes {
                let position = window * colonnes + column
                tiles.append(barre < SpellProfile.barCount && position < SpellProfile.slotsPerBar
                             ? DeckTile(.sort(barre: barre, position: position)) : .vide)
            }
        }
        return DeckLayout(colonnes: colonnes, lignes: lignes, touches: tiles)
    }

    /// Le nombre de fenêtres qu'il faut pour parcourir une barre entière.
    static func pagesParRangee(colonnes: Int) -> Int {
        max(1, (SpellProfile.slotsPerBar + colonnes - 1) / colonnes)
    }

    /// Le nombre total de pages du mode « une barre par rangée ».
    static func pageCountParRangee(colonnes: Int, lignes: Int) -> Int {
        let sortRows = lignes > 1 ? lignes - 1 : lignes
        return pagesParRangee(colonnes: colonnes) * max(1, (SpellProfile.barCount + sortRows - 1) / sortRows)
    }
}

/// Comment le Stream Deck montre les sorts. Générique dans les préférences,
/// remplaçable par perso dans son profil.
enum DeckMode: Codable, Equatable, Hashable, Sendable {
    /// La barre active sur les touches, « barre suivante » passe à l'autre.
    case parBarre
    /// Une barre par rangée, « barre suivante » décale la fenêtre.
    case parRangee
    /// Une grille posée à la main.
    case personnalisee(DeckLayout)

    /// La grille à composer pour cet état de session — `page` est la barre
    /// active ou la fenêtre selon le mode ; une disposition personnalisée
    /// est reprise telle quelle, ses `sortActif` suivant la barre active.
    func layout(colonnes: Int, lignes: Int, page: Int) -> DeckLayout {
        switch self {
        case .parBarre: return .parBarre(colonnes: colonnes, lignes: lignes)
        case .parRangee: return .parRangee(colonnes: colonnes, lignes: lignes, page: page)
        case .personnalisee(let custom): return custom.fitted(colonnes: colonnes, lignes: lignes)
        }
    }

    /// Le nombre de pages que « barre suivante » parcourt.
    func pageCount(colonnes: Int, lignes: Int) -> Int {
        switch self {
        case .parBarre, .personnalisee: return SpellProfile.barCount
        case .parRangee: return DeckLayout.pageCountParRangee(colonnes: colonnes, lignes: lignes)
        }
    }

    /// La barre que `sortActif` désigne pour cette page.
    func barreActive(page: Int) -> Int {
        switch self {
        case .parBarre, .personnalisee: return page % SpellProfile.barCount
        case .parRangee: return 0
        }
    }
}

extension DeckLayout {
    /// La même disposition ramenée à une autre grille : chaque touche garde sa
    /// ligne et sa colonne, ce qui déborde disparaît, ce qui manque est vide.
    func fitted(colonnes: Int, lignes: Int) -> DeckLayout {
        guard colonnes != self.colonnes || lignes != self.lignes else { return self }
        var out = DeckLayout(colonnes: colonnes, lignes: lignes, touches: [])
        for row in 0..<lignes { for column in 0..<colonnes { out[row, column] = self[row, column] } }
        return out
    }
}
