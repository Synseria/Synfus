import CoreGraphics

/// La portée du sort préparé, lue sur le plateau : le jeu teinte de bleu les
/// cases à portée, foncé avec ligne de vue, clair sans. Le sol change d'une
/// carte à l'autre (sable, neige, pierre bleue) : une case n'est jugée bleuie
/// que comparée à elle-même sans sort, la référence, reprise à chaque lecture
/// où aucun sort n'est préparé. Pur.
struct PorteeSort: Equatable, Sendable {
    enum Teinte: Equatable, Sendable {
        /// Bleu foncé : à portée, ligne de vue dégagée.
        case portee
        /// Bleu clair : à portée, sans ligne de vue.
        case horsVue
        /// Pas teintée : hors de la zone du sort (décor, obstacle, sol hors de portée).
        case libre
        /// Couverte (un personnage, la marque de visée du jeu) et jamais vue autrement.
        case inconnue
    }

    struct Couleur: Equatable, Sendable {
        var r: Double, v: Double, b: Double

        var luma: Double { 0.299 * r + 0.587 * v + 0.114 * b }

        func ecart(_ autre: Couleur) -> Double { max(abs(r - autre.r), abs(v - autre.v), abs(b - autre.b)) }
    }

    /// Les couleurs d'une case : son centre, puis près de ses quatre sommets
    /// (un personnage couvre le centre et le haut, rarement les côtés).
    struct Signature: Equatable, Sendable {
        let taches: [Couleur]
    }

    private var reference: [GrilleIso.Case: Signature] = [:]
    /// Les cases lues pendant que le sort est préparé ; vide sans sort.
    private(set) var teintes: [GrilleIso.Case: Teinte] = [:]

    /// Un sort est préparé : des cases sont bleuies.
    var sortPrepare: Bool { !teintes.isEmpty }

    /// Hors des cases lues (bord de la fenêtre, hors de l'image) : libre.
    func teinte(_ position: GrilleIso.Case) -> Teinte { teintes[position] ?? .libre }

    /// Une tache est bleuie quand le bleu y monte d'au moins autant devant le
    /// rouge et devant le vert : le vert d'un déplacement monte aussi devant le rouge.
    static let seuilBleu = 25.0
    static let seuilBleuSurVert = 15.0
    /// Au-delà, une tache non bleuie a changé : quelque chose la couvre.
    static let seuilCouverte = 45.0
    /// Moins de cases bleuies : pas de sort, un reflet ou un perso en bleu (un sort au contact en bleuit quatre).
    static let casesMin = 3
    /// Les deux bleus se séparent par la luminance ; plus proches, une seule teinte.
    static let ecartClairSombre = 15.0

    /// Une lecture du plateau. Sans sort, elle devient la référence ; avec,
    /// chaque case est classée, et une case couverte garde ce qu'on en savait.
    mutating func lire(_ lues: [GrilleIso.Case: Signature]) {
        guard !reference.isEmpty else {
            reference = lues
            return
        }
        var bleuies: [GrilleIso.Case: Double] = [:]
        var nouvelles: [GrilleIso.Case: Teinte] = [:]
        for (position, signature) in lues {
            guard let avant = reference[position] else { continue }
            switch Self.comparer(signature, a: avant) {
            case .bleuie(let luma): bleuies[position] = luma
            case .libre: nouvelles[position] = .libre
            case .couverte: nouvelles[position] = teintes[position] ?? .inconnue
            }
        }
        guard bleuies.count >= Self.casesMin else {
            // Pas de sort : le plateau tel qu'il est (persos déplacés compris) devient la référence.
            reference.merge(lues) { $1 }
            teintes = [:]
            return
        }
        let seuil = Self.seuilClair(Array(bleuies.values))
        for (position, luma) in bleuies {
            nouvelles[position] = seuil.map { luma > $0 ? .horsVue : .portee } ?? .portee
        }
        teintes = nouvelles
    }

    enum Constat: Equatable { case bleuie(luma: Double), libre, couverte }

    /// Trois taches sur cinq bleuies : la case l'est ; deux changées autrement : couverte.
    static func comparer(_ signature: Signature, a reference: Signature) -> Constat {
        var bleuies: [Double] = []
        var changees = 0
        for (tache, avant) in zip(signature.taches, reference.taches) {
            let bleu = (tache.b - tache.r) - (avant.b - avant.r)
            let surVert = (tache.b - tache.v) - (avant.b - avant.v)
            if bleu >= seuilBleu, surVert >= seuilBleuSurVert {
                bleuies.append(tache.luma)
            } else if tache.ecart(avant) >= seuilCouverte {
                changees += 1
            }
        }
        if bleuies.count >= 3 { return .bleuie(luma: bleuies.sorted()[bleuies.count / 2]) }
        return changees >= 2 ? .couverte : .libre
    }

