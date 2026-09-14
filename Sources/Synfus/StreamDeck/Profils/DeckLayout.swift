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
    /// La même case sur la barre **suivante** — le sort « d'en face », en
    /// appui long sur une case de la barre active.
    case sortBarreSuivante(position: Int)
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
        case .sortBarreSuivante(let position): return "Case \(position + 1) de la barre suivante"
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
        case .sort, .sortActif, .sortBarreSuivante: return true
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
    /// tour — **sans** action longue : une fin de tour ne doit partir que
    /// d'un geste voulu. Tronquée ou complétée à la largeur.
    static func navigationRow(colonnes: Int) -> [DeckTile] {
        let row: [DeckTile] = [
            DeckTile(.barreSuivante, long: .barrePremiere),
            DeckTile(.persoSuivant, long: .persoPrecedent),
            DeckTile(.menu),
            DeckTile(.commande(GameCommands.suiviID)),
            DeckTile(.finDeTour),
        ]
        return Array(row.prefix(colonnes)) + Array(repeating: .vide, count: max(0, colonnes - row.count))
    }

    /// **Barre par barre** : la navigation en haut, puis les cases de la barre
    /// active dans l'ordre. Sur une grille d'une seule ligne, pas de navigation.
    /// Avec `sortLong`, l'appui long d'une case joue la même case de la barre
    /// suivante — le sort « d'en face », en vignette dans le coin.
    static func parBarre(colonnes: Int, lignes: Int, sortLong: Bool = true) -> DeckLayout {
        let sortRows = lignes > 1 ? lignes - 1 : lignes
        var tiles: [DeckTile] = lignes > 1 ? navigationRow(colonnes: colonnes) : []
        for i in 0..<(sortRows * colonnes) {
            tiles.append(i < SpellProfile.slotsPerBar
                         ? DeckTile(.sortActif(position: i), long: sortLong ? .sortBarreSuivante(position: i) : nil) : .vide)
        }
        return DeckLayout(colonnes: colonnes, lignes: lignes, touches: tiles)
    }

    /// **Une barre par rangée** : la navigation en haut, puis chaque rangée
    /// montre une barre, par fenêtres de `colonnes` cases — 1-5 puis 6-10 puis
    /// 11-12 sur cinq colonnes. Deux rangées montrent les barres 1 et 2 ; la
    /// page suivante, une fois les fenêtres épuisées, passe aux barres suivantes.
    /// Avec `sortLong`, l'appui long d'une case joue la case de la **fenêtre
    /// suivante** de la même barre (1 → 6 sur cinq colonnes).
    static func parRangee(colonnes: Int, lignes: Int, page: Int, sortLong: Bool = true) -> DeckLayout {
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
                let next = position + colonnes
                guard barre < SpellProfile.barCount, position < SpellProfile.slotsPerBar else { tiles.append(.vide); continue }
                tiles.append(DeckTile(.sort(barre: barre, position: position),
                                      long: sortLong && next < SpellProfile.slotsPerBar ? .sort(barre: barre, position: next) : nil))
            }
        }
        return DeckLayout(colonnes: colonnes, lignes: lignes, touches: tiles)
    }

    /// Ce qu'une page du mode « une barre par rangée » montre, en clair :
    /// « Barres 1-2 · cases 1-5 ».
    static func pageLabelParRangee(_ page: Int, colonnes: Int, lignes: Int) -> String {
        let sortRows = lignes > 1 ? lignes - 1 : lignes
        let windows = pagesParRangee(colonnes: colonnes)
        let window = page % windows, group = page / windows
        let first = group * sortRows + 1
        let last = min(SpellProfile.barCount, first + sortRows - 1)
        let bars = first == last ? "Barre \(first)" : "Barres \(first)-\(last)"
        let from = window * colonnes + 1
        let to = min(SpellProfile.slotsPerBar, from + colonnes - 1)
        return "\(bars) · cases \(from)-\(to)"
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

/// Comment le Stream Deck montre les sorts : le mode, ses réglages, et la
/// grille posée à la main s'il y en a une. Générique dans les préférences,
/// remplaçable par perso dans son profil. Toujours `Optional` + défaut à la
/// lecture : une sauvegarde ancienne ne doit rien casser.
struct DeckSettings: Codable, Equatable, Hashable, Sendable {
    enum Kind: String, Codable, CaseIterable, Identifiable, Sendable {
        /// La barre active sur les touches, « barre suivante » passe à l'autre.
        case parBarre
        /// Une barre par rangée, « barre suivante » décale la fenêtre.
        case parRangee
        /// Une grille posée à la main.
        case personnalisee

        var id: String { rawValue }
        var label: String {
            switch self {
            case .parBarre: return "Barre par barre"
            case .parRangee: return "Une barre par rangée"
            case .personnalisee: return "Personnalisée"
            }
        }
    }

    var kind: Kind = .parBarre
    /// Mode par rangée : les pages retenues, **dans l'ordre** où « barre
    /// suivante » les parcourt ; vide = toutes, dans l'ordre naturel.
    var pages: [Int] = []
    /// Appui long sur un sort = le sort « d'en face » (barre suivante, ou
    /// fenêtre suivante), affiché en vignette dans le coin de la touche.
    var sortLong = true
    /// La grille du mode personnalisé.
    var custom: DeckLayout?

    init(kind: Kind = .parBarre, pages: [Int] = [], sortLong: Bool = true, custom: DeckLayout? = nil) {
        self.kind = kind
        self.pages = pages
        self.sortLong = sortLong
        self.custom = custom
    }

    /// Une sauvegarde à laquelle il manque des clés se relit avec les défauts.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decodeIfPresent(Kind.self, forKey: .kind) ?? .parBarre
        pages = try c.decodeIfPresent([Int].self, forKey: .pages) ?? []
        sortLong = try c.decodeIfPresent(Bool.self, forKey: .sortLong) ?? true
        custom = try c.decodeIfPresent(DeckLayout.self, forKey: .custom)
    }

    static let parBarre = DeckSettings()

    /// Les pages du mode par rangée effectivement parcourues, dans l'ordre.
    func pagesParRangee(colonnes: Int, lignes: Int) -> [Int] {
        let all = Array(0..<DeckLayout.pageCountParRangee(colonnes: colonnes, lignes: lignes))
        let kept = pages.filter { all.contains($0) }
        return kept.isEmpty ? all : kept
    }

    /// La grille à composer pour cet état de session — `page` est la barre
    /// active ou le rang de fenêtre selon le mode ; une disposition
    /// personnalisée est reprise telle quelle, ses `sortActif` suivant la
    /// barre active.
    func layout(colonnes: Int, lignes: Int, page: Int) -> DeckLayout {
        switch kind {
        case .parBarre: return .parBarre(colonnes: colonnes, lignes: lignes, sortLong: sortLong)
        case .parRangee:
            let order = pagesParRangee(colonnes: colonnes, lignes: lignes)
            return .parRangee(colonnes: colonnes, lignes: lignes, page: order[page % order.count], sortLong: sortLong)
        case .personnalisee:
            return (custom ?? .parBarre(colonnes: colonnes, lignes: lignes, sortLong: sortLong)).fitted(colonnes: colonnes, lignes: lignes)
        }
    }

    /// Le nombre de pages que « barre suivante » parcourt.
    func pageCount(colonnes: Int, lignes: Int) -> Int {
        switch kind {
        case .parBarre, .personnalisee: return SpellProfile.barCount
        case .parRangee: return pagesParRangee(colonnes: colonnes, lignes: lignes).count
        }
    }

    /// La barre que `sortActif` désigne pour cette page.
    func barreActive(page: Int) -> Int {
        switch kind {
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
