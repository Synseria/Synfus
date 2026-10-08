import CoreGraphics
import Foundation

/// Ce qu'un genre de lecture regarde pour décider de relancer l'OCR.
enum MesureSignature: Sendable {
    /// Le texte blanc de toute la zone, en grille fixe : la position, posée
    /// sur le jeu, ne change qu'avec la carte.
    case zone
    /// Le bouton de combat : sa couleur sur toute la zone, son texte sur son
    /// seul corps. Le décompte au-dessus change chaque seconde sans rien dire
    /// de neuf — l'échéance est tenue localement — et la fin du tour se voit
    /// à la couleur.
    case bouton
    /// Un suivi (quêtes, chasse) : le texte de ses seules lignes, en grille
    /// fine. Un objectif gris clair d'une ligne doit relancer l'OCR, le jeu
    /// qui bouge autour de l'encadré non.
    case lignes

    /// Luminance au-delà de laquelle un pixel compte comme du texte. Les
    /// objectifs d'un suivi, gris clair et fins, culminent vers 230 : au seuil
    /// du blanc, une ligne n'allume que deux ou trois cases ; l'encadré sombre
    /// du suivi reste loin sous 180 (mesuré sur deux captures, carte sombre et
    /// carte claire).
    var seuil: UInt8 { self == .lignes ? 180 : EmpreinteTexte.seuil }
}

/// Ce qui décide de relancer l'OCR : le texte clair, là où il a été lu, et
/// pour le bouton de combat, sa couleur — le même « Fin de tour » blanc passe
/// du gris à la couleur sans qu'un pixel clair ne bouge.
struct SignatureZone: Equatable, Sendable {
    let empreinte: EmpreinteTexte
    /// Part colorée de la zone entière, pour les zones où la couleur compte.
    let couleur: Double?
    /// Où l'empreinte se mesure, en pixels de la zone (origine en haut à
    /// gauche) ; `nil` : toute la zone. La capture suivante se mesure au même
    /// cadre, pour lui être comparable.
    let cadre: CGRect?
    /// Les lignes lues descendent jusqu'au bas de la zone : la suite du texte
    /// peut y être coupée (un suivi plus long que la zone).
    let auBord: Bool

    init(empreinte: EmpreinteTexte, couleur: Double?, cadre: CGRect? = nil, auBord: Bool = false) {
        self.empreinte = empreinte
        self.couleur = couleur
        self.cadre = cadre
        self.auBord = auBord
    }

    /// La signature d'une image : grille fixe sur toute la zone pour `.zone`
    /// (et pour le bouton tant qu'il n'a pas été lu), grille fine dans le
    /// cadre sinon.
    init(_ image: LumaBitmap, mesure: MesureSignature, cadre: CGRect?, couleur: Double?, auBord: Bool = false) {
        let cadre = mesure == .zone ? nil : cadre
        let empreinte = mesure == .lignes || cadre != nil
            ? EmpreinteTexte(image, dans: cadre, seuil: mesure.seuil)
            : EmpreinteTexte(image)
        self.init(empreinte: empreinte, couleur: couleur, cadre: cadre, auBord: auBord)
    }

    func semblable(a autre: SignatureZone) -> Bool {
        guard empreinte.semblable(a: autre.empreinte) else { return false }
        guard let couleur, let autre = autre.couleur else { return true }
        return (couleur >= LectureCombat.seuilSignature) == (autre >= LectureCombat.seuilSignature)
    }

    /// Le cadre des lignes lues (boîtes en pixels de la zone, origine en haut
    /// à gauche) : leur union élargie d'une demi-ligne, et prolongée d'une
    /// ligne et demie vers le bas, où paraît l'objectif ou la quête qui
    /// s'ajoute. `auBord` : ce prolongement sort de la zone. `nil` : rien lu.
    static func cadre(lignes boites: [CGRect], image: CGSize) -> (cadre: CGRect, auBord: Bool)? {
        guard let premiere = boites.first else { return nil }
        let union = boites.dropFirst().reduce(premiere) { $0.union($1) }
        let hauteurs = boites.map(\.height).sorted()
        let ligne = hauteurs[hauteurs.count / 2]
        let bas = union.maxY + 1.5 * ligne
        let cadre = CGRect(x: union.minX - ligne / 2, y: union.minY - ligne / 2,
                           width: union.width + ligne, height: bas - union.minY + ligne / 2)
            .integral
            .intersection(CGRect(origin: .zero, size: image))
        guard !cadre.isNull, cadre.width >= 1, cadre.height >= 1 else { return nil }
        return (cadre, bas >= image.height)
    }
}

