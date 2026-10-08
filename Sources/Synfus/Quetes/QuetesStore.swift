import Foundation

/// Les quêtes en vigueur : lues sur le disque à la première ouverture de la
/// palette, téléchargées si elles manquent ou ont plus de 30 jours ; un échec
/// garde ce qui est là.
@MainActor
final class QuetesStore: ObservableObject {
    static let shared = QuetesStore()

    @Published private(set) var quetes: Quetes? {
        didSet { indexer() }
    }
    private var parId: [Int: Quete] = [:]
    /// Triées une fois pour les onglets des réglages : par niveau, par nom.
    private(set) var quetesTriees: [Quete] = []
    private(set) var pnjsTries: [PNJ] = []

    private func indexer() {
        let langue = L10n.courante.langue
        let toutes = quetes?.quetes ?? []
        parId = Dictionary(toutes.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        quetesTriees = toutes.sorted {
            ($0.niveau, Lieu.traduit($0.noms, langue) ?? "") < ($1.niveau, Lieu.traduit($1.noms, langue) ?? "")
        }
        pnjsTries = (quetes?.pnjs ?? []).sorted {
            (Lieu.traduit($0.noms, langue) ?? "").localizedStandardCompare(Lieu.traduit($1.noms, langue) ?? "")
                == .orderedAscending
        }
    }
    @Published private(set) var chargement = false
    @Published private(set) var echec: String?
    private var lues = false
    /// Le téléchargement lancé par `preparer`, qu'attend `chargees`.
    private var telechargement: Task<Void, Never>?

    private init() {}

    /// Une quête par son identifiant, sans parcourir les deux mille.
    func fiche(_ id: Int) -> FicheQuete? {
        guard let quetes, let quete = parId[id] else { return nil }
        return quetes.fiche(quete, en: L10n.courante.langue)
    }

    func nom(_ id: Int) -> String? {
        parId[id].flatMap { Lieu.traduit($0.noms, L10n.courante.langue) }
    }

    func preparer() {
        if !lues {
            lues = true
            quetes = QuetesDofusDB.gardees()
        }
        guard !chargement, telechargement == nil, DofusDB.perimee(depuis: quetes?.date, maintenant: Date())
        else { return }
        telechargement = Task {
            try? await mettreAJour()
            telechargement = nil
        }
    }

    /// Les quêtes, après le téléchargement s'il n'y en a encore aucune — pour
    /// qui en a besoin tout de suite, comme la lecture du suivi.
    func chargees() async -> Quetes? {
        preparer()
        if quetes == nil { await telechargement?.value }
        return quetes
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
