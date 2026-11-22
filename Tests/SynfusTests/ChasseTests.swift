import CoreGraphics
import Foundation
import Testing
@testable import Synfus

/// La chasse au trésor : décodage de DofusDB, carte d'arrivée, indices
/// retrouvés dans une saisie ou une lecture de l'écran.
struct ChasseTests {

    /// Réduit d'une vraie réponse (`treasure-hunt?x=-25&y=-36&direction=0`) :
    /// les cartes ne sont pas dans l'ordre des distances, et portent des
    /// champs que Synfus ignore.
    private static let etapeEst = """
    {"total":4,"limit":50,"skip":0,"data":[
     {"_id":"a","id":139461129,"posX":-20,"posY":-36,"distance":5,"__v":0,"pois":[
       {"_id":"b","id":1021,"name":{"id":"936352","de":"Gestreifte Teekanne","en":"Striped Teapot","es":"Tetera con rayas","fr":"Théière à rayures","pt":"Chaleira Listrada"},"className":"PointOfInterestData"},
       {"_id":"c","id":993,"name":{"id":"936360","fr":"Poupée koalak"},"className":"PointOfInterestData"}]},
     {"_id":"d","id":139461641,"posX":-19,"posY":-36,"distance":6,"pois":[{"id":993,"name":{"fr":"Poupée koalak"}}]},
     {"_id":"e","id":139459081,"posX":-24,"posY":-36,"distance":1,"pois":[{"id":851,"name":{"fr":"Anneau d'or"}}]},
     {"_id":"f","id":139459593,"posX":-23,"posY":-36,"distance":2,"pois":[{"id":1021,"name":{"fr":"Théière à rayures"}}]}]}
    """

    /// Réduit d'une page de `point-of-interest`.
    private static let pageIndices = """
    {"total":179,"limit":50,"skip":0,"data":[
     {"_id":"1","id":875,"name":{"id":"930995","de":"Steinhügel","en":"Cairn","es":"Cairn","fr":"Cairn","pt":"Cairn"},"className":"PointOfInterestData","m_id":875},
     {"_id":"2","id":896,"name":{"id":"936391","en":"Unikron Skull","es":"Cráneo de urikornio","fr":"Crâne de likrone"}},
     {"_id":"3","id":897,"name":{"id":"936392","en":"Unikron Skull in Ice","es":"Cráneo de urikornio en el hielo","fr":"Crâne de likrone dans la glace"}},
     {"_id":"4","id":955,"name":{"en":"Bell","es":"Cascabel","fr":"Grelot"}},
     {"_id":"5","id":974,"name":{"en":"Egg in a Hole","es":"Huevo en un agujero","fr":"Œuf dans un trou"}},
     {"_id":"6","id":993,"name":{"en":"Koalak Doll","es":"Muñeca koalak","fr":"Poupée koalak"}},
     {"_id":"7","id":1021,"name":{"en":"Striped Teapot","es":"Tetera con rayas","fr":"Théière à rayures"}}]}
    """

    private func cartes() throws -> [EtapeChasse.Carte] {
        try JSONDecoder().decode(DofusDB.Page<EtapeChasse.Carte>.self, from: Data(Self.etapeEst.utf8)).data
    }

    private func indices() throws -> [Indice] {
        try JSONDecoder().decode(DofusDB.Page<ChasseDofusDB.IndiceAPI>.self, from: Data(Self.pageIndices.utf8))
            .data.map(\.indice)
    }

    private func ids(_ liste: [Indice]) -> [Int] { liste.map(\.id) }

    // MARK: - Décodage

    @Test("Une réponse d'étape se décode : position, distance, indices portés")
    func decodageEtape() throws {
        let cartes = try cartes()
        #expect(cartes.count == 4)
        #expect(cartes[0] == EtapeChasse.Carte(x: -20, y: -36, distance: 5, indices: [1021, 993]))
    }

