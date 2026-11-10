import CoreGraphics
import Foundation

/// Couleur opaque en composantes 0…1 — volontairement **sans AppKit ni SwiftUI** :
/// `SynfusMark` doit rester compilable hors de l'app, le générateur
/// `Tools/generate-app-icons.sh` le compilant tel quel pour produire le `.icns`.
struct SynfusRGB: Equatable, Sendable {
    let red: Double, green: Double, blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    func cg(_ alpha: Double = 1) -> CGColor { CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha) }

    func melange(_ autre: SynfusRGB, _ t: Double) -> SynfusRGB {
        SynfusRGB(red: red + (autre.red - red) * t, green: green + (autre.green - green) * t,
                  blue: blue + (autre.blue - blue) * t)
    }
}

/// La marque Synfus : l'Œuf ajouré — un Dofus en treillis de rubans ondés,
/// blanc bleuté, éclairé du dedans, posé sur un feuillage à l'accent de
/// l'app. Fond transparent, comme les icônes du jeu ; tracés originaux,
/// aucun asset d'Ankama.
///
/// Le treillis est un vrai volume : deux familles de rubans enroulés autour
/// de l'œuf, vus d'un peu au-dessus ; ceux du dos passent par les jours,
/// ceux de devant sont fondus d'une pièce (contours de tout, puis plein de
/// tout) et coupés net par la silhouette.
///
/// Moteur **pur** — entrées → `CGImage`, aucun état. Cette description unique
/// sert à l'icône du bundle (via `Tools/AppIconExport.swift`) et au symbole de
/// la barre de menus (via `SynfusGlyph`) : il n'y a pas de second dessin.
///
/// Repère : **1024 × 1024, y vers le bas**.
enum SynfusMark {

    // MARK: - Repère

    static let cote: Double = 1024

    /// Le cadre du glyphe (`dessinerGlyphe`), où la barre de menus le recadre.
    static var cadreGlyphe: CGRect {
        feuillesDuGlyphe.map { chemin($0).boundingBoxOfPath }.reduce(silhouette().boundingBoxOfPath) { $0.union($1) }
    }

    /// Un trait sous ce nombre de pixels du rendu final s'étale en gris sale.
    private static let traitMinimalPixels: Double = 1.4

    /// Le treillis d'une taille de rendu : en petit, moins de rubans et plus
    /// larges, sans quoi les jours se bouchent.
    struct Treillis: Sendable {
        let brins: Int
        /// Demi-périodes de l'onde, de la pointe au col.
        let vagues: Double
        let largeur: Double
    }

    static func treillis(pixels: Int) -> Treillis {
        switch pixels {
        case 128...: return Treillis(brins: 8, vagues: 2, largeur: 34)
        case 48...: return Treillis(brins: 6, vagues: 1.5, largeur: 52)
        default: return Treillis(brins: 5, vagues: 1.2, largeur: 78)
        }
    }

    // MARK: - Palette

    private static let blanc = SynfusRGB(hex: 0xFFFFFF)
    private static let bleu = SynfusRGB(hex: 0x9CBDE3)
    private static let bleuOmbre = SynfusRGB(hex: 0x5F86B8)
    private static let bleuProfond = SynfusRGB(hex: 0x3D5F8F)
    private static let contour = SynfusRGB(hex: 0x1A2740)
    private static let lueurCoeur = SynfusRGB(hex: 0xF2FAFF)
    private static let lueurMilieu = SynfusRGB(hex: 0xB5DAF7)
    private static let lueurBord = SynfusRGB(hex: 0x7FB2E0)
    /// L'accent de l'app (`Couleurs.accent`) et ses nuances.
    private static let feuilleClair = SynfusRGB(hex: 0x5FD3AE)
    private static let feuilleMilieu = SynfusRGB(hex: 0x30A687)
    private static let feuilleSombre = SynfusRGB(hex: 0x1A6E58)
    private static let feuilleContour = SynfusRGB(hex: 0x0E3A30)

