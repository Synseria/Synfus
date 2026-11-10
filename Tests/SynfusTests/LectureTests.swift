import Testing
import Foundation
import CoreGraphics
@testable import Synfus

/// Le décodage des lignes lues en haut à gauche de la fenêtre. Les entrées
/// sont les sorties réelles de Vision sur des captures du jeu.
struct PositionCarteTests {

    @Test("Lecture réelle : zone puis coordonnées et niveau")
    func lectureReelle() {
        let lignes = ["Montagne des Koalaks (Village des Eleveu.", "-16, 1 - Niveau 1",
                      "ISANCT]", "De Brikke et de Brokke"]
        let position = PositionCarte.lire(lignes)
        #expect(position?.x == -16)
        #expect(position?.y == 1)
        #expect(position?.zone == "Montagne des Koalaks (Village des Eleveu")
    }

    @Test("Deux coordonnées négatives, et un « Niveau » mal lu")
    func deuxNegatives() {
        let position = PositionCarte.lire(["Bonta (Faubourgs des artisans)", "-29, -57 - Nivcau 10"])
        #expect(position?.coordonnees == "[-29,-57]")
        #expect(position?.zone == "Bonta (Faubourgs des artisans)")
    }

    @Test("Le signe moins lu en flèche ou en tiret long reste un moins")
    func tiretsSubstitues() {
        #expect(PositionCarte.lire(["→16, 1 - Niveau 1"])?.x == -16)
        #expect(PositionCarte.lire(["— 3 , −12"])?.coordonnees == "[-3,-12]")
    }

    @Test("La virgule lue en point passe encore")
    func virguleEnPoint() {
        #expect(PositionCarte.lire(["4. -18 - Niveau 20"])?.coordonnees == "[4,-18]")
    }

    @Test("Deux nombres ailleurs qu'en tête de ligne ne sont pas une position")
    func pasEnTete() {
        #expect(PositionCarte.lire(["Quête : tuer 3, 4 bouftous"]) == nil)
        #expect(PositionCarte.lire(["Niveau 1"]) == nil)
        #expect(PositionCarte.lire([]) == nil)
    }

    @Test("Une valeur hors carte est une erreur de lecture")
    func horsBorne() {
        #expect(PositionCarte.lire(["1600, 1 - Niveau 1"]) == nil)
    }

    @Test("Sans ligne de zone, la position reste lue")
    func sansZone() {
        let position = PositionCarte.lire(["-16, 1 - Niveau 1"])
        #expect(position?.coordonnees == "[-16,1]")
        #expect(position?.zone == nil)
    }
}

/// L'empreinte qui évite de relancer l'OCR tant que le texte ne change pas.
struct EmpreinteTexteTests {

    private func image(texteEn colonnes: Range<Int>, fond: UInt8 = 60) -> LumaBitmap {
        let (w, h) = (192, 48)
        var pixels = [UInt8](repeating: fond, count: w * h)
        for y in 10..<20 { for x in colonnes { pixels[y * w + x] = 255 } }
        return LumaBitmap(width: w, height: h, pixels: pixels)
    }

    @Test("Le même texte sur un décor qui change reste semblable")
    func decorQuiBouge() {
        let a = EmpreinteTexte(image(texteEn: 10..<80, fond: 40))
        let b = EmpreinteTexte(image(texteEn: 10..<80, fond: 180))
        #expect(a.semblable(a: b))
    }

    @Test("Un autre texte change l'empreinte")
    func texteQuiChange() {
        let a = EmpreinteTexte(image(texteEn: 10..<80))
        let b = EmpreinteTexte(image(texteEn: 10..<140))
        #expect(!a.semblable(a: b))
    }

    /// Un suivi : un titre blanc et un objectif gris clair sur l'encadré
    /// sombre ; avec `decor`, le jeu qui bouge plus bas, hors de ses lignes.
    private func suivi(objectif: Range<Int>, decor: Bool = false) -> LumaBitmap {
        let (w, h) = (200, 300)
        var pixels = [UInt8](repeating: 40, count: w * h)
        for y in 20..<28 { for x in 10..<150 { pixels[y * w + x] = 255 } }
        for y in 34..<42 { for x in objectif { pixels[y * w + x] = 200 } }
        if decor { for y in 200..<260 { for x in 20..<120 { pixels[y * w + x] = 250 } } }
        return LumaBitmap(width: w, height: h, pixels: pixels)
    }

