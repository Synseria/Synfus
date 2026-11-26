// Statistiques d'utilisation : Synfus vu de la télémétrie commune (SynseriaKit), et les persos
// de chaque jour, qui lui sont propres.

import Combine
import Foundation
import ServiceManagement
import SynseriaDesign
import Telemetrie

/// Le seul foyer des statistiques : chaque geste compté passe par `compter`, l'onglet Usage lit
/// `registre.historique` et `persos`, et les jours terminés partent au collecteur une fois par
/// jour (`Preferences.partagerStatistiques`). Couper le partage n'arrête pas le compte, qui ne
/// quitte pas le Mac.
@MainActor
final class UsageStore: ObservableObject, SourceDeTelemetrie {
    static let identifiantApp = "fr.synseria.Synfus"
    /// `service.name` et préfixe des mesures, tels que le filtre du collecteur les connaît.
    static let service = CleDeTelemetrie(convertissant: "synfus")
    static let espaceDesMesures = CleDeTelemetrie(convertissant: "persos")

    /// Hors de l'app signée (tests, binaire nu de `swift run`) : en mémoire, sans configuration
    /// ni version — rien ne s'écrit sur le Mac, rien ne part.
    static let shared: UsageStore = {
        let app = Bundle.main.bundleIdentifier == identifiantApp
        return UsageStore(dossier: app ? Ressources.dossierUtilisateur : nil,
                          configuration: app ? .duBundle : nil,
                          version: app ? AppIntegrity.version : nil)
    }()

    let registre: RegistreDeTelemetrie
    @Published private(set) var persos: HistoriquePersos

    /// `persos.json`, `nil` en mémoire.
    let fichierPersos: URL?
    private let preferences: Preferences
    private let horloge: () -> Date
    private var persosModifies = false
    private var dernierEffectif: (persos: Int, instant: Date)?
    private var subscriptions: Set<AnyCancellable> = []

    /// - Parameter dossier: où vivent `usage.json` (le registre commun, même fichier que
    ///   l'ancien compte de Synfus : historique, attente et identifiant de secours relus) et
    ///   `persos.json` ; `nil` : en mémoire.
    init(dossier: URL?, configuration: ConfigurationDeTelemetrie?, version: String?,
         preferences: Preferences = .shared, materiel: String? = IdentifiantDInstallation.materiel(),
         envoi: @escaping RegistreDeTelemetrie.Envoi = RegistreDeTelemetrie.poster,
         horloge: @escaping () -> Date = Date.init) {
        var fichierUsage = dossier?.appending(path: "usage.json")
        var fichierPersos = dossier?.appending(path: "persos.json")
        var persos = HistoriquePersos()
        let donnees = fichierPersos.flatMap { try? Data(contentsOf: $0) }
        let relu = donnees.flatMap { try? JSONDecoder().decode(HistoriquePersos.self, from: $0) }
        // Un `persos.json` illisible ne s'écrase jamais : mis de côté, sinon ce lancement reste
        // en mémoire.
        if let fichier = fichierPersos, donnees != nil, relu == nil, !Self.mettreDeCote(fichier) {
            fichierUsage = nil
            fichierPersos = nil
        }
        if let fichier = fichierPersos {
            persos = relu ?? HistoriquePersos()
            // À chaque lancement, avant que le registre ne réécrive `usage.json` sans eux : les
            // persos qu'une version d'avant y a remis (retour à une ancienne version, build de
            // dev et app installée sur le même dossier) sont repris. Si `persos.json` ne s'écrit
            // pas, rien ne s'écrit de ce lancement : l'ancien fichier reste entier.
            let avant = persos
            if let ancien = fichierUsage.flatMap({ try? Data(contentsOf: $0) }) {
                persos.fusionner(HistoriquePersos.reprendre(ancien))
            }
            if (persos != avant || !FileManager.default.fileExists(atPath: fichier.path)) && !Self.ecrire(persos, dans: fichier) {
                fichierUsage = nil
                fichierPersos = nil
            }
        }
        self.persos = persos
        self.fichierPersos = fichierPersos
        self.preferences = preferences
        self.horloge = horloge
        registre = RegistreDeTelemetrie(service: Self.service, espaceDesMesures: Self.espaceDesMesures,
                                        fichier: fichierUsage, configuration: configuration,
                                        identifiantApp: Self.identifiantApp, version: version,
                                        materiel: materiel, envoi: envoi, horloge: horloge)
        registre.source = self
    }

