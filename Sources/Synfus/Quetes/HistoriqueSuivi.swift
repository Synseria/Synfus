import Foundation

/// Ce que les lectures du suivi ont dit de chaque perso : sa dernière lecture,
/// et l'étape lue de chaque quête, datée. Pur. Seule source de « tel perso en
/// est là » : le suivi lu est celui du perso devant, alors que les coches
/// sont communes à tous les persos.
struct HistoriqueSuivi: Equatable, Sendable {
    struct EtapeLue: Equatable, Sendable {
        let perso: String
        /// `nil` : la lecture n'a pas établi l'étape.
        let etape: Int?
        let date: Date
    }

    /// Au-delà, une étape lue ne dit plus où en est le perso.
    static let memoire: TimeInterval = 24 * 3600

    private var vues: [String: SuiviQuetes.Lu] = [:]
    private var etapes: [Int: [String: EtapeLue]] = [:]

    /// Note la lecture du suivi de `perso` ; rend les quêtes qu'elle dit
    /// sorties de son suivi depuis sa lecture précédente (`disparues`).
    mutating func noter(_ lu: SuiviQuetes.Lu, perso: String, date: Date) -> Set<Int> {
        let disparues = vues[perso].map { Self.disparues(avant: $0, apres: lu) } ?? []
        vues[perso] = lu
        for reconnue in lu.reconnues {
            etapes[reconnue.id, default: [:]][perso] = EtapeLue(perso: perso, etape: reconnue.etape, date: date)
        }
        for id in disparues { etapes[id]?[perso] = nil }
        return disparues
    }

    /// Les persos lus à l'étape `etape` de la quête depuis moins de `memoire`,
    /// par nom. `seule` : la quête n'a qu'une étape, que le suivi ne désigne
    /// donc jamais.
    func persos(_ quete: Int, etape: Int, seule: Bool, maintenant: Date) -> [EtapeLue] {
        (etapes[quete] ?? [:]).values
            .filter { ($0.etape ?? (seule ? 0 : nil)) == etape && maintenant.timeIntervalSince($0.date) < Self.memoire }
            .sorted { $0.perso < $1.perso }
    }

    /// Les quêtes de `avant` que `apres` ne montre plus, quand rien d'autre ne
    /// l'explique. Une quête manque aussi quand elle est sortie de la zone lue
    /// ou que son titre s'est mal lu : il faut que la lecture voie le suivi
    /// (au moins une quête reconnue), dans le même ordre, et que :
    ///
    /// - sa voisine du dessus (ou l'en-tête) n'ait pas gagné de lignes — sans
    ///   quoi ses objectifs s'y sont peut-être rangés, son titre mal lu ;
    /// - une quête qui la suivait soit encore lue (sa place est dans la zone),
    ///   ou bien que rien n'ait pu la pousser hors de la zone : aucune quête
    ///   nouvelle, aucune au-dessus d'elle ni l'en-tête plus haut qu'avant.
    ///
    /// Reste ce que rien ne distingue d'une quête finie : une quête que le
    /// joueur ne suit plus, un panneau du jeu posé pile sur elle. Le panneau
    /// ne fait que poser la question.
    static func disparues(avant: SuiviQuetes.Lu, apres: SuiviQuetes.Lu) -> Set<Int> {
        let anciens = avant.reconnues.map(\.id), lus = apres.reconnues.map(\.id)
        guard !lus.isEmpty, lus.filter(anciens.contains) == anciens.filter(lus.contains) else { return [] }
        let lignesAvant = Dictionary(zip(anciens, avant.lignes), uniquingKeysWith: max)
        let lignesApres = Dictionary(zip(lus, apres.lignes), uniquingKeysWith: max)
        func garde(_ id: Int) -> Bool { lignesApres[id, default: 0] <= lignesAvant[id, default: 0] }
        let enteteGarde = apres.entete <= avant.entete
        let rienDeNeuf = lus.allSatisfy(anciens.contains)
        var disparues: Set<Int> = []
        for (rang, id) in anciens.enumerated() where !lus.contains(id) {
            let dessus = anciens[..<rang].filter(lus.contains)
            guard dessus.last.map(garde) ?? enteteGarde else { continue }
            let suivie = anciens[(rang + 1)...].contains(where: lus.contains)
            if suivie || (rienDeNeuf && enteteGarde && dessus.allSatisfy(garde)) { disparues.insert(id) }
        }
        return disparues
    }
}
