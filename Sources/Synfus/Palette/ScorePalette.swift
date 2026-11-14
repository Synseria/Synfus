/// La pertinence d'un résultat de la palette, le tri « Auto ». Pur. Avec une requête, la
/// correspondance d'abord, puis le genre (zaap, boss et perso, PNJ, le reste à égalité) ; puis, avec ou
/// sans requête : favori, habitudes, proximité.
struct ScorePalette: Equatable, Sendable {
    /// Les points de `Champs.points` ; `nil` sans requête, où ni eux ni le genre ne départagent.
    let correspondance: Int?
    let genre: Int
    let favori: Bool
    /// Les choix écrasés en paliers (`palier`) : une entrée choisie cent fois ne noie pas une
    /// correspondance meilleure, et la récence départage deux habitudes du même palier.
    let habitude: Int
    let recence: Int
    /// En cartes, depuis le perso devant.
    let distance: Int?

    init(_ entree: EntreePalette, correspondance: Int?, compte: FrequentationPalette.Compte?) {
        self.correspondance = correspondance
        genre = correspondance == nil ? 0 : Self.rangDeGenre(entree)
        favori = entree.favori
        habitude = Self.palier(compte?.fois ?? 0)
        recence = compte?.dernier ?? 0
        distance = entree.distance
    }

    /// Un de plus à chaque doublement : 1 choix, 2 ou 3, 4 à 7, 8 à 15…
    static func palier(_ fois: Int) -> Int {
        fois > 0 ? Int.bitWidth - fois.leadingZeroBitCount : 0
    }

    /// Zaap, puis boss (sa fiche ou l'aide au combat) ou perso, puis PNJ ; le reste à égalité.
    static func rangDeGenre(_ entree: EntreePalette) -> Int {
        if entree.genre == .zaap { return 3 }
        if entree.estBoss || entree.genre == .perso { return 2 }
        return entree.genre == .pnj ? 1 : 0
    }

    /// `a` passe-t-il devant `b` ? `nil` à égalité : l'appelant départage par l'ordre d'arrivée,
    /// pour un ordre total et stable.
    static func avant(_ a: ScorePalette, _ b: ScorePalette) -> Bool? {
        if a.correspondance != b.correspondance { return (a.correspondance ?? .min) > (b.correspondance ?? .min) }
        if a.genre != b.genre { return a.genre > b.genre }
        if a.favori != b.favori { return a.favori }
        if a.habitude != b.habitude { return a.habitude > b.habitude }
        if a.recence != b.recence { return a.recence > b.recence }
        return plusProche(a.distance, b.distance)
    }

    /// Une distance connue passe devant une inconnue ; `nil` à égalité.
    static func plusProche(_ a: Int?, _ b: Int?) -> Bool? {
        switch (a, b) {
        case let (da?, db?) where da != db: return da < db
        case (_?, nil): return true
        case (nil, _?): return false
        default: return nil
        }
    }
}
