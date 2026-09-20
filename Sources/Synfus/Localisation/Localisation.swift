import Foundation

/// Les langues de l'interface. La valeur brute est le code de langue, et le
/// nom du fichier `Resources/Localisation/<code>.json`.
enum Langue: String, CaseIterable, Identifiable, Sendable {
    case fr
    case en
    case es

    var id: String { rawValue }

    /// Le nom de la langue dans la langue elle-même : c'est ainsi qu'on la
    /// reconnaît dans une liste, quelle que soit celle de l'interface.
    var nom: String {
        switch self {
        case .fr: return "Français"
        case .en: return "English"
        case .es: return "Español"
        }
    }

    /// La langue à employer d'après la liste des langues préférées, dans
    /// l'ordre de préférence (`Locale.preferredLanguages` : « fr-FR »,
    /// « es-419 », « en »…). La première qui correspond l'emporte ; à défaut,
    /// le français — la langue source, celle dont les textes sont sûrs.
    static func choisir(parmi preferees: [String]) -> Langue {
        for identifiant in preferees {
            let code = identifiant.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if let code, let langue = Langue(rawValue: code) { return langue }
        }
        return .fr
    }
}

/// La table des libellés d'une langue, `clé → texte`, avec le français en
/// repli : une clé qui manque à une traduction s'affiche en français, jamais
/// sous forme de clé. Valeur immuable, chargée une fois au lancement.
///
/// Les libellés vivent dans `Resources/Localisation/<code>.json` — un objet
/// plat, trié, lisible par qui veut traduire — et le code ne porte que des
/// **clés** (`L("barre.aucunPerso")`). Les arguments suivent la syntaxe de
/// `String(format:)` : `%@` pour un texte, `%lld` pour un entier.
struct Localisation: Sendable {
    let langue: Langue
    let textes: [String: String]
    let repli: [String: String]

    /// Le texte d'une clé : dans la langue, sinon en français, sinon la clé
    /// elle-même — visible, donc corrigeable.
    func texte(_ cle: String) -> String {
        textes[cle] ?? repli[cle] ?? cle
    }

    /// Lit `<dossier>/<code>.json`. `nil` si le fichier manque ou est illisible.
    static func table(_ langue: Langue, dans dossier: URL) -> [String: String]? {
        let url = dossier.appendingPathComponent("\(langue.rawValue).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: data)
    }

    static func charger(_ langue: Langue, dans dossier: URL) -> Localisation {
        let fr = table(.fr, dans: dossier) ?? [:]
        let textes = langue == .fr ? fr : (table(langue, dans: dossier) ?? [:])
        return Localisation(langue: langue, textes: textes, repli: fr)
    }
}

/// La localisation en vigueur, résolue **une fois** au lancement — `static let`
/// est initialisé de façon sûre quel que soit le fil qui appelle `L()` en
/// premier. Changer de langue veut donc dire relancer Synfus, ce que fait le
/// réglage de l'onglet Général.
enum L10n {
    static let courante: Localisation = {
        let langue = Langue.choisir(parmi: Locale.preferredLanguages)
        guard let dossier else {
            return Localisation(langue: langue, textes: [:], repli: [:])
        }
        return Localisation.charger(langue, dans: dossier)
    }()

    /// Le dossier des tables : celui du bundle (`Contents/Resources/Localisation`,
    /// copié par `build.sh`), sinon celui du dépôt — pour `swift run` et les
    /// tests, où il n'y a pas de bundle.
    static let dossier: URL? = {
        if let bundle = Bundle.main.resourceURL?.appendingPathComponent("Localisation"),
           FileManager.default.fileExists(atPath: bundle.path) {
            return bundle
        }
        let depot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // Localisation/
            .deletingLastPathComponent()   // Synfus/
            .deletingLastPathComponent()   // Sources/
            .appendingPathComponent("Resources/Localisation")
        return FileManager.default.fileExists(atPath: depot.path) ? depot : nil
    }()
}

/// Le libellé d'une clé dans la langue en vigueur.
func L(_ cle: String) -> String {
    L10n.courante.texte(cle)
}

/// Le libellé d'une clé, avec ses arguments (`%@`, `%lld`).
func L(_ cle: String, _ arguments: CVarArg...) -> String {
    String(format: L10n.courante.texte(cle), arguments: arguments)
}
