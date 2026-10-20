import CoreGraphics

/// Retrouver les zones de lecture sur une capture du jeu, sans tracé : l'OCR
/// du contenu entier rend chaque texte et sa place, et chaque élément de
/// l'interface se reconnaît à ce qu'il dit — des coordonnées en haut à
/// gauche, des lignes horodatées pour le tchat, un pourcentage pour le cœur,
/// « Fin de tour » pour le bouton, des noms de quêtes ou d'indices pour les
/// suivis. Chaque joueur a sa fenêtre et son interface : la zone suit ce que
/// son écran montre, avec la marge que demande un texte qui change (un nom de
/// zone plus long, un tchat qui se remplit). Pur : textes et cadres lui sont
/// donnés.
enum DetectionZones {
    /// Un texte lu sur le contenu entier ; son cadre en fractions du contenu,
    /// origine en haut à gauche, comme `ZoneEcran`.
    struct TexteVu: Equatable, Sendable {
        let texte: String
        let cadre: CGRect
    }

    /// Les zones des éléments à l'écran ; un élément absent (pas de combat,
    /// pas de chasse) n'en a pas. `titres`, `indices` : les rangs, dans
    /// `textes`, de ceux qui portent un nom de quête ou un indice de chasse.
    static func detecter(_ textes: [TexteVu], titres: Set<Int> = [], indices: Set<Int> = []) -> [GenreLecture: ZoneEcran] {
        var zones: [GenreLecture: ZoneEcran] = [:]
        zones[.position] = position(textes)
        zones[.combat] = combat(textes)
        zones[.vie] = vie(textes)
        zones[.tchat] = tchat(textes)
        zones[.quetes] = suivi(titres.sorted().map { textes[$0] }, parmi: textes, defaut: .quetesParDefaut)
        zones[.chasse] = suivi(indices.sorted().map { textes[$0] }, parmi: textes, defaut: .chasseParDefaut)
        return zones
    }

    /// Le nom de la zone et la ligne qui commence par les coordonnées, en haut
    /// à gauche ; aussi large que le défaut au moins — un autre nom de zone
    /// sera plus long.
    static func position(_ textes: [TexteVu]) -> ZoneEcran? {
        guard let coordonnees = textes.first(where: {
            $0.cadre.minX < 0.3 && $0.cadre.minY < 0.35 && ressembleAuxCoordonnees($0.texte)
        }) else { return nil }
        let h = coordonnees.cadre.height
        var cadre = coordonnees.cadre
        let nom = textes.filter {
            $0.cadre.minX < 0.3 && $0.texte.contains(where: \.isLetter)
                && $0.cadre.maxY <= coordonnees.cadre.minY + h / 2 && coordonnees.cadre.minY - $0.cadre.maxY < h * 1.5
        }.max { $0.cadre.maxY < $1.cadre.maxY }
        if let nom { cadre = cadre.union(nom.cadre) }
        let haut = max(cadre.minY - h * 0.4, 0)
        return ZoneEcran(x: 0, y: haut, largeur: max(ZoneEcran.positionParDefaut.largeur, cadre.maxX * 1.25),
                         hauteur: cadre.maxY + h * 0.4 - haut).bornee()
    }

    /// Une ligne qui commence par deux nombres séparés d'une virgule. Plus
    /// lâche que `PositionCarte.coordonnees` : lu sur l'écran entier, le signe
    /// moins devient parfois un chiffre (« 316, 1 » pour « -16, 1 », mesuré) —
    /// pour trouver la zone, la forme suffit.
    static func ressembleAuxCoordonnees(_ texte: String) -> Bool {
        PositionCarte.coordonnees(dans: texte) != nil || texte.firstMatch(of: /^\s*\D?\d{1,4}\s*[,.]\s*\D?\d{1,4}\b/) != nil
    }

    /// Le bouton de fin de tour (ou « Prêt ») le plus à droite de la moitié
    /// basse, et le décompte au-dessus. Une ligne du tchat qui le nomme
    /// (« Terminez votre tour avec le bouton Fin de tour ») n'en est pas un.
    static func combat(_ textes: [TexteVu]) -> ZoneEcran? {
        let boutons = textes.filter {
            $0.cadre.minY > 0.5 && Harebourg.heure($0.texte) == nil && LectureCombat.estBouton($0.texte)
                && $0.texte.filter(\.isLetter).count <= 14
        }
        guard let bouton = boutons.max(by: { $0.cadre.maxX < $1.cadre.maxX }) else { return nil }
        let c = bouton.cadre, h = c.height
        let largeur = max(c.width * 1.8, h * 6)
        return ZoneEcran(x: c.midX - largeur / 2, y: c.minY - h * 3.2, largeur: largeur, hauteur: h * 4.6).bornee()
    }

