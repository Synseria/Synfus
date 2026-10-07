import Foundation

/// La carte en vigueur, pour tout Synfus : zaaps, palette. Rafraîchie depuis
/// DofusDB au démarrage quand elle a plus de `DofusDB.peremption`, et au clic
/// « Mettre à jour » ; un échec garde la carte en place.
@MainActor
final class CarteStore: ObservableObject {
    static let shared = CarteStore()

    @Published private(set) var carte: Carte {
        didSet { zaaps = carte.zaaps }
    }
    /// Tirés de la carte une fois, pas à chaque lecture : la palette, la
    /// réécriture du `/travel` et les réglages les relisent souvent.
    private(set) var zaaps: [Zaap]

    private init() {
        let carte = CarteDofusDB.locale()
        self.carte = carte
        zaaps = carte.zaaps
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
