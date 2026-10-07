import Foundation
import Testing
@testable import Synfus

/// Les quêtes : assemblées depuis DofusDB, leurs ressources, et la palette.
struct QuetesTests {

    /// Wogew l'hewmite, raccourcie : trois étapes, deux objets à ramener.
    static let page = """
    {"total":1,"data":[{"id":18,"name":{"fr":"Wogew l'hewmite","en":"Wogew the Hewmit"},"levelMin":70,
      "stepIds":[57,55],"startPosition":[{"mapId":160695296,"npcId":196}],
      "steps":[
        {"id":55,"name":{"fr":"Le sang du wabbit GM"},"objectives":[
          {"className":"QuestObjectiveFightMonsterData","text":{"fr":"Vaincre x1 {monster,182} en un seul combat"},
           "coords":{"x":25,"y":-8},"parameters":{"parameter0":182,"parameter1":1}},
          {"className":"QuestObjectiveBringItemToNpcData","text":{"fr":"Ramener à {npc,119} : x3 {item,1746}"},
           "map":{"posX":-2,"posY":-4},"parameters":{"parameter0":119,"parameter1":1746,"parameter2":3}}]},
        {"id":57,"name":{"fr":"Analyse de sang"},"objectives":[
          {"className":"QuestObjectiveBringItemToNpcData","text":{"fr":"Ramener à {npc,196} : x2 {item,1746}"},
           "parameters":{"parameter0":196,"parameter1":1746,"parameter2":2}},
          {"className":"QuestObjectiveDiscoverMapData","text":{"fr":"Découvrir la carte : {map,99}"}}]}]}]}
    """

    static func quetes() throws -> Quetes {
        let api = try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(page.utf8)).data
        func nomme(_ id: Int, _ nom: String) throws -> QuetesDofusDB.Nomme {
            try JSONDecoder().decode(QuetesDofusDB.Nomme.self, from: Data(#"{"id":\#(id),"name":{"fr":"\#(nom)"}}"#.utf8))
        }
        let carte = try JSONDecoder().decode(QuetesDofusDB.CarteAPI.self,
                                             from: Data(#"{"id":160695296,"posX":-1,"posY":-39}"#.utf8))
        return QuetesDofusDB.assembler(
            quetes: api, objets: [try nomme(1746, "Sang de Wabbit GM")], monstres: [try nomme(182, "Wabbit GM")],
            pnjs: [try nomme(119, "Otomaï"), try nomme(196, "Wogew")], cartes: [carte], date: .now)
    }

    @Test("Les étapes suivent stepIds, les renvois se résolvent, un renvoi inconnu reste lisible")
    func assemblage() throws {
        let quetes = try Self.quetes()
        let quete = try #require(quetes.quetes.first)
        #expect(quete.etapes.map { $0.noms["fr"] } == ["Analyse de sang", "Le sang du wabbit GM"])
        #expect(quetes.texte("Ramener à {npc,119} : x3 {item,1746}", en: .fr) == "Ramener à Otomaï : x3 Sang de Wabbit GM")
        #expect(quetes.texte("Découvrir la carte : {map,99}", en: .fr) == "Découvrir la carte : [map]")
        let renvois = QuetesDofusDB.renvois(
            try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(Self.page.utf8))
                .data.flatMap { ($0.steps ?? []).flatMap { $0.objectives ?? [] } })
        #expect(renvois.objets == [1746] && renvois.monstres == [182] && renvois.pnjs == [119, 196])
    }

    @Test("Les ressources de la quête s'additionnent d'une étape à l'autre")
    func ressources() throws {
        let quete = try #require(try Self.quetes().quetes.first)
        #expect(Quetes.ressources(quete).map { [$0.objet, $0.quantite] } == [[1746, 5]])
    }

    @Test("Un PNJ est situé par le départ de la quête et par les objectifs qui mènent à lui")
    func pnjs() throws {
        let pnjs = try Self.quetes().pnjs
        #expect(pnjs.first { $0.id == 196 }?.positions == [PNJ.Position(x: -1, y: -39)])
        #expect(pnjs.first { $0.id == 119 }?.positions == [PNJ.Position(x: -2, y: -4)])
    }

    private func contexte() throws -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna")
        contexte.zaaps = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:])
        contexte.quetes = try Self.quetes()
        return contexte
    }

    @Test("/quete trouve la quête ; l'ouvrir montre les ressources puis les objectifs")
    func palette() throws {
        let contexte = try contexte()
        let quete = try #require(RecherchePalette.entrees("/quete wogew", contexte).first)
        #expect(quete.effet == .ouvrirQuete(18))
        let detail = RecherchePalette.quete(18, "", contexte)
        #expect(detail.first?.genre == .ressource)
        #expect(detail.first?.effet == .copier("Sang de Wabbit GM"))
        let otomai = try #require(detail.first { $0.titre.contains("Otomaï") })
        #expect(otomai.detail == "-2,-4")
        #expect(RecherchePalette.quete(18, "otomai", contexte).count == 1)
    }

    @Test("/pnj et le filtre PNJ : le trajet vers sa position")
    func paletteePNJ() throws {
        let contexte = try contexte()
        #expect(RecherchePalette.entrees("/pnj wogew", contexte).first?.detail == "-1,-39")
        #expect(RecherchePalette.entrees("", contexte, filtre: .pnj).allSatisfy { $0.genre == .pnj })
        #expect(RecherchePalette.entrees("wogew", contexte, filtre: .quetes).map(\.genre) == [.quete])
    }
}