    @Test("Dans les lignes d'un suivi, un objectif gris clair qui change relance l'OCR ; le jeu autour, non")
    func lignesDuSuivi() throws {
        let boites = [CGRect(x: 10, y: 20, width: 140, height: 8), CGRect(x: 10, y: 34, width: 120, height: 8)]
        let cadre = try #require(SignatureZone.cadre(lignes: boites, image: CGSize(width: 200, height: 300))).cadre
        func signature(_ image: LumaBitmap) -> SignatureZone {
            SignatureZone(image, mesure: .lignes, cadre: cadre, couleur: nil)
        }
        let avant = signature(suivi(objectif: 10..<130))
        #expect(avant.semblable(a: signature(suivi(objectif: 10..<130, decor: true))))
        #expect(!avant.semblable(a: signature(suivi(objectif: 10..<60))))
    }

    @Test("Le cadre des lignes : leur union, prolongée vers le bas ; au bas de la zone, la suite peut être coupée")
    func cadreDesLignes() {
        let boites = [CGRect(x: 10, y: 20, width: 100, height: 10), CGRect(x: 10, y: 34, width: 140, height: 10)]
        let haute = SignatureZone.cadre(lignes: boites, image: CGSize(width: 200, height: 300))
        #expect(haute?.cadre == CGRect(x: 5, y: 15, width: 150, height: 44))
        #expect(haute?.auBord == false)
        let basse = SignatureZone.cadre(lignes: boites, image: CGSize(width: 200, height: 52))
        #expect(basse?.cadre == CGRect(x: 5, y: 15, width: 150, height: 37))
        #expect(basse?.auBord == true)
        #expect(SignatureZone.cadre(lignes: [], image: CGSize(width: 200, height: 300)) == nil)
    }

    /// Le bouton de fin de tour, blanc, et au-dessus le décompte — blanc lui
    /// aussi, au pire.
    private func combat(decompte: Range<Int>, bouton: Range<Int> = 20..<100) -> LumaBitmap {
        let (w, h) = (120, 100)
        var pixels = [UInt8](repeating: 40, count: w * h)
        for y in 30..<40 { for x in decompte { pixels[y * w + x] = 255 } }
        for y in 60..<70 { for x in bouton { pixels[y * w + x] = 255 } }
        return LumaBitmap(width: w, height: h, pixels: pixels)
    }

    @Test("Le décompte qui défile ne relance pas l'OCR ; le texte du bouton qui change, si")
    func decompteDuBouton() {
        let corps = LectureCombat.corpsDuBouton(texte: CGRect(x: 20, y: 60, width: 80, height: 10),
                                                image: CGSize(width: 120, height: 100))
        func signature(_ image: LumaBitmap) -> SignatureZone {
            SignatureZone(image, mesure: .bouton, cadre: corps, couleur: 0.21)
        }
        let avant = signature(combat(decompte: 50..<70))
        #expect(avant.semblable(a: signature(combat(decompte: 50..<62))))
        #expect(!avant.semblable(a: signature(combat(decompte: 50..<70, bouton: 20..<60))))
    }
}

/// La géométrie des zones de lecture : fractions du contenu, sans barre de
/// titre, ramenées à une hauteur fixe.
struct ZoneEcranTests {

    @Test("En fenêtré, la zone se place sous la barre de titre")
    func sousLaBarreDeTitre() {
        let contenu = ZoneEcran.contenu(fenetre: CGSize(width: 1000, height: 628), barreTitre: 28, pleinEcran: false)
        #expect(contenu == CGRect(x: 0, y: 28, width: 1000, height: 600))
        let source = ZoneEcran.source(CGRect(x: 0.1, y: 0.5, width: 0.2, height: 0.1), contenu: contenu)
        #expect(source == CGRect(x: 100, y: 328, width: 200, height: 60))
    }

    @Test("En plein écran, le contenu est toute la fenêtre")
    func pleinEcran() {
        let contenu = ZoneEcran.contenu(fenetre: CGSize(width: 1728, height: 1059), barreTitre: 28, pleinEcran: true)
        #expect(contenu == CGRect(x: 0, y: 0, width: 1728, height: 1059))
    }

    @Test("La même zone suit la taille de la fenêtre")
    func suitLaTaille() {
        let zone = ZoneEcran.positionParDefaut.rect
        let petite = ZoneEcran.source(zone, contenu: CGRect(x: 0, y: 0, width: 800, height: 500))
        let grande = ZoneEcran.source(zone, contenu: CGRect(x: 0, y: 0, width: 1600, height: 1000))
        #expect(grande.width == petite.width * 2)
        #expect(grande.minY == petite.minY * 2)
    }

