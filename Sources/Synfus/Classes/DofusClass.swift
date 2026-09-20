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
        /// Clé sans accent ni majuscule : celle du nom français, sous laquelle
        /// le titre de fenêtre est retrouvé et l'icône rangée sur le disque.
        let key: String
        /// Le nom français — la langue source du dépôt.
        let label: String
        /// Les noms du même perso dans les clients anglais et espagnol. Le
        /// titre de la fenêtre est dans la langue du **jeu**, pas de Synfus :
        /// un client anglais annonce « Rogue », un espagnol « Tymador », et
        /// sans ces alias l'un et l'autre tombaient en classe inconnue.
        let en: String
        let es: String
        let color: Color

        var id: String { key }

        /// Le nom dans une langue de l'interface, par code (« fr », « en »,
        /// « es ») — le français pour tout autre code.
        func nom(langue: String) -> String {
            switch langue {
            case "en": return en
            case "es": return es
            default: return label
            }
        }
    }

    /// Les 19 classes, dans l'ordre du jeu. Couleurs choisies pour rester
    /// distinctes les unes des autres, en clair comme en sombre.
    ///
    /// Cette liste est la seule source : y ajouter une classe la fait apparaître
    /// d'office dans les réglages comme dans la barre.
    static let breeds: [Breed] = [
        Breed(key: "feca",       label: "Féca",       en: "Feca", es: "Feca", color: Color(red: 0.36, green: 0.62, blue: 0.86)),
        Breed(key: "osamodas",   label: "Osamodas",   en: "Osamodas", es: "Osamodas", color: Color(red: 0.42, green: 0.70, blue: 0.42)),
        Breed(key: "enutrof",    label: "Enutrof",    en: "Enutrof", es: "Anutrof", color: Color(red: 0.85, green: 0.68, blue: 0.24)),
        Breed(key: "sram",       label: "Sram",       en: "Sram", es: "Sram", color: Color(red: 0.45, green: 0.42, blue: 0.62)),
        Breed(key: "xelor",      label: "Xélor",      en: "Xelor", es: "Xelor", color: Color(red: 0.30, green: 0.56, blue: 0.68)),
        Breed(key: "ecaflip",    label: "Ecaflip",    en: "Ecaflip", es: "Zurcarák", color: Color(red: 0.86, green: 0.42, blue: 0.36)),
        Breed(key: "eniripsa",   label: "Eniripsa",   en: "Eniripsa", es: "Aniripsa", color: Color(red: 0.92, green: 0.60, blue: 0.72)),
        Breed(key: "iop",        label: "Iop",        en: "Iop", es: "Yopuka", color: Color(red: 0.84, green: 0.30, blue: 0.28)),
        Breed(key: "cra",        label: "Crâ",        en: "Cra", es: "Ocra", color: Color(red: 0.52, green: 0.72, blue: 0.34)),
        Breed(key: "sadida",     label: "Sadida",     en: "Sadida", es: "Sadida", color: Color(red: 0.36, green: 0.66, blue: 0.52)),
        Breed(key: "sacrieur",   label: "Sacrieur",   en: "Sacrier", es: "Sacrógrito", color: Color(red: 0.72, green: 0.24, blue: 0.34)),
        Breed(key: "pandawa",    label: "Pandawa",    en: "Pandawa", es: "Pandawa", color: Color(red: 0.56, green: 0.50, blue: 0.44)),
        Breed(key: "roublard",   label: "Roublard",   en: "Rogue", es: "Tymador", color: Color(red: 0.40, green: 0.48, blue: 0.56)),
        Breed(key: "zobal",      label: "Zobal",      en: "Masqueraider", es: "Zobal", color: Color(red: 0.78, green: 0.52, blue: 0.28)),
        Breed(key: "steamer",    label: "Steamer",    en: "Foggernaut", es: "Steamer", color: Color(red: 0.30, green: 0.64, blue: 0.64)),
        Breed(key: "eliotrope",  label: "Eliotrope",  en: "Eliotrope", es: "Eliotropo", color: Color(red: 0.62, green: 0.42, blue: 0.78)),
        Breed(key: "huppermage", label: "Huppermage", en: "Huppermage", es: "Hipermago", color: Color(red: 0.48, green: 0.38, blue: 0.80)),
        Breed(key: "ouginak",    label: "Ouginak",    en: "Ouginak", es: "Uginak", color: Color(red: 0.66, green: 0.46, blue: 0.32)),
        Breed(key: "forgelance", label: "Forgelance", en: "Forgelance", es: "Forjalanza", color: Color(red: 0.34, green: 0.52, blue: 0.74)),
    ]

    private static let index: [String: Breed] = Dictionary(
        uniqueKeysWithValues: breeds.map { ($0.key, $0) }
    )

    /// La classe connue sous cette clé, s'il y en a une.
    static func breed(forKey key: String) -> Breed? { index[key] }

    /// Nom replié (anglais, espagnol) → clé française. Le français n'y est
    /// pas : son repli **est** la clé.
    private static let alias: [String: String] = Dictionary(
        breeds.flatMap { breed in [breed.en, breed.es].map { (fold($0), breed.key) } }
            .filter { $0.0 != $0.1 },
        uniquingKeysWith: { premier, _ in premier }
    )

    /// Retire les accents pour que « Crâ » retrouve son entrée « cra » — et
    /// ramène un nom anglais ou espagnol à la clé française : « Rogue » et
    /// « Tymador » sont « roublard ». Un nom inconnu est rendu replié tel
    /// quel, pour la couleur dérivée et l'abréviation.
    static func key(for className: String?) -> String? {
        guard let className else { return nil }
        let key = fold(className)
        guard !key.isEmpty else { return nil }
        return alias[key] ?? key
    }

    private static func fold(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespaces)
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
