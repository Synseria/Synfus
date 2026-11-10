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

    @Test("Fiche au clavier : entrée et guide d'emblée, clef et dépliables avec le détail ; ↵ par défaut va à l'entrée")
    func cartes() throws {
        let donjon = try #require(try Self.donjons().donjon(id: 71))
        let entree = Self.lieu("Donjon du Comte Harebourg", carte: 112460048)
        let attente = CartesFiche.donjon(entree: entree, guide: donjon.nomFrancais, detail: nil)
        #expect(attente.rangees == [[.entree(entree), .guide("Donjon du Comte Harebourg")], []])
        #expect(attente.parDefaut == .entree(entree))
        #expect(CartesFiche.donjon(entree: nil, guide: nil, detail: nil).parDefaut == nil)

        let boss = DetailDonjon.Monstre(id: 3416, noms: [:], boss: true, fiche: Self.fiche)
        let mansot = DetailDonjon.Monstre(id: 3384, noms: [:], boss: false, fiche: Self.fiche)
        let detail = DetailDonjon(monstres: [boss, mansot], clefs: [.init(objet: 14047, noms: [:], quantite: 1)],
                                  succes: [.init(noms: [:], description: [:])])
        let cartes = CartesFiche.donjon(entree: entree, guide: "Guide", detail: detail)
        #expect(cartes.rangees == [[.entree(entree), .guide("Guide"), .clef(objet: 14047)], [.monstres, .succes]])
        // Seuls des boss : rien à déplier pour les monstres.
        #expect(CartesFiche.donjon(entree: entree, guide: nil, detail: DetailDonjon(monstres: [boss], clefs: [], succes: []))
            .rangees == [[.entree(entree)], []])
    }

    @Test("Fiche au clavier : ↓ entre et descend de rangée, ↑ remonte jusqu'à la ligne, ←/→ restent dans la rangée")
    func navigation() {
        typealias P = CartesFiche.Position
        let cartes = CartesFiche(rangees: [[.guide("a"), .guide("b"), .guide("c")], [], [.monstres, .succes]])
        #expect(cartes.dessous(nil) == P(rangee: 0, colonne: 0))
        // La rangée vide est sautée, la colonne gardée au plus près.
        #expect(cartes.dessous(P(rangee: 0, colonne: 2)) == P(rangee: 2, colonne: 1))
        #expect(cartes.dessous(P(rangee: 2, colonne: 0)) == nil)
        #expect(cartes.dessus(P(rangee: 2, colonne: 1)) == P(rangee: 0, colonne: 1))
        #expect(cartes.dessus(P(rangee: 0, colonne: 1)) == nil)
        #expect(cartes.derniere == P(rangee: 2, colonne: 0))
        #expect(cartes.laterale(P(rangee: 0, colonne: 2), 1) == P(rangee: 0, colonne: 2))
        #expect(cartes.laterale(P(rangee: 0, colonne: 2), -1) == P(rangee: 0, colonne: 1))
        #expect(cartes.action(P(rangee: 2, colonne: 1)) == .succes)
        #expect(cartes.valide(P(rangee: 1, colonne: 0)) == nil)
        #expect(cartes.valide(P(rangee: 0, colonne: 5)) == P(rangee: 0, colonne: 2))
        #expect(CartesFiche.vide.dessous(nil) == nil && CartesFiche.vide.derniere == nil)
    }

    private static let fiche = FicheCombat(FicheCombat.MonstreAPI(
        id: 1, name: nil, grades: [.init(grade: 1, level: 1, lifePoints: 1, actionPoints: 1, movementPoints: 1,
                                         reductionNeutral: nil, reductionEarth: nil, reductionFire: nil,
                                         reductionWater: nil, reductionAir: nil)]))!
}