    // MARK: - L'œuf

    private static let centreX = 512.0
    private static let pointe = 92.0
    private static let base = 788.0
    private static let demiLargeur = 258.0
    /// Vu d'un peu au-dessus : l'avant descend, l'arrière monte.
    private static let plongee = 0.16

    /// Demi-largeur à `u` ∈ [-1, 1], de la pointe à la base : plus large en bas.
    private static func rayon(_ u: Double) -> Double {
        demiLargeur * sqrt(max(0, 1 - u * u)) * (1 + 0.16 * u) / 1.03
    }

    private static func hauteur(_ u: Double) -> Double { pointe + (u + 1) / 2 * (base - pointe) }

    /// Un point de la surface à l'angle `phi` (0 : face à nous), et sa profondeur.
    private static func surface(_ u: Double, _ phi: Double, echelle: Double = 1) -> (point: CGPoint, z: Double) {
        let r = rayon(u) * echelle
        return (CGPoint(x: centreX + r * sin(phi), y: hauteur(u) + r * cos(phi) * plongee), cos(phi))
    }

    static func silhouette(echelle: Double = 1) -> CGPath {
        let chemin = CGMutablePath()
        let pas = 480
        for i in 0...pas {
            let t = Double(i) / Double(pas) * 2 * .pi
            let u = -cos(t)
            let point = CGPoint(x: centreX + rayon(u) * echelle * (sin(t) >= 0 ? 1 : -1), y: hauteur(u))
            i == 0 ? chemin.move(to: point) : chemin.addLine(to: point)
        }
        chemin.closeSubpath()
        return chemin
    }

    /// Un ruban le long de points, chacun avec sa demi-largeur.
    private static func ruban(_ points: [(point: CGPoint, demi: Double)]) -> CGPath? {
        guard points.count >= 2 else { return nil }
        var gauche: [CGPoint] = [], droite: [CGPoint] = []
        for i in points.indices {
            let a = points[max(i - 1, 0)].point, b = points[min(i + 1, points.count - 1)].point
            let longueur = max(hypot(b.x - a.x, b.y - a.y), 1e-6)
            let (tx, ty) = ((b.x - a.x) / longueur, (b.y - a.y) / longueur)
            let (p, w) = points[i]
            gauche.append(CGPoint(x: p.x - ty * w, y: p.y + tx * w))
            droite.append(CGPoint(x: p.x + ty * w, y: p.y - tx * w))
        }
        let chemin = CGMutablePath()
        chemin.addLines(between: gauche + droite.reversed())
        chemin.closeSubpath()
        return chemin
    }

    /// Les rubans du treillis, coupés en tronçons de devant et du dos. Celui
    /// de devant déborde du bord : la silhouette le coupera net.
    static func rubans(_ treillis: Treillis) -> (devant: CGPath, dos: CGPath) {
        let devant = CGMutablePath(), dos = CGMutablePath()
        let pas = 2 * Double.pi / Double(treillis.brins)
        for famille in [-1.0, 1.0] {
            for brin in 0..<treillis.brins {
                var troncon: [(point: CGPoint, demi: Double)] = []
                var enAvant: Bool?
                func ranger() {
                    if let chemin = ruban(troncon) { (enAvant == true ? devant : dos).addPath(chemin) }
                }
                let echantillons = 420
                for k in 0...echantillons {
                    let u = -0.975 + 1.95 * Double(k) / Double(echantillons)
                    let onde = famille * 0.5 * pas * sin(treillis.vagues * .pi * (u + 1) / 2)
                    let (point, z) = surface(u, Double(brin) * pas + pas / 4 + onde)
                    // Aux pôles, les rubans s'affinent pour ne pas s'empâter.
                    let finesse = pow(max(rayon(u) / demiLargeur, 0.06), 0.6)
                    let demi = treillis.largeur / 2 * finesse * (z >= 0 ? 0.42 + 0.58 * z : 0.6)
                    let ici = z >= -0.3
                    if let enAvant, enAvant != ici {
                        troncon.append((point, demi))
                        ranger()
                        troncon = [troncon[troncon.count - 1]]
                    }
                    enAvant = ici
                    troncon.append((point, demi))
                }
                ranger()
            }
        }
        return (devant, dos)
    }