/// Empreinte de ce qui est **écrit** dans une imagette : les seuls pixels
/// clairs — le texte du jeu est blanc cerné de sombre —, réduits à une grille.
///
/// C'est elle qui rend la lecture en continu gratuite : la position ne change
/// qu'au changement de carte, et une capture dont l'empreinte n'a pas bougé
/// ne repasse pas par l'OCR. Le décor qui bouge derrière le texte (feuillage,
/// persos qui passent) est sombre ou coloré, il ne franchit pas le seuil.
struct EmpreinteTexte: Equatable, Sendable {
    static let colonnes = 96
    static let lignes = 24
    /// Luminance au-delà de laquelle un pixel compte comme du texte.
    static let seuil: UInt8 = 225
    /// Part de pixels clairs qui allume une case.
    static let remplissage = 0.08
    /// Cases qui peuvent différer sans que le texte ait changé.
    static let tolerance = 6
    /// Une case de la grille fine, en pixels à l'échelle de référence : une
    /// ligne de texte du jeu (8 à 10 pixels) y tient sur trois cases de haut.
    /// La grille fixe, sur une zone haute comme un suivi, a des cases de
    /// vingt-huit pixels où une ligne n'allume rien (mesuré).
    static let cellule = (largeur: 5, hauteur: 3)

    let cases: [Bool]

    init(cases: [Bool]) { self.cases = cases }

    /// Grille fixe sur toute l'image.
    init(_ image: LumaBitmap) {
        self.init(cases: Self.cases(image, dans: CGRect(x: 0, y: 0, width: image.width, height: image.height),
                                    colonnes: Self.colonnes, lignes: Self.lignes, seuil: Self.seuil))
    }

    /// Grille fine (`cellule`) dans `cadre`, toute l'image sans cadre.
    init(_ image: LumaBitmap, dans cadre: CGRect?, seuil: UInt8) {
        let rect = (cadre ?? CGRect(x: 0, y: 0, width: image.width, height: image.height))
            .intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height)).integral
        let (largeur, hauteur) = rect.isNull ? (0, 0) : (Int(rect.width), Int(rect.height))
        self.init(cases: Self.cases(image, dans: rect,
                                    colonnes: max(1, largeur / Self.cellule.largeur),
                                    lignes: max(1, hauteur / Self.cellule.hauteur), seuil: seuil))
    }

    private static func cases(_ image: LumaBitmap, dans rect: CGRect, colonnes: Int, lignes: Int,
                              seuil: UInt8) -> [Bool] {
        var cases = [Bool](repeating: false, count: colonnes * lignes)
        guard !rect.isNull, rect.width >= 1, rect.height >= 1 else { return cases }
        let (ox, oy, w, h) = (Int(rect.minX), Int(rect.minY), Int(rect.width), Int(rect.height))
        for cy in 0..<lignes {
            let y0 = cy * h / lignes, y1 = max(y0 + 1, (cy + 1) * h / lignes)
            for cx in 0..<colonnes {
                let x0 = cx * w / colonnes, x1 = max(x0 + 1, (cx + 1) * w / colonnes)
                var clairs = 0
                for y in y0..<min(y1, h) {
                    let debut = (oy + y) * image.width + ox
                    for x in x0..<min(x1, w) where image.pixels[debut + x] >= seuil { clairs += 1 }
                }
                let aire = (min(y1, h) - y0) * (min(x1, w) - x0)
                cases[cy * colonnes + cx] = Double(clairs) >= Double(aire) * remplissage
            }
        }
        return cases
    }

    /// Même texte, au bruit près.
    func semblable(a autre: EmpreinteTexte) -> Bool {
        guard cases.count == autre.cases.count else { return false }
        return zip(cases, autre.cases).lazy.filter { $0 != $1 }.count <= Self.tolerance
    }
}
