import AppKit
import Testing
@testable import Synfus

/// Le panneau des quêtes : ses poignées de redimensionnement, le menu de son
/// en-tête (clic ou glisser), le repli des objectifs faits et le mode compact.
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

    @Test("Sur le titre de l'en-tête, un appui qui tremble reste un clic, un mouvement franc déplace")
    func clicOuGlisser() {
        let appui = NSPoint(x: 50, y: 50)
        let glisse = { (dx: CGFloat, dy: CGFloat) in
            WindowDragArea.estUnGlisser(depuis: appui, jusqua: NSPoint(x: appui.x + dx, y: appui.y + dy))
        }
        #expect(!glisse(0, 0))
        #expect(!glisse(2, -2))
        #expect(!glisse(WindowDragArea.seuilGlisser, 0))
        #expect(glisse(3, 1))
        #expect(glisse(-4, 0))
        #expect(glisse(0, 12))
    }

    private func nom(_ id: Int) -> String { "Q\(id)" }

    @Test("Le menu : les épinglées, la montrée cochée, puis le suivi et ses quêtes à leur étape")
    func menu() {
        let reconnues = [SuiviQuetes.Reconnue(id: 7, etape: 2), SuiviQuetes.Reconnue(id: 18, etape: nil)]
        let elements = MenuQuetes.elements(epinglees: [18, 42], montree: 42, reconnues: reconnues, etat: .lu, coches: 3, actives: [.masquerObjets], nom: nom)
        #expect(elements == [
            .titre(L("quete.menu.epinglees")),
            .epinglee(id: 18, nom: "Q18", montree: false),
            .epinglee(id: 42, nom: "Q42", montree: true),
            .desepingler(id: 42, nom: "Q42"),
            .toutDesepingler,
            .separateur,
            .titre(L("quete.menu.suivi")),
            .lireSuivi(enCours: false),
            .option(.cocherSuivi, actif: false),
            .reconnue(reconnues[0], titre: L("quete.menu.reconnueEtape", "Q7", 3), epinglee: false),
            .reconnue(reconnues[1], titre: "Q18", epinglee: true),
            .message(L("quete.suivi.coches", nombre: 3, 3)),
            .separateur,
            .option(.compact, actif: false),
            .option(.consigne, actif: false),
            .option(.masquerObjets, actif: true),
        ])
        #expect(MenuQuetes.nouvelles(reconnues, epinglees: [18, 42]) == 1)
    }

    /// Le séparateur et les options, en pied du menu.
    private let pied = 1 + MenuQuetes.Option.affichage.count

    @Test("Le menu dit pourquoi le suivi ne propose rien")
    func menuSansQuete() {
        let vide = MenuQuetes.elements(epinglees: [], montree: nil, reconnues: [], etat: .lu, coches: 0, actives: [], nom: nom)
        #expect(vide.contains(.message(L("quete.menu.aucune"))))
        #expect(!vide.contains(.toutDesepingler))
        #expect(vide.dropLast(pied).last == .message(L("quete.suivi.rien")))
        let enCours = MenuQuetes.elements(epinglees: [1], montree: 1, reconnues: [], etat: .enCours, coches: 2, actives: [], nom: nom)
        // Pendant la lecture, rien n'est dit de la précédente.
        #expect(Array(enCours.dropLast(pied).suffix(2)) == [.lireSuivi(enCours: true), .option(.cocherSuivi, actif: false)])
        // Une seule quête : la retirer, c'est tout retirer.
        #expect(enCours.contains(.desepingler(id: 1, nom: "Q1")) && !enCours.contains(.toutDesepingler))
        let illisible = MenuQuetes.elements(epinglees: [1], montree: 1, reconnues: [], etat: .illisible, coches: 2, actives: [], nom: nom)
        #expect(illisible.dropLast(pied).last == .message(L("quete.suivi.illisible")))
    }

    @Test("Le menu dit ce qui commence sur la case du perso, entre les épinglées et le suivi")
    func menuIci() {
        let ici = MenuQuetes.Ici(coordonnees: "[1,2]", quetes: [.init(id: 5, nom: "Q5", niveau: 10),
                                                               .init(id: 18, nom: "Q18", niveau: 70)], pnjs: ["Wogew", "Otomaï"])
        let elements = MenuQuetes.elements(epinglees: [18], montree: 18, reconnues: [], etat: .jamaisLu, coches: 0,
                                           actives: [], ici: ici, nom: nom)
        #expect(Array(elements.prefix(9)) == [
            .titre(L("quete.menu.epinglees")),
            .epinglee(id: 18, nom: "Q18", montree: true),
            .desepingler(id: 18, nom: "Q18"),
            .separateur,
            .titre(L("quete.menu.ici", "[1,2]")),
            .ici(id: 5, titre: L("quete.menu.iciQuete", "Q5", 10), epinglee: false),
            .ici(id: 18, titre: L("quete.menu.iciQuete", "Q18", 70), epinglee: true),
            .message(L("quete.menu.iciPNJ", "Wogew, Otomaï")),
            .separateur,
        ])
        let rien = MenuQuetes.elements(epinglees: [18], montree: 18, reconnues: [], etat: .jamaisLu, coches: 0, actives: [],
                                       ici: MenuQuetes.Ici(coordonnees: "[1,2]", quetes: [], pnjs: []), nom: nom)
        #expect(!rien.contains(.titre(L("quete.menu.ici", "[1,2]"))))
    }

    @Test("Le mode compact ne grandit aucune mesure de la fiche")
    func compact() {
        let confort = Mirror(reflecting: MetriquesQuete.confort).children.map(\.value)
        let compact = Mirror(reflecting: MetriquesQuete.compact).children.map(\.value)
        #expect(confort.count == compact.count && !confort.isEmpty)
        for (grand, petit) in zip(confort, compact) {
            switch (grand, petit) {
            case let (grand as CGFloat, petit as CGFloat): #expect(petit <= grand)
            case let (grand as CGSize, petit as CGSize): #expect(petit.width <= grand.width && petit.height <= grand.height)
            default: Issue.record("mesure d'un type inattendu : \(grand)")
            }
        }
        #expect(MetriquesQuete.compact != .confort)
        #expect(MetriquesQuete.pour(compact: true) == .compact && MetriquesQuete.pour(compact: false) == .confort)
    }

    /// [0,4] trois fois (aller voir, inspecter, revenir), puis [0,9] une fois :
    /// sur [0,4], seul le prochain à faire est proposé ; sur [0,9], le seul
    /// de sa carte l'est même s'il n'est pas le prochain.
    @Test("« Tu y es » : le prochain objectif de la carte, le seul de sa carte, ou celui en cours")
    func suggestion() {
        let ici = PNJ.Position(x: 0, y: 4), ailleurs = PNJ.Position(x: 0, y: 9)
        let etape = FicheQuete.Etape(
            nom: "E", description: nil,
            objectifs: [(1, ici), (2, ici), (3, nil), (4, ici), (5, ailleurs)].map {
                FicheQuete.Objectif(id: $0.0, texte: "O\($0.0)", position: $0.1, carte: nil, combat: false)
            },
            recompenses: .init(niveau: 1, experience: 0, kamas: 0, objets: [], emotes: [], titres: []))
        #expect(etape.suggeres(en: ici, valides: [], enCours: nil, combatFini: false) == [1])
        #expect(etape.suggeres(en: ici, valides: [1], enCours: nil, combatFini: false) == [2])
        // Le prochain est ailleurs (3, non situé) : [0,4] n'est pas à valider.
        #expect(etape.suggeres(en: ici, valides: [1, 2], enCours: nil, combatFini: false).isEmpty)
        #expect(etape.suggeres(en: ailleurs, valides: [], enCours: nil, combatFini: false) == [5])
        #expect(etape.suggeres(en: ailleurs, valides: [5], enCours: nil, combatFini: false).isEmpty)
        #expect(etape.suggeres(en: nil, valides: [], enCours: nil, combatFini: false).isEmpty)
        // En cours, l'objectif est proposé sur sa carte, rang et voisins
        // n'y font rien ; ailleurs ou fait, non.
        #expect(etape.suggeres(en: ici, valides: [1, 2], enCours: 4, combatFini: false) == [4])
        #expect(etape.suggeres(en: ici, valides: [], enCours: 4, combatFini: false) == [1, 4])
        #expect(etape.suggeres(en: ailleurs, valides: [5], enCours: 4, combatFini: false).isEmpty)
        #expect(etape.suggeres(en: ici, valides: [1, 2, 4], enCours: 4, combatFini: false).isEmpty)
    }

    /// [0,4] : aller voir (1), vaincre (2) ; [0,9] : vaincre (3), seul de sa carte.
    @Test("« Vaincre… » n'est proposé qu'après un combat fini sur sa carte, quel que soit son rang")
    func suggestionCombat() {
        let ici = PNJ.Position(x: 0, y: 4), ailleurs = PNJ.Position(x: 0, y: 9)
        let etape = FicheQuete.Etape(
            nom: "E", description: nil,
            objectifs: [(1, ici, false), (2, ici, true), (3, ailleurs, true)].map {
                FicheQuete.Objectif(id: $0.0, texte: "O\($0.0)", position: $0.1, carte: nil, combat: $0.2)
            },
            recompenses: .init(niveau: 1, experience: 0, kamas: 0, objets: [], emotes: [], titres: []))
        #expect(etape.suggeres(en: ici, valides: [], enCours: nil, combatFini: false) == [1])
        #expect(etape.suggeres(en: ici, valides: [], enCours: nil, combatFini: true) == [1, 2])
        // Prochain, en cours ou seul de sa carte : sans combat, rien.
        #expect(etape.suggeres(en: ici, valides: [1], enCours: 2, combatFini: false).isEmpty)
        #expect(etape.suggeres(en: ailleurs, valides: [], enCours: nil, combatFini: false).isEmpty)
        #expect(etape.suggeres(en: ailleurs, valides: [], enCours: nil, combatFini: true) == [3])
        #expect(etape.suggeres(en: ailleurs, valides: [3], enCours: nil, combatFini: true).isEmpty)
    }
}
