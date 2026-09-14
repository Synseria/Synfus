import Carbon.HIToolbox
import Foundation

/// Ce qu'une case de la barre contient : un sort connu, ou n'importe quoi
/// d'autre — objet, emote, sort qu'on n'a pas su nommer — dont on garde la
/// vignette lue à l'écran.
struct SpellSlot: Codable, Equatable, Sendable {
    /// Identifiant DofusDB — celui de `sorts.json` — quand le sort est connu.
    var sortId: Int?
    var nom: String
    /// Nom d'un PNG dans le dossier du profil, découpé dans la capture : l'icône
    /// quand `sortId` est nul, ou quand on préfère celle de l'écran.
    var vignette: String?

    init(sortId: Int?, nom: String, vignette: String? = nil) {
        self.sortId = sortId
        self.nom = nom
        self.vignette = vignette
    }
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
    /// La touche « corps à corps » (l'arme équipée), même règle.
    var corpsACorps: HotKey?

    static let defaults = SpellKeyMap(
        barres: [row(modifiers: 0), row(modifiers: UInt32(controlKey)), row(modifiers: UInt32(controlKey | shiftKey))],
        finDeTour: nil, corpsACorps: nil
    )

    /// La rangée du haut entière — les douze touches de `&` à `-` sur un AZERTY,
    /// de `1` à `=` sur un ANSI — avec un modificateur. Le jeu numérote ses douze
    /// cases sur ces douze touches.
    static let topRow: [UInt32] = HotKey.digitRow + [27, 24]

    static func row(modifiers: UInt32) -> [HotKey?] {
        let keys: [HotKey?] = topRow.map { HotKey(keyCode: $0, modifiers: modifiers) }
        return keys + Array(repeating: nil, count: max(0, SpellProfile.slotsPerBar - keys.count))
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

/// Une commande du jeu hors sorts — ouvrir l'inventaire, suivre le perso… :
/// un nom, un symbole SF pour la touche, et la touche du jeu, réglable.
struct GameCommand: Codable, Equatable, Sendable, Identifiable {
    var id: String
    var nom: String
    var symbole: String
    var touche: HotKey?
}

/// Les commandes proposées sur le Stream Deck derrière la touche « Menu ».
/// Les défauts sont les raccourcis du jeu tels qu'on les connaît — à
/// vérifier dans Options → Raccourcis, et modifiables ici.
enum GameCommands {
    static let suiviID = "suivi"

    static let defaults: [GameCommand] = [
        GameCommand(id: "inventaire", nom: "Inventaire", symbole: "bag", touche: HotKey(keyCode: 34, modifiers: 0)),         // I
        GameCommand(id: "caracteristiques", nom: "Caractéristiques", symbole: "person.text.rectangle", touche: HotKey(keyCode: 8, modifiers: 0)), // C
        GameCommand(id: "sorts", nom: "Sorts", symbole: "book", touche: HotKey(keyCode: 1, modifiers: 0)),                  // S
        GameCommand(id: "quetes", nom: "Quêtes", symbole: "scroll", touche: HotKey(keyCode: 12, modifiers: 0)),             // Q
        GameCommand(id: "carte", nom: "Carte", symbole: "map", touche: HotKey(keyCode: 46, modifiers: 0)),                  // M
        GameCommand(id: "amis", nom: "Amis", symbole: "person.2", touche: HotKey(keyCode: 3, modifiers: 0)),                // F
        GameCommand(id: "guilde", nom: "Guilde", symbole: "flag", touche: HotKey(keyCode: 5, modifiers: 0)),                // G
        GameCommand(id: "metiers", nom: "Métiers", symbole: "hammer", touche: HotKey(keyCode: 38, modifiers: 0)),           // J
        GameCommand(id: "bestiaire", nom: "Bestiaire", symbole: "pawprint", touche: HotKey(keyCode: 11, modifiers: 0)),     // B
        GameCommand(id: "alliance", nom: "Alliance", symbole: "shield", touche: HotKey(keyCode: 0, modifiers: 0)),          // A
        GameCommand(id: suiviID, nom: "Suivi du perso", symbole: "figure.walk", touche: HotKey(keyCode: 13, modifiers: UInt32(controlKey))), // ⌃W
    ]

    /// Complète une liste enregistrée des commandes apparues depuis — sans
    /// toucher à celles qui existent.
    static func normalized(_ saved: [GameCommand]) -> [GameCommand] {
        var list = saved
        for command in defaults where !list.contains(where: { $0.id == command.id }) { list.append(command) }
        return list
    }
}
