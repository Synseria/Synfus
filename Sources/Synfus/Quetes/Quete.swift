import Foundation

/// Les quêtes du jeu et les PNJ qu'elles situent, telles que DofusDB les
/// donne (`QuetesDofusDB`). Pur : des noms, des coordonnées, des quantités.
struct Quetes: Codable, Equatable, Sendable {
    /// La forme du fichier gardé sur le disque : une autre (ancienne) n'est
    /// pas relue, les quêtes se retéléchargent — sans quoi un cache d'avant
    /// un nouveau champ le laisserait vide trente jours.
    static let formatActuel = 7
    let format: Int
    let date: Date
    let quetes: [Quete]
    let pnjs: [PNJ]
    /// Les noms des objets, monstres et PNJ cités par les objectifs, par
    /// identifiant (en texte : clés JSON).
    let objets: [String: [String: String]]
    let monstres: [String: [String: String]]
    let nomsPNJ: [String: [String: String]]
    /// Les sous-zones où les quêtes placent des PNJ ou que citent leurs
    /// objectifs, et leur zone.
    let sousZones: [String: SousZoneNommee]
    /// La grande famille de chaque objet cité (`superTypeId` de DofusDB),
    /// par identifiant d'objet, et le nom de chaque famille (« Ressource »,
    /// « Consommable », « Objet de quête »…).
    let famillesObjets: [String: Int]
    let familles: [String: [String: String]]
    /// Les émotes et titres que des étapes donnent, par identifiant.
    let emotes: [String: [String: String]]
    let titres: [String: [String: String]]
    /// Les métiers et les camps d'alignement, pour les conditions des quêtes.
    let metiers: [String: [String: String]]
    let camps: [String: [String: String]]

    /// La famille « Objet de quête » de DofusDB (`item-super-types`) : un
    /// identifiant, pas un nom, qui change avec la langue.
    static let familleObjetDeQuete = 14

    /// Moins de quêtes que cela : une réponse tronquée.
    static let minimumPlausible = 500

    /// « Ramener à {npc,119} : x1 {item,1746} » → « Ramener à Otomaï : x1 Sang de Wabbit GM ».
    /// Un renvoi inconnu reste lisible : son seul type, entre crochets. Une
    /// carte (`{map,…}`) s'écrit par ses coordonnées, `carte`, comme le jeu la
    /// montre — DofusDB n'a pas de nom de carte.
    func texte(_ modele: String, en langue: Langue, carte: PNJ.Position? = nil) -> String {
        Self.resoudre(modele) { genre, id in
            genre == "map" ? Self.nomCarte(carte) : nomRenvoi(genre, id, en: langue)
        }
    }

    /// Le texte d'un objectif dans la langue, sa carte par les coordonnées de
    /// l'objectif : celles que DofusDB lui donne sont celles de la carte qu'il
    /// cite (vérifié sur tout le catalogue, même quand l'identifiant de carte
    /// diffère d'un étage).
    func texte(_ objectif: ObjectifQuete, en langue: Langue) -> String {
        texte(Lieu.traduit(objectif.textes, langue) ?? "", en: langue, carte: objectif.position)
    }

    /// Sans coordonnées, un mot neutre (« la carte indiquée ») plutôt que
    /// « [map] ».
    static func nomCarte(_ position: PNJ.Position?) -> String {
        position.map { Coordonnees.texte($0.x, $0.y) } ?? L("quete.carte.inconnue")
    }

    /// Le nom d'un renvoi (`item`, `monster`, `npc`, `subarea`), `nil` s'il
    /// est inconnu.
    func nomRenvoi(_ genre: String, _ id: String, en langue: Langue) -> String? {
        let noms: [String: String]? = switch genre {
        case "item": objets[id]
        case "monster": monstres[id]
        case "npc": nomsPNJ[id]
        case "subarea": sousZones[id]?.noms
        default: nil
        }
        return noms.flatMap { Lieu.traduit($0, langue) }
    }

