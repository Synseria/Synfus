// Les persos connectés et joués, jour par jour, gardés sur le Mac (pur) : le paquet de
// télémétrie ne tient que l'instantané des mesures, le cumul d'une journée vit ici.

import Foundation
import Telemetrie

/// Une journée de persos, dans le fuseau de l'utilisateur.
struct JourPersos: Codable, Equatable, Sendable {
    /// `2026-11-09` (`JourDeTelemetrie.cle`).
    let jour: String
    var max = 0
    /// Intégrale du nombre de persos connectés sur le temps, et temps passé avec au moins
    /// un perso : leur rapport est la moyenne de la journée.
    var secondes: Double = 0
    var secondesAvecPersos: Double = 0
    /// Les noms ne quittent jamais le Mac : seul leur nombre part.
    var joues: [String] = []

    init(jour: String) { self.jour = jour }

    var moyenne: Double? { secondesAvecPersos > 0 ? secondes / secondesAvecPersos : nil }

    /// `max` et `joues` toujours, `moyenne` arrondie au centième si un perso était connecté :
    /// les clés `persos.*` que le collecteur garde.
    var mesures: [CleDeTelemetrie: ValeurDeTelemetrie] {
        var mesures: [CleDeTelemetrie: ValeurDeTelemetrie] = [
            CleDeTelemetrie(convertissant: "max"): .entier(max),
            CleDeTelemetrie(convertissant: "joues"): .entier(joues.count),
        ]
        if let moyenne { mesures[CleDeTelemetrie(convertissant: "moyenne")] = .reel((moyenne * 100).rounded() / 100) }
        return mesures
    }
}

/// L'historique des persos : 90 jours, du plus ancien au plus récent.
struct HistoriquePersos: Codable, Equatable, Sendable {
    private(set) var jours: [JourPersos] = []

    static let conservation = 90
    /// Un écart plus long entre deux relevés de l'effectif (veille, Mac suspendu) ne compte
    /// que pour cette durée.
    static let ecartMaximal: TimeInterval = 15 * 60

    init() {}

    func jour(_ cle: String) -> JourPersos? { jours.last { $0.jour == cle } }

    mutating func noterPersoJoue(_ nom: String, le jour: String) {
        modifier(jour) { if !$0.joues.contains(nom) { $0.joues.append(nom) } }
    }

    /// `persos` connectés pendant `duree` (bornée par `ecartMaximal`), jusqu'au relevé de `jour`.
    mutating func noterEffectif(_ persos: Int, pendant duree: TimeInterval, le jour: String) {
        let duree = min(Swift.max(duree, 0), Self.ecartMaximal)
        modifier(jour) {
            $0.max = Swift.max($0.max, persos)
            guard persos > 0 else { return }
            $0.secondes += Double(persos) * duree
            $0.secondesAvecPersos += duree
        }
    }

    /// Moyenne, sur les jours de la période où un perso au moins était connecté, du nombre de
    /// persos connectés et du nombre de persos joués ; `nombreDeJours` `nil` : tout l'historique.
    func moyennes(sur nombreDeJours: Int?, aujourdhui: String,
                  calendrier: Calendar = JourDeTelemetrie.gregorien) -> (connectes: Double, joues: Double)? {
        let debut = nombreDeJours.map { Self.decaler(aujourdhui, de: -($0 - 1), calendrier: calendrier) } ?? ""
        let actifs = jours.filter { $0.jour >= debut && $0.jour <= aujourdhui && $0.moyenne != nil }
        guard !actifs.isEmpty else { return nil }
        let n = Double(actifs.count)
        return (actifs.compactMap(\.moyenne).reduce(0, +) / n, Double(actifs.map(\.joues.count).reduce(0, +)) / n)
    }

    private mutating func modifier(_ cle: String, _ changement: (inout JourPersos) -> Void) {
        if let index = jours.lastIndex(where: { $0.jour == cle }) {
            changement(&jours[index])
            return
        }
        var nouveau = JourPersos(jour: cle)
        changement(&nouveau)
        // Une horloge remise en arrière ne crée pas un jour hors d'ordre.
        let rang = jours.firstIndex { $0.jour > cle } ?? jours.endIndex
        jours.insert(nouveau, at: rang)
        if jours.count > Self.conservation { jours.removeFirst(jours.count - Self.conservation) }
    }

    static func decaler(_ cle: String, de jours: Int, calendrier: Calendar = JourDeTelemetrie.gregorien) -> String {
        guard let date = JourDeTelemetrie.date(cle, calendrier: calendrier),
              let decalee = calendrier.date(byAdding: .day, value: jours, to: date)
        else { return cle }
        return JourDeTelemetrie.cle(decalee, calendrier: calendrier)
    }

    // MARK: - Reprise de l'ancien `usage.json`

    /// Les jours de `autre` ajoutés ; un jour déjà là garde le plus long relevé et l'union des
    /// noms. Rien ne se retire : reprendre deux fois ne change rien.
    mutating func fusionner(_ autre: HistoriquePersos) {
        for jour in autre.jours {
            modifier(jour.jour) { present in
                let joues = present.joues + jour.joues.filter { !present.joues.contains($0) }
                if jour.secondesAvecPersos > present.secondesAvecPersos {
                    present.secondes = jour.secondes
                    present.secondesAvecPersos = jour.secondesAvecPersos
                }
                present.max = Swift.max(present.max, jour.max)
                present.joues = joues
            }
        }
    }

    /// Les persos que l'`usage.json` d'avant SynseriaKit gardait dans chaque jour (`persosMax`,
    /// `persosSecondes`, `secondesAvecPersos`, `persosJoues`) : le registre commun ne les connaît
    /// pas et les efface à sa première écriture. Un fichier illisible ne rend rien.
    static func reprendre(_ ancien: Data) -> HistoriquePersos {
        struct Ancien: Decodable {
            struct Jour: Decodable {
                let jour: String
                let persosMax: Int?
                let persosSecondes: Double?
                let secondesAvecPersos: Double?
                let persosJoues: [String]?
            }
            let jours: [Jour]?
        }
        var historique = HistoriquePersos()
        for ancien in (try? JSONDecoder().decode(Ancien.self, from: ancien))?.jours ?? [] {
            var jour = JourPersos(jour: ancien.jour)
            jour.max = ancien.persosMax ?? 0
            jour.secondes = ancien.persosSecondes ?? 0
            jour.secondesAvecPersos = ancien.secondesAvecPersos ?? 0
            jour.joues = ancien.persosJoues ?? []
            guard jour.max > 0 || jour.secondesAvecPersos > 0 || !jour.joues.isEmpty else { continue }
            historique.modifier(jour.jour) { $0 = jour }
        }
        return historique
    }
}

// Relecture tolérante : un champ absent ou illisible prend son défaut au lieu de faire échouer
// toute la lecture, que `UsageStore` remplacerait alors par un historique vide.

extension JourPersos {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(jour: try c.decode(String.self, forKey: .jour))
        max = (try? c.decodeIfPresent(Int.self, forKey: .max)) ?? 0
        secondes = (try? c.decodeIfPresent(Double.self, forKey: .secondes)) ?? 0
        secondesAvecPersos = (try? c.decodeIfPresent(Double.self, forKey: .secondesAvecPersos)) ?? 0
        joues = (try? c.decodeIfPresent([String].self, forKey: .joues)) ?? []
    }
}

extension HistoriquePersos {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        jours = (try? c.decodeIfPresent([JourPersos].self, forKey: .jours)) ?? []
    }
}
