import Foundation
import Testing
@testable import Synfus

/// Les quêtes : assemblées depuis DofusDB, leurs ressources, et la palette.
struct QuetesTests {

    /// Wogew l'hewmite, raccourcie : trois étapes, deux objets à ramener.
    static let page = """
    {"total":1,"data":[{"id":18,"name":{"fr":"Wogew l'hewmite","en":"Wogew the Hewmit"},"levelMin":70,"isPartyQuest":true,
      "stepIds":[57,55],"startPosition":[{"mapId":160695296,"npcId":196}],
      "steps":[
        {"id":55,"name":{"fr":"Le sang du wabbit GM"},"objectives":[
          {"className":"QuestObjectiveFightMonsterData","text":{"fr":"Vaincre x1 {monster,182} en un seul combat"},
           "coords":{"x":25,"y":-8},"parameters":{"parameter0":182,"parameter1":1}},
          {"className":"QuestObjectiveBringItemToNpcData","text":{"fr":"Ramener à {npc,119} : x3 {item,1746}"},
           "map":{"posX":-2,"posY":-4,"subAreaId":10},"parameters":{"parameter0":119,"parameter1":1746,"parameter2":3}}]},
        {"id":57,"name":{"fr":"Analyse de sang"},"objectives":[
          {"className":"QuestObjectiveBringItemToNpcData","text":{"fr":"Ramener à {npc,196} : x2 {item,1746}"},
           "parameters":{"parameter0":196,"parameter1":1746,"parameter2":2}},
          {"className":"QuestObjectiveDiscoverMapData","text":{"fr":"Découvrir la carte : {map,99}"}}]}]}]}
    """

    static func quetes() throws -> Quetes {
        let api = try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(page.utf8)).data
        func nomme(_ id: Int, _ nom: String, type: Int? = nil) throws -> QuetesDofusDB.Nomme {
            var nomme = try JSONDecoder().decode(QuetesDofusDB.Nomme.self,
                                                 from: Data(#"{"id":\#(id),"name":{"fr":"\#(nom)"}}"#.utf8))
            nomme.typeId = type
            return nomme
        }
        let type = try JSONDecoder().decode(QuetesDofusDB.TypeObjetAPI.self,
                                            from: Data(#"{"id":137,"superType":{"name":{"fr":"Objet de quête"}}}"#.utf8))
        let carte = try JSONDecoder().decode(QuetesDofusDB.CarteAPI.self,
                                             from: Data(#"{"id":160695296,"posX":-1,"posY":-39,"subAreaId":56}"#.utf8))
        let sousZone = try JSONDecoder().decode(QuetesDofusDB.SousZoneAPI.self,
                                                from: Data(#"{"id":10,"areaId":0,"name":{"fr":"Village d'Amakna"}}"#.utf8))
        let cites = QuetesDofusDB.Cites(
            objets: [try nomme(1746, "Sang de Wabbit GM", type: 137)], monstres: [try nomme(182, "Wabbit GM")],
            pnjs: [try nomme(119, "Otomaï"), try nomme(196, "Wogew")], cartes: [carte],
            sousZones: [sousZone], zones: [try nomme(0, "Amakna")], types: [type])
        return QuetesDofusDB.assembler(quetes: api, cites: cites, date: .now)
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

    @Test("Les passages d'un PNJ : le plus cité d'abord, avec sa sous-zone nommée")
    func passages() throws {
        // Une quête place Wogew en 5,5 ; deux autres en -2,-4.
        func quete(_ id: Int, _ x: Int, _ y: Int) -> String {
            #"{"id":\#(id),"name":{"fr":"Q\#(id)"},"steps":[{"id":\#(id),"name":{"fr":"E"},"objectives":[{"#
                + #""className":"QuestObjectiveGoToNpcData","text":{"fr":"Aller voir {npc,196}"},"#
                + #""map":{"posX":\#(x),"posY":\#(y),"subAreaId":10},"parameters":{"parameter0":196}}]}]}"#
        }
        let page = #"{"total":3,"data":["# + [quete(1, 5, 5), quete(2, -2, -4), quete(3, -2, -4)].joined(separator: ",") + "]}"
        let api = try JSONDecoder().decode(DofusDB.Page<QuetesDofusDB.QueteAPI>.self, from: Data(page.utf8)).data
        let wogew = try JSONDecoder().decode(QuetesDofusDB.Nomme.self, from: Data(#"{"id":196,"name":{"fr":"Wogew"}}"#.utf8))
        let quetes = QuetesDofusDB.assembler(quetes: api, cites: QuetesDofusDB.Cites(pnjs: [wogew]), date: .now)
        #expect(quetes.pnjs.first?.passages.map(\.quetes) == [2, 1])
        #expect(quetes.pnjs.first?.passages.first?.position == PNJ.Position(x: -2, y: -4))
        #expect(try Self.quetes().sousZones["10"]
                == SousZoneNommee(noms: ["fr": "Village d'Amakna"], zone: ["fr": "Amakna"]))
    }

    @Test("Un PNJ est situé par le départ de la quête et par les objectifs qui mènent à lui")
    func pnjs() throws {
        let pnjs = try Self.quetes().pnjs
        #expect(pnjs.first { $0.id == 196 }?.passages.map(\.position) == [PNJ.Position(x: -1, y: -39)])
        #expect(pnjs.first { $0.id == 119 }?.passages == [PNJ.Passage(position: PNJ.Position(x: -2, y: -4),
                                                                      sousZone: 10, quetes: 1)])
    }

    private func contexte() throws -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna")
        contexte.zaaps = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:])
        contexte.quetes = try Self.quetes()
        return contexte
    }

    @Test("/quete trouve la quête, qui s'ouvre dans son panneau")
    func palette() throws {
        let quete = try #require(RecherchePalette.entrees("/quete wogew", try contexte()).first)
        #expect(quete.effet == .ouvrirQuete(18))
    }

    @Test("La fiche : ressources additionnées, objectifs résolus, carte quand elle est connue")
    func fiche() throws {
        let fiche = try #require(try Self.quetes().fiche(18, en: .fr))
        #expect(fiche.ressources == [FicheQuete.Ressource(nom: "Sang de Wabbit GM", quantite: 5, categorie: "Objet de quête")])
        #expect(fiche.groupe && !fiche.donjon)
        #expect(fiche.etapes.map(\.nom) == ["Analyse de sang", "Le sang du wabbit GM"])
        let otomai = try #require(fiche.etapes[1].objectifs.first { $0.texte.contains("Otomaï") })
        #expect(otomai.position == PNJ.Position(x: -2, y: -4))
        #expect(fiche.etapes[0].objectifs[1].position == nil)
    }

    @Test("/pnj et le filtre PNJ : le trajet vers sa position")
    func paletteePNJ() throws {
        let contexte = try contexte()
        #expect(RecherchePalette.entrees("/pnj wogew", contexte).first?.detail == "-1,-39")
        #expect(RecherchePalette.entrees("/pnj otomai", contexte).first?.sousTitre?.hasPrefix("Village d'Amakna · Amakna") == true)
        #expect(RecherchePalette.entrees("", contexte, filtre: .pnj).allSatisfy { $0.genre == .pnj })
        #expect(RecherchePalette.entrees("wogew", contexte, filtre: .quetes).map(\.genre) == [.quete])
    }
}
