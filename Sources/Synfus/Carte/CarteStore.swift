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
    var reperes: ReperesCarte { indexee.reperes }
    /// Les cartes intérieures, à part de la carte : relues du disque,
    /// redemandées comme elle tous les `DofusDB.peremption`.
    @Published private(set) var interieurs = CartesInterieures.vide

    private init() {}

    func start() {
        Task {
            publier(await Task.detached(priority: .userInitiated) { CarteIndexee(CarteDofusDB.locale()) }.value)
            await rafraichirCarte()
        }
        Task {
            if let gardee = await Task.detached(priority: .utility, operation: { CartesInterieures.gardee() }).value {
                interieurs = gardee
            }
            await rafraichirInterieurs()
        }
    }

    /// Chaque jour (`DonneesDuJeu`) : ce qui a passé `DofusDB.peremption` se redemande.
    func rafraichir() {
        Task { await rafraichirCarte() }
        Task { await rafraichirInterieurs() }
    }

    private func rafraichirCarte() async {
        guard DofusDB.perimee(depuis: carte.date, maintenant: Date()) else { return }
        try? await mettreAJour()
    }

    private func rafraichirInterieurs() async {
        guard DofusDB.perimee(depuis: interieurs.date, maintenant: Date()) else { return }
        await mettreAJourInterieurs()
    }

    /// La carte des captures de la documentation, sans disque ni réseau.
    func poserPourCaptures(_ carte: Carte) { publier(CarteIndexee(carte)) }

    func mettreAJour() async throws {
        let nouvelle = try await CarteDofusDB.telecharger()
        publier(await Task.detached(priority: .utility) {
            try? CarteDofusDB.garder(nouvelle)
            return CarteIndexee(nouvelle)
        }.value)
    }

    /// Un échec garde la liste en place ; elle se redemande au prochain rafraîchissement.
    private func mettreAJourInterieurs() async {
        guard let nouveaux = try? await CartesInterieures.telecharger() else { return }
        interieurs = nouveaux
        Task.detached(priority: .utility) { try? nouveaux.garder() }
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
    let reperes: ReperesCarte

    init(_ carte: Carte) {
        self.carte = carte
        zaaps = carte.zaaps
        reseau = ReseauSousZones(carte)
        reperes = ReperesCarte(carte.lieux)
    }
}