    static func resoudre(_ modele: String, nom: (_ genre: String, _ id: String) -> String?) -> String {
        var resultat = ""
        var reste = Substring(modele)
        while let ouvrante = reste.firstIndex(of: "{"), let fermante = reste[ouvrante...].firstIndex(of: "}") {
            resultat += reste[..<ouvrante]
            let parties = reste[reste.index(after: ouvrante)..<fermante].split(separator: ",")
            if parties.count == 2 {
                resultat += nom(String(parties[0]), String(parties[1])) ?? "[\(parties[0])]"
            } else {
                resultat += reste[ouvrante...fermante]
            }
            reste = reste[reste.index(after: fermante)...]
        }
        return resultat + reste
    }

    func nomObjet(_ id: Int, en langue: Langue) -> String {
        objets[String(id)].flatMap { Lieu.traduit($0, langue) } ?? "#\(id)"
    }

    /// Les objets à réunir pour toute la quête, quantités additionnées, dans
    /// l'ordre où les étapes les demandent.
    static func ressources(_ quete: Quete) -> [(objet: Int, quantite: Int)] {
        var ordre: [Int] = []
        var totaux: [Int: Int] = [:]
        for etape in quete.etapes {
            for objectif in etape.objectifs {
                guard let objet = objectif.objet, let quantite = objectif.quantite else { continue }
                if totaux[objet] == nil { ordre.append(objet) }
                totaux[objet, default: 0] += quantite
            }
        }
        return ordre.map { ($0, totaux[$0]!) }
    }
}

struct Quete: Codable, Equatable, Sendable {
    let id: Int
    let noms: [String: String]
    let niveau: Int
    /// À faire à plusieurs.
    let groupe: Bool
    /// Passe par un donjon.
    let donjon: Bool
    /// Les quêtes à finir avant celle-ci.
    let prerequis: [Int]
    /// Les conditions pour la commencer, telles que DofusDB les écrit
    /// (`startCriterion`, lu par `ConditionsQuete`).
    let critere: String?
    let etapes: [EtapeQuete]
    /// Où elle commence : le PNJ qui la donne et sa case (`startPosition`).
    var departs: [DepartQuete] = []
}

struct DepartQuete: Codable, Equatable, Sendable {
    let pnj: Int
    let position: PNJ.Position
    /// Ce qui distingue une case du Monde des Douze de son homonyme
    /// d'Incarnam (`QuetesIci`).
    let sousZone: Int?
}

struct EtapeQuete: Codable, Equatable, Sendable {
    let noms: [String: String]
    /// Ce que le jeu dit de l'étape, la consigne en clair.
    let descriptions: [String: String]
    let objectifs: [ObjectifQuete]
    let recompenses: RecompensesEtape
}

/// Ce qu'une étape rapporte à un perso de son niveau optimal.
struct RecompensesEtape: Codable, Equatable, Sendable {
    struct Objet: Codable, Equatable, Sendable {
        let objet: Int
        let quantite: Int
    }

    static let aucune = RecompensesEtape(niveau: 0, experience: 0, kamas: 0, objets: [], emotes: [], titres: [])

    let niveau: Int
    let experience: Int
    let kamas: Int
    let objets: [Objet]
    let emotes: [Int]
    let titres: [Int]

    /// La formule du client : `niveau × (100 + 2 niveau)² / 20 × durée × ratio`,
    /// sans bonus d'expérience.
    static func experience(niveau: Int, duree: Double, ratio: Double) -> Int {
        let niveau = Double(niveau)
        return Int((niveau * (100 + 2 * niveau) * (100 + 2 * niveau) / 20 * duree * ratio).rounded(.down))
    }

    /// La formule du client : `(niveau² + 20 niveau − 20) × ratio × durée`.
    static func kamas(niveau: Int, duree: Double, ratio: Double) -> Int {
        let niveau = Double(niveau)
        return max(Int(((niveau * niveau + 20 * niveau - 20) * ratio * duree).rounded(.down)), 0)
    }
}

struct ObjectifQuete: Codable, Equatable, Sendable {
    /// L'identifiant DofusDB : ce qu'on retient d'un objectif validé, stable
    /// d'une mise à jour des quêtes à l'autre, contrairement à son rang.
    let id: Int
    /// Le texte du jeu, renvois compris (`{item,1746}`), par langue.
    let textes: [String: String]
    let x: Int?
    let y: Int?
    /// La carte où il se passe, pour en montrer la vue.
    let carte: Int?
    /// L'objet à ramener et combien — les ressources de la quête.
    let objet: Int?
    let quantite: Int?
    /// Le genre d'objectif de DofusDB (`typeId`, liste `quest-objective-types`).
    let type: Int?

