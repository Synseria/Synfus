import SwiftUI

/// Les classes du jeu : leurs noms, leur couleur, leur emblème.
///
/// L'icône du Dock ne peut pas servir de repère : tous les clients partagent le
/// même bundle `Dofus.app`, donc la même icône. La classe, elle, est lisible
/// dans le titre de la fenêtre — on lui associe une couleur stable et
/// l'emblème de DofusDB, que chacun peut remplacer (voir `ClassesStore`).
enum DofusClass {

    /// Une classe du jeu.
    struct Breed: Identifiable, Hashable, Sendable {
        /// Clé sans accent ni majuscule, tirée du nom français : celle sous
        /// laquelle le titre de fenêtre est retrouvé et l'icône de
        /// l'utilisateur rangée sur le disque. Elle ne change jamais, même si
        /// DofusDB renomme la classe.
        let key: String
        /// Ce qui relie la table intégrée à la liste téléchargée.
        let idDofusDB: Int
        /// Les noms par langue (« fr », « en », « es »).
        let noms: [String: String]
        /// Tous les noms sous lesquels un titre de fenêtre peut l'annoncer : le
        /// titre est dans la langue du **jeu**, pas de Synfus (« Rogue »,
        /// « Tymador »), et un nom que DofusDB a remplacé reste reconnu.
        let alias: Set<String>
        let color: Color
        let embleme: URL?

        var id: String { key }

        /// Le nom français — la langue source du dépôt.
        var label: String { noms["fr"] ?? key }

        /// Le nom dans une langue de l'interface, par code — le français pour
        /// une langue que la classe n'a pas.
        func nom(langue: String) -> String { noms[langue] ?? label }

        var nomLocalise: String { nom(langue: L10n.courante.langue.rawValue) }
    }

    /// D'où vient l'emblème affiché.
    enum Provenance: Equatable {
        /// Posé par l'utilisateur : toujours prioritaire.
        case tienne
        case dofusDB(URL)
    }

    /// Celui de l'utilisateur d'abord, celui de DofusDB ensuite.
    static func provenance(tienne: Bool, embleme: URL?) -> Provenance? {
        if tienne { return .tienne }
        return embleme.map(Provenance.dofusDB)
    }

    /// Les 19 classes, dans l'ordre du jeu, avec leur identifiant DofusDB.
    /// C'est la reconnaissance hors ligne — le premier lancement sans réseau
    /// retrouve chaque classe — et la seule source des couleurs, choisies pour
    /// rester distinctes les unes des autres, en clair comme en sombre.
    /// DofusDB en rafraîchit les noms et y ajoute les classes à venir
    /// (`ClassesDofusDB.catalogue`).
    static let integrees: [Breed] = [
        integree(1, "Féca", en: "Feca", es: "Feca", Color(red: 0.36, green: 0.62, blue: 0.86)),
        integree(2, "Osamodas", en: "Osamodas", es: "Osamodas", Color(red: 0.42, green: 0.70, blue: 0.42)),
        integree(3, "Enutrof", en: "Enutrof", es: "Anutrof", Color(red: 0.85, green: 0.68, blue: 0.24)),
        integree(4, "Sram", en: "Sram", es: "Sram", Color(red: 0.45, green: 0.42, blue: 0.62)),
        integree(5, "Xélor", en: "Xelor", es: "Xelor", Color(red: 0.30, green: 0.56, blue: 0.68)),
        integree(6, "Ecaflip", en: "Ecaflip", es: "Zurcarák", Color(red: 0.86, green: 0.42, blue: 0.36)),
        integree(7, "Eniripsa", en: "Eniripsa", es: "Aniripsa", Color(red: 0.92, green: 0.60, blue: 0.72)),
        integree(8, "Iop", en: "Iop", es: "Yopuka", Color(red: 0.84, green: 0.30, blue: 0.28)),
        integree(9, "Crâ", en: "Cra", es: "Ocra", Color(red: 0.52, green: 0.72, blue: 0.34)),
        integree(10, "Sadida", en: "Sadida", es: "Sadida", Color(red: 0.36, green: 0.66, blue: 0.52)),
        integree(11, "Sacrieur", en: "Sacrier", es: "Sacrógrito", Color(red: 0.72, green: 0.24, blue: 0.34)),
        integree(12, "Pandawa", en: "Pandawa", es: "Pandawa", Color(red: 0.56, green: 0.50, blue: 0.44)),
        integree(13, "Roublard", en: "Rogue", es: "Tymador", Color(red: 0.40, green: 0.48, blue: 0.56)),
        integree(14, "Zobal", en: "Masqueraider", es: "Zobal", Color(red: 0.78, green: 0.52, blue: 0.28)),
        integree(15, "Steamer", en: "Foggernaut", es: "Steamer", Color(red: 0.30, green: 0.64, blue: 0.64)),
        integree(16, "Eliotrope", en: "Eliotrope", es: "Eliotropo", Color(red: 0.62, green: 0.42, blue: 0.78)),
        integree(17, "Huppermage", en: "Huppermage", es: "Hipermago", Color(red: 0.48, green: 0.38, blue: 0.80)),
        integree(18, "Ouginak", en: "Ouginak", es: "Uginak", Color(red: 0.66, green: 0.46, blue: 0.32)),
        integree(20, "Forgelance", en: "Forgelance", es: "Forjalanza", Color(red: 0.34, green: 0.52, blue: 0.74)),
    ]