    // MARK: - Le feuillage

    private struct Feuille {
        let base: CGPoint
        let angle: Double
        let longueur: Double
        let largeur: Double
        /// 0 : pleine lumière ; vers 1, dans l'ombre de l'œuf.
        let ombre: Double
    }

    private static let socle = CGPoint(x: 512, y: 836)

    /// En éventail derrière l'œuf, deux à deux de part et d'autre.
    private static let feuillesDuFond: [Feuille] = [
        (-2.98, 340.0, 82.0), (-0.16, 340.0, 82.0), (-2.62, 380.0, 88.0), (-0.52, 380.0, 88.0),
        (-2.22, 360.0, 82.0), (-0.92, 360.0, 82.0),
    ].map { Feuille(base: socle, angle: $0.0, longueur: $0.1, largeur: $0.2, ombre: 0.45) }

    /// Devant le col, qu'elles cachent.
    private static let feuillesDevant: [Feuille] = [
        (-2.6, 250.0, 64.0, -36.0), (-0.54, 250.0, 64.0, 36.0), (-1.98, 180.0, 50.0, -16.0), (-1.16, 180.0, 50.0, 16.0),
    ].map { Feuille(base: CGPoint(x: socle.x + $0.3, y: socle.y + 36), angle: $0.0, longueur: $0.1, largeur: $0.2, ombre: 0.08) }

    private static func chemin(_ feuille: Feuille) -> CGPath {
        let (dx, dy) = (cos(feuille.angle), sin(feuille.angle))
        func point(_ t: Double, _ ecart: Double) -> CGPoint {
            CGPoint(x: feuille.base.x + dx * feuille.longueur * t - dy * ecart,
                    y: feuille.base.y + dy * feuille.longueur * t + dx * ecart)
        }
        let chemin = CGMutablePath()
        chemin.move(to: feuille.base)
        chemin.addCurve(to: point(1, 0), control1: point(0.22, feuille.largeur * 1.2), control2: point(0.78, feuille.largeur * 0.85))
        chemin.addCurve(to: feuille.base, control1: point(0.78, -feuille.largeur * 0.85),
                        control2: point(0.22, -feuille.largeur * 1.2))
        chemin.closeSubpath()
        return chemin
    }

    private static func dessiner(_ feuille: Feuille, trait: Double, nervure: Bool, in ctx: CGContext) {
        let forme = chemin(feuille)
        ctx.addPath(forme)
        ctx.setStrokeColor(feuilleContour.cg())
        ctx.setLineWidth(trait * 2)
        ctx.strokePath()
        ctx.saveGState()
        ctx.addPath(forme)
        ctx.clip()
        let (dx, dy) = (cos(feuille.angle), sin(feuille.angle))
        let milieu = CGPoint(x: feuille.base.x + dx * feuille.longueur / 2, y: feuille.base.y + dy * feuille.longueur / 2)
        let ecart = CGPoint(x: -dy * feuille.largeur, y: dx * feuille.largeur)
        let clair = feuilleClair.melange(feuilleMilieu, feuille.ombre)
        let sombre = feuilleSombre.melange(feuilleContour, feuille.ombre / 2)
        ctx.drawLinearGradient(
            degrade([clair.cg(), feuilleMilieu.melange(sombre, feuille.ombre).cg(), sombre.cg()], [0, 0.5, 1]),
            start: CGPoint(x: milieu.x + ecart.x, y: milieu.y + ecart.y),
            end: CGPoint(x: milieu.x - ecart.x, y: milieu.y - ecart.y), options: [])
        if nervure {
            ctx.setStrokeColor(feuilleClair.melange(blanc, 0.35).cg(0.65))
            ctx.setLineWidth(trait * 0.6)
            ctx.setLineCap(.round)
            let depart = CGPoint(x: feuille.base.x + dx * feuille.longueur * 0.1, y: feuille.base.y + dy * feuille.longueur * 0.1)
            let arrivee = CGPoint(x: feuille.base.x + dx * feuille.longueur * 0.86,
                                  y: feuille.base.y + dy * feuille.longueur * 0.86)
            ctx.move(to: depart)
            ctx.addQuadCurve(to: arrivee, control: CGPoint(x: milieu.x - dy * feuille.largeur * 0.1,
                                                           y: milieu.y + dx * feuille.largeur * 0.1))
            ctx.strokePath()
        }
        ctx.restoreGState()
    }

