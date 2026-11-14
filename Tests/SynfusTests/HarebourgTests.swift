import Foundation
import Testing
@testable import Synfus

/// La confusion du Comte Harebourg : où viser, la vie et le canal combat lus
/// à l'écran, et le suivi d'un combat.
struct HarebourgTests {
    typealias Confusion = Harebourg.Confusion

    // MARK: - Où viser

    @Test("Chaque confusion désigne son côté, et le corps à corps la tourne à rebours")
    func visee() {
        #expect(Confusion.aucune.visee == .cible)
        #expect(Confusion.horaire.visee == .gauche)
        #expect(Confusion.demiTour.visee == .opposee)
        #expect(Confusion.contreHoraire.visee == .droite)
        #expect(Confusion.horaire.apres(coups: 1) == .aucune)
        #expect(Confusion.horaire.apres(coups: 2) == .contreHoraire)
        #expect(Confusion.aucune.apres(coups: 5) == .contreHoraire)
        #expect(Confusion(quarts: -1) == .contreHoraire)
    }

    @Test("La case visée, tournée de la confusion, retombe sur la cible")
    func caseVisee() {
        let cible = (x: 0, y: -2)
        for quarts in 0..<4 {
            let confusion = Confusion(quarts: quarts)
            var tombe = confusion.caseVisee(cible: cible)
            // Le sort tombe sur la case visée tournée d'autant de quarts
            // horaires — y vers le bas : (x, y) → (−y, x).
            for _ in 0..<quarts { tombe = (-tombe.y, tombe.x) }
            #expect(tombe == cible, "\(quarts) quart(s)")
        }
        // Cible devant (en haut) : un quart horaire fait viser à gauche.
        #expect(Confusion.horaire.caseVisee(cible: cible) == (-2, 0))
        #expect(Confusion.demiTour.caseVisee(cible: cible) == (0, 2))
        #expect(Confusion.contreHoraire.caseVisee(cible: cible) == (2, 0))
    }

    // MARK: - Par la vie

    @Test("Les tranches de vie", arguments: [
        (100.0, Confusion.horaire), (95, .horaire), (88, .contreHoraire), (76, .contreHoraire),
        (60, .demiTour), (47, .demiTour), (40, .contreHoraire), (32, .contreHoraire), (20, .horaire), (1, .horaire),
    ])
    func tranches(pourcentage: Double, attendue: Confusion) {
        #expect(Harebourg.parVie(pourcentage: pourcentage).confusion == attendue)
        #expect(Harebourg.parVie(pourcentage: pourcentage).voisine == nil)
    }

    @Test("À un point d'une limite, la tranche voisine est possible", arguments: [
        (91.0, Confusion.horaire, Confusion.contreHoraire), (90, .contreHoraire, .horaire),
        (75, .contreHoraire, .demiTour), (74, .demiTour, .contreHoraire),
        (46, .demiTour, .contreHoraire), (45, .contreHoraire, .demiTour),
        (31, .contreHoraire, .horaire), (30, .horaire, .contreHoraire), (90.7, .horaire, .contreHoraire),
    ])
    func frontieres(pourcentage: Double, attendue: Confusion, voisine: Confusion) {
        let parVie = Harebourg.parVie(pourcentage: pourcentage)
        #expect(parVie.confusion == attendue)
        #expect(parVie.voisine == voisine)
    }

    @Test("Le cœur de vie : pourcentage, points sur maximum, points seuls")
    func vie() {
        #expect(Harebourg.vie(["100%"]) == .pourcentage(100))
        #expect(Harebourg.vie(["57 %"]) == .pourcentage(57))
        #expect(Harebourg.vie(["3 450 / 4 200"]) == .points(actuels: 3450, max: 4200))
        #expect(Harebourg.vie(["3\u{202F}450/4\u{202F}200"]) == .points(actuels: 3450, max: 4200))
        #expect(Harebourg.vie(["2.394", "12", "5"]) == .points(actuels: 2394, max: nil))
        #expect(Harebourg.vie(["3450"]) == .points(actuels: 3450, max: nil))
        #expect(Harebourg.vie([]) == nil)
        #expect(Harebourg.vie(["PV"]) == nil)
        #expect(Harebourg.Vie.points(actuels: 2100, max: 4200).pourcentage(maxConnu: nil) == 50)
        #expect(Harebourg.Vie.points(actuels: 2100, max: nil).pourcentage(maxConnu: 4200) == 50)
        #expect(Harebourg.Vie.points(actuels: 2100, max: nil).pourcentage(maxConnu: nil) == nil)
        #expect(Harebourg.Vie.points(actuels: 5000, max: nil).pourcentage(maxConnu: 4200) == nil)
    }

