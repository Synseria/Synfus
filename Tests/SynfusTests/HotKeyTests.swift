import Testing
import Carbon.HIToolbox
import AppKit
@testable import Synfus

struct HotKeyTests {

    @Test("Les modificateurs sont rendus dans l'ordre canonique macOS")
    func ordreDesModificateurs() {
        let touche = HotKey(
            keyCode: 18,
            modifiers: UInt32(cmdKey) | UInt32(shiftKey) | UInt32(optionKey) | UInt32(controlKey)
        )
        #expect(touche.displayString == "⌃⌥⇧⌘1")
    }

    @Test("Un raccourci simple se lit tel quel")
    func raccourciSimple() {
        #expect(HotKey(keyCode: 18, modifiers: UInt32(cmdKey)).displayString == "⌘1")
    }

    /// Les keycodes désignent des positions physiques, pas des caractères : sur
    /// AZERTY la rangée du haut tape « & é " ' ( » mais tout le monde l'appelle
    /// « 1 2 3 4 5 ». Afficher le caractère produit dérouterait l'utilisateur.
    @Test("La rangée du haut s'affiche 1 à 0 quel que soit le clavier")
    func rangeeDesChiffres() {
        let rendus = HotKey.digitRow.map { HotKey.keyName($0) }
        #expect(rendus == ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
    }

    @Test("La rangée du haut compte dix touches distinctes")
    func rangeeSansDoublon() {
        #expect(Set(HotKey.digitRow).count == 10)
    }

    @Test("Les touches nommées ont un symbole", arguments: [
        (UInt32(48), "⇥"), (UInt32(53), "⎋"), (UInt32(36), "↩"),
        (UInt32(50), "@"), (UInt32(122), "F1"),
    ])
    func touchesNommees(code: UInt32, attendu: String) {
        #expect(HotKey.keyName(code) == attendu)
    }

    @Test("Un keycode inconnu reste identifiable")
    func keycodeInconnu() {
        #expect(HotKey.keyName(200) == "#200")
    }

    @Test("Les touches de fonction sont reconnues comme telles")
    func touchesDeFonction() {
        #expect(HotKey.isFunctionKey(122))       // F1
        #expect(!HotKey.isFunctionKey(18))       // « 1 »
    }

    @Test("Les modificateurs AppKit sont traduits en constantes Carbon")
    func traductionDesModificateurs() {
        let mods = HotKey.carbonModifiers(from: [.command, .shift])
        #expect(mods == UInt32(cmdKey) | UInt32(shiftKey))
        #expect(HotKey.carbonModifiers(from: []) == 0)
        // `.capsLock` n'est pas un modificateur de raccourci.
        #expect(HotKey.carbonModifiers(from: [.capsLock]) == 0)
    }

    @Test("Les cinq premiers emplacements reçoivent ⌘1 à ⌘5")
    func raccourcisParDefaut() {
        for slot in 0..<5 {
            let touche = HotKey.defaultHotKey(slot: slot)
            #expect(touche?.modifiers == UInt32(cmdKey))
            #expect(touche?.keyCode == HotKey.digitRow[slot])
        }
    }

    @Test("Au-delà de la rangée du haut, plus de raccourci par défaut")
    func plusDeRaccourciParDefaut() {
        #expect(HotKey.defaultHotKey(slot: HotKey.digitRow.count) == nil)
    }

    /// Un raccourci global sans modificateur intercepterait la touche partout, y
    /// compris pendant que l'utilisateur écrit dans le chat du jeu.
    @Test("Une touche nue est refusée, sauf touche de fonction")
    func toucheNueRefusee() throws {
        let nue = try #require(evenement(keyCode: 0, modifiers: []))
        #expect(HotKey(event: nue) == nil)

        let fonction = try #require(evenement(keyCode: 122, modifiers: []))
        #expect(HotKey(event: fonction) != nil)

        let combinee = try #require(evenement(keyCode: 0, modifiers: [.command]))
        #expect(HotKey(event: combinee) == HotKey(keyCode: 0, modifiers: UInt32(cmdKey)))
    }

    private func evenement(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) -> NSEvent? {
        NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0,
            windowNumber: 0, context: nil, characters: "",
            charactersIgnoringModifiers: "", isARepeat: false, keyCode: keyCode
        )
    }

    @Test("Un raccourci survit à un aller-retour JSON")
    func serialisation() throws {
        let touche = HotKey(keyCode: 48, modifiers: UInt32(controlKey))
        let data = try JSONEncoder().encode(touche)
        #expect(try JSONDecoder().decode(HotKey.self, from: data) == touche)
    }
}
