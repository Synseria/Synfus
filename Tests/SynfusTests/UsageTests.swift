import Foundation
import Telemetrie
import Testing
@testable import Synfus

/// Les statistiques d'utilisation : les persos de chaque jour, la reprise de l'ancien
/// `usage.json`, et ce qui part au collecteur par la télémétrie commune (dont le paquet
/// teste le reste : débit, attente, diagnostics).
@MainActor
struct UsageTests {
    private final class StockageMemoire: PreferencesStore {
        private var contenu: [String: Data] = [:]
        func donnees(pour cle: String) -> Data? { contenu[cle] }
        func enregistrer(_ donnees: Data, pour cle: String) { contenu[cle] = donnees }
    }

    /// Le transport remplacé : les corps envoyés, une réponse acceptée.
    private final class Collecteur: @unchecked Sendable {
        private let verrou = NSLock()
        private var corps: [Data] = []
        var recus: [Data] { verrou.withLock { corps } }
        func recevoir(_ requete: URLRequest) -> Int? {
            verrou.withLock { corps.append(requete.httpBody ?? Data()) }
            return 200
        }
    }

    private let calendrier: Calendar = {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendrier
    }()

    /// Les clés que le collecteur garde (filtre de vraisemblance d'otel-edge).
    private static let clesAcceptees = #/^(installation\.id|jour|langue|persos\.(max|moyenne|joues)|reglage\.[a-z0-9_]+|usage\.[a-z0-9_]+|diagnostic\.(type|version|contenu))$/#

    /// Un `usage.json` tel que Synfus l'écrivait avant SynseriaKit.
    private static let ancienUsage = """
    {"depuis": "2026-11-08", "cumul": {"palette": 40}, "identifiantDeSecours": "SECOURS",
     "dernierEnvoi": "2026-11-09T08:00:00Z", "dernierRapport": "{}",
     "jours": [
       {"jour": "2026-11-08", "compteurs": {"palette": 2}, "persosMax": 4, "persosSecondes": 7200,
        "secondesAvecPersos": 2400, "persosJoues": ["Aeryn", "Nova"], "reglages": {"barre": true},
        "langue": "fr", "envoye": true},
       {"jour": "2026-11-09", "compteurs": {"chasse": 1}, "persosMax": 0, "persosSecondes": 0,
        "secondesAvecPersos": 0, "persosJoues": [], "envoye": true},
       {"jour": "2026-11-10", "compteurs": {"palette": 1}, "persosMax": 2, "persosSecondes": 600,
        "secondesAvecPersos": 300, "persosJoues": ["Aeryn"], "envoye": false}
     ]}
    """

    private func dossierTemporaire() throws -> URL {
        let dossier = FileManager.default.temporaryDirectory.appending(path: "SynfusUsage-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        return dossier
    }

    /// Une heure de novembre 2026, dans le fuseau du Mac : celui des clés de jour.
    private func date(_ jour: Int, _ heure: Int, _ minute: Int = 0) -> Date {
        JourDeTelemetrie.gregorien.date(from: DateComponents(year: 2026, month: 11, day: jour, hour: heure, minute: minute))!
    }

    // MARK: - Persos

    @Test("Effectif : maximum, moyenne pondérée par le temps, écart borné")
    func effectif() {
        var historique = HistoriquePersos()
        historique.noterEffectif(2, pendant: 600, le: "2026-11-10")
        historique.noterEffectif(4, pendant: 600, le: "2026-11-10")
        historique.noterEffectif(0, pendant: 600, le: "2026-11-10")
        // Une nuit de veille ne compte que pour l'écart maximal.
        historique.noterEffectif(4, pendant: 8 * 3600, le: "2026-11-10")
        let jour = historique.jour("2026-11-10")!
        #expect(jour.max == 4)
        let attendu = (2.0 * 600 + 4 * 600 + 4 * HistoriquePersos.ecartMaximal) / (1200 + HistoriquePersos.ecartMaximal)
        #expect(abs(jour.moyenne! - attendu) < 0.0001)
    }

    @Test("Un perso joué ne compte qu'une fois par jour ; les mesures n'en disent que le nombre")
    func persosJoues() {
        var historique = HistoriquePersos()
        for nom in ["Aeryn", "Nova", "Aeryn"] { historique.noterPersoJoue(nom, le: "2026-11-10") }
        historique.noterEffectif(2, pendant: 60, le: "2026-11-10")
        #expect(historique.jour("2026-11-10")?.joues.count == 2)
        #expect(historique.moyennes(sur: 7, aujourdhui: "2026-11-10", calendrier: calendrier)?.joues == 2)
        #expect(Self.textes(historique.jour("2026-11-10")!.mesures)
                == ["joues": .entier(2), "max": .entier(2), "moyenne": .reel(2)])
    }

