import SwiftUI

/// Habillage visuel d'une classe de perso.
///
/// L'icône du Dock ne peut pas servir de repère : tous les clients partagent le
/// même bundle `Dofus.app`, donc la même icône. La classe, elle, est lisible
/// dans le titre de la fenêtre — on lui associe ici une couleur stable, qui
/// donne à la barre un repère identifiable d'un coup d'œil.
enum DofusClass {

    /// Couleurs choisies pour rester distinctes les unes des autres, en clair
    /// comme en sombre.
    private static let palette: [String: Color] = [
        "feca":       Color(red: 0.36, green: 0.62, blue: 0.86),
        "osamodas":   Color(red: 0.42, green: 0.70, blue: 0.42),
        "enutrof":    Color(red: 0.85, green: 0.68, blue: 0.24),
        "sram":       Color(red: 0.45, green: 0.42, blue: 0.62),
        "xelor":      Color(red: 0.30, green: 0.56, blue: 0.68),
        "ecaflip":    Color(red: 0.86, green: 0.42, blue: 0.36),
        "eniripsa":   Color(red: 0.92, green: 0.60, blue: 0.72),
        "iop":        Color(red: 0.84, green: 0.30, blue: 0.28),
        "cra":        Color(red: 0.52, green: 0.72, blue: 0.34),
        "sadida":     Color(red: 0.36, green: 0.66, blue: 0.52),
        "sacrieur":   Color(red: 0.72, green: 0.24, blue: 0.34),
        "pandawa":    Color(red: 0.56, green: 0.50, blue: 0.44),
        "roublard":   Color(red: 0.40, green: 0.48, blue: 0.56),
        "zobal":      Color(red: 0.78, green: 0.52, blue: 0.28),
        "steamer":    Color(red: 0.30, green: 0.64, blue: 0.64),
        "eliotrope":  Color(red: 0.62, green: 0.42, blue: 0.78),
        "huppermage": Color(red: 0.48, green: 0.38, blue: 0.80),
        "ouginak":    Color(red: 0.66, green: 0.46, blue: 0.32),
        "forgelance": Color(red: 0.34, green: 0.52, blue: 0.74),
    ]

    /// Retire les accents pour que « Crâ » retrouve son entrée « cra ».
    private static func normalize(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
    }

    static func color(for className: String?) -> Color {
        guard let className else { return .secondary }
        let key = normalize(className)
        if let known = palette[key] { return known }

        // Classe inconnue (ajout d'une future classe, titre inattendu) : on
        // dérive une teinte stable du nom plutôt que de tout afficher en gris.
        let hash = key.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.5, brightness: 0.72)
    }

    /// Abréviation affichée dans la pastille.
    static func abbreviation(for className: String?) -> String {
        guard let className, !className.isEmpty else { return "?" }
        return String(normalize(className).prefix(2)).capitalized
    }
}