    // MARK: - Au canal combat

    @Test("Les écritures d'une même confusion se valent", arguments: [
        // 90° horaire, et ses autres écritures relevées par les joueurs.
        ("90° horaire", Confusion.horaire), ("270° contre horaire", .horaire), ("Contre Horaire 3Pi/2", .horaire),
        ("Horaire 1Pi/2", .horaire), ("Horaire 2Pi/4", .horaire), ("Contre Horaire 6Pi/4", .horaire),
        ("1/2 pi horaire", .horaire),
        // 90° contre-horaire.
        ("90° contre-horaire", .contreHoraire), ("270° Horaire", .contreHoraire),
        ("Contre Horaire 1Pi/2", .contreHoraire), ("Horaire 3Pi/2", .contreHoraire),
        ("contre horaire 2Pi/4", .contreHoraire), ("Horaire 6Pi/4", .contreHoraire),
        ("anti-horaire π/2", .contreHoraire),
        // Le demi-tour.
        ("180° horaire", .demiTour), ("Horaire 2Pi/2", .demiTour), ("Horaire 4Pi/4", .demiTour),
        ("Contre Horaire 2Pi/2", .demiTour), ("contre horaire Pi", .demiTour),
        // L'anglais et l'espagnol, l'OCR qui lit le degré « º ».
        ("90° clockwise", .horaire), ("90° counterclockwise", .contreHoraire), ("90º antihorario", .contreHoraire),
    ])
    func ecritures(ligne: String, attendue: Confusion) {
        #expect(Harebourg.confusion("[14:04] Syn-App : Confusion \(ligne) (1 tour)") == attendue)
    }

    @Test("Sans sens ni angle, une ligne n'annonce rien", arguments: [
        "[14:04] Syn-App : 1% Dommages finaux (3)", "[14:04] Piou Rose : -56 PV (mort).", "90°",
        "Pour ne pas te faire voler ton compte", "[14:04] Syn-App lance Bulle. Coup critique !",
        "horaire", "[18:34] Précédente connexion sur ce compte : 14/09/2026 à 17:43", "Horaire 45°",
        "On se place pour le combat", "[14:05] Syn-App : -2 PM (horaire)",
    ])
    func rien(ligne: String) {
        #expect(Harebourg.confusion(ligne) == nil)
    }

    @Test("La dernière annonce du tchat, son perso et sa ligne")
    func dernierConstat() throws {
        let persos = ["Syn-App", "Syn-Ops"]
        let lignes = [
            "[14:04] Syn-App : Confusion 90° horaire (1 tour)",
            "[14:04] Syn-App lance Bulle.",
            "[14:05] Syn-Ops : Confusion 180° horaire (1 tour)",
            "[14:05] Piou Rose : -56 PV",
        ]
        let lu = try #require(Harebourg.dernierConstat(lignes, persos: persos))
        #expect(lu.constat == .init(confusion: .demiTour, perso: "Syn-Ops"))
        #expect(lu.ligne == 2)
        // Une faute de lecture dans le nom ; une ligne repliée.
        let repliee = ["[14:06] Syn-Apo : une très longue ligne de confusion", "contre horaire 3Pi/2", "[14:06] Fin."]
        let relu = try #require(Harebourg.dernierConstat(repliee, persos: persos))
        #expect(relu.constat == .init(confusion: .horaire, perso: "Syn-App"))
        // Un nom qu'aucun perso ne porte : l'annonce reste anonyme.
        #expect(Harebourg.dernierConstat(["[14:07] Ally : 90° horaire"], persos: persos)?.constat.perso == nil)
        #expect(Harebourg.dernierConstat(["rien ici"], persos: persos) == nil)
    }

    // MARK: - Le suivi d'un combat

    private let t0 = Date(timeIntervalSince1970: 10_000)

