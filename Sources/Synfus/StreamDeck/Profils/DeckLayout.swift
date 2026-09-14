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
    /// La même case `decalage` barres plus loin que la barre active — le
    /// sort « d'en face » (1) ou « d'après » (2), en appui long / très long.
    case sortBarreDecalee(position: Int, decalage: Int)
    case persoSuivant, persoPrecedent, persoActif
    /// La page suivante / précédente / première — barre ou fenêtre selon le mode.
    case barreSuivante, barrePrecedente, barrePremiere
    case menu, finDeTour, corpsACorps
    /// Relit la barre de sorts à l'écran et remet le profil à jour — pour les
    /// variantes changées en jeu. En appui long sur « Menu » par défaut.
    case reconnaitre
    /// Une commande du jeu, par son `GameCommand.id`.
    case commande(String)
    case vide

    var label: String {
        switch self {
        case .sort(let barre, let position): return "Barre \(barre + 1), case \(position + 1)"
        case .sortActif(let position): return "Case \(position + 1) de la barre active"
        case .sortBarreDecalee(let position, let decalage): return "Case \(position + 1), \(decalage) barre\(decalage > 1 ? "s" : "") plus loin"
        case .persoSuivant: return "Perso suivant"
        case .persoPrecedent: return "Perso précédent"
        case .persoActif: return "Perso actif"
        case .barreSuivante: return "Barre suivante"
        case .barrePrecedente: return "Barre précédente"
        case .barrePremiere: return "Première barre"
        case .menu: return "Menu"
        case .finDeTour: return "Fin de tour"
        case .corpsACorps: return "Corps à corps"
        case .reconnaitre: return "Relire les sorts à l'écran"
        case .commande(let id): return "Commande « \(id) »"
        case .vide: return "Vide"
        }
    }

    /// Le rôle de la touche, pour les actions « classiques » du plugin qui
    /// se placent par rôle et non par position : les n-ièmes « sort », le
    /// « perso suivant », etc. `nil` pour une case vide.
    var role: String? {
        switch self {
        case .sort, .sortActif, .sortBarreDecalee: return "sort"
        case .persoSuivant: return "persoSuivant"
        case .persoPrecedent: return "persoPrecedent"
        case .persoActif: return "persoActif"
        case .barreSuivante: return "barreSuivante"
        case .barrePrecedente: return "barrePrecedente"
        case .barrePremiere: return "barrePremiere"
        case .menu: return "menu"
        case .finDeTour: return "finDeTour"
        case .corpsACorps: return "corpsACorps"
        case .reconnaitre: return "reconnaitre"
        case .commande(let id): return "commande:" + id
        case .vide: return nil
        }
    }

    /// Les sources qui affichent un sort — celles que le menu recouvre.
    var estUnSort: Bool {
        switch self {
        case .sort, .sortActif, .sortBarreDecalee: return true
        default: return false
        }
    }
}

/// Une touche : ce qu'un appui court fait, ce qu'un appui long fait, ce
/// qu'un appui très long fait — rien, par défaut.
struct DeckTile: Codable, Equatable, Hashable, Sendable {
    var court: DeckSource
    var long: DeckSource?
    var tresLong: DeckSource?

    init(_ court: DeckSource, long: DeckSource? = nil, tresLong: DeckSource? = nil) {
        self.court = court
        self.long = long
        self.tresLong = tresLong
    }

    var sources: [DeckSource] { [court, long, tresLong].compactMap { $0 } }

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
    /// barre ▶ (long : première) │ perso ▶ (long : ◀) │ menu (long : relire
    /// les sorts) │ suivi │ fin de tour — **sans** action longue : une fin de tour ne doit partir que
    /// d'un geste voulu. Tronquée ou complétée à la largeur.
    static func navigationRow(colonnes: Int) -> [DeckTile] {
        let row: [DeckTile] = [
            DeckTile(.barreSuivante, long: .barrePremiere),
            DeckTile(.persoSuivant, long: .persoPrecedent),
            DeckTile(.menu, long: .reconnaitre),
            DeckTile(.commande(GameCommands.suiviID)),
            DeckTile(.finDeTour),
        ]
        return Array(row.prefix(colonnes)) + Array(repeating: .vide, count: max(0, colonnes - row.count))
    }

    /// **Barre par barre** : la navigation en haut, puis les cases de la barre
    /// active dans l'ordre. Sur une grille d'une seule ligne, pas de navigation.
    /// Selon `sortLong`, l'appui long d'une case joue la même case de la barre
    /// suivante, et l'appui très long celle de la barre d'après — les trois
    /// barres sous dix touches, sans page.
    static func parBarre(colonnes: Int, lignes: Int, sortLong: SortLong = .deuxNiveaux) -> DeckLayout {
        let sortRows = lignes > 1 ? lignes - 1 : lignes
        var tiles: [DeckTile] = lignes > 1 ? navigationRow(colonnes: colonnes) : []
        for i in 0..<(sortRows * colonnes) {
            guard i < SpellProfile.slotsPerBar else { tiles.append(.vide); continue }
            tiles.append(DeckTile(.sortActif(position: i),
                                  long: sortLong.niveaux >= 1 ? .sortBarreDecalee(position: i, decalage: 1) : nil,
                                  tresLong: sortLong.niveaux >= 2 ? .sortBarreDecalee(position: i, decalage: 2) : nil))
        }
        return DeckLayout(colonnes: colonnes, lignes: lignes, touches: tiles)
    }

