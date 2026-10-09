import Foundation

/// Où trouver un monstre ou un objet, d'après DofusDB (`OuTrouverDofusDB`) :
/// les repaires d'un monstre — sous-zones où il vit, donjons dont il est —,
/// les monstres qui lâchent un objet, sa recette. Pur : la case où aller se
/// choisit ici, sur la carte intégrée, depuis la position du perso.
enum OuTrouver {
    /// Ce qu'on cherche : un monstre cité par un objectif, un objet à réunir.
    enum Sujet: Hashable, Sendable {
        case monstre(Int)
        case objet(Int)
    }

    typealias Case = (x: Int, y: Int)

    /// La case d'un repaire, et sa carte du monde (`Zaap.monde`).
    struct Situation: Equatable, Sendable {
        let x: Int
        let y: Int
        let monde: Int
    }

    /// Une sous-zone : sa case relevée la plus proche du perso, sinon un repère
    /// qui s'y trouve (intérieurs, autres mondes). Un donjon : son repère sur
    /// la carte, par sa carte d'entrée, sinon par son nom — l'entrée que donne
    /// DofusDB est souvent la première salle, sur la carte du donjon même.
    /// `nil` : rien ne le situe (expéditions, monstres de quête).
    static func situer(_ repaire: RepaireMonstre, depuis depart: Case?, reseau: ReseauSousZones,
                       reperes: ReperesCarte) -> Situation? {
        let lieu: Lieu?
        switch repaire.genre {
        case .sousZone:
            if let proche = laPlusProche(reseau.cases(repaire.id), de: depart) {
                return Situation(x: proche.x, y: proche.y, monde: Zaap.mondeDesDouze)
            }
            lieu = reperes.lieu(sousZone: repaire.id)
        case .donjon:
            lieu = repaire.entree.flatMap(reperes.donjon(carte:))
                ?? repaire.noms[Langue.fr.rawValue].flatMap(reperes.donjon(nom:))
        }
        return lieu.map { Situation(x: $0.x, y: $0.y, monde: $0.monde) }
    }

    /// La case la plus proche du départ ; sans départ, celle du milieu de la
    /// sous-zone, pour ne pas viser un bord au hasard. À égalité, la première.
    static func laPlusProche(_ cases: [Case], de depart: Case?) -> Case? {
        guard !cases.isEmpty else { return nil }
        let reference = depart ?? (cases.map(\.x).reduce(0, +) / cases.count, cases.map(\.y).reduce(0, +) / cases.count)
        return cases.min { ItineraireZaap.distance($0, reference) < ItineraireZaap.distance($1, reference) }
    }

    /// Les repaires situés, du plus proche au plus loin d'après `cartes` (le
    /// coût d'un trajet copié, zaaps compris) ; sans coût — position inconnue,
    /// autre monde —, après, dans l'ordre donné. Un repaire que rien ne situe
    /// est laissé de côté.
    static func situes(_ repaires: [RepaireMonstre], depuis depart: Case?, reseau: ReseauSousZones,
                       reperes: ReperesCarte, cartes: (Case) -> Int?) -> [RepaireSitue] {
        repaires.compactMap { repaire in
            situer(repaire, depuis: depart, reseau: reseau, reperes: reperes).map { situation in
                RepaireSitue(repaire: repaire, situation: situation,
                             cartes: situation.monde == Zaap.mondeDesDouze ? cartes((situation.x, situation.y)) : nil)
            }
        }
        .enumerated()
        .sorted { a, b in
            switch (a.element.cartes, b.element.cartes) {
            case let (ca?, cb?) where ca != cb: return ca < cb
            case (_?, nil): return true
            case (nil, _?): return false
            default: return a.offset < b.offset
            }
        }
        .map(\.element)
    }

    /// Les monstres qui lâchent l'objet, avec leurs repaires situés : celui
    /// dont le repaire est le plus proche d'abord, à égalité le plus généreux.
    /// Sans position, du plus généreux au moins généreux.
    static func lacheurs(_ sources: SourcesObjet, situer: (FicheMonstre) -> [RepaireSitue])
        -> [(lacheur: SourcesObjet.Lacheur, repaires: [RepaireSitue])] {
        sources.lacheurs.map { ($0, situer($0.monstre)) }
            .enumerated()
            .sorted { a, b in
                switch (a.element.1.first?.cartes, b.element.1.first?.cartes) {
                case let (ca?, cb?) where ca != cb: return ca < cb
                case (_?, nil): return true
                case (nil, _?): return false
                default:
                    return a.element.0.taux != b.element.0.taux ? a.element.0.taux > b.element.0.taux : a.offset < b.offset
                }
            }
            .map { (lacheur: $0.element.0, repaires: $0.element.1) }
    }
}

/// Un endroit où vit un monstre : une sous-zone, ou un donjon.
struct RepaireMonstre: Codable, Equatable, Sendable {
    enum Genre: String, Codable, Sendable {
        case sousZone = "sousZone"
        case donjon
    }

    let genre: Genre
    /// La sous-zone ou le donjon, chez DofusDB.
    let id: Int
    let noms: [String: String]
    /// Un donjon : sa carte d'entrée (`entranceMapId`).
    let entree: Int?
}

struct FicheMonstre: Codable, Equatable, Sendable {
    let id: Int
    let noms: [String: String]
    let repaires: [RepaireMonstre]
}

/// D'où vient un objet : les monstres qui le lâchent, sa recette.
struct SourcesObjet: Codable, Equatable, Sendable {
    struct Lacheur: Codable, Equatable, Sendable {
        let monstre: FicheMonstre
        /// En pour cent, au grade le plus haut.
        let taux: Double
    }

    struct Ingredient: Codable, Equatable, Sendable {
        let noms: [String: String]
        let quantite: Int
    }

    struct Recette: Codable, Equatable, Sendable {
        let metier: [String: String]
        let niveau: Int
        let ingredients: [Ingredient]
    }

    /// Le plus généreux d'abord.
    let lacheurs: [Lacheur]
    let recette: Recette?
}

/// Un repaire et la case où aller.
struct RepaireSitue: Equatable, Sendable {
    let repaire: RepaireMonstre
    let situation: OuTrouver.Situation
    /// Les cartes depuis le perso, zaap compris ; `nil` sans position ou hors
    /// du Monde des Douze.
    let cartes: Int?
}

extension OuTrouver.Sujet {
    var estUnMonstre: Bool {
        if case .monstre = self { return true }
        return false
    }
}
