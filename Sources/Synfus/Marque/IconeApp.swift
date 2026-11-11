import Foundation

/// L'icône de l'app choisie dans les Réglages : un motif sur un fond. Pur, et
/// compilé avec `SynfusMark` par `Tools/generate-app-icons.sh` : ni AppKit ni `L()`.
struct IconeApp: Codable, Hashable, Sendable {
    enum Motif: String, Codable, CaseIterable, Sendable {
        /// L'Œuf ajouré.
        case oeuf
        /// La Couvée : trois œufs de dragon.
        case couvee
    }

    enum Fond: String, Codable, CaseIterable, Sendable {
        case nuit, foret, aube
        /// Pas de tuile : la marque seule.
        case transparent
    }

    var motif: Motif
    var fond: Fond

    /// Celle du bundle (`Resources/Synfus.icns`).
    static let parDefaut = IconeApp(motif: .oeuf, fond: .nuit)

    /// Les huit, motif par motif.
    static let toutes: [IconeApp] = Motif.allCases.flatMap { motif in Fond.allCases.map { IconeApp(motif: motif, fond: $0) } }

    init(motif: Motif, fond: Fond) {
        self.motif = motif
        self.fond = fond
    }

    private enum CodingKeys: String, CodingKey { case motif, fond }

    /// Un motif ou un fond inconnu (sauvegarde d'une version plus récente)
    /// reprend le défaut : une valeur illisible rendrait toute la sauvegarde
    /// illisible.
    init(from decoder: Decoder) throws {
        let conteneur = try decoder.container(keyedBy: CodingKeys.self)
        motif = (try? conteneur.decode(String.self, forKey: .motif)).flatMap(Motif.init) ?? Self.parDefaut.motif
        fond = (try? conteneur.decode(String.self, forKey: .fond)).flatMap(Fond.init) ?? Self.parDefaut.fond
    }
}
