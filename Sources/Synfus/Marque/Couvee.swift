import CoreGraphics
import Foundation

/// La Couvée, l'autre motif de l'icône (`IconeApp.Motif.couvee`) : trois œufs
/// de dragon, l'émeraude écaillé devant, la turquoise mouchetée et le pourpre
/// ondé derrière. Contour unique sombre, volume par dégradé, peau ton sur ton,
/// brillance en croissant ; tracés originaux, aucun asset d'Ankama.
///
/// Sans fond : `SynfusMark.image` la pose sur la tuile. Repère **256 × 256, y vers le bas**.
enum Couvee {

    /// Ce que la couvée occupe, contours et ombre compris.
    static let cadre = CGRect(x: 12, y: 37, width: 232, height: 197)

    /// Aspect d'un œuf : plus large, il tourne au galet ; plus étroit, à l'œuf de poule.
    private static let aspect: Double = 176.0 / 228.0

    /// Un trait sous ce nombre de pixels du rendu final s'étale en gris sale.
    private static let traitMinimalPixels: Double = 1.7

    /// Sous cette taille du repère en pixels, les peaux ne survivent pas à la
    /// réduction : corps, brillance et contours portent seuls le motif.
    private static let peauxDes: Double = 80

    // MARK: - Palette

    private static let contour = SynfusRGB(hex: 0x1A1410)
    private static let brillance = SynfusRGB(hex: 0xFFFFFF)

    private static let emeraudeHaut = SynfusRGB(hex: 0x7ED67F)
    private static let emeraudeMilieu = SynfusRGB(hex: 0x3FA65C)
    private static let emeraudeBas = SynfusRGB(hex: 0x1C6E38)
    private static let ecailleSombre = SynfusRGB(hex: 0x155A2E)
    private static let ecailleClaire = SynfusRGB(hex: 0x9FE8A6)
    private static let emeraudeVentre = SynfusRGB(hex: 0x124424)

    private static let turquoiseHaut = SynfusRGB(hex: 0x58C4D4)
    private static let turquoiseBas = SynfusRGB(hex: 0x16758F)
    private static let moucheture = SynfusRGB(hex: 0x0C556C)
    private static let mouchetureCoeur = SynfusRGB(hex: 0x6FD4E2)
    private static let turquoiseVentre = SynfusRGB(hex: 0x0B4A5E)

    private static let pourpreHaut = SynfusRGB(hex: 0xE86A63)
    private static let pourpreBas = SynfusRGB(hex: 0xA31B33)
    private static let ondeSombre = SynfusRGB(hex: 0x7F1029)
    private static let ondeClaire = SynfusRGB(hex: 0xFF9D86)
    private static let pourpreVentre = SynfusRGB(hex: 0x6D0D24)

    // MARK: - Géométrie

    /// Pointe resserrée et haute, ventre très large sous la mi-hauteur, assise lourde.
    private static func oeuf(dans rect: CGRect) -> CGPath {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        let chemin = CGMutablePath()
        chemin.move(to: p(0.5, 0))
        chemin.addCurve(to: p(0, 0.605), control1: p(0.273, 0.018), control2: p(0, 0.246))
        chemin.addCurve(to: p(0.5, 1), control1: p(0, 0.895), control2: p(0.216, 1))
        chemin.addCurve(to: p(1, 0.605), control1: p(0.784, 1), control2: p(1, 0.895))
        chemin.addCurve(to: p(0.5, 0), control1: p(1, 0.246), control2: p(0.727, 0.018))
        chemin.closeSubpath()
        return chemin
    }

    private static func cadreOeuf(centre: CGPoint, largeur: Double) -> CGRect {
        let hauteur = largeur / aspect
        return CGRect(x: centre.x - largeur / 2, y: centre.y - hauteur / 2, width: largeur, height: hauteur)
    }

    private static let devant = cadreOeuf(centre: CGPoint(x: 128, y: 132), largeur: 137.3)
    private static let gauche = cadreOeuf(centre: CGPoint(x: 62, y: 112), largeur: 88)
    private static let droite = cadreOeuf(centre: CGPoint(x: 194, y: 112), largeur: 88)

