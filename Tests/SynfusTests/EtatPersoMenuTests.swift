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

@Suite("Menu : la lecture de l'écran manquante")
struct AutorisationsMenuTests {
    @Test("Proposée seulement si quelque chose la lit")
    func quandProposer() {
        func manque(_ position: Bool = false, _ combat: Bool = false, _ apercus: Bool = false, _ panneau: Bool = false,
                    autorisee: Bool = false) -> Bool {
            AutorisationsMenu.lectureEcranManque(autorisee: autorisee, lirePosition: position, lireCombat: combat,
                                                 apercus: apercus, panneauLisant: panneau)
        }
        #expect(!manque())
        #expect(manque(true) && manque(false, true) && manque(false, false, true) && manque(false, false, false, true))
        #expect(!manque(true, true, true, true, autorisee: true))
    }
}