    /// Au lancement : l'effectif suivi, le relevé périodique et les diagnostics de MetricKit.
    func start() {
        WindowManager.shared.$clients
            .map(\.count)
            .removeDuplicates()
            .sink { [weak self] persos in MainActor.assumeIsolated { self?.noterEffectif(persos) } }
            .store(in: &subscriptions)
        registre.demarrer()
    }

    /// À la fermeture : le compte du jour écrit, sans envoi (la requête ne survivrait pas).
    func arreter() { registre.releve(envoi: false) }

    // MARK: - Compte

    func compter(_ evenement: EvenementUsage) {
        registre.compter(evenement.cle)
    }

    func noterPersoJoue(_ nom: String) {
        persos.noterPersoJoue(nom, le: Self.aujourdhui(horloge()))
        persosModifies = true
    }

    /// Le temps écoulé depuis le relevé précédent compte pour l'effectif d'alors ; `nombre` vaut
    /// à partir de maintenant.
    func noterEffectif(_ nombre: Int) {
        let maintenant = horloge()
        let jour = Self.aujourdhui(maintenant)
        if let precedent = dernierEffectif {
            persos.noterEffectif(precedent.persos, pendant: maintenant.timeIntervalSince(precedent.instant), le: jour)
        }
        persos.noterEffectif(nombre, pendant: 0, le: jour)
        dernierEffectif = (nombre, maintenant)
        persosModifies = true
    }

    // MARK: - SourceDeTelemetrie

    var partageActif: Bool { preferences.partagerStatistiques }

    /// L'effectif mené jusqu'à maintenant et `persos.json` écrit, puis les réglages et la langue ;
    /// les persos partent par `mesures(jour:)`.
    func releve() -> ReleveDeLApp {
        noterEffectif(dernierEffectif?.persos ?? WindowManager.shared.clients.count)
        if persosModifies, let fichierPersos {
            persosModifies = !Self.ecrire(persos, dans: fichierPersos)
        }
        return ReleveDeLApp(reglages: Self.reglages(preferences, demarrageAuto: OuvertureALaSession.etat(SMAppService.mainApp.status) != .inactive),
                            langue: L10n.courante.langue.rawValue)
    }

    /// La journée entière telle que `persos.json` la garde, demandée au moment de l'envoi : un
    /// jour en attente part avec ses persos, et un jour terminé avec ce qui a suivi son dernier
    /// relevé. Un jour sans perso part à 0.
    func mesures(jour: String) -> [CleDeTelemetrie: ValeurDeTelemetrie]? {
        (persos.jour(jour) ?? JourPersos(jour: jour)).mesures
    }

    // MARK: - Règles

    /// Les réglages qui disent quelles fonctions sont en service.
    static func reglages(_ prefs: Preferences, demarrageAuto: Bool) -> [CleDeTelemetrie: Bool] {
        let reglages: [String: Bool] = [
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
            "canal_beta": prefs.canalDeMiseAJour == .beta,
            "demarrage_auto": demarrageAuto,
        ]
        return reglages.reduce(into: [:]) { $0[CleDeTelemetrie(convertissant: $1.key)] = $1.value }
    }

    static func aujourdhui(_ date: Date = Date()) -> String { JourDeTelemetrie.cle(date) }

    /// `persos.illisible.json`, à côté, remplace celui d'avant : de quoi rattraper à la main.
    private static func mettreDeCote(_ fichier: URL) -> Bool {
        let cote = fichier.deletingLastPathComponent().appending(path: "persos.illisible.json")
        try? FileManager.default.removeItem(at: cote)
        return (try? FileManager.default.moveItem(at: fichier, to: cote)) != nil
    }

    private static func ecrire(_ persos: HistoriquePersos, dans fichier: URL) -> Bool {
        guard let donnees = try? JSONEncoder().encode(persos) else { return false }
        do {
            try FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
            try donnees.write(to: fichier, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
