import CoreGraphics
import Testing
@testable import Synfus

/// Le pointeur (repère AppKit) ramené au contenu de la fenêtre du jeu (repère AX).
extension ZoneEcranTests {
    /// Un écran principal de 1117 points de haut, comme un MacBook 14 pouces.
    private var hauteur: CGFloat { 1117 }
    private var barre: CGFloat { 28 }

    /// Le point AppKit d'un point AX.
    private func appKit(_ x: CGFloat, _ yAX: CGFloat) -> CGPoint { CGPoint(x: x, y: hauteur - yAX) }

    @Test("Fenêtré : la barre de titre ne fait pas partie du contenu")
    func pointeurFenetre() throws {
        let fenetre = CGRect(x: 100, y: 50, width: 1728, height: 1084 + barre)
        let coin = try #require(ZoneEcran.fraction(pointEcran: appKit(100, 50 + barre), fenetreAX: fenetre,
                                                   hauteurPrincipale: hauteur, barreTitre: barre, pleinEcran: false))
        #expect(coin == .zero)
        let milieu = try #require(ZoneEcran.fraction(pointEcran: appKit(100 + 864, 50 + barre + 542), fenetreAX: fenetre,
                                                     hauteurPrincipale: hauteur, barreTitre: barre, pleinEcran: false))
        #expect(abs(milieu.x - 0.5) < 1e-9 && abs(milieu.y - 0.5) < 1e-9)
        // Sur la barre de titre : hors du contenu.
        #expect(ZoneEcran.fraction(pointEcran: appKit(300, 60), fenetreAX: fenetre, hauteurPrincipale: hauteur,
                                   barreTitre: barre, pleinEcran: false) == nil)
    }

    @Test("Plein écran : le contenu commence en haut")
    func pointeurPleinEcran() throws {
        let fenetre = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let f = try #require(ZoneEcran.fraction(pointEcran: appKit(0, 10), fenetreAX: fenetre, hauteurPrincipale: hauteur,
                                                barreTitre: barre, pleinEcran: true))
        #expect(abs(f.y - 10.0 / 1117) < 1e-9)
    }

    @Test("Un écran à gauche du principal, x négatif")
    func pointeurEcranAGauche() throws {
        let fenetre = CGRect(x: -1920, y: 0, width: 1920, height: 1080)
        let f = try #require(ZoneEcran.fraction(pointEcran: appKit(-960, 540), fenetreAX: fenetre,
                                                hauteurPrincipale: hauteur, barreTitre: barre, pleinEcran: true))
        #expect(abs(f.x - 0.5) < 1e-9 && abs(f.y - 0.5) < 1e-9)
    }

    @Test("Un écran au-dessus du principal, y AX négatif")
    func pointeurEcranAuDessus() throws {
        let fenetre = CGRect(x: 0, y: -1080, width: 1920, height: 1080)
        // AppKit : au-dessus de l'écran principal, y > sa hauteur.
        let point = CGPoint(x: 480, y: hauteur + 270)
        let f = try #require(ZoneEcran.fraction(pointEcran: point, fenetreAX: fenetre, hauteurPrincipale: hauteur,
                                                barreTitre: barre, pleinEcran: true))
        #expect(abs(f.x - 0.25) < 1e-9 && abs(f.y - 0.75) < 1e-9)
    }

    @Test("Hors de la fenêtre : rien")
    func pointeurDehors() {
        let fenetre = CGRect(x: 100, y: 50, width: 800, height: 600)
        for point in [appKit(99, 300), appKit(900, 300), appKit(500, 650), appKit(500, 20)] {
            #expect(ZoneEcran.fraction(pointEcran: point, fenetreAX: fenetre, hauteurPrincipale: hauteur,
                                       barreTitre: barre, pleinEcran: false) == nil)
        }
    }

    @Test("Le cadre AppKit du contenu recouvre le contenu")
    func pointeurCadreAppKit() {
        let fenetre = CGRect(x: 100, y: 50, width: 800, height: 600 + barre)
        let cadre = ZoneEcran.cadreAppKit(fenetreAX: fenetre, hauteurPrincipale: hauteur, barreTitre: barre,
                                          pleinEcran: false)
        #expect(cadre == CGRect(x: 100, y: hauteur - 50 - barre - 600, width: 800, height: 600))
        // Son coin haut gauche est la fraction (0, 0).
        let haut = CGPoint(x: cadre.minX, y: cadre.maxY)
        #expect(ZoneEcran.fraction(pointEcran: haut, fenetreAX: fenetre, hauteurPrincipale: hauteur,
                                   barreTitre: barre, pleinEcran: false) == .zero)
    }
}
