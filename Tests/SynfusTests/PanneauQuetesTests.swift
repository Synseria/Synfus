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

    @Test("Le menu des étapes : toutes, numérotées, la montrée et les faites distinguées")
    func menuEtapes() {
        let entrees = MenuEtapes.entrees([("Parler", true), ("Chasser", false), ("Rendre", false)], montree: 1)
        #expect(entrees == [
            .init(rang: 0, titre: L("quete.etapes.item", 1, "Parler"), montree: false, faite: true),
            .init(rang: 1, titre: L("quete.etapes.item", 2, "Chasser"), montree: true, faite: false),
            .init(rang: 2, titre: L("quete.etapes.item", 3, "Rendre"), montree: false, faite: false),
        ])
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
            .separateur,
            .fermer,
        ])
        #expect(MenuQuetes.nouvelles(reconnues, epinglees: [18, 42]) == 1)
    }

    @Test("Un suivi illisible dit la cause que la lecture a portée, avec son geste")
    func problemesDuSuivi() {
        typealias P = MenuQuetes.Probleme
        #expect(P.de(.illisible(.sansAutorisation), autorise: false) == .sansAutorisation)
        // Autorisé depuis l'échec : plus de cause à montrer.
        #expect(P.de(.illisible(.sansAutorisation), autorise: true) == nil)
        #expect(P.de(.illisible(.sansPerso), autorise: true) == .sansPerso)
        // Une capture qui échoue n'est pas une zone à calibrer.
        #expect(P.de(.illisible(.captureImpossible), autorise: true) == .captureImpossible)
        #expect(P.de(.illisible(.texteIllisible), autorise: true) == .zone)
        #expect(P.de(.sansQuetes, autorise: true) == .indisponible)
        #expect(P.de(.lu, autorise: false) == nil)
        #expect(P.sansPerso.geste == nil)
        #expect([P.sansAutorisation, .captureImpossible, .zone, .indisponible].map(\.geste) == [.autoriser, .relire, .calibrer, .reessayer])
    }

    @Test("« Tout épingler » : en tête du suivi dès deux quêtes à épingler, jamais pour une seule")
    func menuToutEpingler() {
        let reconnues = [SuiviQuetes.Reconnue(id: 7, etape: 2), SuiviQuetes.Reconnue(id: 9, etape: nil),
                         SuiviQuetes.Reconnue(id: 18, etape: nil)]
        #expect(MenuQuetes.aEpingler(reconnues, epinglees: [9]).map(\.id) == [7, 18])
        let deux = MenuQuetes.elements(epinglees: [9], montree: 9, reconnues: reconnues, etat: .lu, coches: 0, actives: [], nom: nom)
        let tete = deux.drop { $0 != .titre(L("quete.menu.suivi")) }.dropFirst().first
        #expect(tete == .toutEpingler)
        let une = MenuQuetes.elements(epinglees: [9, 18], montree: 9, reconnues: reconnues, etat: .lu, coches: 0, actives: [], nom: nom)
        #expect(!une.contains(.toutEpingler))
    }

    @Test("Une quête qui commence ici et n'est pas épinglée met la section « Ici » en tête du menu")
    func menuIciEnTete() {
        let ici = MenuQuetes.Ici(coordonnees: "[1,2]", quetes: [.init(id: 5, nom: "Q5", niveau: 10)], pnjs: [])
        let tete = MenuQuetes.elements(epinglees: [1], montree: 1, reconnues: [], etat: .lu, coches: 0, actives: [], ici: ici, nom: nom)
        #expect(tete.first == .titre(L("quete.menu.ici", "[1,2]")))
        #expect(tete.contains(.ici(id: 5, titre: L("quete.menu.iciQuete", "Q5", 10), epinglee: false)))
        #expect(ici.aEpingler([5]).isEmpty)
        // Déjà épinglée : la section reste, mais après les épinglées.
        let apres = MenuQuetes.elements(epinglees: [5], montree: 5, reconnues: [], etat: .lu, coches: 0, actives: [], ici: ici, nom: nom)
        #expect(apres.first == .titre(L("quete.menu.epinglees")))
        #expect(apres.contains(.ici(id: 5, titre: L("quete.menu.iciQuete", "Q5", 10), epinglee: true)))
    }

    @Test("Ce que l'en-tête redemande à chaque rendu ne se refait que si la case, les quêtes, la langue ou la carte changent")
    func cleIci() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        let cle = QuetePanel.CleIci(position: PositionCarte(x: 1, y: 2, zone: nil), quetes: date, langue: .fr, reseauLu: true)
        #expect(cle == QuetePanel.CleIci(position: PositionCarte(x: 1, y: 2, zone: nil), quetes: date, langue: .fr, reseauLu: true))
        #expect(cle != QuetePanel.CleIci(position: PositionCarte(x: 1, y: 3, zone: nil), quetes: date, langue: .fr, reseauLu: true))
        #expect(cle != QuetePanel.CleIci(position: cle.position, quetes: nil, langue: .fr, reseauLu: true))
        #expect(cle != QuetePanel.CleIci(position: cle.position, quetes: date, langue: .en, reseauLu: true))
        #expect(cle != QuetePanel.CleIci(position: cle.position, quetes: date, langue: .fr, reseauLu: false))
    }

    /// Le séparateur, les options, puis le séparateur et « Fermer le panneau », en pied du menu.
    private let pied = 1 + MenuQuetes.Option.affichage.count + 2

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
        let sansEcran = MenuQuetes.elements(epinglees: [1], montree: 1, reconnues: [], etat: .illisible(.sansAutorisation), coches: 2,
                                            actives: [], autorise: false, nom: nom)
        #expect(Array(sansEcran.dropLast(pied).suffix(2)) == [.message(L("quete.suivi.sansAutorisation")), .geste(.autoriser)])
    }

    @Test("Le menu dit ce qui commence sur la case du perso, en tête tant qu'une quête n'est pas épinglée")
    func menuIci() {
        let ici = MenuQuetes.Ici(coordonnees: "[1,2]", quetes: [.init(id: 5, nom: "Q5", niveau: 10),
                                                               .init(id: 18, nom: "Q18", niveau: 70)], pnjs: ["Wogew", "Otomaï"])
        let elements = MenuQuetes.elements(epinglees: [18], montree: 18, reconnues: [], etat: .jamaisLu, coches: 0,
                                           actives: [], ici: ici, nom: nom)
        #expect(Array(elements.prefix(9)) == [
            .titre(L("quete.menu.ici", "[1,2]")),
            .ici(id: 5, titre: L("quete.menu.iciQuete", "Q5", 10), epinglee: false),
            .ici(id: 18, titre: L("quete.menu.iciQuete", "Q18", 70), epinglee: true),
            .message(L("quete.menu.iciPNJ", "Wogew, Otomaï")),
            .separateur,
            .titre(L("quete.menu.epinglees")),
            .epinglee(id: 18, nom: "Q18", montree: true),
            .desepingler(id: 18, nom: "Q18"),
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
            case let (grand as Jetons.Typo, petit as Jetons.Typo): #expect(petit.taille <= grand.taille)
            case let (grand as CGSize, petit as CGSize): #expect(petit.width <= grand.width && petit.height <= grand.height)
            default: Issue.record("mesure d'un type inattendu : \(grand)")
            }
        }
        #expect(MetriquesQuete.compact != .confort)
        #expect(MetriquesQuete.pour(compact: true) == .compact && MetriquesQuete.pour(compact: false) == .confort)
    }

    private static func etape(_ objectifs: [(Int, PNJ.Position?, Bool)]) -> FicheQuete.Etape {
        FicheQuete.Etape(
            nom: "E", description: nil,
            objectifs: objectifs.map {
                FicheQuete.Objectif(id: $0.0, texte: "O\($0.0)", position: $0.1, carte: nil, combat: $0.2)
            },
            recompenses: .init(niveau: 1, experience: 0, kamas: 0, objets: [], emotes: [], titres: []))
    }

    /// [0,4] trois fois (aller voir, inspecter, revenir), puis [0,9] une fois :
    /// sans suivi lu, seul le prochain à faire est proposé, ou celui en cours —
    /// même seul de sa carte, un objectif plus loin dans l'étape ne l'est pas.
    @Test("« Tu y es » sans suivi lu : le prochain objectif de la carte, ou celui en cours")
    func suggestion() {
        let ici = PNJ.Position(x: 0, y: 4), ailleurs = PNJ.Position(x: 0, y: 9)
        let etape = Self.etape([(1, ici, false), (2, ici, false), (3, nil, false), (4, ici, false), (5, ailleurs, false)])
        func suggeres(_ position: PNJ.Position?, _ valides: Set<Int>, enCours: Int? = nil) -> Set<Int> {
            etape.suggeres(en: position, valides: valides, enCours: enCours, combatFini: false, lu: nil)
        }
        #expect(suggeres(ici, []) == [1])
        #expect(suggeres(ici, [1]) == [2])
        // Le prochain est ailleurs (3, non situé) : [0,4] n'est pas à valider.
        #expect(suggeres(ici, [1, 2]).isEmpty)
        #expect(suggeres(ailleurs, []).isEmpty)
        #expect(suggeres(ailleurs, [1, 2, 3, 4]) == [5])
        #expect(suggeres(ailleurs, [5]).isEmpty)
        #expect(suggeres(nil, []).isEmpty)
        // En cours, l'objectif est proposé sur sa carte, rang et voisins
        // n'y font rien ; ailleurs ou fait, non.
        #expect(suggeres(ici, [1, 2], enCours: 4) == [4])
        #expect(suggeres(ici, [], enCours: 4) == [1, 4])
        #expect(suggeres(ailleurs, [5], enCours: 4).isEmpty)
        #expect(suggeres(ici, [1, 2, 4], enCours: 4).isEmpty)
    }

    /// [0,4] : aller voir (1), vaincre (2) ; [0,9] : vaincre (3).
    @Test("« Vaincre… » n'est proposé qu'après un combat fini sur sa carte")
    func suggestionCombat() {
        let ici = PNJ.Position(x: 0, y: 4), ailleurs = PNJ.Position(x: 0, y: 9)
        let etape = Self.etape([(1, ici, false), (2, ici, true), (3, ailleurs, true)])
        func suggeres(_ position: PNJ.Position, _ valides: Set<Int>, enCours: Int? = nil, fini: Bool,
                      lu: SuiviQuetes.Reconnue? = nil) -> Set<Int> {
            etape.suggeres(en: position, valides: valides, enCours: enCours, combatFini: fini, lu: lu)
        }
        #expect(suggeres(ici, [], fini: false) == [1])
        // Sans lecture, le combat fini sur sa carte suffit, à tout rang.
        #expect(suggeres(ici, [], fini: true) == [1, 2])
        #expect(suggeres(ici, [1], fini: true) == [2])
        // Prochain ou en cours : sans combat, rien.
        #expect(suggeres(ici, [1], enCours: 2, fini: false).isEmpty)
        #expect(suggeres(ailleurs, [], fini: true) == [3])
        #expect(suggeres(ailleurs, [1, 2], fini: true) == [3])
        #expect(suggeres(ailleurs, [3], fini: true).isEmpty)
        // Le suivi montre les deux combats ouverts : chacun, après son combat.
        let ouverts = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [2, 3], faits: [1])
        #expect(suggeres(ailleurs, [], fini: true, lu: ouverts) == [3])
        #expect(suggeres(ailleurs, [], fini: false, lu: ouverts).isEmpty)
        // Le suivi tait le second combat : même après lui, rien.
        let tait = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [2], faits: [1], nonMontres: [3])
        #expect(suggeres(ailleurs, [], fini: true, lu: tait).isEmpty)
    }

    /// La quête prise chez Amayiro : aller voir Machin (1), puis rapporter à
    /// Amayiro (2), sur la case où l'on vient de la prendre.
    @Test("Chez Amayiro : « lui rapporter » n'est pas proposé tant que le jeu montre « aller voir » un autre")
    func suggestionAmayiro() {
        let machin = PNJ.Position(x: 3, y: -7), amayiro = PNJ.Position(x: -1, y: 2)
        let etape = Self.etape([(1, machin, false), (2, amayiro, false)])
        func suggeres(_ position: PNJ.Position, _ valides: Set<Int>, lu: SuiviQuetes.Reconnue?) -> Set<Int> {
            etape.suggeres(en: position, valides: valides, enCours: nil, combatFini: false, lu: lu)
        }
        // Sans lecture : le prochain est chez Machin.
        #expect(suggeres(amayiro, [], lu: nil).isEmpty)
        #expect(suggeres(machin, [], lu: nil) == [1])
        // Le jeu montre « aller voir Machin » et tait « rapporter » : rien chez
        // Amayiro, et « rapporter » passe en retrait.
        let auDepart = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [1], nonMontres: [2])
        #expect(suggeres(amayiro, [], lu: auDepart).isEmpty)
        #expect(etape.nonOuverts(valides: [], lu: auDepart) == [2])
        // Machin vu, le jeu montre « rapporter » : proposé chez Amayiro, même
        // sans la coche de Machin.
        let auRetour = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [2], faits: [1])
        #expect(suggeres(amayiro, [], lu: auRetour) == [2])
        #expect(etape.nonOuverts(valides: [], lu: auRetour).isEmpty)
        // Sans lecture, Machin coché : « rapporter » est le prochain.
        #expect(suggeres(amayiro, [1], lu: nil) == [2])
    }

    /// Trois PNJ à voir dans n'importe quel ordre (1, 2, 3), puis rapporter (4).
    @Test("Plusieurs PNJ à voir sans ordre : chacun montré ouvert est proposé sur sa case")
    func suggestionSansOrdre() {
        let cases = (1...4).map { PNJ.Position(x: $0, y: 0) }
        let etape = Self.etape((1...4).map { ($0, cases[$0 - 1], false) })
        func suggeres(_ rang: Int, _ lu: SuiviQuetes.Reconnue?, enCours: Int? = nil) -> Set<Int> {
            etape.suggeres(en: cases[rang - 1], valides: [], enCours: enCours, combatFini: false, lu: lu)
        }
        let ouverts = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [1, 2, 3], nonMontres: [4])
        #expect(suggeres(3, ouverts) == [3])
        #expect(suggeres(4, ouverts).isEmpty)
        #expect(suggeres(3, nil).isEmpty)
        // Coupé par « VOIR PLUS… » après le deuxième : le troisième n'est pas
        // su, il ne l'est qu'en cours.
        let coupe = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [1, 2])
        #expect(suggeres(3, coupe).isEmpty)
        #expect(suggeres(3, coupe, enCours: 3) == [3])
        #expect(etape.nonOuverts(valides: [], lu: coupe).isEmpty)
        // Une lecture d'une autre étape ne dit rien de celle-ci.
        let autre = SuiviQuetes.Reconnue(id: 7, etape: nil, aFaire: [99], nonMontres: [4])
        #expect(suggeres(3, autre).isEmpty)
        #expect(etape.nonOuverts(valides: [], lu: autre).isEmpty)
    }
}