    @Test("La vie au début du tour donne la confusion, les coups la tournent")
    func suiviParVie() throws {
        var suivi = SuiviConfusion()
        suivi.vie(.pourcentage(60), perso: "A", le: t0)
        // Hors de son tour : une prévision.
        #expect(suivi.estimation("A")?.enTour == false)
        #expect(suivi.estimation("A")?.confusion == .demiTour)
        suivi.combat("A", avant: nil, apres: .monTour(fin: nil), le: t0.addingTimeInterval(5))
        // La vie lue juste après le bouton est encore celle du début du tour ;
        // plus tard, elle ne la change plus.
        suivi.vie(.pourcentage(95), perso: "A", le: t0.addingTimeInterval(6))
        suivi.vie(.pourcentage(40), perso: "A", le: t0.addingTimeInterval(9))
        var estimation = try #require(suivi.estimation("A"))
        #expect(estimation == .init(confusion: .horaire, source: .vie(pourcentage: 95), voisine: nil, coups: 0, enTour: true))
        suivi.coup(1, perso: "A")
        suivi.coup(1, perso: "A")
        estimation = try #require(suivi.estimation("A"))
        #expect(estimation.confusion == .contreHoraire)
        #expect(estimation.coups == 2)
        #expect(estimation.compteLesCoups)
        // Le tour fini, coups et vie du début oubliés : prévision sur la vie actuelle.
        suivi.combat("A", avant: .monTour(fin: nil), apres: .pasMonTour, le: t0.addingTimeInterval(20))
        estimation = try #require(suivi.estimation("A"))
        #expect(estimation == .init(confusion: .contreHoraire, source: .vie(pourcentage: 40), voisine: nil, coups: 0, enTour: false))
    }

    @Test("Des points sans maximum attendent un maximum lu")
    func pointsSansMaximum() {
        var suivi = SuiviConfusion()
        suivi.vie(.points(actuels: 2000, max: nil), perso: "A", le: t0)
        #expect(suivi.estimation("A") == nil)
        #expect(suivi.vieLue("A") == .points(actuels: 2000, max: nil))
        suivi.vie(.points(actuels: 3000, max: 4000), perso: "A", le: t0)
        suivi.vie(.points(actuels: 2000, max: nil), perso: "A", le: t0)
        #expect(suivi.estimation("A")?.source == .vie(pourcentage: 50))
    }

    @Test("L'annonce du tchat prime sur la vie, pour le seul tour qu'elle annonce")
    func suiviParTchat() {
        var suivi = SuiviConfusion()
        let noms = ["A", "B"]
        suivi.vie(.pourcentage(60), perso: "A", le: t0)
        suivi.combat("A", avant: nil, apres: .monTour(fin: nil), le: t0)
        suivi.tchat(["[10:00] A : Confusion 90° horaire"], fenetre: "A", persos: noms, le: t0.addingTimeInterval(1))
        #expect(suivi.estimation("A")?.source == .tchat)
        #expect(suivi.estimation("A")?.confusion == .horaire)
        // Les coups comptés à la main ne s'y ajoutent pas : le jeu les annonce.
        suivi.coup(1, perso: "A")
        #expect(suivi.estimation("A")?.confusion == .horaire)
        // L'annonce d'un autre perso ne change rien pour A.
        suivi.tchat(["[10:00] A : Confusion 90° horaire", "[10:01] B : Confusion 180° horaire"],
                    fenetre: "A", persos: noms, le: t0.addingTimeInterval(30))
        #expect(suivi.estimation("A")?.confusion == .horaire)
        // Au tour suivant de A, l'ancienne annonce ne vaut plus : la vie reprend.
        suivi.combat("A", avant: .monTour(fin: nil), apres: .pasMonTour, le: t0.addingTimeInterval(20))
        suivi.combat("A", avant: .pasMonTour, apres: .monTour(fin: nil), le: t0.addingTimeInterval(40))
        #expect(suivi.estimation("A")?.source == .vie(pourcentage: 60))
    }