    @Test("Un indice garde ses noms fr, en et es, rien d'autre")
    func decodageIndices() throws {
        let liste = try indices()
        #expect(liste.count == 7)
        #expect(liste[0].noms == ["fr": "Cairn", "en": "Cairn", "es": "Cairn"])
        #expect(liste[5].nom(en: .es) == "Muñeca koalak")
    }

    @Test("La liste gardée sur le disque se relit telle quelle")
    func releveRelu() throws {
        let releve = ChasseDofusDB.Releve(date: Date(timeIntervalSinceReferenceDate: 800_000_000), indices: try indices())
        let relu = try JSONDecoder().decode(ChasseDofusDB.Releve.self, from: JSONEncoder().encode(releve))
        #expect(relu == releve)
    }

    // MARK: - Destination

    @Test("La destination est la plus proche des cartes qui portent l'indice")
    func destination() throws {
        let cartes = try cartes()
        // 1021 est à 5 et à 2 cartes : l'API ne trie pas.
        #expect(EtapeChasse.destination(indice: 1021, cartes: cartes)?.distance == 2)
        #expect(EtapeChasse.resultat(indice: 993, cartes: cartes) == .trouve(x: -20, y: -36, distance: 5))
        #expect(EtapeChasse.resultat(indice: 4242, cartes: cartes) == .introuvable)
        #expect(EtapeChasse.resultat(indice: 993, cartes: []) == .introuvable)
    }

    // MARK: - Direction

    @Test("Codes de l'API et flèches du clavier")
    func direction() {
        #expect(Direction.allCases.map(\.rawValue) == [0, 2, 4, 6])
        #expect(Direction(toucheFleche: 124) == .est)
        #expect(Direction(toucheFleche: 125) == .sud)
        #expect(Direction(toucheFleche: 123) == .ouest)
        #expect(Direction(toucheFleche: 126) == .nord)
        #expect(Direction(toucheFleche: 36) == nil)
        #expect(Direction.nord.libelle == L("chasse.direction.nord"))
    }

    // MARK: - Recherche

    @Test("La saisie ignore accents, casse et ligatures ; le début du nom passe avant")
    func rechercheAccents() throws {
        let liste = try indices()
        #expect(ids(IndicesChasse.rechercher("crane de lik", parmi: liste, langue: .fr)) == [896, 897])
        #expect(ids(IndicesChasse.rechercher("THEIERE", parmi: liste, langue: .fr)) == [1021])
        #expect(ids(IndicesChasse.rechercher("oeuf", parmi: liste, langue: .fr)) == [974])
        #expect(ids(IndicesChasse.rechercher("koalak", parmi: liste, langue: .fr)) == [993])
        #expect(ids(IndicesChasse.rechercher("teapot", parmi: liste, langue: .en)) == [1021])
        #expect(IndicesChasse.rechercher("  ", parmi: liste, langue: .fr).isEmpty)
    }

    @Test("Une faute de frappe trouve encore l'indice, pas un mot sans rapport")
    func rechercheFaute() throws {
        let liste = try indices()
        #expect(ids(IndicesChasse.rechercher("poupee koalack", parmi: liste, langue: .fr)) == [993])
        #expect(IndicesChasse.rechercher("zzzzzz", parmi: liste, langue: .fr).isEmpty)
    }

    // MARK: - OCR

    @Test("Les lignes de l'OCR donnent les indices, fautes et icônes comprises, dans leur ordre")
    func indicesLus() throws {
        let liste = try indices()
        let lignes = ["CHASSE AU TRÉSOR", "Départ [-25,-36]", "→ Poupee koaiak",
                      "Théiére á rayures ?", "Etape 3/6", "Crâne de likrone dans la glace"]
        #expect(ids(IndicesChasse.indicesReconnus(dans: lignes, parmi: liste)) == [993, 1021, 897])
    }

    @Test("Un indice relu plus bas ne compte qu'à sa dernière place")
    func indicesRelus() throws {
        let liste = try indices()
        let lignes = ["Grelot", "Cairn", "Grelot"]
        #expect(ids(IndicesChasse.indicesReconnus(dans: lignes, parmi: liste)) == [875, 955])
    }

