import SwiftUI

extension Jetons.Typo: Equatable {
    static func == (gauche: Self, droite: Self) -> Bool {
        gauche.taille == droite.taille && gauche.interligne == droite.interligne && gauche.graisse == droite.graisse
            && gauche.famille == droite.famille && gauche.chiffresFixes == droite.chiffresFixes
    }
}

extension Font {
    /// La seule voie vers une police de vue : un rôle de `Jetons.Typo` (titrePage, titre, corps,
    /// corpsFort, note, petit, micro, chiffre, grandChiffre, raccourci). `gras` passe la graisse
    /// du rôle à semibold, l'unique graisse au-dessus de la normale ; `design` remplace le dessin
    /// du rôle (monospace d'une valeur à copier).
    static func synfus(_ role: Jetons.Typo, gras: Bool = false, design: Font.Design? = nil) -> Font {
        guard gras || design != nil else { return role.police }
        let dessin: Font.Design = design ?? (role.famille == .titre ? .rounded : .default)
        let police = Font.system(size: role.taille, weight: gras ? .semibold : role.graisse, design: dessin)
        return role.chiffresFixes ? police.monospacedDigit() : police
    }
}

/// À poser sur la racine de chaque fenêtre : sans elle, un contrôle du système y prend l'accent
/// de l'utilisateur. Un `ViewModifier`, pour que la teinte suive la couleur choisie.
struct RacineSynfus: ViewModifier {
    func body(content: Content) -> some View { content.tint(Couleurs.primaire) }
}

extension View {
    func racineSynfus() -> some View { modifier(RacineSynfus()) }

    /// Le texte d'un bouton sans texte : l'infobulle, et son nom pour VoiceOver,
    /// que `.help` ne donne pas.
    func aide(_ texte: String) -> some View { help(texte).accessibilityLabel(texte) }
}
