import AppKit
import SwiftUI

/// La marque réduite à sa silhouette : l'œuf en contour, les fenêtres pleines.
///
/// La géométrie vient de [SynfusMark](Sources/Synfus/SynfusMark.swift) — un seul
/// dessin sert l'icône du bundle, la barre de menus et la poignée de la barre
/// flottante. Ce qui change ici tient à la taille de lecture :
///
/// - **Monochrome.** Dans la barre de menus, macOS attend une image *template*
///   qu'il teint selon le thème et inverse quand le menu est ouvert. Les couleurs
///   de la marque n'y survivraient pas, et le PNG du bundle — fond opaque — y
///   poserait une vignette sombre.
/// - **Fenêtres pleines et trait épaissi.** Sous 20 px, le contour de 2,5 % de
///   la maquette tombe sous le pixel et ne laisse qu'un gris sale.
enum SynfusGlyph {

    /// Proportions du rectangle englobant de l'œuf.
    static let ratio: CGFloat = 156.0 / 214.0

    /// Épaisseur du contour, en fraction de la hauteur.
    static let epaisseurRelative: CGFloat = 0.075

    static func oeuf(dans rect: CGRect) -> Path {
        Path(SynfusMark.egg(in: rect))
    }

    static func fenetres(dans rect: CGRect) -> Path {
        var path = Path()
        for fenetre in SynfusMark.windows {
            let cadre = SynfusMark.rect(of: fenetre, in: rect)
            let rayon = fenetre.radius * rect.width
            path.addRoundedRect(in: cadre, cornerSize: CGSize(width: rayon, height: rayon))
        }
        return path
    }

    // MARK: - Barre de menus

    /// Image *template* pour le `NSStatusItem`. `isTemplate` laisse macOS la
    /// teindre : seule l'opacité compte, la couleur qu'on y met est ignorée.
    static func menuBarImage(hauteur: CGFloat = 18) -> NSImage {
        let taille = NSSize(width: (hauteur * ratio).rounded(), height: hauteur)

        let image = NSImage(size: taille, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let trait = hauteur * epaisseurRelative
            // Le contour déborde de part et d'autre du tracé : sans cette marge,
            // les flancs de l'œuf seraient rognés par le bord de l'image.
            let cadre = CGRect(origin: .zero, size: taille).insetBy(dx: trait / 2, dy: trait / 2)

            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(trait)
            ctx.addPath(oeuf(dans: cadre).cgPath)
            ctx.strokePath()
            ctx.addPath(fenetres(dans: cadre).cgPath)
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Le glyphe en vue SwiftUI, teinté par le style courant.
struct SynfusGlyphView: View {
    var epaisseur: CGFloat = SynfusGlyph.epaisseurRelative

    var body: some View {
        GeometryReader { geo in
            let trait = geo.size.height * epaisseur
            let cadre = CGRect(origin: .zero, size: geo.size).insetBy(dx: trait / 2, dy: trait / 2)
            ZStack {
                SynfusGlyph.oeuf(dans: cadre).stroke(style: StrokeStyle(lineWidth: trait))
                SynfusGlyph.fenetres(dans: cadre).fill()
            }
        }
        .aspectRatio(SynfusGlyph.ratio, contentMode: .fit)
    }
}