    @Test("L'échelle ramène le contenu à la hauteur de référence, sans dépasser le natif")
    func echelle() {
        #expect(ZoneEcran.echelle(hauteurContenu: 1080, plafond: 2) == 1)
        #expect(ZoneEcran.echelle(hauteurContenu: 2160, plafond: 2) == 0.5)
        #expect(ZoneEcran.echelle(hauteurContenu: 360, plafond: 2) == 2)
        #expect(ZoneEcran.echelle(hauteurContenu: 0, plafond: 2) == 1)
    }

    @Test("Une zone tracée hors du contenu y est ramenée")
    func bornee() {
        let zone = ZoneEcran(x: 0.95, y: -0.1, largeur: 0.2, hauteur: 0.001).bornee()
        #expect(zone.x + zone.largeur <= 1)
        #expect(zone.y == 0)
        #expect(zone.hauteur == ZoneEcran.tailleMinimale)
    }
}

/// Le bouton « Fin de tour » : en couleur, gris ou absent. Les lignes sont
/// celles que Vision a rendues sur de vraies captures. La couleur du tour
/// change avec les thèmes du jeu ; le gris, jamais.
struct LectureCombatTests {

    @Test("Fin de tour sur un bouton coloré, avec le décompte : mon tour")
    func monTour() {
        let constat = LectureCombat.classer(lignes: ["29s", "FIN DE TOUR"], couleur: 0.6)
        #expect(constat == .init(genre: .monTour, secondes: 29))
    }

    @Test("Fin de tour sur un bouton gris : le tour d'un autre")
    func pasMonTour() {
        #expect(LectureCombat.classer(lignes: ["FIN DE TOUR"], couleur: 0).genre == .pasMonTour)
    }

    @Test("Rien de lisible dans la zone : hors combat, même s'il y a de la couleur")
    func horsCombat() {
        #expect(LectureCombat.classer(lignes: [], couleur: 0.8).genre == .horsCombat)
        #expect(LectureCombat.classer(lignes: ["Astrub"], couleur: 0).genre == .horsCombat)
    }

    @Test("Le bouton se reconnaît en anglais, en espagnol, et malgré l'OCR")
    func langues() {
        #expect(LectureCombat.classer(lignes: ["END TURN"], couleur: 0.6).genre == .monTour)
        #expect(LectureCombat.classer(lignes: ["FIN DE TURNO"], couleur: 0.6).genre == .monTour)
        #expect(LectureCombat.classer(lignes: ["FIN DETOUR"], couleur: 0.6).genre == .monTour)
        #expect(LectureCombat.classer(lignes: ["PRÊT"], couleur: 0).genre == .placement)
        #expect(LectureCombat.classer(lignes: ["READY"], couleur: 0).genre == .placement)
        #expect(LectureCombat.estBouton("Fin de tour"))
        #expect(!LectureCombat.estBouton("29s"))
    }

    @Test("Le décompte se lit collé ou espacé, et rien d'autre ne passe pour lui")
    func decompte() {
        #expect(LectureCombat.decompte("29s") == 29)
        #expect(LectureCombat.decompte(" 5 S") == 5)
        #expect(LectureCombat.decompte("FIN DE TOUR") == nil)
        #expect(LectureCombat.decompte("s") == nil)
        #expect(LectureCombat.decompte("1234s") == nil)
    }

    private func pixels(_ couleurs: [[UInt8]]) -> [UInt8] { couleurs.flatMap { $0 } }

    @Test("Toute couleur du tour compte — rose, bleu, vert d'un thème —, pas le gris")
    func couleurQuelconque() {
        let rose: [UInt8] = [194, 112, 185, 255]
        let bleu: [UInt8] = [70, 110, 210, 255]
        let lisere: [UInt8] = [76, 45, 72, 255]
        let gris: [UInt8] = [128, 128, 128, 255]
        #expect(LectureCombat.ratioColore(rgba: pixels([rose, bleu, lisere, gris]), largeur: 4) == 0.5)
        #expect(LectureCombat.ratioColore(rgba: [], largeur: 0) == 0)
    }

