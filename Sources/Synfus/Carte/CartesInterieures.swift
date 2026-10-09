import Foundation

/// Les cartes du jeu qui ne sont pas en extérieur (`map-positions`,
/// `outdoor` faux : maisons, banques, souterrains). `/travel` ne vise que des
/// coordonnées : un PNJ sur une carte intérieure est atteint devant le
/// bâtiment, à ses coordonnées, et il reste à y entrer. Une liste à part, et
/// légère — des identifiants —, pour ne retélécharger ni la carte ni les quêtes.
struct CartesInterieures: Codable, Equatable, Sendable {
    /// Une autre forme (ancienne) ne se relit pas : la liste se redemande.
    static let formatActuel = 1
    var format = CartesInterieures.formatActuel
    let date: Date
    let cartes: Set<Int>

    static let vide = CartesInterieures(date: .distantPast, cartes: [])

    func contient(_ carte: Int?) -> Bool {
        carte.map(cartes.contains) ?? false
    }

    // MARK: - DofusDB

    private struct CarteAPI: Decodable, Sendable {
        let id: Int
    }

    static func telecharger() async throws -> CartesInterieures {
        let cartes: [CarteAPI] = try await DofusDB.toutesEnParallele(
            "map-positions", [URLQueryItem(name: "outdoor", value: "false")] + DofusDB.selection(["id"]))
        return CartesInterieures(date: Date(), cartes: Set(cartes.map(\.id)))
    }

    // MARK: - Disque

    /// `~/Library/Application Support/Synfus/Interieurs.json`
    private static var fichier: URL {
        Ressources.dossierUtilisateur.appending(path: "Interieurs.json", directoryHint: .notDirectory)
    }

    static func relire(_ donnees: Data?) -> CartesInterieures? {
        guard let donnees, let liste = try? JSONDecoder().decode(CartesInterieures.self, from: donnees),
              liste.format == formatActuel
        else { return nil }
        return liste
    }

    static func gardee() -> CartesInterieures? { relire(try? Data(contentsOf: fichier)) }

    func garder() throws {
        try FileManager.default.createDirectory(at: Self.fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(self).write(to: Self.fichier, options: .atomic)
    }
}
