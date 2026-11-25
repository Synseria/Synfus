// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// apps/Synfus.json 9a033559a9784ae0 · contenu 6365418f1b15f98e
import SwiftUI
import SynseriaDesign

/// Les valeurs de design propres à Synfus ; le commun vient du paquet SynseriaKit.
extension Jetons {
    // MARK: Tailles — propre à Synfus
    /// écran du jeu derrière les flottants (aperçus)
    static let largeurFenetre: CGFloat = 1280
    /// palette
    static let largeurPalette: CGFloat = 660
    /// panneau des quêtes, à son ouverture
    static let largeurPanneauQuetes: CGFloat = 360
    /// panneau de chasse au trésor
    static let largeurPanneauChasse: CGFloat = 216
    /// panneau d'aide aux boss
    static let largeurPanneauBoss: CGFloat = 252
    /// fenêtre des réglages
    static let largeurReglages: CGFloat = 1120
    /// colonne d'une page de réglages
    static let largeurColonne: CGFloat = 640
    /// vignette d'une carte du jeu ; sa hauteur est hauteur-rangee
    static let largeurVignette: CGFloat = 48

    /// Le thème par défaut de Synfus.
    static let themeParDefaut = Theme(teinte: 260, suivreLeSysteme: true)

    /// Les couleurs propres à Synfus.
    enum Propres {
        static func suggestionSynfus(sombre: Bool) -> RVB { sombre ? RVB(0x9E73F2) : RVB(0x7C4DE0) }
    }
}
