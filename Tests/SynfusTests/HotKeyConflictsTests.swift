import Testing
import Carbon.HIToolbox
@testable import Synfus

/// Deux gestes sur la même combinaison : le système n'en enregistre qu'un, et
/// rien ne le disait ligne par ligne dans les réglages.
struct HotKeyConflictsTests {

    private func touche(_ code: UInt32, _ mods: Int = cmdKey) -> HotKey {
        HotKey(keyCode: code, modifiers: UInt32(mods))
    }

    @Test("Sans doublon, rien à signaler")
    func aucunConflit() {
        #expect(HotKeyConflicts.doublons([touche(18), touche(19), touche(20)]).isEmpty)
    }

    @Test("Une combinaison donnée deux fois est signalée une fois")
    func doublon() {
        let conflits = HotKeyConflicts.doublons([touche(18), touche(19), touche(18)])
        #expect(conflits == [touche(18)])
    }

    @Test("Les emplacements sans raccourci ne font jamais conflit")
    func videsIgnores() {
        #expect(HotKeyConflicts.doublons([nil, nil, touche(18)]).isEmpty)
    }

    @Test("Les modificateurs distinguent deux raccourcis de la même touche")
    func modificateursDistincts() {
        #expect(HotKeyConflicts.doublons([
            touche(50, cmdKey),
            touche(50, cmdKey | shiftKey),
            touche(50, cmdKey | optionKey),
        ]).isEmpty)
    }

    @Test("Trois fois la même combinaison ne la signale qu'une fois")
    func triple() {
        #expect(HotKeyConflicts.doublons([touche(18), touche(18), touche(18)]) == [touche(18)])
    }
}
