import AppKit
import Testing
@testable import Synfus

/// Le panneau des quêtes : ses poignées de redimensionnement.
struct PanneauQuetesTests {
    private let depart = NSRect(x: 100, y: 200, width: 360, height: 480)
    private let minimum = NSSize(width: 280, height: 200)

    @Test("Un bord tiré ne déplace que lui : le haut et le bord opposé restent")
    func bords() {
        let droite = BordsPanneau.droite.cadre(depart, decalage: CGVector(dx: 40, dy: 30), minimum: minimum)
        #expect(droite == NSRect(x: 100, y: 200, width: 400, height: 480))
        let gauche = BordsPanneau.gauche.cadre(depart, decalage: CGVector(dx: -40, dy: 0), minimum: minimum)
        #expect(gauche == NSRect(x: 60, y: 200, width: 400, height: 480))
        // Vers le bas, y diminue : le panneau grandit, son haut (680) reste.
        let coin = BordsPanneau([.gauche, .bas]).cadre(depart, decalage: CGVector(dx: 20, dy: -50), minimum: minimum)
        #expect(coin == NSRect(x: 120, y: 150, width: 340, height: 530))
        #expect(coin.maxY == depart.maxY)
    }

    @Test("Le panneau ne passe pas sous sa taille minimale, le bord opposé tient")
    func tailleMinimale() {
        let cadre = BordsPanneau([.gauche, .bas]).cadre(depart, decalage: CGVector(dx: 500, dy: 500), minimum: minimum)
        #expect(cadre.size == minimum)
        #expect(cadre.maxX == depart.maxX && cadre.maxY == depart.maxY)
    }
}