    // MARK: - Rendu

    private static let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

    private static func degrade(_ couleurs: [CGColor], _ positions: [CGFloat]) -> CGGradient {
        CGGradient(colorsSpace: sRGB, colors: couleurs as CFArray, locations: positions)!
    }

    /// L'icône carrée, fond transparent ; `nil` si le contexte est refusé.
    static func image(pixelSize: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: pixelSize, height: pixelSize, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let echelle = Double(pixelSize) / cote
        ctx.translateBy(x: 0, y: Double(pixelSize))
        ctx.scaleBy(x: echelle, y: -echelle)
        dessiner(pixels: pixelSize, in: ctx)
        return ctx.makeImage()
    }

    private static func dessiner(pixels: Int, in ctx: CGContext) {
        let treillis = treillis(pixels: pixels)
        let trait = max(8, traitMinimalPixels / 2 * cote / Double(pixels))
        let nervures = pixels >= 64
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        ombrePortee(ctx)
        for feuille in feuillesDuFond { dessiner(feuille, trait: trait, nervure: nervures, in: ctx) }
        ombreDeLOeuf(ctx)
        oeuf(treillis, trait: trait, in: ctx)
        // Les feuilles de devant posent une ombre douce sur le bas de l'œuf,
        // et seulement sur lui : rien ne déborde sur le fond transparent.
        ctx.saveGState()
        ctx.addPath(silhouette())
        ctx.clip()
        let flou = Double(pixels) / cote
        ctx.setShadow(offset: CGSize(width: 0, height: 12 * flou), blur: 28 * flou, color: feuilleContour.cg(0.6))
        for feuille in feuillesDevant { ctx.addPath(chemin(feuille)) }
        ctx.setFillColor(feuilleContour.cg())
        ctx.fillPath()
        ctx.restoreGState()
        for feuille in feuillesDevant { dessiner(feuille, trait: trait, nervure: nervures, in: ctx) }
    }

    /// L'œuf assombrit les feuilles du fond là où il s'y pose.
    private static func ombreDeLOeuf(_ ctx: CGContext) {
        ctx.saveGState()
        for feuille in feuillesDuFond { ctx.addPath(chemin(feuille)) }
        ctx.clip()
        ctx.translateBy(x: centreX, y: 790)
        ctx.scaleBy(x: 1, y: 0.42)
        ctx.drawRadialGradient(degrade([feuilleContour.cg(0.6), feuilleContour.cg(0)], [0, 1]),
                               startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 330, options: [])
        ctx.restoreGState()
    }

    private static func ombrePortee(_ ctx: CGContext) {
        ctx.saveGState()
        ctx.translateBy(x: centreX, y: 905)
        ctx.scaleBy(x: 1, y: 0.16)
        ctx.drawRadialGradient(degrade([SynfusRGB(hex: 0).cg(0.32), SynfusRGB(hex: 0).cg(0)], [0, 1]),
                               startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: 320, options: [])
        ctx.restoreGState()
    }