    /// Relevés sur une vraie capture du bouton grisé : son dégradé gris, le
    /// fond et les icônes lavande pâle de la rangée du dessous.
    @Test("Le bouton grisé et ses icônes lavande ne comptent pas comme couleur")
    func boutonGrise() {
        let gris1: [UInt8] = [139, 139, 139, 255]
        let gris2: [UInt8] = [120, 119, 119, 255]
        let fond: [UInt8] = [60, 55, 61, 255]
        let lavande: [UInt8] = [205, 180, 215, 255]
        #expect(LectureCombat.ratioColore(rgba: pixels([gris1, gris2, fond, lavande]), largeur: 2) == 0)
    }

    @Test("La couleur se mesure dans le seul rectangle demandé")
    func rectangle() {
        let vert: [UInt8] = [173, 255, 68, 255]
        let gris: [UInt8] = [128, 128, 128, 255]
        // 2 × 2 : le décompte vert en haut, le bouton gris en bas.
        let image = pixels([vert, vert, gris, gris])
        #expect(LectureCombat.ratioColore(rgba: image, largeur: 2) == 0.5)
        #expect(LectureCombat.ratioColore(rgba: image, largeur: 2, dans: CGRect(x: 0, y: 1, width: 2, height: 1)) == 0)
    }

    @Test("Le corps du bouton entoure son texte, borné à l'image")
    func corps() {
        let corps = LectureCombat.corpsDuBouton(texte: CGRect(x: 10, y: 50, width: 100, height: 20),
                                                image: CGSize(width: 115, height: 200))
        #expect(corps == CGRect(x: 0, y: 32, width: 115, height: 56))
    }

    @Test("Le combat se lit toutes les 3 s hors combat, chaque seconde dès qu'il est vu et jusqu'à sa fin")
    func rythmeDuCombat() {
        #expect(GenreLecture.combat.intervalle(combat: .pasMonTour, devant: false) == 2)
        #expect(GenreLecture.combat.intervalle(combat: .horsCombat, devant: false) == 3)
        #expect(GenreLecture.combat.intervalle(combat: nil, devant: true) == 3)
        #expect(GenreLecture.combat.intervalle(combat: .horsCombat, devant: true) == 3)
        #expect(GenreLecture.combat.intervalle(combat: .placement, devant: true) == 1)
        #expect(GenreLecture.combat.intervalle(combat: .monTour(fin: nil), devant: true) == 1)
        #expect(GenreLecture.combat.intervalle(combat: .pasMonTour, devant: true) == 1)
        #expect(GenreLecture.position.intervalle(combat: .placement, devant: true) == 1)
        #expect(GenreLecture.quetes.intervalle(combat: .pasMonTour, devant: true) == 3)
    }

    @Test("La vie et le tchat de l'aide aux boss se lisent chaque seconde, dans le contenu")
    func vieEtTchat() {
        for genre in [GenreLecture.vie, .tchat] {
            #expect(genre.intervalle(combat: .monTour(fin: nil), devant: true) == 1)
            #expect(genre.parDefaut.bornee() == genre.parDefaut)
        }
        #expect(GenreLecture.vie.mesure == .zone)
        #expect(GenreLecture.tchat.mesure == .lignes)
    }

