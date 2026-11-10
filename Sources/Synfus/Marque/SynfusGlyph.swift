import AppKit

/// La marque réduite à sa silhouette pour la barre de menus : l'œuf ajouré
/// et ses deux feuilles (`SynfusMark.dessinerGlyphe`), recadrés au plus juste.
///
/// Monochrome : macOS attend une image *template* qu'il teint selon le thème
/// et inverse quand le menu est ouvert. Seule l'opacité compte — les jours
/// du treillis et le détourage de l'œuf sont effacés dans l'alpha.
enum SynfusGlyph {

    /// Image *template* pour le `NSStatusItem`.
    static func menuBarImage(hauteur: CGFloat = 18) -> NSImage {
        let cadre = SynfusMark.cadreGlyphe
        let echelle = hauteur / cadre.height
        let taille = NSSize(width: (cadre.width * echelle).rounded(), height: hauteur)
        let image = NSImage(size: taille, flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: echelle, y: echelle)
            ctx.translateBy(x: -cadre.minX, y: -cadre.minY)
            SynfusMark.dessinerGlyphe(in: ctx)
            return true
        }
        image.isTemplate = true
        return image
    }
}