    private static func oeuf(_ treillis: Treillis, trait: Double, in ctx: CGContext) {
        let (devant, dos) = rubans(treillis)
        // Le dedans, vu par les jours : la lueur, puis les rubans du dos.
        ctx.saveGState()
        ctx.addPath(silhouette(echelle: 0.985))
        ctx.clip()
        // Un fond teinté partout, la lueur en ellipse dessus : pas de pointe
        // vide au-dessus d'une lueur ronde.
        ctx.setFillColor(lueurBord.cg(0.4))
        ctx.fill(CGRect(x: 0, y: 0, width: cote, height: cote))
        ctx.saveGState()
        ctx.translateBy(x: centreX, y: hauteur(0.1))
        ctx.scaleBy(x: 1, y: 1.3)
        ctx.drawRadialGradient(degrade([lueurCoeur.cg(0.95), lueurMilieu.cg(0.6), lueurBord.cg(0)], [0, 0.5, 1]),
                               startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: demiLargeur, options: [])
        ctx.restoreGState()
        ctx.addPath(dos)
        ctx.setFillColor(bleuProfond.cg(0.75))
        ctx.fillPath()
        ctx.restoreGState()

        // Le devant, d'une pièce avec un rebord, dans la silhouette : le bord
        // de l'œuf est une courbe, pas des bouts de rubans.
        let piece = CGMutablePath()
        piece.addPath(devant)
        piece.addPath(silhouette().copy(strokingWithWidth: treillis.largeur * 1.3, lineCap: .round, lineJoin: .round,
                                        miterLimit: 10))
        ctx.saveGState()
        ctx.addPath(silhouette())
        ctx.clip()
        ctx.addPath(piece)
        ctx.setStrokeColor(contour.cg())
        ctx.setLineWidth(trait * 2)
        ctx.strokePath()
        eclairer(piece, in: ctx)
        ctx.restoreGState()
        ctx.addPath(silhouette())
        ctx.setStrokeColor(contour.cg())
        ctx.setLineWidth(trait * 2)
        ctx.strokePath()
        fleuron(treillis, trait: trait, in: ctx)
    }

    /// Le fleuron où les rubans se rejoignent, posé sur la pointe.
    private static func fleuron(_ treillis: Treillis, trait: Double, in ctx: CGContext) {
        let largeur = treillis.largeur * 2.1
        let forme = CGPath(ellipseIn: CGRect(x: centreX - largeur / 2, y: pointe - largeur * 0.22, width: largeur,
                                             height: largeur * 0.62), transform: nil)
        ctx.addPath(forme)
        ctx.setStrokeColor(contour.cg())
        ctx.setLineWidth(trait * 2)
        ctx.strokePath()
        ctx.saveGState()
        ctx.addPath(forme)
        ctx.clip()
        let haut = CGPoint(x: centreX - largeur * 0.2, y: pointe - largeur * 0.2)
        ctx.drawRadialGradient(degrade([blanc.cg(), bleu.cg(), bleuOmbre.cg()], [0, 0.6, 1]), startCenter: haut, startRadius: 0,
                               endCenter: haut, endRadius: largeur * 0.75, options: [.drawsAfterEndLocation])
        ctx.restoreGState()
    }

