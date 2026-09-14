import Carbon.HIToolbox
import Foundation

/// Un sort posé dans une case de la barre.
struct SpellSlot: Codable, Equatable, Sendable {
    /// Identifiant DofusDB — celui de `sorts.json` et du nom de fichier de l'icône.
    var sortId: Int
    var nom: String
}

/// Une barre de sorts du jeu : `SpellProfile.slotsPerBar` cases, vides ou non.
struct SpellBar: Codable, Equatable, Sendable {
    var nom: String
    var cases: [SpellSlot?]

    static func empty(nom: String) -> SpellBar {
        SpellBar(nom: nom, cases: Array(repeating: nil, count: SpellProfile.slotsPerBar))
    }
}

/// Les sorts d'un perso, barre par barre — ce que le Stream Deck affiche quand
/// ce perso est devant. Un fichier JSON par perso, lisible, exportable,
/// versionnable par l'utilisateur s'il le souhaite.
struct SpellProfile: Codable, Equatable, Sendable {
    /// Le jeu affiche douze cases par rangée.
    static let slotsPerBar = 12
    static let barCount = 3
    static let currentVersion = 1

    var version: Int = currentVersion
    var perso: String
    /// Classe au moment de la création — sert à choisir les candidats.
    var classe: String?
    var barres: [SpellBar]

    static func empty(perso: String, classe: String?) -> SpellProfile {
        SpellProfile(perso: perso, classe: classe,
                     barres: (1...barCount).map { SpellBar.empty(nom: "Barre \($0)") })
    }

    /// Une case, par barre et position (0-based). `nil` hors limites.
    func slot(bar: Int, position: Int) -> SpellSlot? {
        guard barres.indices.contains(bar), barres[bar].cases.indices.contains(position) else { return nil }
        return barres[bar].cases[position]
    }

    mutating func set(_ slot: SpellSlot?, bar: Int, position: Int) {
        guard barres.indices.contains(bar), barres[bar].cases.indices.contains(position) else { return }
        barres[bar].cases[position] = slot
    }

    /// Une sauvegarde d'une version antérieure est relue telle quelle ; les
    /// barres manquantes sont complétées, les cases aussi — jamais tronquées.
    mutating func normalize() {
        while barres.count < Self.barCount { barres.append(.empty(nom: "Barre \(barres.count + 1)")) }
        for i in barres.indices where barres[i].cases.count < Self.slotsPerBar {
            barres[i].cases += Array(repeating: nil, count: Self.slotsPerBar - barres[i].cases.count)
        }
    }
}

/// Les touches que le jeu attend pour chaque case de chaque barre, plus la fin
/// de tour — ce que le plugin frappe. Des **keycodes de position**, comme
/// `HotKey` : sur AZERTY la rangée du haut tape `& é "`, mais c'est la touche
/// qui compte, pas le caractère.
///
/// Défaut : barre 1 → `1…0` nus, barre 2 → `⌃1…⌃0`, barre 3 → `⌃⇧1…⌃⇧0` —
/// l'organisation courante des joueurs à plusieurs barres. Les cases 11 et 12
/// n'ont pas de touche par défaut. Aucune n'emploie ⌘, réservé aux raccourcis
/// de Synfus (`digitRow` + ⌘ = les emplacements).
struct SpellKeyMap: Codable, Equatable, Sendable {
    var barres: [[HotKey?]]
    /// La touche « fin de tour » du jeu ; sans défaut tant qu'elle n'a pas été
    /// confirmée en jeu — une touche fausse en combat coûte cher.
    var finDeTour: HotKey?

    static let defaults = SpellKeyMap(
        barres: [row(modifiers: 0), row(modifiers: UInt32(controlKey)), row(modifiers: UInt32(controlKey | shiftKey))],
        finDeTour: nil
    )

    /// La rangée de chiffres avec un modificateur, complétée de cases sans touche.
    static func row(modifiers: UInt32) -> [HotKey?] {
        let digits: [HotKey?] = HotKey.digitRow.map { HotKey(keyCode: $0, modifiers: modifiers) }
        return digits + Array(repeating: nil, count: max(0, SpellProfile.slotsPerBar - digits.count))
    }

    func key(bar: Int, position: Int) -> HotKey? {
        guard barres.indices.contains(bar), barres[bar].indices.contains(position) else { return nil }
        return barres[bar][position]
    }

    /// Les jeux de modificateurs proposés pour une barre — la rangée de
    /// chiffres reste la même, seul le modificateur change.
    static let modifierChoices: [(label: String, value: UInt32)] = [
        ("aucun", 0),
        ("⌃", UInt32(controlKey)),
        ("⇧", UInt32(shiftKey)),
        ("⌥", UInt32(optionKey)),
        ("⌃⇧", UInt32(controlKey | shiftKey)),
        ("⌃⌥", UInt32(controlKey | optionKey)),
        ("⌥⇧", UInt32(optionKey | shiftKey)),
    ]
}
