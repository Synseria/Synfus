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

    @Test("Un panneau se tient par son coin haut gauche")
    func poignee() {
        let cadre = CGRect(x: 100, y: 200, width: 300, height: 400)
        #expect(PanneauxJeu.poignee(de: cadre) == CGPoint(x: 100, y: 600))
    }
}
