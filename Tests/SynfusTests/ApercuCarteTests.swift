import AppKit
import Testing
@testable import Synfus

/// Où se pose la vue agrandie d'une carte : à côté de la fenêtre de sa
/// vignette, sinon à gauche de la souris, toujours dans l'écran.
struct ApercuCarteTests {
    private let ecran = NSRect(x: 0, y: 0, width: 1440, height: 900)
    private let taille = NSSize(width: 638, height: 438)

    private func x(fenetre: NSRect?, souris: NSPoint = NSPoint(x: 1000, y: 450)) -> CGFloat {
        ApercuCarte.cadre(taille: taille, fenetre: fenetre, souris: souris, ecran: ecran).minX
    }

    @Test("À gauche de la fenêtre s'il y a la place, à droite sinon")
    func cotes() {
        #expect(x(fenetre: NSRect(x: 700, y: 300, width: 360, height: 480)) == 54)
        #expect(x(fenetre: NSRect(x: 100, y: 300, width: 360, height: 480)) == 468)
    }

    @Test("Sans place à côté de la fenêtre, ni de fenêtre connue : à gauche de la souris, dans l'écran")
    func souris() {
        let palette = NSRect(x: 390, y: 400, width: 660, height: 400)
        #expect(x(fenetre: palette) == 338)  // 1000 − 3 × 8 − 638
        #expect(x(fenetre: nil, souris: NSPoint(x: 300, y: 450)) == 0)
    }

    @Test("À hauteur de la souris, sans sortir de l'écran")
    func hauteur() {
        let haut = ApercuCarte.cadre(taille: taille, fenetre: nil, souris: NSPoint(x: 1000, y: 890), ecran: ecran)
        #expect(haut.maxY == ecran.maxY)
        let milieu = ApercuCarte.cadre(taille: taille, fenetre: nil, souris: NSPoint(x: 1000, y: 450), ecran: ecran)
        #expect(milieu.midY == 450)
    }
}
