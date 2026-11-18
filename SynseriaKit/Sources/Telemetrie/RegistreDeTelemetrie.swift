// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit 832ae65487891069 · contenu 2735195b573384dc
// Le compte du jour, gardé sur le Mac, envoyé chaque jour si l'utilisateur le partage.

import Foundation
import MetricKit
import Observation

/// Ce que l'app relève d'elle-même à chaque relevé : ses réglages, la langue de son interface,
/// ses mesures propres. Le paquet n'en connaît aucun.
public struct ReleveDeLApp: Equatable, Sendable {
    public var reglages: [CleDeTelemetrie: Bool]
    public var langue: String?
    public var mesures: [CleDeTelemetrie: ValeurDeTelemetrie]

    public init(reglages: [CleDeTelemetrie: Bool] = [:], langue: String? = nil,
                mesures: [CleDeTelemetrie: ValeurDeTelemetrie] = [:]) {
        self.reglages = reglages
        self.langue = langue
        self.mesures = mesures
    }
}

/// L'app vue du registre : si l'utilisateur partage, et ce qu'elle relève.
@MainActor
public protocol SourceDeTelemetrie: AnyObject {
    /// Le réglage « Partager les statistiques d'utilisation ». Couper le partage n'arrête pas le
    /// compte, qui ne quitte pas le Mac.
    var partageActif: Bool { get }
    func releve() -> ReleveDeLApp
    /// Les mesures d'une journée (`2026-11-09`), demandées au moment de composer l'envoi ou
    /// l'aperçu : la journée entière, jours en attente compris. `nil` : celles du dernier relevé
    /// de ce jour-là (défaut, pour l'app qui ne garde pas ses mesures jour par jour).
    func mesures(jour: String) -> [CleDeTelemetrie: ValeurDeTelemetrie]?
}

extension SourceDeTelemetrie {
    public func mesures(jour: String) -> [CleDeTelemetrie: ValeurDeTelemetrie]? { nil }
}

/// Le seul foyer de la télémétrie d'une app : chaque geste compté passe par `compter`, l'app lit
/// `historique`, et les jours terminés partent au collecteur une fois par jour.
@MainActor
@Observable
public final class RegistreDeTelemetrie {
    /// Le transport : la requête, le statut HTTP rendu (`nil` sans réponse). Remplacé sous test.
    public typealias Envoi = @Sendable (URLRequest) async -> Int?

    public private(set) var historique: HistoriqueDeTelemetrie
    @ObservationIgnored public var source: (any SourceDeTelemetrie)?

    @ObservationIgnored private let service: CleDeTelemetrie
    @ObservationIgnored private let espaceDesMesures: CleDeTelemetrie?
    @ObservationIgnored private let fichier: URL?
    @ObservationIgnored private let configuration: ConfigurationDeTelemetrie?
    @ObservationIgnored private let version: String?
    @ObservationIgnored private let envoi: Envoi
    @ObservationIgnored private let horloge: () -> Date
    /// Fixé à la création, jamais pendant un rendu : le tirer peut écrire `historique`
    /// (identifiant de secours).
    @ObservationIgnored private let installation: String
    @ObservationIgnored private var modifie = false
    @ObservationIgnored private var envoiEnCours = false
    @ObservationIgnored private var minuterie: Timer?
    @ObservationIgnored private var abonne: AbonneDiagnostics?

    /// Relevé, écriture sur disque et envoi en retard : une requête au plus par relevé.
    static let intervalle: TimeInterval = 10 * 60
    /// Un échec d'envoi ne se retente qu'après ce délai.
    static let attenteApresEchec: TimeInterval = 3600

