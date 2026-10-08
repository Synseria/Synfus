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
}

/// Une étape de chasse : d'une carte de départ, dans une direction, la
/// première carte qui porte l'indice. Pur : la réponse de DofusDB est fournie.
enum EtapeChasse {
    /// Une carte de la direction demandée et les indices qu'elle porte.
    struct Carte: Decodable, Equatable, Sendable {
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
        private struct Poi: Decodable { let id: Int }

        init(from decoder: any Decoder) throws {
            let conteneur = try decoder.container(keyedBy: CodingKeys.self)
            x = try conteneur.decode(Int.self, forKey: .posX)
            y = try conteneur.decode(Int.self, forKey: .posY)
            distance = try conteneur.decode(Int.self, forKey: .distance)
            indices = Set(try conteneur.decode([Poi].self, forKey: .pois).map(\.id))
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
