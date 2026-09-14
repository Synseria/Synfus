import SwiftUI

/// Habillage visuel d'une classe de perso.
///
/// L'icône du Dock ne peut pas servir de repère : tous les clients partagent le
/// même bundle `Dofus.app`, donc la même icône. La classe, elle, est lisible
/// dans le titre de la fenêtre — on lui associe ici une couleur stable, que
/// chacun peut remplacer par l'image de son choix (voir `ClassIconStore`).
enum DofusClass {

    /// Une classe du jeu.
    struct Breed: Identifiable, Hashable {
        /// Clé sans accent ni majuscule : celle sous laquelle le titre de fenêtre
        /// est retrouvé, et sous laquelle l'icône est rangée sur le disque.
        let key: String
        let label: String
        let color: Color

        var id: String { key }
    }

    /// Les 19 classes, dans l'ordre du jeu. Couleurs choisies pour rester
    /// distinctes les unes des autres, en clair comme en sombre.
    ///
    /// Cette liste est la seule source : y ajouter une classe la fait apparaître
    /// d'office dans les réglages comme dans la barre.
    static let breeds: [Breed] = [
        Breed(key: "feca",       label: "Féca",       color: Color(red: 0.36, green: 0.62, blue: 0.86)),
        Breed(key: "osamodas",   label: "Osamodas",   color: Color(red: 0.42, green: 0.70, blue: 0.42)),
        Breed(key: "enutrof",    label: "Enutrof",    color: Color(red: 0.85, green: 0.68, blue: 0.24)),
        Breed(key: "sram",       label: "Sram",       color: Color(red: 0.45, green: 0.42, blue: 0.62)),
        Breed(key: "xelor",      label: "Xélor",      color: Color(red: 0.30, green: 0.56, blue: 0.68)),
        Breed(key: "ecaflip",    label: "Ecaflip",    color: Color(red: 0.86, green: 0.42, blue: 0.36)),
        Breed(key: "eniripsa",   label: "Eniripsa",   color: Color(red: 0.92, green: 0.60, blue: 0.72)),
        Breed(key: "iop",        label: "Iop",        color: Color(red: 0.84, green: 0.30, blue: 0.28)),
        Breed(key: "cra",        label: "Crâ",        color: Color(red: 0.52, green: 0.72, blue: 0.34)),
        Breed(key: "sadida",     label: "Sadida",     color: Color(red: 0.36, green: 0.66, blue: 0.52)),
        Breed(key: "sacrieur",   label: "Sacrieur",   color: Color(red: 0.72, green: 0.24, blue: 0.34)),
        Breed(key: "pandawa",    label: "Pandawa",    color: Color(red: 0.56, green: 0.50, blue: 0.44)),
        Breed(key: "roublard",   label: "Roublard",   color: Color(red: 0.40, green: 0.48, blue: 0.56)),
        Breed(key: "zobal",      label: "Zobal",      color: Color(red: 0.78, green: 0.52, blue: 0.28)),
        Breed(key: "steamer",    label: "Steamer",    color: Color(red: 0.30, green: 0.64, blue: 0.64)),
        Breed(key: "eliotrope",  label: "Eliotrope",  color: Color(red: 0.62, green: 0.42, blue: 0.78)),
        Breed(key: "huppermage", label: "Huppermage", color: Color(red: 0.48, green: 0.38, blue: 0.80)),
        Breed(key: "ouginak",    label: "Ouginak",    color: Color(red: 0.66, green: 0.46, blue: 0.32)),
        Breed(key: "forgelance", label: "Forgelance", color: Color(red: 0.34, green: 0.52, blue: 0.74)),
    ]

    private static let index: [String: Breed] = Dictionary(
        uniqueKeysWithValues: breeds.map { ($0.key, $0) }
    )

    /// Retire les accents pour que « Crâ » retrouve son entrée « cra ».
    static func key(for className: String?) -> String? {
        guard let className else { return nil }
        let key = className
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
        return key.isEmpty ? nil : key
    }

    static func color(for className: String?) -> Color {
        guard let key = key(for: className) else { return .secondary }
        if let known = index[key] { return known.color }

        // Classe inconnue (ajout d'une future classe, titre inattendu) : on
        // dérive une teinte stable du nom plutôt que de tout afficher en gris.
        let hash = key.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.5, brightness: 0.72)
    }

    /// Abréviation affichée dans la pastille, faute d'icône.
    static func abbreviation(for className: String?) -> String {
        guard let key = key(for: className) else { return "?" }
        return String(key.prefix(2)).capitalized
    }
}
