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
        #expect(map.key(bar: 0, position: 11) == nil)
        #expect(map.finDeTour == nil)
    }

    @Test("L'état envoyé au Stream Deck porte la barre active, ses sorts et leurs touches")
    func etatStreamDeck() {
        var p = SpellProfile.empty(perso: "Aeryn", classe: "Feca")
        p.set(SpellSlot(sortId: 7, nom: "Bouclier"), bar: 1, position: 0)
        let client = DofusClient(pid: 10, slotKey: "10#0", axWindow: .application(10),
                                 rawTitle: "Aeryn - Feca - 3.6 - Release", name: "Aeryn",
                                 characterClass: "Feca", dormant: false)
        let state = StreamDeckLink.state(client: client, profile: p, dofusDevant: true, barre: 1,
                                         keyMap: .defaults, enCombat: nil) { id in id == 7 ? "PNG" : nil }
        #expect(state.perso == "Aeryn")
        #expect(state.barre == 2 && state.barres == 3)
        #expect(state.cases.count == 12)
        #expect(state.cases[0].nom == "Bouclier" && state.cases[0].icone == "PNG")
        #expect(state.cases[0].touche == DeckKey(HotKey(keyCode: 18, modifiers: UInt32(controlKey))))
        #expect(state.cases[1].sortId == nil && state.cases[1].touche != nil)
        #expect(state.enCombat == nil)
    }

    @Test("Sans perso devant, l'état reste complet mais vide de sorts")
    func etatSansPerso() {
        let state = StreamDeckLink.state(client: nil, profile: nil, dofusDevant: false, barre: 0,
                                         keyMap: .defaults, enCombat: nil) { _ in nil }
        #expect(state.perso == nil && !state.dofusDevant)
        #expect(state.cases.allSatisfy { $0.sortId == nil })
    }

    @Test("Une commande du plugin se décode, une inconnue non")
    func commandes() throws {
        let ok = try JSONDecoder().decode(DeckCommand.self, from: Data(#"{"type":"perso","slot":2}"#.utf8))
        #expect(ok.type == .perso && ok.slot == 2)
        #expect((try? JSONDecoder().decode(DeckCommand.self, from: Data(#"{"type":"frappe","keyCode":1}"#.utf8))) == nil)
    }
}
