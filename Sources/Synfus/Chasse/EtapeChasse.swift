import CoreGraphics
import Foundation

/// La direction d'une étape, telle que l'API de DofusDB la code.
enum Direction: Int, CaseIterable, Identifiable, Sendable {
    case est = 0
    case sud = 2
    case ouest = 4
    case nord = 6

    var id: Int { rawValue }

    /// Le symbole SF de la flèche.
    var symbole: String {
        switch self {
        case .est: return "arrow.right"
        case .sud: return "arrow.down"
        case .ouest: return "arrow.left"
        case .nord: return "arrow.up"
        }
    }

    var libelle: String {
        switch self {
        case .est: return L("chasse.direction.est")
        case .sud: return L("chasse.direction.sud")
        case .ouest: return L("chasse.direction.ouest")
        case .nord: return L("chasse.direction.nord")
        }
    }

    /// La flèche du clavier qui la choisit, par keycode de position.
    init?(toucheFleche keyCode: UInt16) {
        switch keyCode {
        case 124: self = .est
        case 125: self = .sud
        case 123: self = .ouest
        case 126: self = .nord
        default: return nil
        }
    }

    /// La flèche que le jeu met devant l'indice de l'étape en cours, lue par
    /// l'OCR dans sa ligne (« → … ») — Vision écorche parfois la flèche en
    /// triangle plein, d'où les variantes.
    init?(ligneLue ligne: String) {
        for (fleches, direction) in Self.flechesLues where fleches.contains(where: { ligne.contains($0) }) {
            self = direction
            return
        }
        return nil
    }

    /// Les glyphes de flèche reconnus, par direction.
    private static let flechesLues: [(String, Direction)] = [
        ("→➔➜➞➟⇨⇒►▶︎", .est),
        ("←⇦⇐◄◀︎", .ouest),
        ("↑⇧⇑▲", .nord),
        ("↓⇩⇓▼", .sud),
    ]
}

/// Une étape de chasse : d'une carte de départ, dans une direction, la
/// première carte qui porte l'indice. Pur : la réponse de DofusDB est fournie.
enum EtapeChasse {
    /// Une carte de la direction demandée et les indices qu'elle porte.
    struct Carte: Codable, Equatable, Sendable {
        let x: Int
        let y: Int
        /// En cartes depuis le départ.
        let distance: Int
        let indices: Set<Int>

        init(x: Int, y: Int, distance: Int, indices: Set<Int>) {
            self.x = x
            self.y = y
            self.distance = distance
            self.indices = indices
        }

        private enum CodingKeys: String, CodingKey { case posX, posY, distance, pois }
        private struct Poi: Codable { let id: Int }

        init(from decoder: any Decoder) throws {
            let conteneur = try decoder.container(keyedBy: CodingKeys.self)
            x = try conteneur.decode(Int.self, forKey: .posX)
            y = try conteneur.decode(Int.self, forKey: .posY)
            distance = try conteneur.decode(Int.self, forKey: .distance)
            indices = Set(try conteneur.decode([Poi].self, forKey: .pois).map(\.id))
        }

        func encode(to encoder: any Encoder) throws {
            var conteneur = encoder.container(keyedBy: CodingKeys.self)
            try conteneur.encode(x, forKey: .posX)
            try conteneur.encode(y, forKey: .posY)
            try conteneur.encode(distance, forKey: .distance)
            try conteneur.encode(indices.sorted().map { Poi(id: $0) }, forKey: .pois)
        }
    }

    /// Ce que l'étape donne.
    enum Resultat: Equatable, Sendable {
        case trouve(x: Int, y: Int, distance: Int)
        /// Aucune carte de la portée ne porte l'indice.
        case introuvable
        /// Le Phorreur se déplace : aucune carte à donner.
        case phorreur
    }

    /// Ce qu'une étape cherche : un indice de DofusDB, ou le Phorreur.
    enum Cible: Hashable, Sendable {
        case indice(Indice)
        case phorreur