    @Test("Sans perso connecté, max et joues partent à 0, sans moyenne")
    func mesuresAZero() {
        var historique = HistoriquePersos()
        historique.noterEffectif(0, pendant: 600, le: "2026-11-10")
        #expect(Self.textes(historique.jour("2026-11-10")!.mesures) == ["joues": .entier(0), "max": .entier(0)])
    }

    @Test("90 jours gardés, dans l'ordre même si l'horloge recule")
    func conservation() {
        var historique = HistoriquePersos()
        var jour = calendrier.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        for _ in 0..<(HistoriquePersos.conservation + 5) {
            historique.noterEffectif(1, pendant: 60, le: JourDeTelemetrie.cle(jour, calendrier: calendrier))
            jour = calendrier.date(byAdding: .day, value: 1, to: jour)!
        }
        #expect(historique.jours.count == HistoriquePersos.conservation)
        historique.noterEffectif(1, pendant: 60, le: "2026-03-20")
        #expect(historique.jours.map(\.jour) == historique.jours.map(\.jour).sorted())
    }

    @Test("persos.json se relit, champs absents à leur défaut")
    func relectureTolerante() throws {
        let json = #"{"jours": [{"jour": "2026-11-10", "max": 3, "futur": 1}], "autre": 2}"#
        let relu = try JSONDecoder().decode(HistoriquePersos.self, from: Data(json.utf8))
        #expect(relu.jour("2026-11-10")?.max == 3)
        #expect(relu.jour("2026-11-10")?.joues == [])
        #expect(try JSONDecoder().decode(HistoriquePersos.self, from: Data("{}".utf8)) == HistoriquePersos())
    }

    // MARK: - Reprise de l'ancien usage.json

    @Test("Les persos de l'ancien usage.json sont repris, jours sans perso exclus")
    func reprise() {
        let persos = HistoriquePersos.reprendre(Data(Self.ancienUsage.utf8))
        #expect(persos.jours.map(\.jour) == ["2026-11-08", "2026-11-10"])
        #expect(persos.jour("2026-11-08")?.max == 4)
        #expect(persos.jour("2026-11-08")?.moyenne == 3)
        #expect(persos.jour("2026-11-08")?.joues == ["Aeryn", "Nova"])
        #expect(persos.jour("2026-11-10")?.secondes == 600)
        #expect(HistoriquePersos.reprendre(Data("pas du json".utf8)) == HistoriquePersos())
    }