    /// La lumière d'en haut à gauche, le galbe plus sombre vers le bord, un reflet.
    private static func eclairer(_ piece: CGPath, in ctx: CGContext) {
        ctx.saveGState()
        ctx.addPath(piece)
        ctx.clip()
        ctx.drawLinearGradient(degrade([blanc.cg(), blanc.melange(bleu, 0.45).cg(), bleu.cg()], [0, 0.55, 1]),
                               start: CGPoint(x: centreX - 220, y: pointe + 40), end: CGPoint(x: centreX + 200, y: base),
                               options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        let galbe = CGPoint(x: centreX - 40, y: hauteur(-0.1))
        ctx.drawRadialGradient(degrade([bleuOmbre.cg(0), bleuOmbre.cg(0), bleuOmbre.cg(0.55)], [0, 0.62, 1]),
                               startCenter: galbe, startRadius: 0, endCenter: galbe, endRadius: demiLargeur * 1.25,
                               options: [.drawsAfterEndLocation])
        // Le biseau : chaque ruban a une arête claire en haut à gauche, une
        // ombre en bas à droite — la matière d'un treillis imprimé.
        biseau(piece, decalage: CGSize(width: 7, height: 9), couleur: blanc.cg(0.85), in: ctx)
        biseau(piece, decalage: CGSize(width: -6, height: -8), couleur: bleuOmbre.cg(0.7), in: ctx)
        ctx.addEllipse(in: CGRect(x: centreX - demiLargeur * 0.78, y: hauteur(-0.78),
                                  width: demiLargeur * 0.62, height: (base - pointe) * 0.42))
        ctx.setFillColor(blanc.cg(0.3))
        ctx.fillPath()
        ctx.restoreGState()
    }

    /// Peint la part de `piece` que la même pièce décalée ne couvre pas : une
    /// arête du côté opposé au décalage. À appeler dans le détourage de
    /// `piece`. La pièce décalée s'efface dans un calque, en remplissage plein :
    /// un pair-impair compterait deux fois les croisements des rubans.
    private static func biseau(_ piece: CGPath, decalage: CGSize, couleur: CGColor, in ctx: CGContext) {
        var deplacement = CGAffineTransform(translationX: decalage.width, y: decalage.height)
        guard let decalee = piece.copy(using: &deplacement) else { return }
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(couleur)
        ctx.fill(CGRect(x: 0, y: 0, width: cote, height: cote))
        ctx.setBlendMode(.destinationOut)
        ctx.addPath(decalee)
        ctx.setFillColor(SynfusRGB(hex: 0).cg())
        ctx.fillPath()
        ctx.endTransparencyLayer()
    }

    // MARK: - Glyphe

    /// Deux feuilles trapues : les longues de l'icône s'effilochent à 18 pt.
    private static let feuillesDuGlyphe = [-2.84, -0.30].map {
        Feuille(base: CGPoint(x: centreX, y: 872), angle: $0, longueur: 330, largeur: 100, ombre: 0)
    }

    /// La marque en silhouette, pour une image *template* : seule l'opacité
    /// compte. À 18 pt, le volume ne se lit plus : un rebord, des rubans
    /// ondés vus de face qui se croisent en jours, deux feuilles au pied,
    /// détourées de l'œuf par un jour effacé dans l'alpha, jamais peint.
    static func dessinerGlyphe(in ctx: CGContext) {
        let rebord = 66.0, ruban = 64.0, ecart = 180.0
        ctx.setFillColor(SynfusRGB(hex: 0).cg())
        ctx.setLineJoin(.round)
        for feuille in feuillesDuGlyphe { ctx.addPath(chemin(feuille)) }
        ctx.fillPath()
        ctx.setBlendMode(.clear)
        ctx.addPath(silhouette())
        // Le rebord est dans la silhouette : le jour qui le détoure, au-dehors.
        ctx.setLineWidth(84)
        ctx.strokePath()
        ctx.setBlendMode(.normal)
        ctx.saveGState()
        ctx.addPath(silhouette())
        ctx.clip()
        ctx.addPath(silhouette())
        ctx.setLineWidth(rebord * 2)
        ctx.strokePath()
        // Les rubans suivent la largeur de l'œuf : ils se resserrent aux pôles.
        let rubans = CGMutablePath()
        for famille in [-1.0, 1.0] {
            for colonne in -3...3 {
                let points = stride(from: -0.99, through: 0.99, by: 0.01).map { u -> (point: CGPoint, demi: Double) in
                    let x = (Double(colonne) * ecart + famille * ecart / 2 * sin(1.6 * .pi * (u + 1) / 2)) * rayon(u) / demiLargeur
                    return (CGPoint(x: centreX + x, y: hauteur(u)), ruban / 2)
                }
                if let chemin = self.ruban(points) { rubans.addPath(chemin) }
            }
        }
        ctx.addPath(rubans)
        ctx.fillPath()
        ctx.restoreGState()
    }
}
