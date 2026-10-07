import Foundation

/// La carte en vigueur, pour tout Synfus : zaaps, palette. Rafraîchie depuis
/// DofusDB au démarrage quand elle a plus de `DofusDB.peremption`, et au clic
/// « Mettre à jour » ; un échec garde la carte en place.
@MainActor
final class CarteStore: ObservableObject {
    static let shared = CarteStore()

    @Published private(set) var carte: Carte

    private init() {
        carte = CarteDofusDB.locale()
    }

    func start() {
        guard DofusDB.perimee(depuis: carte.date, maintenant: Date()) else { return }
        Task { try? await mettreAJour() }
    }

    func mettreAJour() async throws {
        let nouvelle = try await CarteDofusDB.telecharger()
        try? CarteDofusDB.garder(nouvelle)
        carte = nouvelle
    }
}
