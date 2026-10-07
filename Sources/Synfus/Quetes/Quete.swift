import Foundation

/// Les quêtes du jeu et les PNJ qu'elles situent, telles que DofusDB les
/// donne (`QuetesDofusDB`). Pur : des noms, des coordonnées, des quantités.
struct Quetes: Codable, Equatable, Sendable {
    let date: Date
    let quetes: [Quete]
    let pnjs: [PNJ]
    /// Les noms des objets, monstres et PNJ cités par les objectifs, par
    /// identifiant (en texte : clés JSON).
    let objets: [String: [String: String]]
    let monstres: [String: [String: String]]
    let nomsPNJ: [String: [String: String]]

    /// Moins de quêtes que cela : une réponse tronquée.
    static let minimumPlausible = 500

    /// « Ramener à {npc,119} : x1 {item,1746} » → « Ramener à Otomaï : x1 Sang de Wabbit GM ».
    /// Un renvoi inconnu reste lisible : son seul type, entre crochets.
    func texte(_ modele: String, en langue: Langue) -> String {
        Self.resoudre(modele) { genre, id in
            let noms: [String: String]? = switch genre {
            case "item": objets[id]
            case "monster": monstres[id]
            case "npc": nomsPNJ[id]
            default: nil
            }
            return noms.flatMap { Lieu.traduit($0, langue) }
        }
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
    let etapes: [EtapeQuete]
}

struct EtapeQuete: Codable, Equatable, Sendable {
    let noms: [String: String]
    let objectifs: [ObjectifQuete]
}

struct ObjectifQuete: Codable, Equatable, Sendable {
    /// Le texte du jeu, renvois compris (`{item,1746}`), par langue.
    let textes: [String: String]
    let x: Int?
    let y: Int?
    /// L'objet à ramener et combien — les ressources de la quête.
    let objet: Int?
    let quantite: Int?
}

/// Un PNJ et les cartes où une quête le place.
struct PNJ: Codable, Equatable, Sendable {
    struct Position: Codable, Hashable, Sendable {
        let x: Int
        let y: Int
    }

    let id: Int
    let noms: [String: String]
    let positions: [Position]
}
