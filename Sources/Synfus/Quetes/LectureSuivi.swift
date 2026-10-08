import Foundation

/// Le suivi de quêtes du jeu, lu à la demande pour le panneau des quêtes :
/// au bouton « Lire le suivi » et à l'ouverture du panneau. Jamais au tour —
/// le suivi ne change que de la main du joueur.
@MainActor
final class LectureSuivi: ObservableObject {
    static let shared = LectureSuivi()

    enum Etat: Equatable {
        case jamaisLu
        case enCours
        /// Aucun perso à capturer, ou l'enregistrement de l'écran refusé.
        case illisible
        /// Les quêtes ne sont pas encore téléchargées.
        case sansQuetes
        case lu
    }

    @Published private(set) var reconnues: [SuiviQuetes.Reconnue] = []
    @Published private(set) var etat: Etat = .jamaisLu
    /// Les objectifs que la dernière lecture a cochés (`quetesCocherSuivi`).
    @Published private(set) var cochesLues = 0
    /// La dernière lecture dit encore où en est le jeu : passé `fraicheur`,
    /// le joueur a sans doute avancé, ses « à faire » ne se montrent plus.
    @Published private(set) var fraiche = false
    /// Les lectures de chaque perso : où il en est de chaque quête.
    @Published private(set) var historique = HistoriqueSuivi()
    /// Les quêtes sorties du suivi d'un perso entre deux lectures : finies,
    /// sans doute — le panneau propose de les désépingler.
    @Published private(set) var terminees: Set<Int> = []

    static let fraicheur: Duration = .seconds(10 * 60)
    private var peremption: Task<Void, Never>?

    private init() {}

    /// Les objectifs de la quête que le suivi montre encore à faire, tant que
    /// la lecture est fraîche.
    func aFaire(_ quete: Int) -> Set<Int> {
        guard fraiche, let reconnue = reconnues.first(where: { $0.id == quete }) else { return [] }
        return Set(reconnue.aFaire)
    }

    func lire() {
        guard etat != .enCours else { return }
        etat = .enCours
        Task {
            guard let (perso, lignes) = await LecteurEcran.shared.lireUneFois(.quetes) else { etat = .illisible; return }
            guard let quetes = await QuetesStore.shared.chargees() else { etat = .sansQuetes; return }
            // Deux mille noms dans trois langues, comparés à chaque ligne :
            // hors du main actor.
            let lu = await Task.detached { SuiviQuetes.reconnaitre(lignes, dans: quetes) }.value
            reconnues = lu.reconnues
            let prefs = Preferences.shared
            cochesLues = reconnues.reduce(0) { $0 + prefs.appliquer($1) }
            // Un client pas encore connecté n'a pas de nom de perso à qui
            // rapporter son suivi.
            if WindowTitle.isPersistableName(perso) {
                let disparues = historique.noter(lu, perso: perso, date: Date())
                terminees = terminees.union(disparues).subtracting(reconnues.map(\.id))
            }
            etat = .lu
            rafraichir()
        }
    }

    private func rafraichir() {
        fraiche = true
        peremption?.cancel()
        peremption = Task {
            try? await Task.sleep(for: Self.fraicheur)
            if !Task.isCancelled { fraiche = false }
        }
    }

    /// La quête n'est plus à proposer comme terminée : désépinglée.
    func oublier(_ quetes: [Int]) {
        if !terminees.isDisjoint(with: quetes) { terminees.subtract(quetes) }
    }

    /// Épingle la quête et la montre, à l'étape que le suivi désigne.
    func choisir(_ reconnue: SuiviQuetes.Reconnue) {
        if let etape = reconnue.etape { Preferences.shared.quetesEtape[String(reconnue.id)] = etape }
        QuetePanel.shared.ouvrir(reconnue.id)
    }
}