    /// - Parameters:
    ///   - service: `service.name` du rapport, le nom de l'app en minuscules.
    ///   - espaceDesMesures: le préfixe des mesures de l'app (`persos`), `nil` si elle n'en a pas.
    ///   - fichier: où garder l'historique ; `nil` : en mémoire seulement.
    ///   - configuration: `nil` : l'app compte, n'envoie rien.
    ///   - identifiantApp: le bundle id, mêlé à l'UUID du Mac dans l'identifiant d'installation.
    ///   - version: la version de l'app ; `nil` (hors bundle) : rien ne part.
    public init(service: CleDeTelemetrie, espaceDesMesures: CleDeTelemetrie? = nil, fichier: URL?,
                configuration: ConfigurationDeTelemetrie?, identifiantApp: String, version: String?,
                materiel: String? = IdentifiantDInstallation.materiel(),
                envoi: @escaping Envoi = RegistreDeTelemetrie.poster,
                horloge: @escaping () -> Date = Date.init) {
        self.service = service
        self.espaceDesMesures = espaceDesMesures
        self.fichier = fichier
        self.configuration = configuration
        self.version = version
        self.envoi = envoi
        self.horloge = horloge
        var historique = fichier.flatMap { try? Data(contentsOf: $0) }
            .flatMap { try? Self.decodeur.decode(HistoriqueDeTelemetrie.self, from: $0) } ?? HistoriqueDeTelemetrie()
        let secours = historique.identifiantDeSecours
        installation = IdentifiantDInstallation.fixer(materiel: materiel, app: identifiantApp,
                                                      secours: &historique.identifiantDeSecours)
        modifie = historique.identifiantDeSecours != secours
        self.historique = historique
    }

