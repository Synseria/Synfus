import SwiftUI

extension Jetons.Typo: Equatable {
    static func == (gauche: Self, droite: Self) -> Bool {
        gauche.taille == droite.taille && gauche.interligne == droite.interligne && gauche.graisse == droite.graisse
            && gauche.famille == droite.famille && gauche.chiffresFixes == droite.chiffresFixes
    }
}

extension Font {
    /// La seule voie vers une police de vue : un rôle de `Jetons.Typo` (titrePage, titre, corps,
    /// corpsFort, note, petit, micro, chiffre, grandChiffre, code, codeInterface, raccourci). Pas de
    /// graisse ni de dessin à la carte : appuyer un texte, c'est choisir un autre rôle.
    static func synfus(_ role: Jetons.Typo) -> Font { role.police }
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