        func nom(en langue: Langue) -> String {
            switch self {
            case .indice(let indice): return indice.nom(en: langue)
            case .phorreur: return L("chasse.phorreur")
            }
        }
    }

    /// Les cibles lues par l'OCR, dans l'ordre des lignes — la dernière est
    /// l'étape en cours ; une cible lue deux fois ne compte qu'à sa dernière.
    static func ciblesLues(dans lignes: [String], parmi indices: [Indice]) -> [Cible] {
        var lues: [Cible] = []
        for ligne in lignes {
            let cible: Cible? = estPhorreur(ligne)
                ? .phorreur
                : IndicesChasse.indicesReconnus(dans: [ligne], parmi: indices).first.map(Cible.indice)
            guard let cible else { continue }
            lues.removeAll { $0 == cible }
            lues.append(cible)
        }
        return lues
    }

    /// Le badge « EN COURS » de la ligne : l'étape en cours du suivi la porte
    /// (pin blanche) ; les étapes faites portent « VALIDÉ » (pin bleue).
    static func estEnCours(_ ligne: String) -> Bool {
        Ressemblance.normaliser(ligne).contains("en cours")
    }

    /// Le badge « VALIDÉ » de la ligne — pas le bouton « VALIDER » du bas.
    static func estValidee(_ ligne: String) -> Bool {
        let n = Ressemblance.normaliser(ligne)
        return n.contains("valide") && !n.contains("valider")
    }

    /// Ce que le scan a vu sur une ligne du suivi : le texte lu, la flèche lue
    /// par l'OCR, la meilleure correspondance en pixels, et le badge du jeu.
    struct AnalyseLigne: Sendable, Equatable {
        let texte: String
        let glyphe: Direction?
        let pixel: DetectionFleche.Correspondance?
        let enCours: Bool
        let validee: Bool

        /// La direction retenue pour la ligne — **seulement si la lecture est
        /// sûre** : un pixel à ≥ 0,75 gagne (Vision inverse parfois ↑ et ↓ dans
        /// le texte) ; sinon un pixel à ≥ 0,6 vaut s'il n'y a pas de glyphe
        /// contraire ; glyphe et pixel qui se contredisent sous 0,75 : aucune
        /// direction — mieux vaut attendre un clic que d'en définir une fausse.
        var retenue: Direction? {
            if let pixel, pixel.score >= 0.75 { return pixel.direction }
            if let pixel, pixel.score >= 0.6 {
                if let glyphe, glyphe != pixel.direction { return nil }
                return pixel.direction
            }
            return glyphe
        }

        /// La ligne porte une flèche lisible avec certitude.
        var flechee: Bool { retenue != nil }
    }

    /// L'analyse ligne à ligne du suivi de chasse, de haut en bas.
    /// `cadres` : le cadre de chaque ligne en pixels de `image`, aligné sur `lignes`.
    static func analyser(dans lignes: [String], cadres: [CGRect], image: LumaBitmap?) -> [AnalyseLigne] {
        let n = min(lignes.count, cadres.count)
        return (0..<n).map { rang in
            var detail = DetectionFleche.detail(dans: lignes[rang], cadre: cadres[rang], image: image)
            // Dernier recours : la flèche peut être au bord gauche de la zone,
            // le cadre OCR du texte commençant plus à droite.
            if detail.pixel == nil, let image, cadres[rang].minX > 0 {
                let elargi = CGRect(x: 0, y: cadres[rang].minY, width: cadres[rang].maxX, height: cadres[rang].height)
                detail.pixel = DetectionFleche.direction(dans: image, ligne: elargi, texte: cadres[rang].minX)
            }
            return AnalyseLigne(texte: lignes[rang], glyphe: detail.glyphe, pixel: detail.pixel,
                                enCours: estEnCours(lignes[rang]), validee: estValidee(lignes[rang]))
        }
    }

