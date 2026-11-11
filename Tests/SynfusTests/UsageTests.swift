import Foundation
import Testing
@testable import Synfus

/// Les statistiques d'utilisation : le compte par jour, ce qui part, ce qui
/// reste sur le Mac.
@MainActor
struct UsageTests {
    private final class StockageMemoire: PreferencesStore {
        private var contenu: [String: Data] = [:]
        func donnees(pour cle: String) -> Data? { contenu[cle] }
        func enregistrer(_ donnees: Data, pour cle: String) { contenu[cle] = donnees }
    }

    private let calendrier: Calendar = {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = TimeZone(identifier: "Europe/Paris")!
        return calendrier
    }()

    private let contexte = ContexteUsage(installation: String(repeating: "a", count: 64), version: "0.13.0",
                                         systeme: "26.1", architecture: "arm64")

    /// Les clés que le collecteur garde (liste du collecteur de bord).
    private static let clesAcceptees = #/^(installation\.id|jour|langue|persos\.(max|moyenne|joues)|reglage\.[a-z0-9_]+|usage\.[a-z0-9_]+|diagnostic\.(type|version|contenu))$/#

    @Test("Les gestes se comptent par jour, et par période")
    func compte() {
        var historique = HistoriqueUsage()
        historique.compter(.palette, le: "2026-11-01")
        historique.compter(.palette, le: "2026-11-09")
        historique.compter(.palette, le: "2026-11-10")
        historique.compter(.basculeBarre, le: "2026-11-10")
        #expect(historique.totaux(sur: 7, aujourdhui: "2026-11-10", calendrier: calendrier)
                == [.palette: 2, .basculeBarre: 1])
        #expect(historique.totaux(sur: nil, aujourdhui: "2026-11-10", calendrier: calendrier)[.palette] == 3)
        #expect(historique.depuis == "2026-11-01")
    }

    @Test("Partent les jours terminés, pas encore acceptés, sept au plus")
    func aEnvoyer() {
        var historique = HistoriqueUsage()
        for jour in 1...10 { historique.compter(.palette, le: String(format: "2026-11-%02d", jour)) }
        let enAttente = historique.aEnvoyer(aujourdhui: "2026-11-10")
        #expect(enAttente.map(\.jour) == (3...9).map { String(format: "2026-11-%02d", $0) })
        historique.marquerEnvoyes(["2026-11-08", "2026-11-09"])
        #expect(historique.aEnvoyer(aujourdhui: "2026-11-10").last?.jour == "2026-11-07")
    }

    @Test("Au-delà de la conservation, les jours fondent dans le cumul")
    func conservation() {
        var historique = HistoriqueUsage()
        var date = calendrier.date(from: DateComponents(year: 2026, month: 1, day: 1))!
        for _ in 0..<(HistoriqueUsage.conservation + 5) {
            historique.compter(.chasse, le: JourUsage.cle(date, calendrier: calendrier))
            date = calendrier.date(byAdding: .day, value: 1, to: date)!
        }
        #expect(historique.jours.count == HistoriqueUsage.conservation)
        #expect(historique.cumul["chasse"] == 5)
        #expect(historique.totaux(sur: nil, aujourdhui: "2027-01-01", calendrier: calendrier)[.chasse]
                == HistoriqueUsage.conservation + 5)
    }

    @Test("Un jour qui arrive en retard (horloge reculée) reste à sa place")
    func ordre() {
        var historique = HistoriqueUsage()
        historique.compter(.palette, le: "2026-11-10")
        historique.compter(.palette, le: "2026-11-08")
        #expect(historique.jours.map(\.jour) == ["2026-11-08", "2026-11-10"])
    }

    @Test("Effectif : maximum, moyenne pondérée par le temps, écart borné")
    func effectif() {
        var historique = HistoriqueUsage()
        historique.noterEffectif(2, pendant: 600, le: "2026-11-10")
        historique.noterEffectif(4, pendant: 600, le: "2026-11-10")
        historique.noterEffectif(0, pendant: 600, le: "2026-11-10")
        // Une nuit de veille ne compte que pour l'écart maximal.
        historique.noterEffectif(4, pendant: 8 * 3600, le: "2026-11-10")
        let jour = historique.jour("2026-11-10")!
        #expect(jour.persosMax == 4)
        let attendu = (2.0 * 600 + 4 * 600 + 4 * HistoriqueUsage.ecartMaximal) / (1200 + HistoriqueUsage.ecartMaximal)
        #expect(abs(jour.persosMoyenne! - attendu) < 0.0001)
    }

    @Test("Un perso joué ne compte qu'une fois par jour")
    func persosJoues() {
        var historique = HistoriqueUsage()
        for nom in ["Aeryn", "Nova", "Aeryn"] { historique.noterPersoJoue(nom, le: "2026-11-10") }
        historique.noterEffectif(2, pendant: 60, le: "2026-11-10")
        #expect(historique.jour("2026-11-10")?.persosJoues.count == 2)
        #expect(historique.moyennesPersos(sur: 7, aujourdhui: "2026-11-10", calendrier: calendrier)?.joues == 2)
    }

    @Test("L'historique se relit tel qu'il a été écrit, clés inconnues comprises")
    func relecture() throws {
        var historique = HistoriqueUsage()
        historique.compter(.rangement, le: "2026-11-10")
        var data = try JSONEncoder().encode(historique)
        let texte = (String(bytes: data, encoding: .utf8) ?? "").replacingOccurrences(of: "\"rangement\"", with: "\"futur\"")
        data = Data(texte.utf8)
        let relu = try JSONDecoder().decode(HistoriqueUsage.self, from: data)
        #expect(relu.jour("2026-11-10")?.compteurs == ["futur": 1])
        #expect(relu.totaux(sur: nil, aujourdhui: "2026-11-10", calendrier: calendrier).isEmpty)
    }

    @Test("Le rapport : OTLP JSON, seulement des clés que le collecteur garde, aucun nom de perso")
    func rapport() throws {
        var historique = HistoriqueUsage()
        historique.compter(.palette, le: "2026-11-09")
        historique.noterPersoJoue("Aeryn", le: "2026-11-09")
        historique.noterEffectif(3, pendant: 600, le: "2026-11-09")
        historique.noterReglages(["lire_position": true], langue: "fr", le: "2026-11-09")
        let envoi = Date(timeIntervalSince1970: 1_762_732_800)
        let data = RapportUsage.corps(historique.aEnvoyer(aujourdhui: "2026-11-10"), contexte: contexte, envoi: envoi)
        #expect(!(String(bytes: data, encoding: .utf8) ?? "").contains("Aeryn"))

        let racine = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let ressource = try #require((racine["resourceLogs"] as? [[String: Any]])?.first)
        let attributsRessource = try #require((ressource["resource"] as? [String: Any])?["attributes"] as? [[String: Any]])
        #expect(Set(attributsRessource.compactMap { $0["key"] as? String })
                == ["service.name", "service.version", "os.version", "host.arch"])
        let enregistrement = try #require(
            ((ressource["scopeLogs"] as? [[String: Any]])?.first?["logRecords"] as? [[String: Any]])?.first)
        #expect(enregistrement["timeUnixNano"] as? String == "1762732800000000000")
        #expect((enregistrement["body"] as? [String: Any])?["stringValue"] as? String == "rapport")
        let attributs = try #require(enregistrement["attributes"] as? [[String: Any]])
        var valeurs: [String: [String: Any]] = [:]
        for attribut in attributs {
            let cle = try #require(attribut["key"] as? String)
            #expect(cle.wholeMatch(of: Self.clesAcceptees) != nil, "clé refusée par le collecteur : \(cle)")
            valeurs[cle] = attribut["value"] as? [String: Any]
        }
        #expect(valeurs["usage.palette"]?["intValue"] as? String == "1")
        #expect(valeurs["persos.joues"]?["intValue"] as? String == "1")
        #expect(valeurs["persos.moyenne"]?["doubleValue"] as? Double == 3)
        #expect(valeurs["reglage.lire_position"]?["boolValue"] as? Bool == true)
        #expect(valeurs["jour"]?["stringValue"] as? String == "2026-11-09")
    }

    @Test("Diagnostics : dix gardés au plus, un par envoi, coupés sous la limite du collecteur")
    func diagnostics() throws {
        var historique = HistoriqueUsage()
        let long = Data(("{\"x\":\"" + String(repeating: "a", count: 60_000) + "\"}").utf8)
        historique.ajouter((0..<12).map { DiagnosticUsage(genre: .plantage, version: "0.13.\($0)", json: long) })
        #expect(historique.diagnostics.count == HistoriqueUsage.diagnosticsMaximum)
        let premier = try #require(historique.diagnosticAEnvoyer)
        #expect(premier.version == "0.13.2")
        #expect(premier.contenu.count == DiagnosticUsage.tailleMaximale)

        let data = RapportUsage.corps([], diagnostics: [premier], contexte: contexte, envoi: Date())
        #expect(data.count < 65_536)
        let texte = String(bytes: data, encoding: .utf8) ?? ""
        #expect(texte.contains("\"stringValue\":\"diagnostic\""))
        for (cle, _) in RapportUsage.attributs(premier, installation: contexte.installation) {
            #expect(cle.wholeMatch(of: Self.clesAcceptees) != nil, "\(cle)")
        }
        historique.retirerDiagnostic(premier)
        #expect(historique.diagnosticAEnvoyer?.version == "0.13.3")
    }

    @Test("Tout compteur et tout réglage a une clé que le collecteur garde")
    func clesDuCollecteur() {
        for evenement in EvenementUsage.allCases {
            #expect("usage.\(evenement.rawValue)".wholeMatch(of: Self.clesAcceptees) != nil, "\(evenement)")
        }
        let prefs = Preferences.forTesting(store: StockageMemoire())
        for cle in UsageStore.reglages(prefs, demarrageAuto: false).keys {
            #expect("reglage.\(cle)".wholeMatch(of: Self.clesAcceptees) != nil, "\(cle)")
        }
    }

    @Test("L'identifiant : stable, propre à l'app, 64 caractères hexadécimaux")
    func identifiant() {
        let a = IdentifiantInstallation.calculer(materiel: "UUID-1", app: "fr.synseria.Synfus")
        #expect(a == IdentifiantInstallation.calculer(materiel: "UUID-1", app: "fr.synseria.Synfus"))
        #expect(a != IdentifiantInstallation.calculer(materiel: "UUID-1", app: "fr.synseria.Autre"))
        #expect(a.wholeMatch(of: #/[0-9a-f]{64}/#) != nil)
    }

    @Test("Le jour : fuseau de l'utilisateur, et décalage d'une clé")
    func jours() {
        let date = calendrier.date(from: DateComponents(year: 2026, month: 3, day: 1, hour: 0, minute: 30))!
        #expect(JourUsage.cle(date, calendrier: calendrier) == "2026-03-01")
        #expect(HistoriqueUsage.decaler("2026-03-01", de: -1, calendrier: calendrier) == "2026-02-28")
    }

    @Test("La clé d'un jour est grégorienne, même sur un Mac en calendrier bouddhiste")
    func calendrierGregorien() {
        #expect(JourUsage.gregorien.identifier == .gregorian)
        #expect(JourUsage.gregorien.timeZone == .current)
        var bouddhiste = Calendar(identifier: .buddhist)
        bouddhiste.timeZone = .current
        let date = JourUsage.date("2026-11-10")!
        #expect(JourUsage.cle(date) == "2026-11-10")
        #expect(JourUsage.cle(date, calendrier: bouddhiste) != "2026-11-10")
    }
}
