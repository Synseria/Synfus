import Foundation

/// Les quêtes en vigueur : lues sur le disque au lancement (`preparer`),
/// téléchargées si elles manquent ou ont plus de 30 jours ; un échec
/// garde ce qui est là. Six mégaoctets à lire ou écrire, deux mille quêtes à
/// trier : tout se fait hors du fil principal, qui ne reçoit que le jeu prêt.
@MainActor
final class QuetesStore: ObservableObject {
    static let shared = QuetesStore()

    @Published private(set) var quetes: Quetes?
    /// Les index du jeu publié, remplacés avec lui (`publier`).
    private var enVigueur: QuetesEnVigueur?
    @Published private(set) var chargement = false
    @Published private(set) var echec: String?
    private var lues = false
    /// La lecture du disque puis, s'il le faut, le téléchargement : ce
    /// qu'attend `chargees`.
    private var preparation: Task<Void, Never>?

    private init() {}

    var quetesTriees: [Quete] { enVigueur?.quetesTriees ?? [] }
    var pnjsTries: [PNJ] { enVigueur?.pnjsTries ?? [] }

    func fiche(_ id: Int) -> FicheQuete? {
        enVigueur?.fiche(id)
    }

    func nom(_ id: Int) -> String? {
        enVigueur?.nom(id)
    }

    #if DEBUG
    /// Les quêtes d'exemple (ou leur échec) des captures de la documentation (`CapturesTests`) : rien ne
    /// se lit sur le disque ni ne se télécharge.
    func poserPourCaptures(_ quetes: Quetes?, echec: String? = nil) {
        lues = true
        preparation = Task {}
        self.quetes = quetes
        enVigueur = quetes.map { QuetesEnVigueur($0, langue: L10n.courante.langue) }
        self.echec = echec
    }
    #endif

    func preparer() {
        guard preparation == nil, !chargement else { return }
        let lire = !lues
        guard lire || DofusDB.perimee(depuis: quetes?.date, maintenant: Date()) else { return }
        lues = true
        let langue = L10n.courante.langue
        preparation = Task {
            if lire {
                // Le panneau et la palette disent « chargement », pas « aucune ».
                chargement = true
                let gardees = await Task.detached(priority: .userInitiated) {
                    QuetesDofusDB.gardees().map { QuetesEnVigueur($0, langue: langue) }
                }.value
                chargement = false
                if let gardees { publier(gardees) }
            }
            if DofusDB.perimee(depuis: quetes?.date, maintenant: Date()) { try? await mettreAJour() }
            preparation = nil
        }
    }

    /// Les quêtes, après la lecture et le téléchargement s'il n'y en a encore
    /// aucune — pour qui en a besoin tout de suite, comme la lecture du suivi.
    func chargees() async -> Quetes? {
        preparer()
        if quetes == nil { await preparation?.value }
        return quetes
    }

    func mettreAJour() async throws {
        chargement = true
        echec = nil
        defer { chargement = false }
        do {
            let nouvelles = try await QuetesDofusDB.telecharger()
            let langue = L10n.courante.langue
            let pretes = await Task.detached(priority: .utility) {
                try? QuetesDofusDB.garder(nouvelles)
                return QuetesEnVigueur(nouvelles, langue: langue)
            }.value
            publier(pretes)
        } catch {
            echec = error.localizedDescription
            throw error
        }
    }

    /// Les index avant les quêtes : qui reçoit la publication relit le store.
    private func publier(_ nouvelles: QuetesEnVigueur) {
        guard DofusDB.remplace(nouvelles.quetes.date, enPlace: quetes?.date) else { return }
        enVigueur = nouvelles
        quetes = nouvelles.quetes
    }
}