    private static func integree(_ id: Int, _ fr: String, en: String, es: String, _ color: Color) -> Breed {
        Breed(key: cle(fr) ?? fr, idDofusDB: id, noms: ["fr": fr, "en": en, "es": es],
              alias: [fr, en, es], color: color, embleme: DofusDB.emblemeClasse(id))
    }

    /// Le nom replié sans accent ni casse : « Crâ » devient « cra ». Sans
    /// locale, pour qu'un Mac en turc ne replie pas « Iop » en « ıop ».
    static func cle(_ nom: String) -> String? {
        let cle = nom.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespaces)
        return cle.isEmpty ? nil : cle
    }

    /// Classe inconnue (ajout d'une future classe, titre inattendu) : une
    /// teinte stable dérivée du nom plutôt que tout afficher en gris.
    static func couleurDerivee(_ cle: String) -> Color {
        let hash = cle.unicodeScalars.reduce(UInt32(7)) { ($0 &* 31) &+ $1.value }
        return Color(hue: Double(hash % 360) / 360.0, saturation: 0.5, brightness: 0.72)
    }

    /// Les classes en vigueur et leurs index : ce que lisent la barre, le menu
    /// et les réglages.
    struct Catalogue: Sendable {
        let breeds: [Breed]
        private let index: [String: Breed]
        /// Nom replié, toutes langues → clé.
        private let alias: [String: String]

        init(_ breeds: [Breed]) {
            self.breeds = breeds
            index = Dictionary(breeds.map { ($0.key, $0) }, uniquingKeysWith: { premier, _ in premier })
            alias = Dictionary(
                breeds.flatMap { breed in breed.alias.compactMap(DofusClass.cle).map { ($0, breed.key) } },
                uniquingKeysWith: { premier, _ in premier })
        }

        static let integre = Catalogue(DofusClass.integrees)

        func breed(forKey key: String) -> Breed? { index[key] }

        /// La clé d'un nom de classe lu dans un titre, quelle qu'en soit la
        /// langue : « Rogue » et « Tymador » sont « roublard ». Un nom inconnu
        /// est rendu replié tel quel, pour la couleur dérivée et l'abréviation.
        func key(for className: String?) -> String? {
            guard let className, let cle = DofusClass.cle(className) else { return nil }
            return alias[cle] ?? cle
        }

        func color(for className: String?) -> Color {
            guard let key = key(for: className) else { return .secondary }
            return index[key]?.color ?? DofusClass.couleurDerivee(key)
        }

        /// Abréviation affichée dans la pastille, faute d'icône.
        func abbreviation(for className: String?) -> String {
            guard let key = key(for: className) else { return "?" }
            return String(key.prefix(2)).capitalized
        }
    }
}