    /// Les genres « Vaincre… » : monstres en un ou plusieurs combats (6, 14),
    /// sur une carte (16), monstre à vaincre (7), éliminer (13), joueur en
    /// défi (11). Krosmaster (15) n'est pas un combat sur la carte.
    static let typesCombat: Set<Int> = [6, 7, 11, 13, 14, 16]

    var combat: Bool { type.map(Self.typesCombat.contains) ?? false }

    var position: PNJ.Position? {
        guard let x, let y else { return nil }
        return PNJ.Position(x: x, y: y)
    }
}

struct SousZoneNommee: Codable, Equatable, Sendable {
    let noms: [String: String]
    let zone: [String: String]
}

/// Un PNJ et les cartes où les quêtes le placent. DofusDB ne dit pas si un
/// PNJ ne fait que passer : la position que le plus de quêtes citent est
/// tenue pour la sienne, les autres viennent après.
struct PNJ: Codable, Equatable, Sendable {
    struct Position: Codable, Hashable, Sendable {
        let x: Int
        let y: Int
    }

    struct Passage: Codable, Equatable, Sendable {
        let position: Position
        /// La carte du jeu où les quêtes le placent, pour en montrer la vue ;
        /// la première que DofusDB connaît, quand plusieurs partagent la case.
        let carte: Int?
        let sousZone: Int?
        /// Combien de quêtes le placent ici.
        let quetes: Int

        /// Dans le Monde des Douze, sauf si sa sous-zone dit le contraire.
        /// Ailleurs (Incarnam…), ni zaap ni distance d'Amakna.
        func dansLesDouze(_ reseau: ReseauSousZones) -> Bool { !reseau.horsDesDouze(sousZone) }
    }

    let id: Int
    let noms: [String: String]
    /// Le plus cité d'abord.
    let passages: [Passage]

    /// Ce qu'un favori ou une étiquette désigne : l'identifiant DofusDB, pas
    /// une case — un PNJ en a plusieurs.
    var cle: String { Self.prefixeCle + "\(id)" }
    static let prefixeCle = "pnj:"
}

/// Une quête prête à montrer : noms résolus dans la langue, ressources
/// additionnées, objectifs et leur carte quand elle est connue.
struct FicheQuete: Equatable, Sendable {
    struct Ressource: Equatable, Sendable {
        /// L'identifiant DofusDB, pour dire où le trouver (`OuTrouver`).
        let objet: Int
        let nom: String
        let quantite: Int
        /// « Ressource », « Consommable », « Objet de quête »…
        let categorie: String?
        /// Remis par un PNJ ou ramassé en chemin, il ne s'achète pas : on
        /// peut le masquer des ressources à réunir.
        let objetDeQuete: Bool
    }

    struct Objectif: Equatable, Sendable {
        let id: Int
        let texte: String
        let position: PNJ.Position?
        let carte: Int?
        /// « Vaincre… » : être sur sa carte ne suffit pas, il faut y avoir
        /// fini un combat.
        let combat: Bool
        /// Le monstre qu'il cite, sinon l'objet qu'il cite sans le faire
        /// ramener (celui-là est dans les ressources) : où le trouver.
        var sujet: OuTrouver.Sujet?
    }

    struct Recompenses: Equatable, Sendable {
        /// Le niveau auquel expérience et kamas sont comptés.
        let niveau: Int
        let experience: Int
        let kamas: Int
        let objets: [Ressource]
        let emotes: [String]
        let titres: [String]

        var vides: Bool {
            experience == 0 && kamas == 0 && objets.isEmpty && emotes.isEmpty && titres.isEmpty
        }
    }

    struct Etape: Equatable, Sendable {
        let nom: String
        let description: String?
        let objectifs: [Objectif]
        let recompenses: Recompenses