    /// **Une barre par rangée** : la navigation en haut, puis chaque rangée
    /// montre une barre, par fenêtres de `colonnes` cases — 1-5 puis 6-10 puis
    /// 11-12 sur cinq colonnes. Deux rangées montrent les barres 1 et 2 ; la
    /// page suivante, une fois les fenêtres épuisées, passe aux barres suivantes.
    /// Selon `sortLong`, l'appui long d'une case joue la case de la **fenêtre
    /// suivante** de la même barre (1 → 6 sur cinq colonnes), le très long
    /// celle d'après (1 → 11).
    static func parRangee(colonnes: Int, lignes: Int, page: Int, sortLong: SortLong = .deuxNiveaux) -> DeckLayout {
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
                guard barre < SpellProfile.barCount, position < SpellProfile.slotsPerBar else { tiles.append(.vide); continue }
                func decalee(_ n: Int) -> DeckSource? {
                    let next = position + n * colonnes
                    return sortLong.niveaux >= n && next < SpellProfile.slotsPerBar ? .sort(barre: barre, position: next) : nil
                }
                tiles.append(DeckTile(.sort(barre: barre, position: position), long: decalee(1), tresLong: decalee(2)))
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

/// Ce que l'appui long — et très long — d'une case de sort joue.
enum SortLong: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Rien : la touche joue dès l'enfoncement.
    case aucun
    /// Long = le sort d'en face (barre ou fenêtre suivante).
    case unNiveau
    /// Long = d'en face, très long = celui d'après : trois barres sous dix touches.
    case deuxNiveaux

    var id: String { rawValue }
    var niveaux: Int { self == .aucun ? 0 : self == .unNiveau ? 1 : 2 }
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
    /// Les pages retenues — barres en mode par barre, fenêtres en mode par
    /// rangée —, **dans l'ordre** où « barre suivante » les parcourt ; vide =
    /// toutes, dans l'ordre naturel.
    var pages: [Int] = []
    /// Appui long / très long sur un sort : le sort d'en face, celui d'après.
    var sortLong: SortLong = .deuxNiveaux
    /// La grille du mode personnalisé.
    var custom: DeckLayout?

    init(kind: Kind = .parBarre, pages: [Int] = [], sortLong: SortLong = .deuxNiveaux, custom: DeckLayout? = nil) {
        self.kind = kind
        self.pages = pages
        self.sortLong = sortLong
        self.custom = custom
    }

    /// Une sauvegarde à laquelle il manque des clés — ou qui les porte dans
    /// une forme antérieure — se relit avec les défauts.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = (try? c.decodeIfPresent(Kind.self, forKey: .kind)) ?? nil ?? .parBarre
        pages = (try? c.decodeIfPresent([Int].self, forKey: .pages)) ?? nil ?? []
        sortLong = (try? c.decodeIfPresent(SortLong.self, forKey: .sortLong)) ?? nil ?? .deuxNiveaux
        custom = (try? c.decodeIfPresent(DeckLayout.self, forKey: .custom)) ?? nil
    }

    static let parBarre = DeckSettings()

    /// Toutes les pages que le mode connaît, dans l'ordre naturel.
    func allPages(colonnes: Int, lignes: Int) -> [Int] {
        switch kind {
        case .parBarre, .personnalisee: return Array(0..<SpellProfile.barCount)
        case .parRangee: return Array(0..<DeckLayout.pageCountParRangee(colonnes: colonnes, lignes: lignes))
        }
    }

    /// Les pages effectivement parcourues, dans l'ordre.
    func pageOrder(colonnes: Int, lignes: Int) -> [Int] {
        let all = allPages(colonnes: colonnes, lignes: lignes)
        let kept = pages.filter { all.contains($0) }
        return kept.isEmpty ? all : kept
    }

    /// Ce qu'une page montre, en clair.
    func pageLabel(_ page: Int, colonnes: Int, lignes: Int) -> String {
        switch kind {
        case .parBarre, .personnalisee: return "Barre \(page + 1)"
        case .parRangee: return DeckLayout.pageLabelParRangee(page, colonnes: colonnes, lignes: lignes)
        }
    }

    /// La grille à composer pour cet état de session — `page` est le rang
    /// dans l'ordre des pages ; une disposition personnalisée est reprise
    /// telle quelle, ses `sortActif` suivant la barre active.
    func layout(colonnes: Int, lignes: Int, page: Int) -> DeckLayout {
        switch kind {
        case .parBarre: return .parBarre(colonnes: colonnes, lignes: lignes, sortLong: sortLong)
        case .parRangee:
            let order = pageOrder(colonnes: colonnes, lignes: lignes)
            return .parRangee(colonnes: colonnes, lignes: lignes, page: order[page % order.count], sortLong: sortLong)
        case .personnalisee:
            return (custom ?? .parBarre(colonnes: colonnes, lignes: lignes, sortLong: sortLong)).fitted(colonnes: colonnes, lignes: lignes)
        }
    }

    /// Le nombre de pages que « barre suivante » parcourt.
    func pageCount(colonnes: Int, lignes: Int) -> Int {
        pageOrder(colonnes: colonnes, lignes: lignes).count
    }

    /// La barre que `sortActif` désigne pour cette page.
    func barreActive(page: Int, colonnes: Int, lignes: Int) -> Int {
        switch kind {
        case .parBarre, .personnalisee:
            let order = pageOrder(colonnes: colonnes, lignes: lignes)
            return order[page % order.count]
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
