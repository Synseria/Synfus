// Statistiques d'utilisation : le compte du jour, gardé sur le Mac, envoyé
// chaque jour si l'utilisateur le partage.

import Combine
import Foundation

/// Le seul foyer des statistiques : chaque geste compté passe par `compter`,
/// l'onglet Usage lit `historique`, et les jours terminés partent au
/// collecteur une fois par jour (`Preferences.partagerStatistiques`). Couper
/// le partage n'arrête pas le compte, qui ne quitte pas le Mac.
@MainActor
final class UsageStore: ObservableObject {
    static let shared = UsageStore(fichier: Ressources.dossierUtilisateur.appending(path: "usage.json"))

    @Published private(set) var historique: HistoriqueUsage

    /// Où et avec quoi envoyer, inscrits dans l'Info.plist par la publication
    /// (`SynfusTelemetrieURL`, `SynfusTelemetrieJeton`). Un build local n'en a
    /// pas : il compte, n'envoie rien.
    struct Configuration: Sendable {
        let url: URL
        let jeton: String
    }

    static let configuration: Configuration? = {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let texte = info["SynfusTelemetrieURL"] as? String, let url = URL(string: texte), url.scheme == "https",
              let jeton = info["SynfusTelemetrieJeton"] as? String, !jeton.isEmpty
        else { return nil }
        return Configuration(url: url, jeton: jeton)
    }()

    private let fichier: URL?
    private var modifie = false
    private var minuterie: Timer?
    private var subscriptions: Set<AnyCancellable> = []
    private var dernierEffectif: (persos: Int, instant: Date)?
    private var derniereTentative: Date?
    private var envoiEnCours = false

    /// Relevé de l'effectif, écriture sur disque et envoi en retard.
    private static let intervalle: TimeInterval = 10 * 60
    /// Un échec d'envoi ne se retente qu'après ce délai.
    private static let attenteApresEchec: TimeInterval = 3600
    private static let session = URLSession(configuration: .ephemeral)

