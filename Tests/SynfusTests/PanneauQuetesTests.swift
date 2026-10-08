import AppKit
import Testing
@testable import Synfus

/// Le panneau des quêtes : ses poignées de redimensionnement et le menu de
/// son en-tête.
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

    private func nom(_ id: Int) -> String { "Q\(id)" }

    @Test("Le menu : les épinglées, la montrée cochée, puis le suivi et ses quêtes à leur étape")
    func menu() {
        let reconnues = [SuiviQuetes.Reconnue(id: 7, etape: 2), SuiviQuetes.Reconnue(id: 18, etape: nil)]
        let elements = MenuQuetes.elements(epinglees: [18, 42], montree: 42, reconnues: reconnues, etat: .lu, nom: nom)
        #expect(elements == [
            .titre(L("quete.menu.epinglees")),
            .epinglee(id: 18, nom: "Q18", montree: false),
            .epinglee(id: 42, nom: "Q42", montree: true),
            .separateur,
            .titre(L("quete.menu.suivi")),
            .lireSuivi(enCours: false),
            .reconnue(reconnues[0], titre: L("quete.menu.reconnueEtape", "Q7", 3), epinglee: false),
            .reconnue(reconnues[1], titre: "Q18", epinglee: true),
        ])
        #expect(MenuQuetes.nouvelles(reconnues, epinglees: [18, 42]) == 1)
    }

    @Test("Le menu dit pourquoi le suivi ne propose rien")
    func menuSansQuete() {
        let vide = MenuQuetes.elements(epinglees: [], montree: nil, reconnues: [], etat: .lu, nom: nom)
        #expect(vide.contains(.message(L("quete.menu.aucune"))))
        #expect(vide.last == .message(L("quete.suivi.rien")))
        let enCours = MenuQuetes.elements(epinglees: [1], montree: 1, reconnues: [], etat: .enCours, nom: nom)
        #expect(enCours.last == .lireSuivi(enCours: true))
        let illisible = MenuQuetes.elements(epinglees: [1], montree: 1, reconnues: [], etat: .illisible, nom: nom)
        #expect(illisible.last == .message(L("quete.suivi.illisible")))
    }
}