    /// Le relevé périodique et les diagnostics de MetricKit. Jamais sous les tests de l'app.
    public func demarrer() {
        guard minuterie == nil else { return }
        minuterie = Timer.scheduledTimer(withTimeInterval: Self.intervalle, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.releve() }
        }
        minuterie?.tolerance = 60
        let abonne = AbonneDiagnostics { [weak self] in self?.recevoir($0) }
        MXMetricManager.shared.add(abonne)
        self.abonne = abonne
        releve()
    }

    // MARK: - Compte

    public func compter(_ cle: CleDeTelemetrie, de nombre: Int = 1) {
        historique.compter(cle, de: nombre, le: aujourdhui())
        modifie = true
    }

    public func recevoir(_ diagnostics: [DiagnosticDeTelemetrie]) {
        historique.ajouter(diagnostics)
        modifie = true
        enregistrer()
    }

    /// Note le relevé de l'app, écrit l'historique, puis envoie ce qui attend ; sans envoi à la
    /// fermeture de l'app (la requête ne survivrait pas au processus). Rend l'envoi lancé.
    @discardableResult
    public func releve(envoi: Bool = true) -> Task<Void, Never>? {
        let maintenant = horloge()
        if let source { historique.noter(source.releve(), le: aujourdhui(maintenant)) }
        modifie = true
        enregistrer()
        guard envoi else { return nil }
        return Task { await envoyerCeQuiAttend(maintenant: maintenant) }
    }

    // MARK: - Envoi

    /// Ce qui décrit cette installation ; `nil` sans version.
    public var contexte: ContexteDeTelemetrie? {
        guard let version else { return nil }
        return ContexteDeTelemetrie(service: service, installation: installation, version: version,
                                    distribution: configuration?.distribution)
    }

    /// Une seule requête : les jours en attente, sinon un diagnostic ; le reste attend les relevés
    /// suivants, sous le plafond de `HistoriqueDeTelemetrie.requetesParHeure`.
    private func envoyerCeQuiAttend(maintenant: Date) async {
        guard source?.partageActif == true, let configuration, !envoiEnCours, let contexte,
              let attente = historique.prochainEnvoi(aujourdhui: aujourdhui(maintenant))
        else { return }
        var envoi = completer(attente)
        var corps = corpsDe(envoi, contexte: contexte, maintenant: maintenant)
        // Des jours trop nombreux pour un corps : les plus anciens d'abord, la suite au relevé suivant.
        while corps.count > RapportDeTelemetrie.tailleMaximale, case .jours(let jours) = envoi, jours.count > 1 {
            envoi = .jours(Array(jours.dropLast()))
            corps = corpsDe(envoi, contexte: contexte, maintenant: maintenant)
        }
        guard historique.autoriserUneRequete(maintenant, attenteApresEchec: Self.attenteApresEchec) else { return }
        envoiEnCours = true
        defer { envoiEnCours = false }
        modifie = true
        enregistrer()
        var requete = URLRequest(url: configuration.url, timeoutInterval: 30)
        requete.httpMethod = "POST"
        requete.setValue("application/json", forHTTPHeaderField: "Content-Type")
        requete.setValue("Bearer \(configuration.jeton)", forHTTPHeaderField: "Authorization")
        requete.httpBody = corps
        switch ReponseDuCollecteur(statut: await self.envoi(requete)) {
        case .echec:
            historique.reprise = maintenant.addingTimeInterval(Self.attenteApresEchec)
        case .refusee:
            // Des jours refusés restent : ils sortent seuls de l'attente passé `retardMaximal`.
            // Un diagnostic le serait à chaque essai.
            if case .diagnostic = envoi {
                historique.acquitter(envoi)
            } else {
                historique.reprise = maintenant.addingTimeInterval(Self.attenteApresEchec)
            }
        case .acceptee:
            historique.acquitter(envoi)
            historique.reprise = nil
            historique.dernierEnvoi = maintenant
            historique.dernierRapport = RapportDeTelemetrie.texte(envoi.jours, diagnostics: envoi.diagnostics, contexte: contexte,
                                                                  espaceDesMesures: espaceDesMesures, envoi: maintenant)
        }
        modifie = true
        enregistrer()
    }

    /// Les mesures de chaque jour telles que l'app les donne maintenant, à défaut celles notées
    /// au dernier relevé : un relevé ne voit que le jour en cours, et seulement toutes les
    /// `intervalle`.
    private func completer(_ envoi: EnvoiDeTelemetrie) -> EnvoiDeTelemetrie {
        guard case .jours(var jours) = envoi, let source else { return envoi }
        for index in jours.indices {
            guard let mesures = source.mesures(jour: jours[index].jour) else { continue }
            jours[index].mesures = Dictionary(uniqueKeysWithValues: mesures.map { ($0.key.texte, $0.value) })
        }
        return .jours(jours)
    }

    private func corpsDe(_ envoi: EnvoiDeTelemetrie, contexte: ContexteDeTelemetrie, maintenant: Date) -> Data {
        RapportDeTelemetrie.corps(envoi.jours, diagnostics: envoi.diagnostics, contexte: contexte,
                                  espaceDesMesures: espaceDesMesures, envoi: maintenant)
    }

    public nonisolated static func poster(_ requete: URLRequest) async -> Int? {
        let reponse = try? await session.data(for: requete).1
        return (reponse as? HTTPURLResponse)?.statusCode
    }

    private nonisolated static let session = URLSession(configuration: .ephemeral)

    /// Le JSON du prochain envoi : les jours en attente, puis un diagnostic, à défaut la journée
    /// en cours telle qu'elle partira demain.
    public func apercuProchainEnvoi() -> String? {
        guard let contexte else { return nil }
        let maintenant = horloge()
        let jour = aujourdhui(maintenant)
        guard let attente = historique.prochainEnvoi(aujourdhui: jour) ?? historique.jour(jour).map({ EnvoiDeTelemetrie.jours([$0]) })
        else { return nil }
        let envoi = completer(attente)
        return RapportDeTelemetrie.texte(envoi.jours, diagnostics: envoi.diagnostics, contexte: contexte,
                                         espaceDesMesures: espaceDesMesures, envoi: maintenant)
    }

    // MARK: - Disque

    private func enregistrer() {
        guard modifie, let fichier else { return }
        modifie = false
        guard let data = try? Self.encodeur.encode(historique) else { return }
        try? FileManager.default.createDirectory(at: fichier.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fichier, options: .atomic)
    }

    private func aujourdhui(_ date: Date? = nil) -> String { JourDeTelemetrie.cle(date ?? horloge()) }

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
