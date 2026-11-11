// Statistiques d'utilisation : ce qui se compte, jour par jour (pur).

import Foundation

/// Tout ce que Synfus compte, et rien d'autre : la liste fermée de ce qui peut
/// partir dans un rapport (`usage.<rawValue>`). Un compteur ajouté ici doit
/// l'être aussi à la liste des clés acceptées du collecteur.
enum EvenementUsage: String, CaseIterable, Codable, Sendable {
    // Bascules, par geste.
    case basculeRaccourci = "bascule_raccourci"
    case basculeBarre = "bascule_barre"
    case basculeMenu = "bascule_menu"
    case basculeAttention = "bascule_attention"
    case rotationRaccourci = "rotation_raccourci"
    case rotationClic = "rotation_clic"
    case session
    case equipeSuivante = "equipe_suivante"
    case rangement
    // Palette : ouverture, puis le genre de l'entrée choisie.
    case palette
    case paletteZaap = "palette_zaap"
    case paletteLieu = "palette_lieu"
    case paletteCommande = "palette_commande"
    case paletteVariable = "palette_variable"
    case palettePerso = "palette_perso"
    case paletteAction = "palette_action"
    case paletteRecent = "palette_recent"
    case paletteQuete = "palette_quete"
    case palettePNJ = "palette_pnj"
    case paletteMonstre = "palette_monstre"
    case paletteObjet = "palette_objet"
    // Outils.
    case trajetCopie = "trajet_copie"
    case trajetReecrit = "trajet_reecrit"
    case invitation
    case chasse
    case quetes
    case bossHarebourg = "boss_harebourg"
    case bossKimbo = "boss_kimbo"
    case bossToxoliath = "boss_toxoliath"
    case bossIlyzaelle = "boss_ilyzaelle"
    case bossTalKasha = "boss_tal_kasha"
    case apercu
    case apercuGrille = "apercu_grille"
    case reglages
    case miseAJour = "mise_a_jour"

    /// Les rubriques de l'onglet Usage.
    enum Famille: CaseIterable, Sendable { case bascules, palette, outils }

    var famille: Famille {
        switch self {
        case .basculeRaccourci, .basculeBarre, .basculeMenu, .basculeAttention, .rotationRaccourci,
             .rotationClic, .session, .equipeSuivante, .rangement:
            return .bascules
        case .palette, .paletteZaap, .paletteLieu, .paletteCommande, .paletteVariable, .palettePerso,
             .paletteAction, .paletteRecent, .paletteQuete, .palettePNJ, .paletteMonstre, .paletteObjet:
            return .palette
        default:
            return .outils
        }
    }

    /// Le choix d'une entrée de la palette, selon son genre.
    static func palette(_ genre: EntreePalette.Genre) -> EvenementUsage {
        switch genre {
        case .zaap: return .paletteZaap
        case .lieu: return .paletteLieu
        case .commande: return .paletteCommande
        case .variable: return .paletteVariable
        case .perso: return .palettePerso
        case .action: return .paletteAction
        case .recent: return .paletteRecent
        case .quete: return .paletteQuete
        case .pnj: return .palettePNJ
        case .monstre: return .paletteMonstre
        case .objet: return .paletteObjet
        }
    }

    static func boss(_ boss: Boss) -> EvenementUsage {
        switch boss {
        case .harebourg: return .bossHarebourg
        case .kimbo: return .bossKimbo
        case .toxoliath: return .bossToxoliath
        case .ilyzaelle: return .bossIlyzaelle
        case .talKasha: return .bossTalKasha
        }
    }
}

/// Une journée d'utilisation, dans le fuseau de l'utilisateur.
struct JourUsage: Codable, Equatable, Sendable {
    /// `2026-11-09` (`JourUsage.cle`).
    let jour: String
    /// Par `EvenementUsage.rawValue` : une clé inconnue (version plus récente
    /// relue par une plus ancienne) se garde sans casser la lecture.
    var compteurs: [String: Int] = [:]
    var persosMax = 0
    /// Intégrale du nombre de persos connectés sur le temps, et temps passé
    /// avec au moins un perso : leur rapport est la moyenne de la journée.
    var persosSecondes: Double = 0
    var secondesAvecPersos: Double = 0
    /// Les noms ne quittent jamais le Mac : seul leur nombre part.
    var persosJoues: [String] = []
    /// Les réglages en vigueur au dernier relevé de la journée.
    var reglages: [String: Bool] = [:]
    var langue: String?
    var envoye = false