        /// Les objectifs à proposer de cocher quand le perso se tient en
        /// `position` : ceux de cette carte, encore à faire, que le jeu tient
        /// ouverts. `lu` : ce que la lecture fraîche du suivi du perso devant
        /// dit de la quête.
        ///
        /// - Le suivi montre l'étape (`lu` montre ouvert un de ses objectifs) :
        ///   seuls les objectifs qu'il montre sont proposés, dans n'importe
        ///   quel ordre — plusieurs PNJ à voir sans ordre. Ce qu'il tait
        ///   (`nonMontres`) ne l'est jamais : à peine la quête prise auprès
        ///   d'un PNJ, « lui rapporter » est sur sa case, mais le jeu montre
        ///   d'abord « aller voir » un autre.
        /// - Sinon, et pour ce que la lecture ne sait pas (après « VOIR
        ///   PLUS… ») : le prochain objectif non coché, ou celui en cours —
        ///   dont on a copié le trajet : on y allait. Ailleurs dans l'étape,
        ///   on n'est peut-être que de passage sur une carte qui revient.
        ///
        /// Un objectif « Vaincre… » exige un combat fini sur sa carte
        /// (`combatFini`, `FinsDeCombat`) : la présence ne prouve rien, le
        /// combat si — à tout rang, tant que le suivi ne le tait pas.
        func suggeres(en position: PNJ.Position?, valides: Set<Int>, enCours: Int?, combatFini: Bool,
                      lu: SuiviQuetes.Reconnue?) -> Set<Int> {
            guard let position else { return [] }
            let lu = lecture(lu)
            let connus = Set((lu?.aFaire ?? []) + (lu?.faits ?? []) + (lu?.nonMontres ?? []))
            let prochain = objectifs.first { !valides.contains($0.id) }?.id
            let proposes = objectifs.filter { objectif in
                guard objectif.position == position, !valides.contains(objectif.id), !objectif.combat || combatFini
                else { return false }
                if connus.contains(objectif.id) { return lu?.aFaire.contains(objectif.id) == true }
                return objectif.combat || objectif.id == prochain || objectif.id == enCours
            }
            return Set(proposes.map(\.id))
        }

        /// Ceux que le suivi, lu en entier, tait et que rien ne coche : pas
        /// encore ouverts (ou faits hors de l'ordre), en retrait.
        func nonOuverts(valides: Set<Int>, lu: SuiviQuetes.Reconnue?) -> Set<Int> {
            Set((lecture(lu)?.nonMontres ?? []).filter { !valides.contains($0) })
        }

        /// La lecture, si elle parle de cette étape : un de ses objectifs y est
        /// montré ouvert.
        private func lecture(_ lu: SuiviQuetes.Reconnue?) -> SuiviQuetes.Reconnue? {
            guard let lu, objectifs.contains(where: { lu.aFaire.contains($0.id) }) else { return nil }
            return lu
        }
    }

    /// Ce qu'il faut pour commencer la quête, au-delà des quêtes à finir.
    enum Exigence: Equatable, Sendable {
        /// L'identifiant DofusDB : le nom vient du catalogue des classes.
        case classe(Int)
        case niveau(Int)
        case metier(String, niveau: Int)
        case alignement(camp: String?, niveau: Int?)
    }

    /// Une quête qui s'ouvre une fois celle-ci finie.
    struct Suivante: Equatable, Sendable {
        let id: Int
        let nom: String
        let niveau: Int
    }

    let id: Int
    let nom: String
    /// Le nom français, celui des guides (Dofus pour les noobs).
    let nomFrancais: String
    let niveau: Int
    let groupe: Bool
    let donjon: Bool
    let exigences: [Exigence]
    let ressources: [Ressource]
    let etapes: [Etape]
    let suivantes: [Suivante]
}

extension Quetes {
    func fiche(_ id: Int, en langue: Langue) -> FicheQuete? {
        quetes.first { $0.id == id }.map { fiche($0, en: langue) }
    }

