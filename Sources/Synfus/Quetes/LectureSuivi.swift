import Combine
import Foundation

/// Le suivi de quêtes du jeu, lu pour le panneau des quêtes : au tour de
/// `LecteurEcran` tant que le panneau est montré — un objectif qui se termine
/// le change —, au bouton « Lire le suivi » et à l'ouverture du panneau.
/// Toute lecture prend le même chemin (`traiter`) : reconnaissance hors du
/// main actor, coches (`Preferences.appliquer`), lectures par perso
/// (`HistoriqueSuivi`). Ce que le panneau montre vient de la lecture du
/// **perso devant**, tant que l'écran la confirme : c'est lui qui joue.
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

    /// Les quêtes du suivi du perso devant, à sa dernière lecture.
    @Published private(set) var reconnues: [SuiviQuetes.Reconnue] = []
    @Published private(set) var etat: Etat = .jamaisLu
    /// Les objectifs qu'a cochés (`quetesCocherSuivi`) la dernière lecture
    /// demandée, ou la dernière du tour qui en a coché.
    @Published private(set) var cochesLues = 0
    /// L'écran a montré la lecture du perso devant il y a moins de
    /// `fraicheur` : au-delà — panneau caché, perso pas revu —, le joueur a
    /// sans doute avancé, ses « à faire » ne se montrent plus.
    @Published private(set) var fraiche = false
    /// Les lectures de chaque perso : où il en est de chaque quête.
    @Published private(set) var historique = HistoriqueSuivi()
    /// Les quêtes sorties du suivi d'un perso entre deux lectures : finies,
    /// sans doute — le panneau propose de les désépingler.
    @Published private(set) var terminees: Set<Int> = []

    static let fraicheur: TimeInterval = 10 * 60
    /// Quand l'écran a montré la lecture de chaque perso pour la dernière
    /// fois, relue ou revue inchangée. Hors des `@Published` : le tour la
    /// confirme toutes les trois secondes sans rien changer à l'écran.
    private var vusLe: [String: Date] = [:]
    /// `LecteurEcran.persoDevant`.
    private var devant: String?
    private var peremption: Task<Void, Never>?
    /// L'index des noms (`SuiviQuetes.Index`) du dernier jeu de quêtes lu.
    private var index: (date: Date, tache: Task<SuiviQuetes.Index, Never>)?
    /// La lecture en cours de traitement : la suivante l'attend, l'ordre
    /// d'arrivée est celui de l'écran.
    private var traitement: Task<Void, Never>?
    private var abonnement: AnyCancellable?

    private init() {
        // La valeur émise : `@Published` publie avant d'affecter.
        abonnement = LecteurEcran.shared.$persoDevant
            .removeDuplicates()
            .sink { [weak self] perso in
                MainActor.assumeIsolated {
                    self?.devant = perso
                    self?.revoir()
                }
            }
    }

    /// Ce que la lecture fraîche du perso devant dit de la quête.
    func reconnue(_ quete: Int) -> SuiviQuetes.Reconnue? {
        fraiche ? reconnues.first { $0.id == quete } : nil
    }

    /// « Lire le suivi », et l'ouverture du panneau.
    func lire() {
        guard etat != .enCours else { return }
        etat = .enCours
        Task {
            guard let lu = await LecteurEcran.shared.lireUneFois(.quetes) else { etat = .illisible; return }
            guard let quetes = await QuetesStore.shared.chargees() else { etat = .sansQuetes; return }
            await traiter(lu.lignes, coupe: lu.coupe, perso: lu.perso, quetes: quetes, demandee: true)
        }
    }

    /// Une lecture du tour : le suivi de `perso`, devant, a changé à l'écran.
    func recevoir(_ lignes: [String], coupe: Bool, perso: String) {
        guard let quetes = QuetesStore.shared.quetes else { return }
        Task { await traiter(lignes, coupe: coupe, perso: perso, quetes: quetes, demandee: false) }
    }

    /// Le tour a revu le suivi de `perso` inchangé : sa dernière lecture tient.
    func confirmer(_ perso: String) {
        guard historique.derniere(perso) != nil else { return }
        vusLe[perso] = Date()
        revoir()
    }

    /// Une lecture reconnue hors du main actor — deux mille noms dans trois
    /// langues, comparés à chaque ligne —, sur l'index du jeu de quêtes, bâti
    /// une fois par jeu. Aussi l'essai du calibrage.
    func reconnaitre(_ lignes: [String], coupe: Bool, dans quetes: Quetes) async -> SuiviQuetes.Lu {
        let pret = await index(quetes)
        return await Task.detached { SuiviQuetes.reconnaitre(lignes, coupe: coupe, dans: pret) }.value
    }

    /// Les rangs des lignes qui portent un nom de quête, sur les quêtes déjà
    /// là — la détection des zones (`AutoCalibrage`) ; aucune sans quêtes.
    func rangsDeTitres(_ lignes: [String]) async -> Set<Int> {
        guard let quetes = QuetesStore.shared.quetes else { return [] }
        let pret = await index(quetes)
        return await Task.detached { SuiviQuetes.rangsDeTitres(lignes, dans: pret) }.value
    }

    private func index(_ quetes: Quetes) async -> SuiviQuetes.Index {
        if let index, index.date == quetes.date { return await index.tache.value }
        let tache = Task.detached { SuiviQuetes.Index(quetes) }
        index = (quetes.date, tache)
        return await tache.value
    }

    /// Le seul chemin d'une lecture, demandée ou du tour.
    private func traiter(_ lignes: [String], coupe: Bool, perso: String, quetes: Quetes, demandee: Bool) async {
        let precedent = traitement
        let tache = Task {
            await precedent?.value
            let lu = await reconnaitre(lignes, coupe: coupe, dans: quetes)
            noter(lu, perso: perso, demandee: demandee)
        }
        traitement = tache
        await tache.value
    }

    private func noter(_ lu: SuiviQuetes.Lu, perso: String, demandee: Bool) {
        let prefs = Preferences.shared
        let coches = prefs.appliquer(lu.reconnues)
        if demandee || coches > 0, cochesLues != coches { cochesLues = coches }
        // Un client pas encore connecté n'a pas de nom de perso à qui
        // rapporter son suivi.
        if WindowTitle.isPersistableName(perso) {
            vusLe[perso] = Date()
            // Une relecture identique ne change rien : rien à redessiner.
            var historique = self.historique
            let disparues = historique.noter(lu, perso: perso, date: Date())
            if historique != self.historique { self.historique = historique }
            let restent = terminees.union(disparues).subtracting(lu.reconnues.map(\.id))
            if restent != terminees { terminees = restent }
        }
        if etat != .lu, demandee || etat != .enCours { etat = .lu }
        revoir()
    }

    #if DEBUG
    /// Un suivi lu d'exemple pour les captures (`CapturesTests`) : aucun écran n'est lu.
    func poserPourCaptures(reconnues: [SuiviQuetes.Reconnue]) {
        self.reconnues = reconnues
    }
    #endif

    /// Ce que le panneau montre : la dernière lecture du perso devant, et si
    /// l'écran l'a montrée il y a moins de `fraicheur`.
    private func revoir() {
        let lues = devant.flatMap { historique.derniere($0) }?.reconnues ?? []
        if reconnues != lues { reconnues = lues }
        let frais = devant.flatMap { vusLe[$0] }.map { Date().timeIntervalSince($0) < Self.fraicheur } ?? false
        if fraiche != frais { fraiche = frais }
        if frais, peremption == nil { peremption = Task { await perimer() } }
    }

    /// Attend que la lecture du perso devant n'ait plus été vue depuis
    /// `fraicheur`, confirmations et bascules comprises.
    private func perimer() async {
        while !Task.isCancelled {
            let vu = devant.flatMap { vusLe[$0] } ?? .distantPast
            let reste = Self.fraicheur - Date().timeIntervalSince(vu)
            guard reste > 0 else { break }
            try? await Task.sleep(for: .seconds(reste))
        }
        peremption = nil
        revoir()
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
