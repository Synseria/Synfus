import SwiftUI

/// L'échelle de texte de Synfus. `marque` sert aux initiales, numéros et petits
/// symboles, jamais à un texte qu'on lit : aucun texte ne descend sous `petit`.
enum TailleTexte: CGFloat, Comparable, Sendable {
    case marque = 9
    case petit = 11
    case note = 12
    case corps = 13
    case titre = 15
    case grand = 20

    static func < (gauche: TailleTexte, droite: TailleTexte) -> Bool { gauche.rawValue < droite.rawValue }
}

extension Font {
    /// La seule voie vers une police de vue. `gras` est l'unique graisse au-dessus
    /// de la normale : deux graisses voisines se liraient comme une erreur.
    static func synfus(_ taille: TailleTexte, gras: Bool = false, design: Font.Design = .default) -> Font {
        .system(size: taille.rawValue, weight: gras ? .semibold : .regular, design: design)
    }
}

extension View {
    /// À poser sur la racine de chaque fenêtre : sans elle, un contrôle du
    /// système y prend l'accent de l'utilisateur.
    func racineSynfus() -> some View { tint(Couleurs.accentTexte) }

    /// Le texte d'un bouton sans texte : l'infobulle, et son nom pour VoiceOver,
    /// que `.help` ne donne pas.
    func aide(_ texte: String) -> some View { help(texte).accessibilityLabel(texte) }
}
