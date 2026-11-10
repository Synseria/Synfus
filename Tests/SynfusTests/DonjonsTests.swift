import Foundation
import Testing
@testable import Synfus

/// La fiche d'un donjon : retrouvée par son repère ou par un boss, détail
/// assemblé, et dans la palette.
struct DonjonsTests {

    private static let api = """
    [{"id":71,"name":{"fr":"Donjon du Comte Harebourg","en":"Count Harebourg's Dungeon"},"optimalPlayerLevel":200,
      "entranceMapId":112460048,"requiredObjects":[{"id":14047,"quantity":1}],"bosses":[3416],
      "monsters":[3384,3416],"achievements":[892,893]},
     {"id":171,"name":{"fr":"Expédition de l'Audace - Donjon du Comte Harebourg"},"bosses":[3416]},
     {"id":28,"name":{"fr":"Canopée du Kimbo"},"bosses":[1045]}]
    """

    private static func donjons() throws -> Donjons {
        let liste = try JSONDecoder().decode([Donjon.API].self, from: Data(api.utf8)).map(Donjon.init)
        return Donjons(liste, nomsBoss: [3416: ["fr": "Comte Harebourg"], 1045: ["fr": "Kimbo"]])
    }

    private static func lieu(_ nom: String, carte: Int) -> Lieu {
        Lieu(id: 1, x: -67, y: -75, monde: 1, idCarte: carte, idSousZone: 794, categorie: CategorieLieu.donjon.rawValue,
             gfx: nil, noms: ["fr": nom], zone: [:], sousZone: [:])
    }

    @Test("Un donjon se retrouve par la carte de son repère, sinon son nom, et par son boss — l'original, pas l'expédition")
    func index() throws {
        let donjons = try Self.donjons()
        #expect(donjons.donjon(de: Self.lieu("Autre nom", carte: 112460048))?.id == 71)
        #expect(donjons.donjon(de: Self.lieu("canopee du kimbo", carte: 1))?.id == 28)
        #expect(donjons.donjon(de: Self.lieu("Inconnu", carte: 1)) == nil)
        #expect(donjons.donjon(boss: 3416)?.id == 71)
        let harebourg = try #require(donjons.donjon(id: 71))
        #expect(harebourg.niveau == 200 && harebourg.clefs == [Donjon.Clef(objet: 14047, quantite: 1)])
        #expect(harebourg.succes == [892, 893])
    }

    @Test("Le détail : les boss d'abord, puis du plus fort au plus faible ; la clef nommée")
    func detail() throws {
        let json = """
        [{"id":3384,"name":{"fr":"Mansot"},"grades":[{"grade":1,"level":180,"lifePoints":3000,"actionPoints":8,"movementPoints":4}]},
         {"id":3416,"name":{"fr":"Comte Harebourg"},"grades":[{"grade":1,"level":200,"lifePoints":9000,"actionPoints":12,"movementPoints":6}]},
         {"id":9,"name":{"fr":"Sans grade"},"grades":[]}]
        """
        let monstres = try JSONDecoder().decode([FicheCombat.MonstreAPI].self, from: Data(json.utf8))
        let donjon = try #require(try Self.donjons().donjon(id: 71))
        let detail = DetailDonjon.assembler(donjon, monstres: monstres, objets: [14047: ["fr": "Clef du Donjon du Comte"]],
                                            succes: [])
        #expect(detail.monstres.map(\.id) == [3416, 3384])
        #expect(detail.monstres.first?.boss == true)
        #expect(detail.clefs.first?.noms["fr"] == "Clef du Donjon du Comte")
    }

    @Test("Palette : un donjon et son boss déplient la même fiche ; sans la liste, le donjon garde son trajet")
    func palette() throws {
        var contexte = ContextePalette()
        contexte.donjons = try Self.donjons()
        contexte.lieux = [Self.lieu("Donjon du Comte Harebourg", carte: 112460048)]
        #expect(RecherchePalette.lieux(contexte).first?.effet == .donjon(71))
        let boss = RecherchePalette.boss(contexte)
        #expect(boss.first { $0.titre == "Comte Harebourg" }?.effet == .donjon(71))
        #expect(RecherchePalette.entrees("kimbo", contexte).contains { $0.effet == .donjon(28) })
        contexte.donjons = nil
        #expect(RecherchePalette.lieux(contexte).first?.effet == .trajet(x: -67, y: -75, sousZone: 794))
    }
}
