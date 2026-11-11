import Foundation

/// Le boss que l'aide suit : l'un de ceux dont elle connaît la mécanique
/// (`Boss`), ou n'importe quel boss de donjon — sa fiche, ses éléments, les
/// conseils de Dofus pour les noobs, le tour du combat. Pur.
enum CibleBoss: Hashable, Sendable {
    case special(Boss)
    /// Par son identifiant DofusDB (`monsters`) et celui de son donjon.
    case donjon(monstre: Int, donjon: Int)

    /// Un boss de donjon, rendu à sa mécanique quand l'aide la connaît : un
    /// seul chemin, qu'on le choisisse dans la palette ou en entrant chez lui.
    static func boss(_ monstre: Int, donjon: Int) -> CibleBoss {
        Boss.allCases.first { $0.monstre == monstre }.map(CibleBoss.special) ?? .donjon(monstre: monstre, donjon: donjon)
    }

    var special: Boss? {
        if case .special(let boss) = self { return boss }
        return nil
    }

    var monstre: Int {
        switch self {
        case .special(let boss): return boss.monstre
        case .donjon(let monstre, _): return monstre
        }
    }

    /// Ce que l'aide lit en combat en plus du bouton de combat.
    var lectures: [GenreLecture] { special?.lectures ?? [] }
}

/// Une chaîne, pour relire telle quelle la sauvegarde d'avant, qui ne
/// connaissait que `Boss` : `harebourg`, ou `donjon:1045:28`.
extension CibleBoss: Codable {
    private static let prefixe = "donjon:"

    init(from decoder: Decoder) throws {
        let texte = try decoder.singleValueContainer().decode(String.self)
        if let boss = Boss(rawValue: texte) {
            self = .special(boss)
            return
        }
        let parties = texte.dropFirst(Self.prefixe.count).split(separator: ":").compactMap { Int($0) }
        guard texte.hasPrefix(Self.prefixe), parties.count == 2 else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: texte))
        }
        self = .donjon(monstre: parties[0], donjon: parties[1])
    }

    func encode(to encoder: Encoder) throws {
        var conteneur = encoder.singleValueContainer()
        switch self {
        case .special(let boss): try conteneur.encode(boss.rawValue)
        case .donjon(let monstre, let donjon): try conteneur.encode("\(Self.prefixe)\(monstre):\(donjon)")
        }
    }
}