    @Test("Une annonce pareille, écrite plus bas, est nouvelle ; la même qui monte ne l'est pas")
    func annonceRepetee() {
        var suivi = SuiviConfusion()
        let ligne = "[10:00] Confusion 90° horaire"
        suivi.combat("A", avant: nil, apres: .monTour(fin: nil), le: t0)
        suivi.tchat([ligne], fenetre: "A", persos: [], le: t0)
        suivi.combat("A", avant: .monTour(fin: nil), apres: .pasMonTour, le: t0.addingTimeInterval(10))
        // La même ligne, poussée vers le haut : rien de nouveau.
        suivi.tchat([ligne, "[10:00] B lance un sort"], fenetre: "A", persos: [], le: t0.addingTimeInterval(15))
        suivi.vie(.pourcentage(60), perso: "A", le: t0.addingTimeInterval(15))
        suivi.combat("A", avant: .pasMonTour, apres: .monTour(fin: nil), le: t0.addingTimeInterval(30))
        #expect(suivi.estimation("A")?.source == .vie(pourcentage: 60))
        // Une ligne pareille revient en bas : c'est l'annonce de ce tour.
        suivi.tchat([ligne, "[10:00] B lance un sort", ligne], fenetre: "A", persos: [], le: t0.addingTimeInterval(31))
        #expect(suivi.estimation("A")?.source == .tchat)
    }

    @Test("Un nouveau décompte est un nouveau tour, même sans bouton gris vu entre les deux")
    func nouveauTourSansGris() {
        var suivi = SuiviConfusion()
        let fin1 = t0.addingTimeInterval(30), fin2 = t0.addingTimeInterval(120)
        suivi.vie(.pourcentage(60), perso: "A", le: t0)
        suivi.combat("A", avant: nil, apres: .monTour(fin: fin1), le: t0)
        suivi.coup(2, perso: "A")
        #expect(suivi.estimation("A")?.coups == 2)
        // Relu au même décompte : le même tour.
        suivi.combat("A", avant: .monTour(fin: fin1), apres: .monTour(fin: fin1.addingTimeInterval(1)), le: t0.addingTimeInterval(5))
        #expect(suivi.estimation("A")?.coups == 2)
        suivi.combat("A", avant: .monTour(fin: fin1), apres: .monTour(fin: fin2), le: t0.addingTimeInterval(90))
        #expect(suivi.estimation("A")?.coups == 0)
        #expect(EtatCombat.nouveauTour(avant: .monTour(fin: nil), apres: .monTour(fin: fin1)) == false)
        #expect(EtatCombat.nouveauTour(avant: .pasMonTour, apres: .monTour(fin: nil)))
    }

    @Test("Les tours se comptent aux débuts de tour, le placement remet à zéro")
    func tours() {
        var tours = ToursCombat()
        let fin = { (s: Double) in EtatCombat.monTour(fin: Date(timeIntervalSince1970: s)) }
        tours.combat("A", avant: .horsCombat, apres: .placement)
        #expect(tours.tour("A") == nil)
        tours.combat("A", avant: .placement, apres: fin(30))
        tours.combat("A", avant: fin(30), apres: .pasMonTour)
        tours.combat("A", avant: .pasMonTour, apres: fin(100))
        // Le bouton gris manqué : le décompte relu dit le troisième tour.
        tours.combat("A", avant: fin(100), apres: fin(200))
        #expect(tours.tour("A") == 3)
        tours.corriger(-5, perso: "A")
        #expect(tours.tour("A") == 1)
        tours.combat("A", avant: fin(200), apres: .horsCombat)
        #expect(tours.tour("A") == nil)
        #expect(ToursCombat.estImpair(1) && ToursCombat.estImpair(3) && !ToursCombat.estImpair(2))
    }

    @Test("Une confusion choisie à la main vaut jusqu'à la fin du tour, coups comptés")
    func manuelle() {
        var suivi = SuiviConfusion()
        suivi.combat("A", avant: nil, apres: .monTour(fin: nil), le: t0)
        suivi.coup(3, perso: "A")
        suivi.choisir(.demiTour, perso: "A")
        #expect(suivi.estimation("A") == .init(confusion: .demiTour, source: .manuelle, voisine: nil, coups: 0, enTour: true))
        suivi.coup(1, perso: "A")
        #expect(suivi.estimation("A")?.confusion == .horaire)
        suivi.combat("A", avant: .monTour(fin: nil), apres: .horsCombat, le: t0.addingTimeInterval(60))
        #expect(suivi.estimation("A") == nil)
    }
}