    /// Le pourcentage du cœur de vie, au bas de l'écran et au plus près du
    /// centre, avec de quoi lire « 12 345 / 12 345 » s'il montre les points.
    static func vie(_ textes: [TexteVu]) -> ZoneEcran? {
        let pourcentages = textes.filter {
            $0.cadre.minY > 0.6 && $0.cadre.midX > 0.2 && $0.cadre.midX < 0.8
                && $0.texte.wholeMatch(of: /\s*\d{1,3}\s*%\s*/) != nil
        }
        guard let coeur = pourcentages.min(by: { abs($0.cadre.midX - 0.5) < abs($1.cadre.midX - 0.5) }) else { return nil }
        let c = coeur.cadre
        let largeur = max(c.width * 2, ZoneEcran.vieParDefaut.largeur * 0.8)
        let hauteur = max(c.height * 3.4, ZoneEcran.vieParDefaut.hauteur * 0.8)
        return ZoneEcran(x: c.midX - largeur / 2, y: c.midY - hauteur / 2, largeur: largeur, hauteur: hauteur).bornee()
    }

    /// Les lignes horodatées de la moitié basse et leurs suites repliées, à
    /// leur bord gauche ; au moins la hauteur et la largeur du défaut, vers
    /// le haut et vers la droite — le tchat se remplit, ses lignes s'allongent.
    static func tchat(_ textes: [TexteVu]) -> ZoneEcran? {
        let horodatees = textes.filter { $0.cadre.minY > 0.4 && Harebourg.heure($0.texte) != nil }
        guard horodatees.count >= 2 else { return nil }
        let bords = horodatees.map(\.cadre.minX).sorted()
        let gauche = bords[bords.count / 2]
        let h = horodatees.map(\.cadre.height).sorted()[horodatees.count / 2]
        let premiere = horodatees.map(\.cadre.minY).min() ?? 0
        let colonne = textes.filter { abs($0.cadre.minX - gauche) < 0.01 && $0.cadre.minY >= premiere - h / 2 }
        let cadre = colonne.map(\.cadre).reduce(CGRect.null) { $0.union($1) }
        let bas = cadre.maxY + h * 0.6
        let haut = max(min(cadre.minY - h * 0.3, bas - ZoneEcran.tchatParDefaut.hauteur), 0)
        let x = max(gauche - h * 0.4, 0)
        let droite = max(cadre.maxX + h, x + ZoneEcran.tchatParDefaut.largeur)
        return ZoneEcran(x: x, y: haut, largeur: droite - x, hauteur: bas - haut).bornee()
    }

    /// Un suivi du jeu, à gauche : du premier repère (nom de quête, indice)
    /// jusqu'aux lignes qui suivent sans grand blanc, et jusqu'au bas du
    /// défaut au moins — le suivi grandit avec les quêtes suivies.
    static func suivi(_ reperes: [TexteVu], parmi textes: [TexteVu], defaut: ZoneEcran) -> ZoneEcran? {
        let reperes = reperes.filter { $0.cadre.minX < 0.45 && $0.cadre.minY < 0.75 }
        guard let premier = reperes.min(by: { $0.cadre.minY < $1.cadre.minY }) else { return nil }
        let h = premier.cadre.height
        var cadre = reperes.map(\.cadre).reduce(premier.cadre) { $0.union($1) }
        for texte in textes.sorted(by: { $0.cadre.minY < $1.cadre.minY })
        where texte.cadre.minY > premier.cadre.minY && texte.cadre.minX < premier.cadre.minX + 0.05 {
            guard texte.cadre.minY - cadre.maxY < h * 3 else { break }
            cadre = cadre.union(texte.cadre)
        }
        let haut = max(premier.cadre.minY - h * 0.8, 0)
        let bas = max(defaut.y + defaut.hauteur, cadre.maxY + h * 2)
        return ZoneEcran(x: 0, y: haut, largeur: max(defaut.x + defaut.largeur, cadre.maxX + 0.02),
                         hauteur: bas - haut).bornee()
    }
}