    init(jour: String) { self.jour = jour }

    func nombre(_ evenement: EvenementUsage) -> Int { compteurs[evenement.rawValue] ?? 0 }

    var persosMoyenne: Double? {
        secondesAvecPersos > 0 ? persosSecondes / secondesAvecPersos : nil
    }

    /// Grégorien quel que soit le calendrier du Mac (bouddhiste, japonais…) :
    /// les clés se comparent en texte et partent telles quelles au collecteur.
    /// Le fuseau, lui, est celui de l'utilisateur : sa journée.
    static var gregorien: Calendar {
        var calendrier = Calendar(identifier: .gregorian)
        calendrier.timeZone = .current
        return calendrier
    }

    static func date(_ cle: String, calendrier: Calendar = JourUsage.gregorien) -> Date? {
        let parties = cle.split(separator: "-").compactMap { Int($0) }
        guard parties.count == 3 else { return nil }
        return calendrier.date(from: DateComponents(year: parties[0], month: parties[1], day: parties[2]))
    }

    static func cle(_ date: Date, calendrier: Calendar = JourUsage.gregorien) -> String {
        let c = calendrier.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// L'historique gardé sur le Mac : le détail des derniers jours, le cumul des
/// plus anciens. Les rapports partent d'ici ; l'onglet Usage s'y lit.
struct HistoriqueUsage: Codable, Equatable, Sendable {
    /// Du plus ancien au plus récent, sans trou de clé ni doublon.
    private(set) var jours: [JourUsage] = []
    /// Les compteurs des jours sortis du détail.
    private(set) var cumul: [String: Int] = [:]
    /// Le premier jour compté.
    private(set) var depuis: String?
    /// Le JSON exact du dernier envoi accepté, et sa date.
    var dernierEnvoi: Date?
    var dernierRapport: String?
    /// Tiré au hasard si le Mac ne donne pas son UUID matériel.
    var identifiantDeSecours: String?
    /// Les rapports de MetricKit pas encore acceptés, les plus récents gardés.
    private(set) var diagnostics: [DiagnosticUsage] = []

    static let diagnosticsMaximum = 10

    mutating func ajouter(_ nouveaux: [DiagnosticUsage]) {
        diagnostics = Array((diagnostics + nouveaux).suffix(Self.diagnosticsMaximum))
    }

    /// Le plus ancien en attente part avec le prochain envoi : un à la fois,
    /// le corps reste sous la limite du collecteur.
    var diagnosticAEnvoyer: DiagnosticUsage? { diagnostics.first }

    mutating func retirerDiagnostic(_ diagnostic: DiagnosticUsage) {
        if let index = diagnostics.firstIndex(of: diagnostic) { diagnostics.remove(at: index) }
    }

    /// Jours gardés en détail ; au-delà, ils fondent dans `cumul`.
    static let conservation = 90
    /// Un rapport en retard part encore pendant ce nombre de jours.
    static let retardMaximal = 7
    /// Un écart plus long entre deux relevés de l'effectif (veille, Mac
    /// suspendu) ne compte que pour cette durée.
    static let ecartMaximal: TimeInterval = 15 * 60

    mutating func compter(_ evenement: EvenementUsage, le jour: String) {
        modifier(jour) { $0.compteurs[evenement.rawValue, default: 0] += 1 }
    }

    mutating func noterPersoJoue(_ nom: String, le jour: String) {
        modifier(jour) { if !$0.persosJoues.contains(nom) { $0.persosJoues.append(nom) } }
    }

    mutating func noterReglages(_ reglages: [String: Bool], langue: String, le jour: String) {
        modifier(jour) {
            $0.reglages = reglages
            $0.langue = langue
        }
    }

    /// `persos` connectés pendant `duree` (bornée par `ecartMaximal`), jusqu'au
    /// relevé de `jour`.
    mutating func noterEffectif(_ persos: Int, pendant duree: TimeInterval, le jour: String) {
        let duree = min(max(duree, 0), Self.ecartMaximal)
        modifier(jour) {
            $0.persosMax = max($0.persosMax, persos)
            guard persos > 0 else { return }
            $0.persosSecondes += Double(persos) * duree
            $0.secondesAvecPersos += duree
        }
    }

    /// Les jours terminés qui n'ont pas encore été acceptés par le collecteur,
    /// dans la limite du retard permis.
    func aEnvoyer(aujourdhui: String) -> [JourUsage] {
        Array(jours.filter { !$0.envoye && $0.jour < aujourdhui }.suffix(Self.retardMaximal))
    }

    mutating func marquerEnvoyes(_ cles: [String]) {
        for index in jours.indices where cles.contains(jours[index].jour) { jours[index].envoye = true }
    }

    /// Les compteurs des `nombreDeJours` derniers jours jusqu'à `aujourdhui`
    /// compris, ou de tout l'historique (`nil`).
    func totaux(sur nombreDeJours: Int?, aujourdhui: String, calendrier: Calendar = JourUsage.gregorien) -> [EvenementUsage: Int] {
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
            if let evenement = EvenementUsage(rawValue: paire.key) { totaux[evenement] = paire.value }
        }
    }

    /// Moyenne, sur les jours de la période où un perso au moins était
    /// connecté, du nombre de persos connectés et du nombre de persos joués.
    func moyennesPersos(sur nombreDeJours: Int?, aujourdhui: String,
                        calendrier: Calendar = JourUsage.gregorien) -> (connectes: Double, joues: Double)? {
        let debut = nombreDeJours.map { Self.decaler(aujourdhui, de: -($0 - 1), calendrier: calendrier) } ?? ""
        let actifs = jours.filter { $0.jour >= debut && $0.jour <= aujourdhui && $0.persosMoyenne != nil }
        guard !actifs.isEmpty else { return nil }
        let n = Double(actifs.count)
        return (actifs.compactMap(\.persosMoyenne).reduce(0, +) / n,
                Double(actifs.map(\.persosJoues.count).reduce(0, +)) / n)
    }

    func jour(_ cle: String) -> JourUsage? { jours.last(where: { $0.jour == cle }) }

    private mutating func modifier(_ cle: String, _ changement: (inout JourUsage) -> Void) {
        if depuis == nil { depuis = cle }
        if let index = jours.lastIndex(where: { $0.jour == cle }) {
            changement(&jours[index])
            return
        }
        var nouveau = JourUsage(jour: cle)
        changement(&nouveau)
        // Une horloge remise en arrière ne crée pas un jour hors d'ordre.
        let rang = jours.firstIndex(where: { $0.jour > cle }) ?? jours.endIndex
        jours.insert(nouveau, at: rang)
        while jours.count > Self.conservation {
            cumul.merge(jours.removeFirst().compteurs, uniquingKeysWith: +)
        }
    }

    static func decaler(_ cle: String, de jours: Int, calendrier: Calendar = JourUsage.gregorien) -> String {
        guard let date = JourUsage.date(cle, calendrier: calendrier),
              let decalee = calendrier.date(byAdding: .day, value: jours, to: date)
        else { return cle }
        return JourUsage.cle(decalee, calendrier: calendrier)
    }
}

// Relecture tolérante d'`usage.json` : un champ ajouté par une version plus
// récente (ou retiré) prend son défaut au lieu de faire échouer toute la
// lecture — que `UsageStore` remplacerait alors par un historique vide,
// identifiant de secours compris.

extension JourUsage {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(jour: try c.decode(String.self, forKey: .jour))
        compteurs = c.valeur(.compteurs, sinon: compteurs)
        persosMax = c.valeur(.persosMax, sinon: persosMax)
        persosSecondes = c.valeur(.persosSecondes, sinon: persosSecondes)
        secondesAvecPersos = c.valeur(.secondesAvecPersos, sinon: secondesAvecPersos)
        persosJoues = c.valeur(.persosJoues, sinon: persosJoues)
        reglages = c.valeur(.reglages, sinon: reglages)
        langue = c.valeur(.langue, sinon: langue)
        envoye = c.valeur(.envoye, sinon: envoye)
    }
}

extension HistoriqueUsage {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init()
        jours = c.valeur(.jours, sinon: jours)
        cumul = c.valeur(.cumul, sinon: cumul)
        depuis = c.valeur(.depuis, sinon: depuis)
        dernierEnvoi = c.valeur(.dernierEnvoi, sinon: dernierEnvoi)
        dernierRapport = c.valeur(.dernierRapport, sinon: dernierRapport)
        identifiantDeSecours = c.valeur(.identifiantDeSecours, sinon: identifiantDeSecours)
        diagnostics = c.valeur(.diagnostics, sinon: diagnostics)
    }
}

private extension KeyedDecodingContainer {
    /// Le champ, ou `defaut` s'il est absent ou illisible.
    func valeur<T: Decodable>(_ cle: Key, sinon defaut: T) -> T {
        (try? decodeIfPresent(T.self, forKey: cle)) ?? defaut
    }
}