    /// La luminance qui sépare le bleu clair du foncé : la coupe qui écarte le
    /// plus les deux groupes (Otsu) ; `nil` si leurs moyennes sont trop proches.
    static func seuilClair(_ lumas: [Double]) -> Double? {
        let tries = lumas.sorted()
        guard tries.count >= 2 else { return nil }
        let total = tries.reduce(0, +)
        var cumul = 0.0
        var meilleure: (score: Double, seuil: Double, ecart: Double)?
        for i in 0..<(tries.count - 1) {
            cumul += tries[i]
            let n1 = Double(i + 1), n2 = Double(tries.count - i - 1)
            let m1 = cumul / n1, m2 = (total - cumul) / n2
            let score = n1 * n2 * (m2 - m1) * (m2 - m1)
            if score > meilleure?.score ?? -1 { meilleure = (score, (tries[i] + tries[i + 1]) / 2, m2 - m1) }
        }
        guard let meilleure, meilleure.ecart >= ecartClairSombre else { return nil }
        return meilleure.seuil
    }

    // MARK: - Mesure

    /// Les signatures des cases entièrement dans l'image, sur la grille en pixels.
    static func mesurer(_ image: ImageRVB, grille: PlateauCombat.Grille) -> [GrilleIso.Case: Signature] {
        let a = CGFloat(grille.a)
        guard a >= 4 else { return [:] }
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let coins = [CGPoint(x: 0, y: 0), CGPoint(x: w, y: 0), CGPoint(x: 0, y: h), CGPoint(x: w, y: h)]
            .map { GrilleIso.caseSous($0, a: a, centre: grille.centre) }
        guard let xMin = coins.map(\.x).min(), let xMax = coins.map(\.x).max(),
              let yMin = coins.map(\.y).min(), let yMax = coins.map(\.y).max() else { return [:] }
        var resultat: [GrilleIso.Case: Signature] = [:]
        for x in xMin...xMax {
            for y in yMin...yMax {
                let c = GrilleIso.projeter(x, y, a: a, centre: grille.centre)
                guard c.x - a >= 0, c.x + a < w, c.y - a / 2 >= 0, c.y + a / 2 < h else { continue }
                let taches = positionsTaches.map { tache(image, x: c.x + $0.u * a, y: c.y + $0.v * a / 2, rayon: $0.rayon, a: a) }
                resultat[GrilleIso.Case(x, y)] = Signature(taches: taches)
            }
        }
        return resultat
    }

    /// Le centre, puis aux 55 % du chemin vers chaque sommet : loin des joints dorés.
    private static let positionsTaches: [(u: CGFloat, v: CGFloat, rayon: CGFloat)] = [
        (0, 0, 0.25), (-0.55, 0, 0.1), (0.55, 0, 0.1), (0, -0.55, 0.1), (0, 0.55, 0.1),
    ]

    /// La couleur moyenne d'un petit losange de `rayon` (en fraction de la case) autour d'un point.
    private static func tache(_ image: ImageRVB, x: CGFloat, y: CGFloat, rayon: CGFloat, a: CGFloat) -> Couleur {
        let pas = max(1, Int(a * rayon / 4))
        let rx = Int(a * rayon), ry = Int(a * rayon / 2)
        var somme = (r: 0, v: 0, b: 0), n = 0
        for dy in stride(from: -ry, through: ry, by: pas) {
            for dx in stride(from: -rx, through: rx, by: pas) {
                guard CGFloat(abs(dx)) / CGFloat(max(rx, 1)) + CGFloat(abs(dy)) / CGFloat(max(ry, 1)) <= 1 else { continue }
                let px = Int(x) + dx, py = Int(y) + dy
                guard px >= 0, px < image.width, py >= 0, py < image.height else { continue }
                let p = image.rvb(px, py)
                somme = (somme.r + p.r, somme.v + p.v, somme.b + p.b)
                n += 1
            }
        }
        let d = Double(max(n, 1))
        return Couleur(r: Double(somme.r) / d, v: Double(somme.v) / d, b: Double(somme.b) / d)
    }
}