/// La coordonnée d'un objectif ne s'écrit que si elle diffère de celle de l'objectif juste avant.
struct CoordonneesObjectifsTests {
    private func objectif(_ id: Int, _ position: (Int, Int)?, sousZone: Int? = nil) -> FicheQuete.Objectif {
        FicheQuete.Objectif(id: id, texte: "", position: position.map { PNJ.Position(x: $0.0, y: $0.1) },
                            carte: nil, combat: false, sujet: nil, sousZone: sousZone)
    }

    @Test("La première coordonnée s'affiche, la répétée non, la suivante différente oui")
    func repetition() {
        let objectifs = [objectif(1, (3, 4)), objectif(2, (3, 4)), objectif(3, (5, 6)), objectif(4, (5, 6)), objectif(5, (3, 4))]
        #expect(CoordonneesObjectifs.affichees(objectifs) == [1, 3, 5])
    }

    @Test("Après un objectif sans position, la coordonnée revient")
    func apresUnSansPosition() {
        let objectifs = [objectif(1, (3, 4)), objectif(2, nil), objectif(3, (3, 4))]
        #expect(CoordonneesObjectifs.affichees(objectifs) == [1, 3])
    }

    @Test("Un premier objectif replié ne prive pas le suivant de sa coordonnée")
    func premierReplie() {
        let objectifs = [objectif(1, (-55, 15)), objectif(2, (-55, 15)), objectif(3, (-55, 15))]
        #expect(CoordonneesObjectifs.affichees(objectifs, repliees: [1]) == [2])
        #expect(CoordonneesObjectifs.affichees(objectifs, repliees: [1, 2]) == [3])
        #expect(CoordonneesObjectifs.affichees(objectifs) == [1])
    }

    @Test("La même case d'un autre monde diffère")
    func autreMonde() {
        let objectifs = [objectif(1, (3, 4), sousZone: 10), objectif(2, (3, 4), sousZone: 99)]
        #expect(CoordonneesObjectifs.affichees(objectifs) == [1, 2])
    }
}