    @Test("Le jeu en anglais se lit aussi, quelle que soit la langue de l'interface")
    func indicesAutreLangue() throws {
        let liste = try indices()
        #expect(ids(IndicesChasse.indicesReconnus(dans: ["Striped Teap0t"], parmi: liste)) == [1021])
    }

    // MARK: - Phorreur

    @Test("Le Phorreur se reconnaît, à une faute près, mais pas l'horreur")
    func phorreur() {
        #expect(EtapeChasse.estPhorreur("Phorreur sournois"))
        #expect(EtapeChasse.estPhorreur("phoreur baveux"))
        #expect(EtapeChasse.estPhorreur("PHORREUR"))
        #expect(!EtapeChasse.estPhorreur("Quelle horreur"))
        #expect(!EtapeChasse.estPhorreur("Poupée koalak"))
    }

    @Test("Les cibles lues mêlent indices et Phorreur, dans l'ordre des lignes")
    func ciblesLues() throws {
        let liste = try indices()
        let lues = EtapeChasse.ciblesLues(dans: ["Poupée koalak", "Phorreur fourbe", "rien"], parmi: liste)
        #expect(lues.count == 2)
        #expect(lues.last == .phorreur)
        if case .indice(let indice) = lues.first { #expect(indice.id == 993) } else { Issue.record("indice attendu") }
    }

    // MARK: - Lecture de l'étape en cours

    @Test("La flèche lue dans une ligne donne une direction")
    func directionLue() {
        #expect(Direction(ligneLue: "→ Poupee koaiak") == .est)
        #expect(Direction(ligneLue: "↑ Cairn") == .nord)
        #expect(Direction(ligneLue: "Grelot") == nil)
    }

    @Test("Les badges EN COURS et VALIDÉ se reconnaissent dans une ligne lue")
    func badgesLus() {
        #expect(EtapeChasse.estEnCours("↑ Gravure d'œil EN COURS"))
        #expect(!EtapeChasse.estEnCours("← Flèche dans une pomme VALIDÉ"))
        #expect(EtapeChasse.estValidee("← Flèche dans une pomme VALIDÉ"))
        // Le bouton « VALIDER » du bas du panneau n'est pas un badge validé.
        #expect(!EtapeChasse.estValidee("3 essais restants VALIDER"))
        #expect(!EtapeChasse.estValidee("↑ Gravure d'œil EN COURS"))
    }

    // MARK: - Étapes et attente

    @Test("L'historique rend les étapes de la dernière à la première, puis rien")
    func historiqueEnPile() {
        var historique = HistoriqueChasse()
        #expect(historique.vide)
        #expect(historique.reprendre() == nil)
        let premiere = HistoriqueChasse.Reprise(departX: nil, departY: nil, direction: .est, cible: .phorreur)
        let seconde = HistoriqueChasse.Reprise(departX: -3, departY: 0, direction: .nord, cible: .phorreur)
        historique.noter(premiere)
        historique.noter(seconde)
        #expect(!historique.vide)
        #expect(historique.reprendre() == seconde)
        #expect(historique.reprendre() == premiere)
        #expect(historique.vide)
        // Tronquer jusqu'à une étape choisie (menu horloge) ne garde que celle-là et avant.
        let troisieme = HistoriqueChasse.Reprise(departX: 5, departY: 6, direction: .sud, cible: .phorreur)
        historique.noter(premiere)
        historique.noter(seconde)
        historique.noter(troisieme)
        historique.tronquer(jusqua: 0)
        #expect(historique.toutes == [premiere])
        #expect(historique.reprendre() == premiere)
        #expect(historique.vide)
    }

    @Test("L'historique affiché ne garde que les étapes de la chasse en cours")
    func historiqueChasseEnCours() throws {
        let liste = try indices()
        let a = EtapeChasse.Cible.indice(liste[0])
        let b = EtapeChasse.Cible.indice(liste[1])
        let autre = EtapeChasse.Cible.indice(liste[5])
        var historique = HistoriqueChasse()
        // Première chasse : deux étapes conclues sur les indices A et B.
        historique.lire([a, b])
        historique.noter(.init(departX: 0, departY: 0, direction: .est, cible: a))
        historique.noter(.init(departX: 1, departY: 0, direction: .nord, cible: b))
        #expect(historique.deLaChasseEnCours.count == 2)
        // Chasse neuve à l'écran (aucun indice connu en commun) : tout repart à zéro.
        historique.lire([autre])
        #expect(historique.deLaChasseEnCours.isEmpty)
        #expect(historique.toutes.isEmpty)
        historique.noter(.init(departX: 2, departY: 0, direction: .sud, cible: autre))
        #expect(historique.deLaChasseEnCours.count == 1)
        // Un scan qui ne lit rien (OCR en rade) ne change rien.
        historique.lire([])
        #expect(historique.deLaChasseEnCours.count == 1)
        // Un scan partiel de la même chasse garde tout.
        historique.lire([autre, b])
        #expect(historique.deLaChasseEnCours.count == 1)
    }

    @Test("Rouvrir une étape remet la pastille de l'indice lu à sa place")
    func rouvertureRemetLIndiceLu() {
        let a = EtapeChasse.Cible.phorreur
        let b = EtapeChasse.Cible.indice(Indice(id: 1, noms: ["fr": "Cairn"]))
        let c = EtapeChasse.Cible.indice(Indice(id: 2, noms: ["fr": "Grelot"]))
        var reprise = HistoriqueChasse.Reprise(departX: 1, departY: 2, direction: .est, cible: b)
        reprise.rangLu = 1
        #expect(reprise.rouverture(departX: 1, departY: 2, lues: [a, c]).lues == [a, b, c])
        #expect(reprise.rouverture(departX: 1, departY: 2, lues: [a, b, c]).lues == [a, b, c])
        reprise.rangLu = nil
        #expect(reprise.rouverture(departX: 1, departY: 2, lues: [a]).lues == [a])
    }

    @Test("Rouvrir une étape ne remplace jamais un départ connu par du vide")
    func rouvertureGardeLeDepart() {
        let sansDepart = HistoriqueChasse.Reprise(departX: nil, departY: nil, direction: .nord, cible: .phorreur)
        let r = sansDepart.rouverture(departX: -3, departY: 4, lues: [])
        #expect(r.departX == -3 && r.departY == 4)
        let avecDepart = HistoriqueChasse.Reprise(departX: 5, departY: 6, direction: .nord, cible: .phorreur)
        let s = avecDepart.rouverture(departX: nil, departY: nil, lues: [])
        #expect(s.departX == 5 && s.departY == 6)
    }

    @Test("Le champ de l'indice attend d'abord le départ, puis la direction, puis l'indice")
    func attenteDuChamp() {
        #expect(AttenteChasse(departConnu: false, directionChoisie: false) == .depart)
        #expect(AttenteChasse(departConnu: false, directionChoisie: true) == .depart)
        #expect(AttenteChasse(departConnu: true, directionChoisie: false) == .direction)
        #expect(AttenteChasse(departConnu: true, directionChoisie: true) == .indice)
    }

    @Test("La phase de la chasse dit ce qu'il reste à faire")
    func phaseChasse() {
        #expect(PhaseChasse(departConnu: false, cible: nil, position: nil) == .depart)
        #expect(PhaseChasse(departConnu: true, cible: nil, position: nil) == .lire)
        #expect(PhaseChasse(departConnu: true, cible: (5, 18), position: nil) == .aller(x: 5, y: 18))
        #expect(PhaseChasse(departConnu: true, cible: (5, 18), position: (5, 22)) == .aller(x: 5, y: 18))
        #expect(PhaseChasse(departConnu: true, cible: (5, 18), position: (5, 18)) == .valider(x: 5, y: 18))
    }

    // MARK: - Recherche mot à mot

    @Test("Chaque mot de la saisie reconnaît un mot du nom : « cra ren » trouve « Crâne de renne »")
    func rechercheParMots() {
        let renne = Indice(id: 1, noms: ["fr": "Crâne de renne"])
        let arbre = Indice(id: 2, noms: ["fr": "Arbre à moitié coupé"])
        let coupe = Indice(id: 3, noms: ["fr": "Arbre coupé"])
        let parmi = [renne, arbre, coupe]
        #expect(IndicesChasse.rechercher("cra ren", parmi: parmi, langue: .fr) == [renne])
        // « arbre coupé » : le nom complet passe avant le mot-à-mot, qui trouve les deux
        let trouves = IndicesChasse.rechercher("arbre coupe", parmi: parmi, langue: .fr)
        #expect(trouves.first == coupe)
        #expect(trouves.contains(arbre))
        #expect(IndicesChasse.rechercher("ren crâne", parmi: parmi, langue: .fr) == [renne])
        #expect(IndicesChasse.rechercher("zzzz ren", parmi: parmi, langue: .fr).isEmpty)
    }

    // MARK: - Flèche cherchée en pixels

    /// Une fausse zone de chasse : fond sombre, une flèche dessinée avec le
    /// gabarit lui-même, et un « texte » (blocs clairs) à droite du cadre de ligne.
    private static func zoneAvecFleche(_ direction: Direction, rang: Int = 0, lignes: Int = 3,
                                        texteX: CGFloat = 44, contour: Bool = false) -> (LumaBitmap, [CGRect]) {
        let largeur = 240, hauteurLigne = 26, marge = 8
        // + une hauteur de ligne : la flèche dessinée dépasse un peu du cadre, ne pas la couper.
        let hauteur = marge + lignes * (hauteurLigne + 6) + hauteurLigne
        var pixels = [UInt8](repeating: 12, count: largeur * hauteur)
        var cadres: [CGRect] = []
        for i in 0..<lignes {
            let y = marge + i * (hauteurLigne + 6)
            cadres.append(CGRect(x: texteX, y: CGFloat(y), width: 150, height: CGFloat(hauteurLigne)))
            // le « texte » de la ligne : blocs clairs après la flèche
            let premierBloc = Int(texteX) + 4
            for x in stride(from: premierBloc, to: 190, by: 14) {
                for dy in 4..<(hauteurLigne - 4) {
                    for dx in 0..<8 { pixels[(y + dy) * largeur + x + dx] = 235 }
                }
            }
            if i == rang {
                let gabarit = DetectionFleche.gabarit(direction, hauteur: Int(CGFloat(hauteurLigne) * 1.15), contour: contour)
                for gy in 0..<gabarit.height {
                    for gx in 0..<gabarit.width {
                        if gabarit[gx, gy] > 127 {
                            let px = 6 + gx, py = y + (hauteurLigne - gabarit.height) / 2 + gy
                            pixels[py * largeur + px] = 250
                        }
                    }
                }
            }
        }
        return (LumaBitmap(width: largeur, height: hauteur, pixels: pixels), cadres)
    }

    @Test("La flèche d'une ligne se retrouve en pixels, dans les quatre directions")
    func flecheEnPixels() {
        for direction in Direction.allCases {
            let (zone, cadres) = Self.zoneAvecFleche(direction, rang: 1)
            let trouvee = DetectionFleche.direction(dans: zone, ligne: cadres[1])
            #expect(trouvee?.direction == direction)
            #expect((trouvee?.score ?? 0) >= DetectionFleche.seuil)
        }
    }

    @Test("Une flèche creuse (en contour, comme le jeu la dessine) est reconnue en pixels")
    func flecheCreuseEnPixels() {
        for direction in Direction.allCases {
            let (zone, cadres) = Self.zoneAvecFleche(direction, rang: 1, contour: true)
            let trouvee = DetectionFleche.direction(dans: zone, ligne: cadres[1])
            #expect(trouvee?.direction == direction)
            #expect((trouvee?.score ?? 0) >= DetectionFleche.seuil)
        }
    }

    /// Une flèche dessinée à la main, pixel par pixel, pointe dans `direction`
    /// (indépendante des gabarits de détection : verrouille la sémantique).
    private static func flecheAMain(_ direction: Direction, hauteur: Int = 24) -> LumaBitmap {
        let w = Int(CGFloat(hauteur) * 1.3), h = hauteur
        var px = [UInt8](repeating: 0, count: w * h)
        func set(_ x: Int, _ y: Int) { if x >= 0, x < w, y >= 0, y < h { px[y * w + x] = 255 } }
        let e = max(2, h / 5)
        let tete = max(w / 3, 4)
        switch direction {
        case .est:
            for y in h / 2 - e / 2 ..< h / 2 - e / 2 + e { for x in 0..<(w - tete) { set(x, y) } }
            for dx in 0..<tete { let demi = dx * (h / 2) / tete; for y in h / 2 - demi...h / 2 + demi { set(w - 1 - dx, y) } }
        case .ouest:
            for y in h / 2 - e / 2 ..< h / 2 - e / 2 + e { for x in tete..<w { set(x, y) } }
            for dx in 0..<tete { let demi = dx * (h / 2) / tete; for y in h / 2 - demi...h / 2 + demi { set(dx, y) } }
        case .sud:
            for x in w / 2 - e / 2 ..< w / 2 - e / 2 + e { for y in 0..<(h - tete) { set(x, y) } }
            for dy in 0..<tete { let demi = dy * (w / 2) / tete; for x in w / 2 - demi...w / 2 + demi { set(x, h - 1 - dy) } }
        case .nord:
            for x in w / 2 - e / 2 ..< w / 2 - e / 2 + e { for y in tete..<h { set(x, y) } }
            for dy in 0..<tete { let demi = dy * (w / 2) / tete; for x in w / 2 - demi...w / 2 + demi { set(x, dy) } }
        }
        return LumaBitmap(width: w, height: h, pixels: px)
    }

    @Test("Une flèche dessinée à la main est reconnue dans sa vraie direction, sans inversion")
    func flecheDessineeAMain() {
        for direction in Direction.allCases {
            let (zone, cadres) = Self.zoneAvecFleche(direction, rang: 1)
            // on colle la flèche à la main à la place du gabarit, au bord gauche
            let f = Self.flecheAMain(direction)
            var pixels = zone.pixels
            let largeur = zone.width
            let y0 = Int(cadres[1].minY) + (Int(cadres[1].height) - f.height) / 2
            for gy in 0..<f.height { for gx in 0..<f.width {
                if f[gx, gy] > 127 { pixels[(y0 + gy) * largeur + 6 + gx] = 250 }
            } }
            // on efface l'ancien gabarit (drawn at rang 1) : fond sombre
            let propre = LumaBitmap(width: zone.width, height: zone.height, pixels: pixels)
            let trouvee = EtapeChasse.premiereFlechee(dans: ["titre", "indice", "rien"], cadres: cadres, image: propre)
            #expect(trouvee?.rang == 1)
            #expect(trouvee?.direction == direction)
        }
    }

    @Test("Les scores par direction sont exposés pour le diagnostic du scan")
    func scoresParDirection() {
        let (zone, cadres) = Self.zoneAvecFleche(.ouest, rang: 1)
        let scores = DetectionFleche.scoresParGabarits(dans: zone, ligne: cadres[1])
        #expect((scores[.ouest] ?? 0) >= DetectionFleche.seuil)
        #expect((scores[.ouest] ?? 0) > (scores[.est] ?? 0))
        #expect((scores[.ouest] ?? 0) > (scores[.nord] ?? 0))
    }

    @Test("Une ligne sans flèche ne vaut aucune direction")
    func pasDeFlecheEnPixels() {
        let (zone, cadres) = Self.zoneAvecFleche(.est, rang: 0)
        // la ligne 2 n'a que du texte
        #expect(DetectionFleche.direction(dans: zone, ligne: cadres[2]) == nil)
    }

    @Test("La première ligne fléchée gagne : lue par l'OCR, sinon en pixels")
    func premiereFlechee() throws {
        let liste = try indices()
        // L'OCR a lu le glyphe de la première ligne : il prime sur les pixels.
        let (zone, cadres) = Self.zoneAvecFleche(.sud, rang: 1)
        let lignes = ["CHASSE AU TRÉSOR", "↓ Poupée koalak", "Poupée koalak"]
        let flechee = EtapeChasse.premiereFlechee(dans: lignes, cadres: cadres, image: zone)
        #expect(flechee?.rang == 1)
        #expect(flechee?.direction == .sud)
        // Sans glyphe lu, la flèche est cherchée en pixels dans l'image.
        let lignesSansGlyphe = ["CHASSE AU TRÉSOR", "Poupée koalak", "Poupée koalak"]
        let enPixels = EtapeChasse.premiereFlechee(dans: lignesSansGlyphe, cadres: cadres, image: zone)
        #expect(enPixels?.rang == 1)
        #expect(enPixels?.direction == .sud)
        // Sans image, sans glyphe : rien.
        #expect(EtapeChasse.premiereFlechee(dans: lignesSansGlyphe, cadres: cadres, image: nil) == nil)
        // La cible de l'étape en cours est celle de la ligne fléchée trouvée en pixels.
        #expect(EtapeChasse.ciblesLues(dans: [lignesSansGlyphe[enPixels!.rang]], parmi: liste).first == .indice(liste[5]))
    }

    @Test("Une flèche sûre en pixels prime sur un glyphe lu qui se trompe de sens")
    func flechePixelsPrimeGlyphe() {
        // Le jeu montre « ← », Vision a lu « ► » : le pixel (score ~1) gagne.
        let (zone, cadres) = Self.zoneAvecFleche(.ouest, rang: 1)
        let lignes = ["CHASSE AU TRÉSOR", "► Poupée koalak", "rien"]
        let trouvee = EtapeChasse.premiereFlechee(dans: lignes, cadres: cadres, image: zone)
        #expect(trouvee?.rang == 1)
        #expect(trouvee?.direction == .ouest)
    }

    @Test("La flèche au bord gauche de la zone est trouvée même si le cadre du texte commence loin")
    func flecheAuBordGauche() {
        let (zone, cadres) = Self.zoneAvecFleche(.sud, rang: 2, texteX: 110)
        let lignes = ["titre", "étape 1/4", "Phorreur"]
        let trouvee = EtapeChasse.premiereFlechee(dans: lignes, cadres: cadres, image: zone)
        #expect(trouvee?.rang == 2)
        #expect(trouvee?.direction == .sud)
    }

    @Test("L'étape lue apparie la direction et l'indice de la même ligne, la dernière fléchée")
    func etapeLueAppariement() throws {
        let liste = try indices()
        // Comme sur l'écran : plusieurs lignes fléchées « EN COURS », l'étape en cours est la dernière.
        let lignes = ["Apprentissage : Assassin", "ÉTAPE : 1/4", "Départ [10,22]", "Baie de Sufokia",
                      "← Poupée koalak EN COURS", "↑ Théière à rayures EN COURS", "???"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.direction == .nord)
        #expect(etape.cible == .indice(liste[6])) // Théière à rayures, la dernière ligne fléchée
        #expect(etape.rang == 5)
    }

    @Test("L'étape lue ignore la ligne VALIDÉ au-dessus de la ligne EN COURS")
    func etapeLueLigneValidee() throws {
        let liste = try indices()
        // Capture réelle : « ← Flèche… VALIDÉ » au-dessus, « ↑ Gravure… EN COURS » en dessous.
        let lignes = ["Départ [10,22]", "← Poupée koalak VALIDÉ", "↑ Théière à rayures EN COURS", "???"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.direction == .nord)
        #expect(etape.cible == .indice(liste[6])) // Théière à rayures, pas la validée
        #expect(etape.rang == 2)
    }

    @Test("Sans badge lisible, la dernière ligne fléchée non validée gagne")
    func etapeLueSansBadge() throws {
        let liste = try indices()
        let lignes = ["← Poupée koalak VALIDÉ", "↑ Théière à rayures"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.direction == .nord)
        #expect(etape.cible == .indice(liste[6]))
        #expect(etape.rang == 1)
    }

    @Test("L'étape lue remonte aux lignes fléchées du dessus quand la dernière n'a pas d'indice reconnu")
    func etapeLueLigneSansIndice() throws {
        let liste = try indices()
        let lignes = ["titre", "← Poupée koalak", "↑ ???"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.direction == .ouest)
        #expect(etape.cible == .indice(liste[5]))
        #expect(etape.rang == 1)
    }

    @Test("Sans flèche lue, la cible est le dernier indice lu et aucune direction n’est posée")
    func etapeLueSansFleche() throws {
        let liste = try indices()
        let lignes = ["titre", "Poupée koalak", "Théière à rayures"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.direction == nil) // aucune flèche lue sûrement : aucune direction posée
        #expect(etape.cible == .indice(liste[6])) // le dernier lu
        #expect(etape.rang == 2)
    }

    @Test("La direction retenue exige une lecture sûre : pixel ≥ 0,75, ou gabarit ≥ 0,6 et glyphe d'accord")
    func retenueSure() {
        // p = (direction, score, parGabarits)
        let base = { (g: Direction?, p: (Direction, Double, Bool)?) in
            EtapeChasse.AnalyseLigne(texte: "x", glyphe: g,
                                     pixel: p.map { DetectionFleche.Correspondance(direction: $0.0, score: $0.1, parGabarits: $0.2) },
                                     enCours: false, validee: false)
        }
        // pixel sûr : il gagne même contre un glyphe trompé
        #expect(base(.nord, (.sud, 0.9, true)).retenue == .sud)
        #expect(base(.nord, (.sud, 0.9, false)).retenue == .sud)
        // gabarit moyen et glyphe d'accord : retenu
        #expect(base(.nord, (.nord, 0.65, true)).retenue == .nord)
        // désaccord gabarit moyen / glyphe : aucune direction (pas de pari)
        #expect(base(.nord, (.sud, 0.65, true)).retenue == nil)
        // gabarit seul à 0,65 : retenu ; sous 0,6 : rien
        #expect(base(nil, (.sud, 0.65, true)).retenue == .sud)
        #expect(base(nil, (.sud, 0.55, true)).retenue == nil)
        // conicité seule : sous 0,75, aucune direction (une lettre peut faire une tête)
        #expect(base(nil, (.sud, 0.65, false)).retenue == nil)
        #expect(base(.nord, (.sud, 0.65, false)).retenue == .nord)
        // conicité seule mais sûre (≥ 0,75) : retenu
        #expect(base(nil, (.sud, 0.8, false)).retenue == .sud)
        // glyphe seul : retenu
        #expect(base(.nord, nil).retenue == .nord)
        // rien : rien
        #expect(base(nil, nil).retenue == nil)
    }

    @Test("Quand l'OCR sépare le badge de la ligne d'indice, le badge de la ligne du dessus compte")
    func etapeLueBadgeSepare() throws {
        let liste = try indices()
        // comme le log natif : « EN COURS » sur sa propre ligne, l'indice dessous
        let lignes = ["Épisode : 2/4", "EN COURS", "• Poupée koalak", "VALIDÉ", "Théière à rayures", "EN COURS", "• Crâne de likrone"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.cible == .indice(liste[1])) // Crâne de likrone, dernière ligne EN COURS
        #expect(etape.rang == 6)
    }

    @Test("Une ligne fléchée sans indice reconnu n'est pas l'étape : sa flèche ne dicte pas la direction")
    func etapeLueFlecheSansCible() throws {
        let liste = try indices()
        let lignes = ["titre", "← ???", "Théière à rayures"]
        let cadres = (0..<lignes.count).map { CGRect(x: 30, y: CGFloat(8 + $0 * 32), width: 150, height: 26) }
        let etape = EtapeChasse.etapeLue(dans: lignes, cadres: cadres, image: nil, parmi: liste)
        #expect(etape.direction == nil) // la flèche de « ??? » n'est pas celle de l'étape
        #expect(etape.cible == .indice(liste[6]))
        #expect(etape.rang == 2)
    }
}
