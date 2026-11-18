// Copié de SynseriaKit (Synseria-Design) — ne pas retoucher : changer le paquet dans Synseria-Design, puis sh propager.sh.
// SynseriaKit ac80a4e0b47b7314 · contenu 52e596c786f964d3
// Ce qui se compte, jour par jour, gardé sur le Mac ; ce qui reste à envoyer (pur).

import Foundation

/// Une journée d'utilisation, dans le fuseau de l'utilisateur.
public struct JourDeTelemetrie: Codable, Equatable, Sendable {
    /// `2026-11-09` (`JourDeTelemetrie.cle`).
    public let jour: String
    /// Par `CleDeTelemetrie.texte` : une clé inconnue (version plus récente relue par une plus
    /// ancienne) se garde sans casser la lecture.
    public internal(set) var compteurs: [String: Int] = [:]
    /// Les réglages en vigueur au dernier relevé de la journée.
    public internal(set) var reglages: [String: Bool] = [:]
    /// Les mesures propres à l'app au dernier relevé (effectifs, moyennes), déjà calculées par elle.
    public internal(set) var mesures: [String: ValeurDeTelemetrie] = [:]
    /// La langue de l'interface, jamais celle d'un texte de l'utilisateur.
    public internal(set) var langue: String?
    public internal(set) var envoye = false

    public init(jour: String) { self.jour = jour }

    public func nombre(_ cle: CleDeTelemetrie) -> Int { compteurs[cle.texte] ?? 0 }

