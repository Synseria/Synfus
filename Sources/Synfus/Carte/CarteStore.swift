import Foundation

/// La carte en vigueur, pour tout Synfus : zaaps, palette. Lue du disque au
/// démarrage, rafraîchie depuis DofusDB quand elle a plus de
/// `DofusDB.peremption`, et au clic « Mettre à jour » ; un échec garde la
/// carte en place. Décodage, écriture et index se font hors du fil principal :
/// vide le temps de la lecture, la carte n'y arrive que prête.
@MainActor
final class CarteStore: ObservableObject {
    static let shared = CarteStore()

    @Published private(set) var carte = Carte.vide
    /// Tirés de la carte une fois, pas à chaque lecture : la palette, la
    /// réécriture du `/travel` et les réglages les relisent souvent.
    private var indexee = CarteIndexee(.vide)
    var zaaps: [Zaap] { indexee.zaaps }
    var reseau: ReseauSousZones { indexee.reseau }

    private init() {}

    func start() {
        Task {
            publier(await Task.detached(priority: .userInitiated) { CarteIndexee(CarteDofusDB.locale()) }.value)
            guard DofusDB.perimee(depuis: carte.date, maintenant: Date()) else { return }
            try? await mettreAJour()
        }
    }

    func mettreAJour() async throws {
        let nouvelle = try await CarteDofusDB.telecharger()
        publier(await Task.detached(priority: .utility) {
            try? CarteDofusDB.garder(nouvelle)
            return CarteIndexee(nouvelle)
        }.value)
    }

    /// Les index avant la carte : qui reçoit la publication relit le store.
    private func publier(_ nouvelle: CarteIndexee) {
        guard DofusDB.remplace(nouvelle.carte.date, enPlace: carte.date) else { return }
        indexee = nouvelle
        carte = nouvelle.carte
    }
}

/// La carte et ce qu'on en tire, bâtis ensemble et publiés d'un coup.
private struct CarteIndexee: Sendable {
    let carte: Carte
    let zaaps: [Zaap]
    let reseau: ReseauSousZones

    init(_ carte: Carte) {
        self.carte = carte
        zaaps = carte.zaaps
        reseau = ReseauSousZones(carte)
    }
}
