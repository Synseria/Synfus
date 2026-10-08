import CoreGraphics

/// Une zone de la fenêtre de jeu à lire — la position du perso, le bouton de
/// fin de tour —, en **fractions du contenu** : la fenêtre sans sa barre de
/// titre. Pur : la géométrie se teste sans écran.
///
/// Le jeu dessine son interface à l'échelle de la fenêtre : un texte en haut
/// à gauche y reste, plus grand dans une grande fenêtre, plus petit dans une
/// petite. Une fraction du contenu le suit donc, quelle que soit la taille.
/// Du **contenu** et non de la fenêtre : en fenêtré, la barre de titre
/// décale tout de 28 points, et une zone serrée calibrée en plein écran
/// tomberait à côté.
///
/// Les valeurs par défaut sont mesurées sur de vraies captures (plein écran
/// et fenêtré) ; l'onglet Diagnostic permet de les recalibrer d'un tracé —
/// l'interface du jeu se déplace, le bouton de fin de tour en premier.
struct ZoneEcran: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
    var largeur: Double
    var hauteur: Double

    var rect: CGRect { CGRect(x: x, y: y, width: largeur, height: hauteur) }

    init(x: Double, y: Double, largeur: Double, hauteur: Double) {
        self.x = x
        self.y = y
        self.largeur = largeur
        self.hauteur = hauteur
    }

    init(_ rect: CGRect) {
        self.init(x: rect.minX, y: rect.minY, largeur: rect.width, hauteur: rect.height)
    }

    /// Nom de la zone et coordonnées : mesurés de 4,1 % à 8,2 % de la hauteur,
    /// le nom le plus long vu à 28 % de la largeur.
    static let positionParDefaut = ZoneEcran(x: 0, y: 0.03, largeur: 0.30, hauteur: 0.065)
    /// Le bouton « Fin de tour » et le décompte au-dessus, à leur place par
    /// défaut : en bas à droite, contre la barre de sorts.
    static let combatParDefaut = ZoneEcran(x: 0.79, y: 0.85, largeur: 0.12, hauteur: 0.12)
    /// Le suivi de chasse au trésor, à sa place par défaut : à gauche, sous
    /// la position, assez haut pour une chasse de dix étapes. Estimé, pas
    /// mesuré : le tracé du Diagnostic est là pour le corriger.
    static let chasseParDefaut = ZoneEcran(x: 0, y: 0.10, largeur: 0.26, hauteur: 0.55)
    /// Le suivi de quêtes, à la même place que celui de chasse (le jeu les
    /// range dans la même colonne), un peu plus large pour ses titres en
    /// gras et plus haut pour cinq quêtes et leurs objectifs. Estimé.
    static let quetesParDefaut = ZoneEcran(x: 0, y: 0.10, largeur: 0.28, hauteur: 0.62)

    /// En deçà, un tracé est un clic, pas une zone.
    static let tailleMinimale = 0.01

    /// La zone en pixels d'une image du contenu entier, arrondie au pixel.
    func pixels(dans taille: CGSize) -> CGRect {
        CGRect(x: x * taille.width, y: y * taille.height,
               width: largeur * taille.width, height: hauteur * taille.height).integral
    }

    /// La zone ramenée dans le contenu, et à une taille lisible.
    func bornee() -> ZoneEcran {
        let l = min(max(largeur, Self.tailleMinimale), 1)
        let h = min(max(hauteur, Self.tailleMinimale), 1)
        return ZoneEcran(x: min(max(x, 0), 1 - l), y: min(max(y, 0), 1 - h), largeur: l, hauteur: h)
    }

    /// Hauteur de contenu, en pixels, à laquelle toute lecture est ramenée :
    /// le texte du jeu y a toujours la même taille — celle où l'OCR lit juste,
    /// mesurée sur un plein écran de 1059 points capturé à un pixel par point.
    /// Une grande fenêtre n'en coûte pas plus, une petite n'est pas illisible.
    static let hauteurReference: CGFloat = 1080

    /// Le contenu dans le repère de la fenêtre (origine en haut à gauche) :
    /// tout, en plein écran ; sous la barre de titre, sinon.
    static func contenu(fenetre: CGSize, barreTitre: CGFloat, pleinEcran: Bool) -> CGRect {
        let titre = pleinEcran ? 0 : min(max(barreTitre, 0), fenetre.height)
        return CGRect(x: 0, y: titre, width: fenetre.width, height: max(fenetre.height - titre, 1))
    }

    /// Une zone (fractions) projetée dans le contenu, en points de la fenêtre.
    static func source(_ zone: CGRect, contenu: CGRect) -> CGRect {
        CGRect(x: contenu.minX + zone.minX * contenu.width,
               y: contenu.minY + zone.minY * contenu.height,
               width: zone.width * contenu.width,
               height: zone.height * contenu.height)
    }

    /// Pixels par point pour ramener le contenu à `reference`, sans dépasser
    /// la résolution native (`plafond`) : agrandir au-delà n'invente rien.
    static func echelle(hauteurContenu: CGFloat, reference: CGFloat = hauteurReference,
                        plafond: CGFloat) -> CGFloat {
        guard hauteurContenu > 0 else { return 1 }
        return min(reference / hauteurContenu, plafond)
    }
}