    @Test("Un tour qui continue garde son échéance ; un nouveau décompte la remplace")
    func echeance() {
        let t0 = Date(timeIntervalSince1970: 1000)
        let debut = EtatCombat.depuis(.init(genre: .monTour, secondes: 30), avant: nil, maintenant: t0)
        #expect(debut == .monTour(fin: t0.addingTimeInterval(30)))
        let suite = EtatCombat.depuis(.init(genre: .monTour, secondes: nil), avant: debut,
                                      maintenant: t0.addingTimeInterval(5))
        #expect(suite == debut)
        // Relu une seconde plus tard, le décompte arrondi redonne l'échéance
        // à une seconde près : elle ne bouge pas, la barre ne se redessine pas.
        let relu = EtatCombat.depuis(.init(genre: .monTour, secondes: 28), avant: debut,
                                     maintenant: t0.addingTimeInterval(1.4))
        #expect(relu == debut)
        // Le tour suivant, ou un décompte qui s'en écarte vraiment : la nouvelle.
        let ecart = EtatCombat.depuis(.init(genre: .monTour, secondes: 30), avant: debut,
                                      maintenant: t0.addingTimeInterval(10))
        #expect(ecart == .monTour(fin: t0.addingTimeInterval(40)))
        #expect(EtatCombat.depuis(.init(genre: .monTour, secondes: 30), avant: .pasMonTour, maintenant: t0.addingTimeInterval(1))
            == .monTour(fin: t0.addingTimeInterval(31)))
        #expect(EtatCombat.depuis(.init(genre: .pasMonTour, secondes: 12), avant: debut, maintenant: t0) == .pasMonTour)
        #expect(!EtatCombat.horsCombat.enCombat)
    }

    @Test("Un combat commencé puis fini compte là où le perso se tient, jusqu'à ce qu'il change de carte")
    func finDeCombat() {
        let ici = PositionCarte(x: 4, y: -2, zone: "Amakna"), luAutrement = PositionCarte(x: 4, y: -2, zone: "Amakn")
        let ailleurs = PositionCarte(x: 5, y: -2, zone: "Amakna")
        var fins = FinsDeCombat()
        fins.combat("Aeryn", avant: .horsCombat, apres: .placement, ici: ici)
        fins.combat("Aeryn", avant: .placement, apres: .monTour(fin: nil), ici: ici)
        #expect(!fins.fini("Aeryn", en: ici))
        fins.combat("Aeryn", avant: .monTour(fin: nil), apres: .horsCombat, ici: ici)
        #expect(fins.fini("Aeryn", en: ici))
        #expect(fins.fini("Aeryn", en: luAutrement))
        #expect(!fins.fini("Nova", en: ici))
        // Une lecture sans coordonnées ne déplace pas le perso.
        fins.position("Aeryn", nil)
        #expect(fins.fini("Aeryn", en: ici))
        // Perdu : renvoyé ailleurs, la fin ne compte plus, même de retour ici.
        fins.position("Aeryn", ailleurs)
        #expect(!fins.fini("Aeryn", en: ailleurs))
        #expect(!fins.fini("Aeryn", en: ici))
        // Sorti du placement : rien n'est vaincu.
        fins.combat("Nova", avant: .placement, apres: .horsCombat, ici: ici)
        #expect(!fins.fini("Nova", en: ici))
        // Le bouton caché un instant : le retour en combat efface la fin.
        fins.combat("Nova", avant: .placement, apres: .pasMonTour, ici: ici)
        fins.combat("Nova", avant: .pasMonTour, apres: .horsCombat, ici: ici)
        #expect(fins.fini("Nova", en: ici))
        fins.combat("Nova", avant: .horsCombat, apres: .pasMonTour, ici: ici)
        #expect(!fins.fini("Nova", en: ici))
        // Repris après une bascule, déjà renvoyé ailleurs : le combat n'a pas
        // fini où il a commencé.
        fins.combat("Nova", avant: .pasMonTour, apres: .horsCombat, ici: ailleurs)
        #expect(!fins.fini("Nova", en: ailleurs))
    }

    @Test("Le même texte passé du gris à la couleur relance l'OCR")
    func signature() {
        let empreinte = EmpreinteTexte(cases: Array(repeating: false, count: EmpreinteTexte.colonnes * EmpreinteTexte.lignes))
        let colore = SignatureZone(empreinte: empreinte, couleur: 0.21)
        let gris = SignatureZone(empreinte: empreinte, couleur: 0.01)
        let coloreAussi = SignatureZone(empreinte: empreinte, couleur: 0.35)
        #expect(!colore.semblable(a: gris))
        #expect(colore.semblable(a: coloreAussi))
        #expect(SignatureZone(empreinte: empreinte, couleur: nil).semblable(a: SignatureZone(empreinte: empreinte, couleur: nil)))
    }

    @Test("Derrière : ni le perso devant, ni un dormant, ni un plein écran")
    func combatsDerriere() {
        func client(_ nom: String, pid: Int32, dormant: Bool = false, pleinEcran: Bool = false) -> DofusClient {
            var client = DofusClient(pid: pid, slotKey: "\(pid)#0", axWindow: .application(pid), rawTitle: nom,
                                     name: nom, characterClass: nil, dormant: dormant)
            client.pleinEcran = pleinEcran
            return client
        }
        let devant = client("Aeryn", pid: 1)
        let clients = [devant, client("Brok", pid: 2), client("Cid", pid: 3, dormant: true),
                       client("Dax", pid: 4, pleinEcran: true)]
        #expect(GenreLecture.combatsDerriere(clients, devant: devant).map(\.name) == ["Brok"])
        #expect(GenreLecture.combatsDerriere(clients, devant: nil).map(\.name) == ["Aeryn", "Brok"])
    }
}
