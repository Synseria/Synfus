import AppKit
import SwiftUI

/// La marque réduite à sa silhouette : la couvée en aplat, l'œuf de tête
/// détouré de ses deux acolytes par un mince jour.
///
/// La géométrie vient de [SynfusMark](Sources/Synfus/SynfusMark.swift) — un seul
/// dessin sert l'icône du bundle et la barre de menus. Ce qui change ici tient à
/// la taille de lecture :
///
/// - **Monochrome.** Dans la barre de menus, macOS attend une image *template*
///   qu'il teint selon le thème et inverse quand le menu est ouvert. Seule
///   l'opacité compte : le jour entre les œufs doit être **transparent**, pas
///   peint — d'où le détourage par effacement plutôt qu'un trait de couleur.
/// - **Aucune peau.** Écailles, mouchetures et ondes ne survivraient pas à
///   18 px ; la matière reste sur l'icône, la barre de menus n'a que la forme.
enum SynfusGlyph {

    /// Cotes de la maquette du glyphe : les trois œufs serrés, cadrés au plus
    /// juste. Tout est exprimé pour une hauteur de référence de 164.
    private static let hauteurReference: CGFloat = 164.16
    private static let largeurReference: CGFloat = 175.52
    private static let cadreAvant = CGRect(x: 24.4, y: 0, width: 126.72, height: 164.16)
    private static let cadreGauche = CGRect(x: 0, y: 0.8, width: 91.52, height: 118.56)
    private static let cadreDroit = CGRect(x: 84.0, y: 0.8, width: 91.52, height: 118.56)
    /// Le jour qui détoure l'œuf de tête, en épaisseur de trait.
    private static let jour: CGFloat = 18.72

    /// Proportions du rectangle englobant de la couvée.
    static let ratio: CGFloat = largeurReference / hauteurReference

    private static func scaled(_ rect: CGRect, _ k: CGFloat) -> CGRect {
        CGRect(x: rect.minX * k, y: rect.minY * k,
               width: rect.width * k, height: rect.height * k)
    }

    // MARK: - Barre de menus

    /// Image *template* pour le `NSStatusItem`. `isTemplate` laisse macOS la
    /// teindre : seule l'opacité compte, la couleur qu'on y met est ignorée.
    static func menuBarImage(hauteur: CGFloat = 18) -> NSImage {
        let k = hauteur / hauteurReference
        let taille = NSSize(width: (largeurReference * k).rounded(), height: hauteur)

        let image = NSImage(size: taille, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.setFillColor(NSColor.black.cgColor)

            // Les deux du fond…
            ctx.addPath(SynfusMark.dragonEgg(in: scaled(cadreGauche, k)))
            ctx.addPath(SynfusMark.dragonEgg(in: scaled(cadreDroit, k)))
            ctx.fillPath()

            // …le jour, effacé dans l'alpha…
            ctx.setBlendMode(.clear)
            ctx.addPath(SynfusMark.dragonEgg(in: scaled(cadreAvant, k)))
            ctx.setLineWidth(jour * k)
            ctx.strokePath()
            ctx.setBlendMode(.normal)

            // …puis l'œuf de tête.
            ctx.addPath(SynfusMark.dragonEgg(in: scaled(cadreAvant, k)))
            ctx.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Le glyphe en vue SwiftUI, teinté par le style courant.
///
/// Sans usage depuis que la poignée de la barre flottante est redevenue un grip
/// de points. Conservée : c'est la seule version SwiftUI du dessin, et le
/// prochain endroit qui voudra signer l'interface la reprendra telle quelle.
struct SynfusGlyphView: View {
    var body: some View {
        GeometryReader { geo in
            let k = geo.size.height / 164.16
            let avant = CGRect(x: 24.4 * k, y: 0, width: 126.72 * k, height: 164.16 * k)
            let gauche = CGRect(x: 0, y: 0.8 * k, width: 91.52 * k, height: 118.56 * k)
            let droit = CGRect(x: 84.0 * k, y: 0.8 * k, width: 91.52 * k, height: 118.56 * k)
            ZStack {
                Path(SynfusMark.dragonEgg(in: gauche)).fill()
                Path(SynfusMark.dragonEgg(in: droit)).fill()
                Path(SynfusMark.dragonEgg(in: avant))
                    .stroke(lineWidth: 18.72 * k)
                    .blendMode(.destinationOut)
                Path(SynfusMark.dragonEgg(in: avant)).fill()
            }
            .compositingGroup()
        }
        .aspectRatio(SynfusGlyph.ratio, contentMode: .fit)
    }
}