    @Test("Bascule : persos repris avant tout relevé, historique et installation relus, une seule fois")
    func bascule() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }
        try Data(Self.ancienUsage.utf8).write(to: dossier.appending(path: "usage.json"))
        let prefs = Preferences.forTesting(store: StockageMemoire())
        let midi = date(11, 12)

        let store = UsageStore(dossier: dossier, configuration: nil, version: "0.14.0", preferences: prefs,
                               materiel: "UUID-1", envoi: { _ in nil }, horloge: { midi })
        #expect(store.persos.jour("2026-11-08")?.joues.count == 2)
        #expect(FileManager.default.fileExists(atPath: dossier.appending(path: "persos.json").path))
        let historique = store.registre.historique
        #expect(historique.depuis == "2026-11-08")
        #expect(historique.dernierEnvoi != nil)
        #expect(historique.identifiantDeSecours == "SECOURS")
        #expect(historique.totaux(sur: nil, aujourdhui: "2026-11-11", calendrier: calendrier)[EvenementUsage.palette.cle] == 43)
        #expect(historique.aEnvoyer(aujourdhui: "2026-11-11").map(\.jour) == ["2026-11-10"])
        // La formule de l'ancien compte : SHA-256 de « bundle id:UUID matériel ».
        #expect(store.registre.contexte?.installation
                == IdentifiantDInstallation.calculer(materiel: "UUID-1", app: "fr.synseria.Synfus"))
        #expect(store.registre.contexte?.service.texte == "synfus")

        // Le registre réécrit usage.json sans les persos : la relance garde persos.json.
        store.noterEffectif(1)
        store.registre.releve(envoi: false)
        #expect(!(try String(contentsOf: dossier.appending(path: "usage.json"), encoding: .utf8)).contains("persosMax"))
        let relance = UsageStore(dossier: dossier, configuration: nil, version: "0.14.0", preferences: prefs,
                                 materiel: "UUID-1", envoi: { _ in nil }, horloge: { midi })
        #expect(relance.persos.jour("2026-11-08")?.max == 4)
        #expect(relance.persos.jour("2026-11-11")?.max == 1)
    }

    @Test("Des persos remis dans usage.json par une version d'avant sont repris, sans rien perdre ni doubler")
    func repriseApresRetour() throws {
        let dossier = try dossierTemporaire()
        defer { try? FileManager.default.removeItem(at: dossier) }
        var deja = HistoriquePersos()
        deja.noterPersoJoue("Nova", le: "2026-11-10")
        deja.noterEffectif(1, pendant: 60, le: "2026-11-10")
        deja.noterEffectif(5, pendant: 60, le: "2026-11-12")
        try JSONEncoder().encode(deja).write(to: dossier.appending(path: "persos.json"))
        try Data(Self.ancienUsage.utf8).write(to: dossier.appending(path: "usage.json"))
        let prefs = Preferences.forTesting(store: StockageMemoire())
        let midi = date(12, 12)

        let store = UsageStore(dossier: dossier, configuration: nil, version: nil, preferences: prefs,
                               materiel: "UUID-1", envoi: { _ in nil }, horloge: { midi })
        #expect(store.persos.jours.map(\.jour) == ["2026-11-08", "2026-11-10", "2026-11-12"])
        let dix = try #require(store.persos.jour("2026-11-10"))
        #expect(dix.joues == ["Nova", "Aeryn"])
        #expect(dix.secondesAvecPersos == 300 && dix.max == 2)
        #expect(store.persos.jour("2026-11-12")?.max == 5)

        let relance = UsageStore(dossier: dossier, configuration: nil, version: nil, preferences: prefs,
                                 materiel: "UUID-1", envoi: { _ in nil }, horloge: { midi })
        #expect(relance.persos == store.persos)
    }

    @Test("Hors de l'app signée (sous les tests), le compte vit en mémoire")
    func horsDeLApp() {
        #expect(UsageStore.shared.fichierPersos == nil)
        #expect(UsageStore.shared.registre.contexte == nil)
    }

    // MARK: - Ce qui part

    @Test("Le rapport d'un jour : service synfus, persos.*, réglages et compteurs, aucun nom de perso")
    func rapport() async throws {
        let collecteur = Collecteur()
        let horloge = Horloge(date(9, 20))
        let prefs = Preferences.forTesting(store: StockageMemoire())
        prefs.partagerStatistiques = true
        let configuration = ConfigurationDeTelemetrie(url: URL(string: "https://collecteur.invalid/v1/logs")!,
                                                      jeton: "jeton", distribution: .release)
        let store = UsageStore(dossier: nil, configuration: configuration, version: "0.14.0-rc.2", preferences: prefs,
                               materiel: "UUID-1", envoi: { collecteur.recevoir($0) }, horloge: { horloge.date })
        store.noterEffectif(3)
        store.noterPersoJoue("Aeryn")
        store.compter(.palette)
        horloge.date = date(9, 20, 10)
        await store.registre.releve()?.value
        #expect(collecteur.recus.isEmpty)
        horloge.date = date(10, 9)
        await store.registre.releve()?.value

        let data = try #require(collecteur.recus.first)
        #expect(!(String(bytes: data, encoding: .utf8) ?? "").contains("Aeryn"))
        let racine = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let ressource = try #require((racine["resourceLogs"] as? [[String: Any]])?.first)
        let attributsRessource = try #require((ressource["resource"] as? [String: Any])?["attributes"] as? [[String: Any]])
        var valeursRessource: [String: String] = [:]
        for attribut in attributsRessource {
            valeursRessource[attribut["key"] as? String ?? ""] = (attribut["value"] as? [String: Any])?["stringValue"] as? String
        }
        #expect(valeursRessource["service.name"] == "synfus")
        #expect(valeursRessource["service.version"] == "0.14.0-rc.2")
        #expect(valeursRessource["deployment.environment"] == "release")
        let enregistrement = try #require(
            ((ressource["scopeLogs"] as? [[String: Any]])?.first?["logRecords"] as? [[String: Any]])?.first)
        let attributs = try #require(enregistrement["attributes"] as? [[String: Any]])
        var valeurs: [String: [String: Any]] = [:]
        for attribut in attributs {
            let cle = try #require(attribut["key"] as? String)
            #expect(cle.wholeMatch(of: Self.clesAcceptees) != nil, "clé refusée par le collecteur : \(cle)")
            valeurs[cle] = attribut["value"] as? [String: Any]
        }
        #expect(valeurs["jour"]?["stringValue"] as? String == "2026-11-09")
        #expect(valeurs["usage.palette"]?["intValue"] as? String == "1")
        #expect(valeurs["persos.max"]?["intValue"] as? String == "3")
        #expect(valeurs["persos.joues"]?["intValue"] as? String == "1")
        #expect(valeurs["persos.moyenne"]?["doubleValue"] as? Double == 3)
        #expect(valeurs["reglage.barre"]?["boolValue"] as? Bool == prefs.barVisible)
        #expect(valeurs["installation.id"]?["stringValue"] as? String
                == IdentifiantDInstallation.calculer(materiel: "UUID-1", app: "fr.synseria.Synfus"))
    }

    @Test("Partage coupé : le compte continue, rien ne part")
    func partageCoupe() async {
        let collecteur = Collecteur()
        let horloge = Horloge(date(9, 20))
        let prefs = Preferences.forTesting(store: StockageMemoire())
        prefs.partagerStatistiques = false
        let configuration = ConfigurationDeTelemetrie(url: URL(string: "https://collecteur.invalid")!,
                                                      jeton: "jeton", distribution: .local)
        let store = UsageStore(dossier: nil, configuration: configuration, version: "0.14.0", preferences: prefs,
                               materiel: "UUID-1", envoi: { collecteur.recevoir($0) }, horloge: { horloge.date })
        store.noterEffectif(1)
        store.compter(.chasse)
        horloge.date = date(10, 9)
        await store.registre.releve()?.value
        #expect(collecteur.recus.isEmpty)
        #expect(store.registre.historique.jour("2026-11-09")?.nombre(EvenementUsage.chasse.cle) == 1)
    }

    @Test("Tout compteur et tout réglage a une clé que le collecteur garde, telle quelle")
    func clesDuCollecteur() {
        for evenement in EvenementUsage.allCases {
            #expect(evenement.cle.texte == evenement.rawValue, "\(evenement)")
            #expect("usage.\(evenement.cle.texte)".wholeMatch(of: Self.clesAcceptees) != nil, "\(evenement)")
        }
        let prefs = Preferences.forTesting(store: StockageMemoire())
        let reglages = UsageStore.reglages(prefs, demarrageAuto: false)
        #expect(reglages.count == 19)
        for cle in reglages.keys {
            #expect("reglage.\(cle.texte)".wholeMatch(of: Self.clesAcceptees) != nil, "\(cle)")
        }
    }

    private static func textes(_ mesures: [CleDeTelemetrie: ValeurDeTelemetrie]) -> [String: ValeurDeTelemetrie] {
        mesures.reduce(into: [:]) { $0[$1.key.texte] = $1.value }
    }

    /// L'instant que voient le registre et le store, avancé par le test.
    private final class Horloge {
        var date: Date
        init(_ date: Date) { self.date = date }
    }
}
