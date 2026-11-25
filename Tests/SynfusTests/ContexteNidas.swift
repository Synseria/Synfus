import Foundation
@testable import Synfus

/// Une recherche « nidas » sur données factices, comme la palette la montre en jeu : le boss et son
/// donjon, deux PNJ homonymes dans la même sous-zone, des PNJ trouvés par leur seul lieu, des objets
/// au nom du roi. Le perso est sur la case du palais.
enum ContexteNidas {
    static let donjon = 71
    static let boss = 3416
    static let sousZone = 900
    static let case_ = PNJ.Position(x: -5, y: -5)

    static func contexte() throws -> ContextePalette {
        let api = """
        [{"id":\(donjon),"name":{"fr":"Palais du roi Nidas"},"optimalPlayerLevel":200,"entranceMapId":112460048,
          "requiredObjects":[],"bosses":[\(boss)],"monsters":[\(boss)],"achievements":[]}]
        """
        let donjons = Donjons(try JSONDecoder().decode([Donjon.API].self, from: Data(api.utf8)).map(Donjon.init),
                              nomsBoss: [boss: ["fr": "Roi Nidas"]])
        let passage = { (x: Int, y: Int, carte: Int?, quetes: [Int]) in
            PNJ.Passage(position: .init(x: x, y: y), carte: carte, sousZone: sousZone, quetes: quetes)
        }
        let quetes = (1...6).map { id in
            Quete(id: id, noms: ["fr": "Le trésor du roi \(id)"], niveau: 200, groupe: false, donjon: false,
                  prerequis: [], critere: nil, etapes: [])
        }
        let objets = ["Joyau de la couronne du roi Nidas", "Poil de nez bleu du Roi Nidas", "Sceptre du roi Nidas",
                      "Cape du roi Nidas", "Bottes du roi Nidas"]
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: case_.x, y: case_.y, zone: "Enutrosor (Palais du roi Nidas)")
        contexte.donjons = donjons
        contexte.lieux = [Lieu(id: 1, x: case_.x, y: case_.y, monde: 1, idCarte: 112460048, idSousZone: 794,
                               categorie: CategorieLieu.donjon.rawValue, gfx: nil, noms: ["fr": "Palais du roi Nidas"],
                               zone: ["fr": "Enutrosor"], sousZone: ["fr": "Creuset des Fortunés"])]
        contexte.quetes = Quetes(
            format: Quetes.formatActuel, date: .now, quetes: quetes,
            pnjs: [PNJ(id: 10, noms: ["fr": "Roi Nidas"], passages: [passage(-5, -5, 112460050, [1])]),
                   PNJ(id: 11, noms: ["fr": "Roi Nidas"], passages: [passage(-4, -5, nil, [2]), passage(-5, -6, nil, [3])]),
                   PNJ(id: 12, noms: ["fr": "Léonard"], passages: [passage(-5, -5, 112460051, [4, 5])]),
                   PNJ(id: 13, noms: ["fr": "Richard le Trésorier"], passages: [passage(-4, -5, nil, [6]), passage(-6, -5, nil, [6])])],
            objets: Dictionary(uniqueKeysWithValues: objets.enumerated().map { (String(20 + $0.offset), ["fr": $0.element]) }),
            monstres: [:], nomsPNJ: [:],
            sousZones: [String(sousZone): SousZoneNommee(noms: ["fr": "Palais du roi Nidas"], zone: ["fr": "Enutrosor"])],
            famillesObjets: [:], familles: [:], emotes: [:], titres: [:], metiers: [:], camps: [:])
        return contexte
    }
}