    /// Grégorien quel que soit le calendrier du Mac (bouddhiste, japonais…) : les clés se
    /// comparent en texte et partent telles quelles au collecteur. Le fuseau, lui, est celui de
    /// l'utilisateur : sa journée.
    public static var gregorien: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .current
        return calendrier
    }

    public static func date(_ cle: String, calendrier: Calendar = gregorien) -> Date? {
        let parties = cle.split(separator: "-").compactMap { Int($0) }
        guard parties.count == 3 else { return nil }
        return calendrier.date(from: DateComponents(year: parties[0], month: parties[1], day: parties[2]))
    }

    public static func cle(_ date: Date, calendrier: Calendar = gregorien) -> String {
        let c = calendrier.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// Ce que porte une requête au collecteur.
public enum EnvoiDeTelemetrie: Equatable, Sendable {
    case jours([JourDeTelemetrie])
    case diagnostic(DiagnosticDeTelemetrie)

    var jours: [JourDeTelemetrie] {
        if case .jours(let jours) = self { return jours }
        return []
    }

    var diagnostics: [DiagnosticDeTelemetrie] {
        if case .diagnostic(let diagnostic) = self { return [diagnostic] }
        return []
    }
}

/// L'historique gardé sur le Mac : le détail des derniers jours, le cumul des plus anciens.
/// Les rapports partent d'ici ; l'écran des statistiques de l'app peut s'y lire.
public struct HistoriqueDeTelemetrie: Codable, Equatable, Sendable {
    /// Du plus ancien au plus récent, sans trou de clé ni doublon.
    public private(set) var jours: [JourDeTelemetrie] = []
    /// Les compteurs des jours sortis du détail.
    public private(set) var cumul: [String: Int] = [:]
    /// Le premier jour compté.
    public private(set) var depuis: String?
    /// Le JSON exact du dernier envoi accepté, et sa date.
    public internal(set) var dernierEnvoi: Date?
    public internal(set) var dernierRapport: String?
    /// Tiré au hasard si le Mac ne donne pas son UUID matériel.
    public internal(set) var identifiantDeSecours: String?
    /// Les rapports de MetricKit pas encore acceptés, les plus récents gardés.
    public private(set) var diagnostics: [DiagnosticDeTelemetrie] = []
    /// Les instants des requêtes parties dans l'heure, notés avant l'envoi : le plafond tient
    /// d'une relance de l'app à l'autre.
    public private(set) var requetes: [Date] = []
    /// Après un échec, rien ne part avant cet instant.
    public internal(set) var reprise: Date?

    public static let diagnosticsMaximum = 10
    /// Jours gardés en détail ; au-delà, ils fondent dans `cumul`.
    public static let conservation = 90
    /// Un rapport en retard part encore pendant ce nombre de jours.
    public static let retardMaximal = 7
    /// Le collecteur fait bannir par CrowdSec (`domus/telemetrie-flood`) l'IP qui dépasse environ
    /// 10 requêtes par heure, et toutes les apps Synseria d'un Mac partagent la sienne : 3 par app
    /// en laisse passer trois sous le seuil.
    public static let requetesParHeure = 3

    public init() {}

    mutating func ajouter(_ nouveaux: [DiagnosticDeTelemetrie]) {
        diagnostics = Array((diagnostics + nouveaux).suffix(Self.diagnosticsMaximum))
    }

    /// Les jours en attente d'abord, tous dans un même corps, puis les diagnostics, un par envoi :
    /// chacun dans sa requête, pour qu'un diagnostic refusé ne retienne jamais les jours, et que
    /// le corps reste sous la limite du collecteur.
    public func prochainEnvoi(aujourdhui: String) -> EnvoiDeTelemetrie? {
        let jours = aEnvoyer(aujourdhui: aujourdhui)
        if !jours.isEmpty { return .jours(jours) }
        return diagnostics.first.map(EnvoiDeTelemetrie.diagnostic)
    }

    /// L'envoi sort de l'attente : accepté, ou refusé pour de bon.
    mutating func acquitter(_ envoi: EnvoiDeTelemetrie) {
        switch envoi {
        case .jours(let jours):
            let cles = Set(jours.map(\.jour))
            for index in self.jours.indices where cles.contains(self.jours[index].jour) { self.jours[index].envoye = true }
        case .diagnostic(let diagnostic):
            if let index = diagnostics.firstIndex(of: diagnostic) { diagnostics.remove(at: index) }
        }
    }

    /// Note une requête à `maintenant` si le débit le permet : pas d'attente après échec en cours,
    /// moins de `requetesParHeure` dans l'heure glissante. Une horloge remise en arrière ne
    /// bloque pas : un instant noté dans le futur est oublié.
    mutating func autoriserUneRequete(_ maintenant: Date, attenteApresEchec: TimeInterval) -> Bool {
        requetes.removeAll { $0 > maintenant || maintenant.timeIntervalSince($0) >= 3600 }
        if let reprise, reprise.timeIntervalSince(maintenant) > attenteApresEchec { self.reprise = nil }
        if let reprise, maintenant < reprise { return false }
        guard requetes.count < Self.requetesParHeure else { return false }
        requetes.append(maintenant)
        return true
    }

    mutating func compter(_ cle: CleDeTelemetrie, de nombre: Int = 1, le jour: String) {
        modifier(jour) { $0.compteurs[cle.texte, default: 0] += nombre }
    }

    mutating func noter(_ releve: ReleveDeLApp, le jour: String) {
        modifier(jour) {
            $0.reglages = Dictionary(uniqueKeysWithValues: releve.reglages.map { ($0.key.texte, $0.value) })
            $0.mesures = Dictionary(uniqueKeysWithValues: releve.mesures.map { ($0.key.texte, $0.value) })
            $0.langue = releve.langue
        }
    }

    /// Les jours terminés qui n'ont pas encore été acceptés par le collecteur, dans la limite
    /// du retard permis : un jour refusé en sort seul, sans retenir les suivants.
    public func aEnvoyer(aujourdhui: String) -> [JourDeTelemetrie] {
        let premier = Self.decaler(aujourdhui, de: -Self.retardMaximal)
        return jours.filter { !$0.envoye && $0.jour < aujourdhui && $0.jour >= premier }
    }

    /// Les compteurs des `nombreDeJours` derniers jours jusqu'à `aujourdhui` compris, ou de tout
    /// l'historique (`nil`).
    public func totaux(sur nombreDeJours: Int?, aujourdhui: String,
                       calendrier: Calendar = JourDeTelemetrie.gregorien) -> [CleDeTelemetrie: Int] {
        var bruts: [String: Int] = [:]
        if let nombreDeJours {
            let debut = Self.decaler(aujourdhui, de: -(nombreDeJours - 1), calendrier: calendrier)
            for jour in jours where jour.jour >= debut && jour.jour <= aujourdhui {
                bruts.merge(jour.compteurs, uniquingKeysWith: +)
            }
        } else {
            bruts = cumul
            for jour in jours { bruts.merge(jour.compteurs, uniquingKeysWith: +) }
        }
        return bruts.reduce(into: [:]) { totaux, paire in
            if let cle = CleDeTelemetrie(paire.key) { totaux[cle] = paire.value }
        }
    }

    public func jour(_ cle: String) -> JourDeTelemetrie? { jours.last(where: { $0.jour == cle }) }

    private mutating func modifier(_ cle: String, _ changement: (inout JourDeTelemetrie) -> Void) {
        if depuis == nil { depuis = cle }
        if let index = jours.lastIndex(where: { $0.jour == cle }) {
            changement(&jours[index])
            return
        }
        var nouveau = JourDeTelemetrie(jour: cle)
        changement(&nouveau)
        // Une horloge remise en arrière ne crée pas un jour hors d'ordre.
        let rang = jours.firstIndex(where: { $0.jour > cle }) ?? jours.endIndex
        jours.insert(nouveau, at: rang)
        while jours.count > Self.conservation {
            cumul.merge(jours.removeFirst().compteurs, uniquingKeysWith: +)
        }
    }

    static func decaler(_ cle: String, de jours: Int, calendrier: Calendar = JourDeTelemetrie.gregorien) -> String {
        guard let date = JourDeTelemetrie.date(cle, calendrier: calendrier),
              let decalee = calendrier.date(byAdding: .day, value: jours, to: date)
        else { return cle }
        return JourDeTelemetrie.cle(decalee, calendrier: calendrier)
    }
}

// Relecture tolérante du fichier : un champ ajouté par une version plus récente (ou retiré)
// prend son défaut au lieu de faire échouer toute la lecture — que le registre remplacerait
// alors par un historique vide, identifiant de secours compris.

extension JourDeTelemetrie {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(jour: try c.decode(String.self, forKey: .jour))
        compteurs = c.valeur(.compteurs, sinon: compteurs)
        reglages = c.valeur(.reglages, sinon: reglages)
        mesures = c.valeur(.mesures, sinon: mesures)
        langue = c.valeur(.langue, sinon: langue)
        envoye = c.valeur(.envoye, sinon: envoye)
    }
}

extension HistoriqueDeTelemetrie {
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        jours = c.valeur(.jours, sinon: jours)
        cumul = c.valeur(.cumul, sinon: cumul)
        depuis = c.valeur(.depuis, sinon: depuis)
        dernierEnvoi = c.valeur(.dernierEnvoi, sinon: dernierEnvoi)
        dernierRapport = c.valeur(.dernierRapport, sinon: dernierRapport)
        identifiantDeSecours = c.valeur(.identifiantDeSecours, sinon: identifiantDeSecours)
        diagnostics = c.valeur(.diagnostics, sinon: diagnostics)
        requetes = c.valeur(.requetes, sinon: requetes)
        reprise = c.valeur(.reprise, sinon: reprise)
    }
}

private extension KeyedDecodingContainer {
    /// Le champ, ou `defaut` s'il est absent ou illisible.
    func valeur<T: Decodable>(_ cle: Key, sinon defaut: T) -> T {
        (try? decodeIfPresent(T.self, forKey: cle)) ?? defaut
    }
}