    // MARK: - Rendu

    private enum Peau { case ecailles, mouchetures, ondes }

    /// L'habit d'un œuf : dégradé du corps, ombre du ventre, force de la brillance, peau.
    private struct Robe {
        let corps: [SynfusRGB]
        let arrets: [CGFloat]
        let ventre: SynfusRGB
        let eclat: Double
        let peau: Peau
    }

    private static let turquoise = Robe(corps: [turquoiseHaut, turquoiseBas], arrets: [0, 1], ventre: turquoiseVentre,
                                        eclat: 0.3, peau: .mouchetures)
    private static let pourpre = Robe(corps: [pourpreHaut, pourpreBas], arrets: [0, 1], ventre: pourpreVentre,
                                      eclat: 0.3, peau: .ondes)
    private static let emeraude = Robe(corps: [emeraudeHaut, emeraudeMilieu, emeraudeBas], arrets: [0, 0.5, 1],
                                       ventre: emeraudeVentre, eclat: 0.34, peau: .ecailles)

    /// Peint la couvée dans son repère déjà installé ; `pixels` : la taille du
    /// repère dans le rendu final, qui borne l'épaisseur des traits.
    static func dessiner(pixels: Double, in ctx: CGContext) {
        let echelle = pixels / 256
        let peaux = pixels >= peauxDes
        ctx.setFillColor(SynfusRGB(hex: 0).cg(0.38))
        ctx.fillEllipse(in: CGRect(x: 20, y: 207, width: 216, height: 26))
        for (rect, robe) in [(gauche, turquoise), (droite, pourpre), (devant, emeraude)] {
            dessinerOeuf(dans: rect, robe: robe, echelle: echelle, peau: peaux, in: ctx)
        }
    }

    /// Corps en dégradé, peau, ombre du ventre, brillance, contour.
    private static func dessinerOeuf(dans rect: CGRect, robe: Robe, echelle: Double, peau: Bool, in ctx: CGContext) {
        let forme = oeuf(dans: rect)
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        // Les cotes des peaux sont données pour un œuf de 176 de large.
        let u = rect.width / 176
        let trait = { (nominal: Double) in max(nominal * u, traitMinimalPixels / echelle) }

        ctx.saveGState()
        ctx.addPath(forme)
        ctx.clip()
        ctx.drawLinearGradient(SynfusMark.degrade(robe.corps.map { $0.cg() }, robe.arrets), start: p(0, 0), end: p(0.6, 1),
                               options: [])
        switch peau ? robe.peau : nil {
        case .ecailles: ecailles(dans: rect, trait: trait, in: ctx)
        case .mouchetures: mouchetures(dans: rect, in: ctx)
        case .ondes: ondes(dans: rect, trait: trait, in: ctx)
        case nil: break
        }
        // L'assise s'enfonce dans la pénombre.
        let ombre = CGMutablePath()
        ombre.move(to: p(0, 0.754))
        ombre.addCurve(to: p(1, 0.754), control1: p(0.25, 0.877), control2: p(0.75, 0.877))
        ombre.addLine(to: p(1, 1.05))
        ombre.addLine(to: p(0, 1.05))
        ombre.closeSubpath()
        ctx.addPath(ombre)
        ctx.setFillColor(robe.ventre.cg(0.55))
        ctx.fillPath()
        ctx.restoreGState()

        let croissant = CGMutablePath()
        croissant.move(to: p(0.239, 0.175))
        croissant.addCurve(to: p(0.653, 0.053), control1: p(0.33, 0.07), control2: p(0.511, 0.026))
        croissant.addCurve(to: p(0.295, 0.276), control1: p(0.523, 0.083), control2: p(0.364, 0.154))
        croissant.addCurve(to: p(0.239, 0.175), control1: p(0.261, 0.241), control2: p(0.239, 0.206))
        croissant.closeSubpath()
        ctx.addPath(croissant)
        ctx.setFillColor(brillance.cg(robe.eclat))
        ctx.fillPath()

        ctx.addPath(forme)
        ctx.setLineWidth(trait(12))
        ctx.setStrokeColor(contour.cg())
        ctx.strokePath()
    }

