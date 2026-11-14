import Foundation
import Testing
@testable import Synfus

/// La règle qui dit si un panneau (ou la barre) est encore atteignable après un écran débranché.
struct PanneauxJeuTests {
    private let principal = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let second = CGRect(x: 1440, y: 0, width: 1920, height: 1080)

    @Test("Un point sur un écran présent est atteignable")
    func surUnEcran() {
        #expect(PanneauxJeu.surUnEcran(CGPoint(x: 700, y: 400), ecrans: [principal]))
        #expect(PanneauxJeu.surUnEcran(CGPoint(x: 2000, y: 500), ecrans: [principal, second]))
    }

    @Test("Un point resté sur un écran débranché ne l'est pas")
    func ecranAbsent() {
        #expect(!PanneauxJeu.surUnEcran(CGPoint(x: 2000, y: 500), ecrans: [principal]))
        #expect(!PanneauxJeu.surUnEcran(CGPoint(x: 700, y: 400), ecrans: []))
    }

    @Test("Un point à peine hors de l'écran compte encore dessus, un point loin non")
    func marge() {
        #expect(PanneauxJeu.surUnEcran(CGPoint(x: -30, y: 450), ecrans: [principal]))
        #expect(!PanneauxJeu.surUnEcran(CGPoint(x: -41, y: 450), ecrans: [principal]))
    }

    @Test("Un panneau poussé à moitié hors de l'écran par la gauche, l'écran branché, ne bouge pas")
    func moitieHorsEcran() {
        let cadre = CGRect(x: -180, y: 300, width: 360, height: 400)
        #expect(PanneauxJeu.bandeauAtteignable(de: cadre, ecrans: [principal]))
    }

    @Test("Un panneau resté sur un écran débranché est rattrapé, un panneau à peine accroché non")
    func bandeauPerdu() {
        #expect(!PanneauxJeu.bandeauAtteignable(de: CGRect(x: 2000, y: 300, width: 360, height: 400), ecrans: [principal]))
        #expect(!PanneauxJeu.bandeauAtteignable(de: CGRect(x: -350, y: 300, width: 360, height: 400), ecrans: [principal]))
        #expect(PanneauxJeu.bandeauAtteignable(de: CGRect(x: 1300, y: 300, width: 360, height: 400), ecrans: [principal, second]))
    }
}
