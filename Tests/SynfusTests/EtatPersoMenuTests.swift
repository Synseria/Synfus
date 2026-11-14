@testable import Synfus
import Testing

@Suite("Menu : l'état d'un perso")
struct EtatPersoMenuTests {
    @Test("Un seul état, le plus pressant : son tour, puis l'appel, le combat, l'autre bureau")
    func priorite() {
        #expect(EtatPersoMenu.de(combat: .monTour(fin: nil), appelle: true, dormant: true) == .sonTour)
        #expect(EtatPersoMenu.de(combat: .pasMonTour, appelle: true, dormant: true) == .appelle)
        #expect(EtatPersoMenu.de(combat: .placement, appelle: false, dormant: true) == .enCombat)
        #expect(EtatPersoMenu.de(combat: .horsCombat, appelle: false, dormant: true) == .autreBureau)
    }

    @Test("Rien quand tout est normal")
    func rien() {
        #expect(EtatPersoMenu.de(combat: nil, appelle: false, dormant: false) == nil)
        #expect(EtatPersoMenu.de(combat: .horsCombat, appelle: false, dormant: false) == nil)
    }
}
