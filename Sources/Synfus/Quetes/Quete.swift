import Foundation

/// Les quêtes du jeu et les PNJ qu'elles situent, telles que DofusDB les
/// donne (`QuetesDofusDB`). Pur : des noms, des coordonnées, des quantités.
struct Quetes: Codable, Equatable, Sendable {
    /// La forme du fichier gardé sur le disque : une autre (ancienne) n'est
    /// pas relue, les quêtes se retéléchargent — sans quoi un cache d'avant
    /// un nouveau champ le laisserait vide trente jours.
    static let formatActuel = 3
    let format: Int
    let date: Date
    let quetes: [Quete]
    let pnjs: [PNJ]
    /// Les noms des objets, monstres et PNJ cités par les objectifs, par
    /// identifiant (en texte : clés JSON).
    let objets: [String: [String: String]]
    let monstres: [String: [String: String]]
    let nomsPNJ: [String: [String: String]]
    /// Les sous-zones où les quêtes placent des PNJ, et leur zone.
    let sousZones: [String: SousZoneNommee]
    /// La grande famille de chaque objet cité (`superTypeId` de DofusDB),
    /// par identifiant d'objet, et le nom de chaque famille (« Ressource »,
    /// « Consommable », « Objet de quête »…).
    let famillesObjets: [String: Int]
    let familles: [String: [String: String]]
    /// Les émotes et titres que des étapes donnent, par identifiant.
    let emotes: [String: [String: String]]
    let titres: [String: [String: String]]

    /// La famille « Objet de quête » de DofusDB (`item-super-types`) : un
    /// identifiant, pas un nom, qui change avec la langue.
    static let familleObjetDeQuete = 14

    /// Moins de quêtes que cela : une réponse tronquée.
    static let minimumPlausible = 500

    /// « Ramener à {npc,119} : x1 {item,1746} » → « Ramener à Otomaï : x1 Sang de Wabbit GM ».
    /// Un renvoi inconnu reste lisible : son seul type, entre crochets.
    func texte(_ modele: String, en langue: Langue) -> String {
        Self.resoudre(modele) { nomRenvoi($0, $1, en: langue) }
    }

    /// Le nom d'un renvoi (`item`, `monster`, `npc`), `nil` s'il est inconnu.
    func nomRenvoi(_ genre: String, _ id: String, en langue: Langue) -> String? {
        let noms: [String: String]? = switch genre {
        case "item": objets[id]
        case "monster": monstres[id]
        case "npc": nomsPNJ[id]
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
    let etapes: [EtapeQuete]
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
        let sousZone: Int?
        /// Combien de quêtes le placent ici.
        let quetes: Int
    }

    let id: Int
    let noms: [String: String]
    /// Le plus cité d'abord.
    let passages: [Passage]
}

/// Une quête prête à montrer : noms résolus dans la langue, ressources
/// additionnées, objectifs et leur carte quand elle est connue.
struct FicheQuete: Equatable, Sendable {
    struct Ressource: Equatable, Sendable {
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
            ressources: Self.ressources(quete).map { ressource($0.objet, $0.quantite, en: langue) },
            etapes: quete.etapes.map { etape in
                let description = texte(Lieu.traduit(etape.descriptions, langue) ?? "", en: langue)
                return FicheQuete.Etape(
                    nom: Lieu.traduit(etape.noms, langue) ?? "",
                    description: description.isEmpty ? nil : description,
                    objectifs: etape.objectifs.map { objectif in
                        var position: PNJ.Position?
                        if let x = objectif.x, let y = objectif.y { position = PNJ.Position(x: x, y: y) }
                        return FicheQuete.Objectif(
                            id: objectif.id, texte: texte(Lieu.traduit(objectif.textes, langue) ?? "", en: langue),
                            position: position, carte: objectif.carte)
                    },
                    recompenses: recompenses(etape.recompenses, en: langue))
            },
            suivantes: suivantes(de: quete.id).map {
                FicheQuete.Suivante(id: $0.id, nom: Lieu.traduit($0.noms, langue) ?? "?", niveau: $0.niveau)
            })
    }

    /// Les quêtes qui demandent celle-ci, la plus basse d'abord.
    func suivantes(de id: Int) -> [Quete] {
        quetes.filter { $0.prerequis.contains(id) }.sorted { ($0.niveau, $0.id) < ($1.niveau, $1.id) }
    }

    private func ressource(_ objet: Int, _ quantite: Int, en langue: Langue) -> FicheQuete.Ressource {
        let famille = famillesObjets[String(objet)]
        return FicheQuete.Ressource(nom: nomObjet(objet, en: langue), quantite: quantite,
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
