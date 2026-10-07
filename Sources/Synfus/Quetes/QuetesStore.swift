import Foundation

/// Les quêtes en vigueur : lues sur le disque à la première ouverture de la
/// palette, téléchargées si elles manquent ou ont plus de 30 jours ; un échec
/// garde ce qui est là.
@MainActor
final class QuetesStore: ObservableObject {
    static let shared = QuetesStore()

    @Published private(set) var quetes: Quetes?
    @Published private(set) var chargement = false
    @Published private(set) var echec: String?
    private var lues = false

    private init() {}

    func preparer() {
        if !lues {
            lues = true
            quetes = QuetesDofusDB.gardees()
        }
        guard !chargement, DofusDB.perimee(depuis: quetes?.date, maintenant: Date()) else { return }
        Task { try? await mettreAJour() }
    }

    func mettreAJour() async throws {
        chargement = true
        echec = nil
        defer { chargement = false }
        do {
            let nouvelles = try await QuetesDofusDB.telecharger()
            try? QuetesDofusDB.garder(nouvelles)
            quetes = nouvelles
        } catch {
            echec = error.localizedDescription
            throw error
        }
    }
}