    /// Toutes les lignes à flèche sûre, de haut en bas.
    static func lignesFlechees(dans lignes: [String], cadres: [CGRect], image: LumaBitmap?) -> [(rang: Int, direction: Direction)] {
        analyser(dans: lignes, cadres: cadres, image: image).enumerated().compactMap { rang, a in
            a.retenue.map { (rang, $0) }
        }
    }

    /// La première ligne fléchée du suivi.
    static func premiereFlechee(dans lignes: [String], cadres: [CGRect], image: LumaBitmap?) -> (rang: Int, direction: Direction)? {
        lignesFlechees(dans: lignes, cadres: cadres, image: image).first
    }

    /// L'étape en cours lue sur l'écran : direction **et** indice viennent de la
    /// **même** ligne — la dernière portant le badge « EN COURS » et un indice
    /// reconnu (les « VALIDÉ » restent au-dessus ; sans badge, la dernière à
    /// indice non validée). La direction n'est posée que si sa flèche a été lue
    /// sûrement (voir `AnalyseLigne.retenue`) : sinon elle reste nil, à choisir
    /// à la main — jamais devinée.
    static func etapeLue(dans lignes: [String], cadres: [CGRect], image: LumaBitmap?, parmi indices: [Indice]) -> (direction: Direction?, cible: Cible?, rang: Int?) {
        let analyse = analyser(dans: lignes, cadres: cadres, image: image)
        let lues = ciblesLues(dans: lignes, parmi: indices)
        // Les lignes qui portent un indice reconnu, avec le badge de la ligne
        // du dessus quand l'OCR a séparé le badge de l'indice.
        let avecCible = analyse.enumerated().compactMap { i, _ in
            ciblesLues(dans: [lignes[i]], parmi: indices).first != nil ? i : nil
        }
        func badgeDe(_ rang: Int) -> AnalyseLigne {
            if analyse[rang].enCours || analyse[rang].validee { return analyse[rang] }
            // le badge « EN COURS »/« VALIDÉ » peut être la ligne juste au-dessus
            if rang > 0, analyse[rang - 1].enCours || analyse[rang - 1].validee { return analyse[rang - 1] }
            return analyse[rang]
        }
        // L'étape en cours : badge « EN COURS », sinon la dernière ligne à indice non validée.
        let enCours = avecCible.filter { badgeDe($0).enCours }
        let pool = enCours.isEmpty ? avecCible.filter { !badgeDe($0).validee } : enCours
        guard let rang = pool.last ?? avecCible.last else { return (nil, lues.last, nil) }
        // Direction et indice de la **même** ligne ; la direction reste nil si
        // la flèche n'a pas été lue sûrement — aucun pari automatique.
        let cible = ciblesLues(dans: [lignes[rang]], parmi: indices).first ?? lues.last
        return (analyse[rang].retenue, cible, rang)
    }

    /// DofusDB ne cherche pas plus loin, le jeu non plus.
    static let portee = 10

    /// La plus proche des cartes qui portent l'indice — l'API ne les rend pas
    /// dans l'ordre.
    static func destination(indice: Int, cartes: [Carte]) -> Carte? {
        cartes.filter { $0.indices.contains(indice) }.min { $0.distance < $1.distance }
    }

    static func resultat(indice: Int, cartes: [Carte]) -> Resultat {
        guard let carte = destination(indice: indice, cartes: cartes) else { return .introuvable }
        return .trouve(x: carte.x, y: carte.y, distance: carte.distance)
    }

    /// Un indice « Phorreur » est un PNJ qui erre : absent de DofusDB, il se
    /// reconnaît à son nom, à une faute d'OCR près — sauf « horreur », le mot
    /// français, à une lettre lui aussi.
    static func estPhorreur(_ texte: String) -> Bool {
        let normalise = Ressemblance.normaliser(texte)
        if normalise.contains("phorreur") { return true }
        return !normalise.contains("horreur") && Ressemblance.distanceDansTexte("phorreur", normalise) <= 1
    }
}