    init(fichier: URL?) {
        self.fichier = fichier
        historique = fichier.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? Self.decodeur.decode(HistoriqueUsage.self, from: $0) } ?? HistoriqueUsage()
    }

    func start() {
        WindowManager.shared.$clients
            .map(\.count)
            .removeDuplicates()
            .sink { [weak self] persos in MainActor.assumeIsolated { self?.noterEffectif(persos) } }
            .store(in: &subscriptions)
        minuterie = Timer.scheduledTimer(withTimeInterval: Self.intervalle, repeats: true) { _ in
            MainActor.assumeIsolated { UsageStore.shared.releve() }
        }
        minuterie?.tolerance = 60
        AbonneDiagnostics.shared.start()
        releve()
    }

    // MARK: - Compte

    func compter(_ evenement: EvenementUsage) {
        historique.compter(evenement, le: Self.aujourdhui())
        modifie = true
    }

    func recevoir(_ diagnostics: [DiagnosticUsage]) {
        historique.ajouter(diagnostics)
        modifie = true
        enregistrer()
    }

    func noterPersoJoue(_ nom: String) {
        historique.noterPersoJoue(nom, le: Self.aujourdhui())
        modifie = true
    }

    /// Le temps écoulé depuis le relevé précédent compte pour l'effectif
    /// d'alors ; `persos` vaut à partir de maintenant.
    private func noterEffectif(_ persos: Int, maintenant: Date = Date()) {
        let jour = Self.aujourdhui(maintenant)
        if let precedent = dernierEffectif {
            historique.noterEffectif(precedent.persos, pendant: maintenant.timeIntervalSince(precedent.instant), le: jour)
        }
        historique.noterEffectif(persos, pendant: 0, le: jour)
        dernierEffectif = (persos, maintenant)
        modifie = true
    }

    /// Le relevé périodique, et celui de la fermeture de Synfus (sans envoi :
    /// la requête ne survivrait pas au processus).
    func releve(envoi: Bool = true) {
        let maintenant = Date()
        noterEffectif(dernierEffectif?.persos ?? WindowManager.shared.clients.count, maintenant: maintenant)
        historique.noterReglages(Self.reglages(Preferences.shared, demarrageAuto: LaunchAtLogin.isEnabled),
                                 langue: L10n.courante.langue.rawValue, le: Self.aujourdhui(maintenant))
        enregistrer()
        if envoi { envoyer(maintenant: maintenant) }
    }

    private func enregistrer() {
        guard modifie, let fichier else { return }
        modifie = false
        guard let data = try? Self.encodeur.encode(historique) else { return }
        try? FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fichier, options: .atomic)
    }

    // MARK: - Envoi

    /// Ce qui décrit cette installation ; `nil` hors bundle (pas de version).
    var contexte: ContexteUsage? {
        guard let version = AppIntegrity.version else { return nil }
        return ContexteUsage(installation: installation, version: version,
                             systeme: ContexteUsage.systeme(ProcessInfo.processInfo.operatingSystemVersion),
                             architecture: ContexteUsage.architectureCourante)
    }

    private lazy var installation: String = {
        let app = Bundle.main.bundleIdentifier ?? "fr.synseria.Synfus"
        if let materiel = IdentifiantInstallation.materiel() {
            return IdentifiantInstallation.calculer(materiel: materiel, app: app)
        }
        let secours = historique.identifiantDeSecours ?? UUID().uuidString
        historique.identifiantDeSecours = secours
        modifie = true
        return IdentifiantInstallation.calculer(materiel: secours, app: app)
    }()

    private func envoyer(maintenant: Date) {
        guard Preferences.shared.partagerStatistiques, let configuration = Self.configuration,
              !envoiEnCours, let contexte else { return }
        if let tentative = derniereTentative, maintenant.timeIntervalSince(tentative) < Self.attenteApresEchec { return }
        let jours = historique.aEnvoyer(aujourdhui: Self.aujourdhui(maintenant))
        let diagnostics = historique.diagnosticAEnvoyer.map { [$0] } ?? []
        guard !jours.isEmpty || !diagnostics.isEmpty else { return }

        var requete = URLRequest(url: configuration.url, timeoutInterval: 30)
        requete.httpMethod = "POST"
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.setValue("Bearer \(configuration.jeton)", forHTTPHeaderField: "Authorization")
        requete.httpBody = RapportUsage.corps(jours, diagnostics: diagnostics, contexte: contexte, envoi: maintenant)
        derniereTentative = maintenant
        envoiEnCours = true
        Task {
            let accepte = await Self.poster(requete)
            envoiEnCours = false
            guard accepte else { return }
            historique.marquerEnvoyes(jours.map(\.jour))
            diagnostics.forEach { historique.retirerDiagnostic($0) }
            historique.dernierEnvoi = maintenant
            historique.dernierRapport = RapportUsage.texte(jours, diagnostics: diagnostics, contexte: contexte, envoi: maintenant)
            derniereTentative = nil
            modifie = true
            enregistrer()
        }
    }

    nonisolated private static func poster(_ requete: URLRequest) async -> Bool {
        guard let (_, reponse) = try? await session.data(for: requete),
              let http = reponse as? HTTPURLResponse
        else { return false }
        return (200..<300).contains(http.statusCode)
    }

    /// Le JSON du prochain envoi : les jours en attente, à défaut la journée
    /// en cours telle qu'elle partira demain.
    func apercuProchainEnvoi(maintenant: Date = Date()) -> String? {
        guard let contexte else { return nil }
        let aujourdhui = Self.aujourdhui(maintenant)
        var jours = historique.aEnvoyer(aujourdhui: aujourdhui)
        if jours.isEmpty, let jour = historique.jour(aujourdhui) { jours = [jour] }
        let diagnostics = historique.diagnosticAEnvoyer.map { [$0] } ?? []
        guard !jours.isEmpty || !diagnostics.isEmpty else { return nil }
        return RapportUsage.texte(jours, diagnostics: diagnostics, contexte: contexte, envoi: maintenant)
    }

    // MARK: - Règles

    /// Les réglages qui disent quelles fonctions sont en service.
    static func reglages(_ prefs: Preferences, demarrageAuto: Bool) -> [String: Bool] {
        [
            "barre": prefs.barVisible,
            "barre_seulement_dofus": prefs.barOnlyWithDofus,
            "numeros": prefs.showNumbers,
            "classes": prefs.showClasses,
            "apercu_survol": prefs.showPreviewOnHover,
            "signal_attention": prefs.attentionAction != .ignore,
            "passage_auto": prefs.attentionAction == .focus,
            "enchainement_clic": prefs.advanceOnClick,
            "signaler_bascule": prefs.signalerBascule,
            "fermer_geles": prefs.killFrozenClients,
            "equipes": !prefs.equipes.isEmpty,
            "invitation_groupee": prefs.inviteGroupee,
            "zaap_auto": prefs.zaapAuto,
            "vues_cartes": prefs.vuesCartes,
            "lire_position": prefs.lirePosition,
            "lire_combat": prefs.lireCombat,
            "lire_combat_derriere": prefs.lireCombatDerriere,
            "maj_auto": prefs.verifierMisesAJour,
            "demarrage_auto": demarrageAuto,
        ]
    }

    static func aujourdhui(_ date: Date = Date()) -> String { JourUsage.cle(date) }

    private static let encodeur: JSONEncoder = {
        let encodeur = JSONEncoder()
        encodeur.dateEncodingStrategy = .iso8601
        return encodeur
    }()

    private static let decodeur: JSONDecoder = {
        let decodeur = JSONDecoder()
        decodeur.dateDecodingStrategy = .iso8601
        return decodeur
    }()
}
