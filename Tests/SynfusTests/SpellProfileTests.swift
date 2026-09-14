import Testing
import Foundation
import Carbon.HIToolbox
@testable import Synfus

/// Le profil de sorts d'un perso : son format, sa tolérance aux anciennes
/// sauvegardes, et l'état qu'il produit pour le Stream Deck.
@MainActor
struct SpellProfileTests {

    @Test("Un profil vide a trois barres de dix cases")
    func profilVide() {
        let p = SpellProfile.empty(perso: "Aeryn", classe: "Feca")
        #expect(p.barres.count == 3)
        #expect(p.barres.allSatisfy { $0.cases.count == 12 && $0.cases.allSatisfy { $0 == nil } })
    }

    @Test("Un profil se relit à l'identique après encodage")
    func allerRetour() throws {
        var p = SpellProfile.empty(perso: "Aeryn", classe: "Feca")
        p.set(SpellSlot(sortId: 12983, nom: "Glyphe agressif"), bar: 0, position: 2)
        let data = try JSONEncoder().encode(p)
        let back = try JSONDecoder().decode(SpellProfile.self, from: data)
        #expect(back == p)
        #expect(back.slot(bar: 0, position: 2)?.nom == "Glyphe agressif")
    }

    @Test("Une sauvegarde amputée de barres ou de cases est complétée, jamais tronquée")
    func sauvegardeAmputee() throws {
        let json = """
        {"version":1,"perso":"Brok","barres":[{"nom":"Barre 1","cases":[{"sortId":1,"nom":"Un"},null]}]}
        """
        var p = try JSONDecoder().decode(SpellProfile.self, from: Data(json.utf8))
        p.normalize()
        #expect(p.barres.count == 3)
        #expect(p.barres[0].cases.count == 12)
        #expect(p.slot(bar: 0, position: 0)?.sortId == 1)
        #expect(p.classe == nil)
    }

    @Test("Les touches par défaut : chiffres nus, ⌃, ⌃⇧ — jamais ⌘")
    func touchesParDefaut() {
        let map = SpellKeyMap.defaults
        #expect(map.barres.count == 3)
        #expect(map.key(bar: 0, position: 0) == HotKey(keyCode: 18, modifiers: 0))
        #expect(map.key(bar: 1, position: 9) == HotKey(keyCode: 29, modifiers: UInt32(controlKey)))
        #expect(map.key(bar: 2, position: 0)?.modifiers == UInt32(controlKey | shiftKey))
        #expect(map.barres.flatMap { $0 }.compactMap { $0 }.allSatisfy { $0.modifiers & UInt32(cmdKey) == 0 })
        #expect(map.key(bar: 0, position: 10) == HotKey(keyCode: 27, modifiers: 0))
        #expect(map.key(bar: 0, position: 11) == HotKey(keyCode: 24, modifiers: 0))
        #expect(map.finDeTour == nil)
    }

    @Test("Les commandes du jeu ont un défaut, et une sauvegarde ancienne reçoit les nouvelles")
    func commandesDuJeu() {
        let defaults = GameCommands.defaults
        #expect(defaults.contains { $0.id == GameCommands.suiviID && $0.touche?.modifiers == UInt32(controlKey) })
        let completed = GameCommands.normalized([GameCommand(id: "inventaire", nom: "Inv", symbole: "bag", touche: nil)])
        #expect(completed.count == defaults.count)
        #expect(completed[0].nom == "Inv" && completed[0].touche == nil)
    }

    @Test("Un profil sans disposition se relit, et une disposition personnalisée fait l'aller-retour")
    func disposition() throws {
        let json = """
        {"version":1,"perso":"Brok","barres":[]}
        """
        let p = try JSONDecoder().decode(SpellProfile.self, from: Data(json.utf8))
        #expect(p.disposition == nil)
        var custom = DeckLayout.parBarre(colonnes: 5, lignes: 3)
        custom[1, 0] = DeckTile(.sort(barre: 2, position: 11), long: .commande("inventaire"))
        var q = SpellProfile.empty(perso: "Brok", classe: nil)
        q.disposition = .personnalisee(custom)
        let back = try JSONDecoder().decode(SpellProfile.self, from: JSONEncoder().encode(q))
        #expect(back.disposition == .personnalisee(custom))
    }

    @Test("Une commande du plugin se décode, une inconnue non")
    func commandes() throws {
        let ok = try JSONDecoder().decode(DeckCommand.self, from: Data(#"{"type":"perso","slot":2}"#.utf8))
        #expect(ok.type == .perso && ok.slot == 2)
        #expect((try? JSONDecoder().decode(DeckCommand.self, from: Data(#"{"type":"frappe","keyCode":1}"#.utf8))) == nil)
        let grid = try JSONDecoder().decode(DeckCommand.self, from: Data(#"{"type":"appareil","colonnes":8,"lignes":4}"#.utf8))
        #expect(grid.type == .appareil && grid.colonnes == 8 && grid.lignes == 4)
    }
}