    func fiche(_ quete: Quete, en langue: Langue) -> FicheQuete {
        FicheQuete(
            id: quete.id,
            nom: Lieu.traduit(quete.noms, langue) ?? "?",
            nomFrancais: Lieu.traduit(quete.noms, .fr) ?? "",
            niveau: quete.niveau,
            groupe: quete.groupe,
            donjon: quete.donjon,
            exigences: exigences(quete, en: langue),
            ressources: Self.ressources(quete).map { ressource($0.objet, $0.quantite, en: langue) },
            etapes: quete.etapes.map { etape in
                let description = texte(Lieu.traduit(etape.descriptions, langue) ?? "", en: langue)
                return FicheQuete.Etape(
                    nom: Lieu.traduit(etape.noms, langue) ?? "",
                    description: description.isEmpty ? nil : description,
                    objectifs: etape.objectifs.map { objectif in
                        FicheQuete.Objectif(
                            id: objectif.id, texte: texte(objectif, en: langue),
                            position: objectif.position, carte: objectif.carte, combat: objectif.combat,
                            sujet: Self.sujet(objectif))
                    },
                    recompenses: recompenses(etape.recompenses, en: langue))
            },
            suivantes: suivantes(de: quete.id).map {
                FicheQuete.Suivante(id: $0.id, nom: Lieu.traduit($0.noms, langue) ?? "?", niveau: $0.niveau)
            })
    }

    /// Le premier monstre cité, sinon le premier objet cité, s'il n'est pas
    /// à ramener. Les renvois sont les mêmes dans chaque langue.
    static func sujet(_ objectif: ObjectifQuete) -> OuTrouver.Sujet? {
        var monstre: Int?, objet: Int?
        _ = resoudre(objectif.textes[Langue.fr.rawValue] ?? objectif.textes.values.first ?? "") { genre, id in
            switch genre {
            case "monster": monstre = monstre ?? Int(id)
            case "item": objet = objet ?? Int(id)
            default: break
            }
            return nil
        }
        if let monstre { return .monstre(monstre) }
        return objectif.objet == nil ? objet.map { .objet($0) } : nil
    }

    /// Le niveau minimum n'est dit que s'il diffère de celui de la quête.
    func exigences(_ quete: Quete, en langue: Langue) -> [FicheQuete.Exigence] {
        let conditions = ConditionsQuete.lire(quete.critere)
        var exigences: [FicheQuete.Exigence] = conditions.classe.map { [.classe($0)] } ?? []
        if let niveau = conditions.niveau, niveau != quete.niveau { exigences.append(.niveau(niveau)) }
        exigences += conditions.metiers.map { metier in
            .metier(metiers[String(metier.id)].flatMap { Lieu.traduit($0, langue) } ?? "#\(metier.id)", niveau: metier.niveau)
        }
        if conditions.camp != nil || conditions.alignement != nil {
            exigences.append(.alignement(camp: conditions.camp.flatMap { camps[String($0)] }.flatMap { Lieu.traduit($0, langue) },
                                         niveau: conditions.alignement))
        }
        return exigences
    }

    /// Les quêtes qui demandent celle-ci, la plus basse d'abord.
    func suivantes(de id: Int) -> [Quete] {
        quetes.filter { $0.prerequis.contains(id) }.sorted { ($0.niveau, $0.id) < ($1.niveau, $1.id) }
    }

    private func ressource(_ objet: Int, _ quantite: Int, en langue: Langue) -> FicheQuete.Ressource {
        let famille = famillesObjets[String(objet)]
        return FicheQuete.Ressource(objet: objet, nom: nomObjet(objet, en: langue), quantite: quantite,
                                    categorie: famille.flatMap { familles[String($0)] }.flatMap { Lieu.traduit($0, langue) },
                                    objetDeQuete: famille == Self.familleObjetDeQuete)
    }

    private func recompenses(_ recompenses: RecompensesEtape, en langue: Langue) -> FicheQuete.Recompenses {
        func noms(_ ids: [Int], _ table: [String: [String: String]]) -> [String] {
            ids.compactMap { table[String($0)].flatMap { Lieu.traduit($0, langue) } }
        }
        return FicheQuete.Recompenses(
            niveau: recompenses.niveau, experience: recompenses.experience, kamas: recompenses.kamas,
            objets: recompenses.objets.map { ressource($0.objet, $0.quantite, en: langue) },
            emotes: noms(recompenses.emotes, emotes), titres: noms(recompenses.titres, titres))
    }
}
