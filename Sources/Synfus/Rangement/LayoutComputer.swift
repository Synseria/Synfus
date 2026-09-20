import CoreGraphics
import Foundation

/// Une disposition de rangement des fenêtres. `Codable` : la dernière employée
/// est persistée, c'est elle que rejoue le raccourci global.
enum Disposition: String, Codable, CaseIterable, Identifiable {
    /// Colonnes égales, pleine hauteur.
    case coteACote
    /// Grille approximativement carrée, dernière rangée alignée à gauche.
    case mosaique
    /// Le perso au premier plan en grand, les autres en colonne de vignettes.
    case principale
    /// Toutes les fenêtres plein cadre, empilées : chacun occupe tout l'écran,
    /// la barre et les raccourcis font tourner la pile. Le grand écran du
    /// multi-compte, sans passer par les espaces plein écran.
    case empilee

    var id: String { rawValue }

    var label: String {
        switch self {
        case .coteACote: L("rangement.coteACote")
        case .mosaique: L("rangement.mosaique")
        case .principale: L("rangement.principale")
        case .empilee: L("rangement.empilee")
        }
    }

    var symbolName: String {
        switch self {
        case .coteACote: "rectangle.split.2x1"
        case .mosaique: "square.grid.2x2"
        case .principale: "rectangle.leadinghalf.inset.filled"
        case .empilee: "square.stack"
        }
    }
}

/// Calcule les cadres d'une disposition. **Pure** : elle ne lit ni écran ni
/// fenêtre, on la nourrit d'une zone et d'un nombre — d'où sa testabilité,
/// sur le modèle de `BounceDetector` et `computeVisibility`. Tout ce qui
/// touche l'Accessibilité vit dans `WindowArranger`.
enum LayoutComputer {
    /// Espace entre deux fenêtres, et rien d'autre : la zone reçue est déjà
    /// le `visibleFrame`, ses marges ne nous regardent pas.
    static let espacement: CGFloat = 8

    /// Largeur minimale de la colonne de vignettes de `.principale` — en deçà,
    /// une fenêtre de jeu n'est plus qu'une bande illisible.
    static let colonneMinimale: CGFloat = 260

    /// Grille approximativement carrée : autant de colonnes que la racine
    /// l'exige, autant de lignes qu'il en faut pour loger tout le monde.
    static func dimensionsGrille(nombre: Int) -> (colonnes: Int, lignes: Int) {
        guard nombre > 0 else { return (0, 0) }
        let colonnes = Int(ceil(Double(nombre).squareRoot()))
        let lignes = Int(ceil(Double(nombre) / Double(colonnes)))
        return (colonnes, lignes)
    }

    /// Les cadres de la disposition dans `zone`, exprimés dans le même repère
    /// qu'elle — en pratique le repère AX, y vers le bas. `cadres[i]` revient à
    /// la i-ème fenêtre, dans l'ordre de la barre. `indexPrincipal` ne joue que
    /// pour `.principale`, et se serre aux bornes s'il en sort.
    static func cadres(
        _ disposition: Disposition,
        nombre: Int,
        indexPrincipal: Int = 0,
        dans zone: CGRect,
        espacement: CGFloat = espacement
    ) -> [CGRect] {
        guard nombre > 0 else { return [] }
        guard nombre > 1 else { return [zone] }

        switch disposition {
        // La seule disposition où les cadres se recouvrent, par définition —
        // tout le monde reçoit la zone entière.
        case .empilee:
            return Array(repeating: zone, count: nombre)

        case .coteACote:
            let largeur = (zone.width - CGFloat(nombre - 1) * espacement) / CGFloat(nombre)
            return (0..<nombre).map { index in
                CGRect(x: zone.minX + CGFloat(index) * (largeur + espacement),
                       y: zone.minY, width: largeur, height: zone.height)
            }

        case .mosaique:
            let (colonnes, lignes) = dimensionsGrille(nombre: nombre)
            let largeur = (zone.width - CGFloat(colonnes - 1) * espacement) / CGFloat(colonnes)
            let hauteur = (zone.height - CGFloat(lignes - 1) * espacement) / CGFloat(lignes)
            return (0..<nombre).map { index in
                let colonne = index % colonnes
                let ligne = index / colonnes
                return CGRect(x: zone.minX + CGFloat(colonne) * (largeur + espacement),
                              y: zone.minY + CGFloat(ligne) * (hauteur + espacement),
                              width: largeur, height: hauteur)
            }

        case .principale:
            let principal = min(max(indexPrincipal, 0), nombre - 1)
            let colonne = max(colonneMinimale, zone.width * 0.22)
            let grand = CGRect(x: zone.minX, y: zone.minY,
                               width: zone.width - colonne - espacement,
                               height: zone.height)
            let vignettes = nombre - 1
            let hauteur = (zone.height - CGFloat(vignettes - 1) * espacement) / CGFloat(vignettes)
            var rang = 0
            return (0..<nombre).map { index in
                if index == principal { return grand }
                defer { rang += 1 }
                return CGRect(x: grand.maxX + espacement,
                              y: zone.minY + CGFloat(rang) * (hauteur + espacement),
                              width: colonne, height: hauteur)
            }
        }
    }

    /// `visibleFrame` Cocoa (origine en bas à gauche de l'écran principal,
    /// y vers le haut) → repère AX (origine en haut à gauche de l'écran
    /// principal, y vers le bas). `hauteurPrincipale` est la hauteur du cadre
    /// **complet** de l'écran principal, `NSScreen.screens[0].frame.height`.
    static func zoneAX(visibleFrame: CGRect, hauteurPrincipale: CGFloat) -> CGRect {
        CGRect(x: visibleFrame.minX,
               y: hauteurPrincipale - visibleFrame.maxY,
               width: visibleFrame.width,
               height: visibleFrame.height)
    }
}