    /// Écailles en quinconce : le creux sombre, et le liseré de lumière que
    /// chaque rangée pose sur la précédente.
    private static func ecailles(dans rect: CGRect, trait: (Double) -> Double, in ctx: CGContext) {
        let u = rect.width / 176
        let pas = 40 * u, demiRangee = 14.5 * u, creux = 24 * u
        func arcs(decalage: Double) -> CGPath {
            let chemin = CGMutablePath()
            var rangee = 0
            var y = rect.minY + decalage
            while y < rect.maxY + demiRangee {
                var x = rect.minX + (rangee.isMultiple(of: 2) ? -pas / 2 : 0) - pas
                while x < rect.maxX + pas {
                    chemin.move(to: CGPoint(x: x, y: y))
                    chemin.addCurve(to: CGPoint(x: x + pas, y: y), control1: CGPoint(x: x, y: y + creux),
                                    control2: CGPoint(x: x + pas, y: y + creux))
                    x += pas
                }
                rangee += 1
                y += demiRangee
            }
            return chemin
        }
        ctx.setLineCap(.round)
        ctx.addPath(arcs(decalage: -3 * u))
        ctx.setLineWidth(trait(2.4))
        ctx.setStrokeColor(ecailleClaire.cg(0.38))
        ctx.strokePath()
        ctx.addPath(arcs(decalage: 0))
        ctx.setLineWidth(trait(5))
        ctx.setStrokeColor(ecailleSombre.cg())
        ctx.strokePath()
    }

    /// Tache sombre, cœur clair décentré : un caillou poli.
    private static func mouchetures(dans rect: CGRect, in ctx: CGContext) {
        let u = rect.width / 176
        let pasX = 52 * u, pasY = 44 * u
        var y = rect.minY
        while y < rect.maxY + pasY {
            var x = rect.minX - pasX
            while x < rect.maxX + pasX {
                for (dx, dy, rayon) in [(12.0, 12.0, 8.0), (38, 32, 5.5)] {
                    let centre = CGPoint(x: x + dx * u, y: y + dy * u)
                    let r = rayon * u
                    ctx.setFillColor(moucheture.cg())
                    ctx.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
                    ctx.setFillColor(mouchetureCoeur.cg(0.5))
                    ctx.fillEllipse(in: CGRect(x: centre.x - 1.5 * u - r / 2, y: centre.y - 1.5 * u - r / 2, width: r, height: r))
                }
                x += pasX
            }
            y += pasY
        }
    }

    /// Ondes embossées : l'arête claire au-dessus, le creux sombre dessous.
    private static func ondes(dans rect: CGRect, trait: (Double) -> Double, in ctx: CGContext) {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height) }
        let traces: [(a: (Double, Double), c1: (Double, Double), c2: (Double, Double), b: (Double, Double))] = [
            ((0, 0.351), (0.261, 0.254), (0.739, 0.254), (1, 0.351)),
            ((0, 0.544), (0.261, 0.456), (0.739, 0.456), (1, 0.544)),
            ((0.034, 0.737), (0.284, 0.649), (0.716, 0.649), (0.966, 0.737)),
        ]
        ctx.setLineCap(.round)
        for onde in traces {
            for (decalage, largeur, couleur) in [(-0.0175, 3.0, ondeClaire.cg(0.45)), (0, 8, ondeSombre.cg())] {
                ctx.move(to: p(onde.a.0, onde.a.1 + decalage))
                ctx.addCurve(to: p(onde.b.0, onde.b.1 + decalage), control1: p(onde.c1.0, onde.c1.1 + decalage),
                             control2: p(onde.c2.0, onde.c2.1 + decalage))
                ctx.setLineWidth(trait(largeur))
                ctx.setStrokeColor(couleur)
                ctx.strokePath()
            }
        }
    }
}
