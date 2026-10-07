import Foundation
import Testing
@testable import Synfus

/// La carte : assemblée depuis DofusDB, les zaaps en sont tirés.
struct CarteTests {

    @Test("Chaque repère reçoit sa sous-zone et sa zone ; un repère orphelin garde des noms vides")
    func assemblage() throws {
        let reperes = """
        {"total":3,"data":[
          {"id":1,"x":-2,"y":0,"worldMapId":1,"categoryId":9,"subareaId":10,"name":{"fr":"Zaap","en":"Zaap"}},
          {"id":2,"x":-2,"y":1,"worldMapId":1,"categoryId":4,"subareaId":10,"name":{"fr":"Banque","en":"Bank"}},
          {"id":3,"x":9,"y":9,"worldMapId":1,"categoryId":4,"subareaId":999,"name":{"fr":"Milice"}}]}
        """
        let sousZones = """
        {"total":1,"data":[{"id":10,"areaId":0,"name":{"id":"1","fr":"Village d'Amakna","en":"Amakna Village"}}]}
        """
        let zones = """
        {"total":1,"data":[{"id":0,"name":{"fr":"Amakna","en":"Amakna"}}]}
        """
        let decodeur = JSONDecoder()
        let lieux = CarteDofusDB.assembler(
            reperes: try decodeur.decode(DofusDB.Page<CarteDofusDB.Repere>.self, from: Data(reperes.utf8)).data,
            sousZones: try decodeur.decode(DofusDB.Page<CarteDofusDB.SousZone>.self, from: Data(sousZones.utf8)).data,
            zones: try decodeur.decode(DofusDB.Page<CarteDofusDB.Zone>.self, from: Data(zones.utf8)).data)
        #expect(lieux.map(\.id) == [1, 2, 3])
        #expect(lieux[1].nom(en: .en) == "Bank")
        #expect(lieux[1].sousZone(en: .fr) == "Village d'Amakna")
        #expect(lieux[1].zone(en: .es) == "Amakna")
        #expect(lieux[2].zone.isEmpty && lieux[2].sousZone.isEmpty)

        let carte = Carte(date: .now, lieux: lieux)
        #expect(carte.zaaps == [Zaap(-2, 0, noms: ["fr": "Village d'Amakna", "en": "Amakna Village"],
                                     zone: ["fr": "Amakna", "en": "Amakna"])])
    }

    @Test("La carte intégrée : tous les zaaps, une banque à Bonta")
    func integree() {
        let carte = Carte.integree
        #expect(carte.lieux.count >= Carte.minimumPlausible)
        #expect(carte.zaaps.count == 45)
        let cles = carte.zaaps.map(\.cle)
        #expect(Set(cles).count == cles.count)
        #expect(carte.lieux.contains { $0.nom(en: .fr) == "Banque" && $0.zone(en: .fr) == "Bonta" })
        #expect(carte.zaaps.contains { $0.nom(en: .fr) == "Cœur immaculé" && $0.zone(en: .fr) == "Bonta" })
    }

    @Test("Un zaap ajouté avant la zone se relit, sans zone")
    func zaapSansZone() throws {
        let ancien = #"{"x":50,"y":-50,"monde":1,"noms":{"fr":"Mon zaap"}}"#
        let zaap = try JSONDecoder().decode(Zaap.self, from: Data(ancien.utf8))
        #expect(zaap == Zaap(50, -50, noms: ["fr": "Mon zaap"]))
    }
}
