import Testing
import CoreGraphics
import Foundation
@testable import Synfus

/// Une capture du contenu entier découpée en zones, contre une capture par
/// zone : la règle qui choisit, la géométrie qui doit rendre les mêmes pixels,
/// et le dépouillement du banc `--banc-captures`.
struct CaptureUniqueTests {

    // MARK: - La règle

    @Test("Sous le seuil, une capture par zone ; au seuil, une capture entière")
    func plan() {
        #expect(PlanCapture.pour([.position]) == .parZone)
        #expect(PlanCapture.pour([.position, .combat]) == .parZone)
        #expect(PlanCapture.pour([.position, .combat, .quetes]) == .entiere)
        // Un genre demandé deux fois reste une zone.
        #expect(PlanCapture.pour([.position, .position, .combat]) == .parZone)
        #expect(PlanCapture.pour([.position, .combat], seuil: 2) == .entiere)
    }

    // MARK: - La découpe

    private static let fenetres: [(CGSize, Bool)] = [
        (CGSize(width: 1728, height: 1117), true), (CGSize(width: 1728, height: 1084), false),
        (CGSize(width: 1280, height: 800), false), (CGSize(width: 2560, height: 1440), true),
        (CGSize(width: 1013, height: 677), false),
    ]

    @Test("Découpée dans le contenu entier, une zone a la place et la taille de sa capture seule, au pixel près")
    func memeGeometrie() throws {
        for (fenetre, pleinEcran) in Self.fenetres {
            let reglage = CaptureContenu(pleinEcran: pleinEcran, normaliser: true)
            func geometrie(_ zone: ZoneEcran) -> GeometrieCapture {
                GeometrieCapture(fenetre: fenetre, region: zone.rect, contenu: reglage, maxWidth: nil,
                                 natif: 2, barreTitre: 28)
            }
            let entiere = geometrie(.entiere)
            let contenu = ZoneEcran.contenu(fenetre: fenetre, barreTitre: 28, pleinEcran: pleinEcran)
            let echelle = CGFloat(entiere.hauteur) / contenu.height
            for zone in GenreLecture.allCases.map(\.parDefaut) + BancCaptures.zones(8) {
                let seule = geometrie(zone)
                let coupe = zone.pixels(dans: CGSize(width: entiere.largeur, height: entiere.hauteur))
                let source = try #require(seule.source)
                #expect(abs(Int(coupe.width) - seule.largeur) <= 1, "\(fenetre) \(zone)")
                #expect(abs(Int(coupe.height) - seule.hauteur) <= 1, "\(fenetre) \(zone)")
                #expect(abs(coupe.minX - (source.minX - contenu.minX) * echelle) <= 1, "\(fenetre) \(zone)")
                #expect(abs(coupe.minY - (source.minY - contenu.minY) * echelle) <= 1, "\(fenetre) \(zone)")
            }
        }
    }

    @Test("Deux zones jointives restent jointives une fois découpées")
    func jointives() {
        let taille = CGSize(width: 1729, height: 1080)
        let a = ZoneEcran(x: 0.1, y: 0.2, largeur: 0.333, hauteur: 0.1).pixels(dans: taille)
        let b = ZoneEcran(x: 0.433, y: 0.2, largeur: 0.2, hauteur: 0.1).pixels(dans: taille)
        #expect(a.maxX == b.minX)
    }

    /// Une image dont chaque pixel dit sa colonne et sa ligne (rouge, vert) :
    /// la découpe en rend exactement le rectangle, sans rien rééchantillonner.
    @Test("La découpe rend exactement les pixels de la zone")
    func memesPixels() throws {
        let (w, h) = (256, 200)
        var octets = [UInt8](repeating: 255, count: w * h * 4)
        for y in 0..<h { for x in 0..<w { octets[(y * w + x) * 4] = UInt8(x); octets[(y * w + x) * 4 + 1] = UInt8(y) } }
        let image = try #require(octets.withUnsafeMutableBytes { tampon -> CGImage? in
            CGContext(data: tampon.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)?
                .makeImage()
        })
        let zone = ZoneEcran.combatParDefaut
        let attendu = zone.pixels(dans: CGSize(width: w, height: h))
        let coupe = try #require(CapturesCalibrage.decouper(zone, dans: image))
        #expect(coupe.width == Int(attendu.width) && coupe.height == Int(attendu.height))
        let donnees = try #require(coupe.dataProvider?.data as Data?)
        let ligne = coupe.bytesPerRow, pas = coupe.bitsPerPixel / 8
        for (x, y) in [(0, 0), (coupe.width - 1, coupe.height - 1), (coupe.width / 2, 3)] {
            #expect(donnees[y * ligne + x * pas] == UInt8(Int(attendu.minX) + x))
            #expect(donnees[y * ligne + x * pas + 1] == UInt8(Int(attendu.minY) + y))
        }
    }

    // MARK: - Le dépouillement du banc

    @Test("Médiane et p90 au rang le plus proche")
    func quantiles() {
        let serie = (1...10).map(Double.init)
        #expect(BancCaptures.quantile(serie, 0.5) == 5)
        #expect(BancCaptures.quantile(serie, 0.9) == 9)
        #expect(BancCaptures.quantile([], 0.5) == 0)
        #expect(BancCaptures.zones(5).count == 5)
        #expect(BancCaptures.zones(2) == [.positionParDefaut, .combatParDefaut])
    }

    @Test("Le seuil suggéré : le plus petit nombre de zones dès lequel la capture entière gagne, et pour tous les suivants")
    func seuilSuggere() {
        func mesure(_ mur: Double, _ cpu: Double) -> BancCaptures.Mesure {
            BancCaptures.Mesure(mur: [mur], cpu: [cpu], cpuSysteme: [], octetsImage: [0])
        }
        let mesures: [Int: [BancCaptures.Mode: BancCaptures.Mesure]] = [
            2: [.parZone: mesure(10, 5), .entiere: mesure(9, 6)],     // plus de CPU : perd
            3: [.parZone: mesure(15, 7), .entiere: mesure(10, 6)],
            5: [.parZone: mesure(25, 12), .entiere: mesure(11, 7)],
        ]
        #expect(BancCaptures.seuilSuggere(mesures) == 3)
        var jamais = mesures
        jamais[5] = [.parZone: mesure(25, 12), .entiere: mesure(30, 7)]
        #expect(BancCaptures.seuilSuggere(jamais) == nil)
    }

    // MARK: - Le banc OCR, sur de vraies captures

    static var dossierCaptures: String? { ProcessInfo.processInfo.environment["SYNFUS_CAPTURES_DOSSIER"] }

    /// Chaque zone de `GenreLecture`, découpée dans le contenu entier ou
    /// capturée seule, sur chaque fenêtre Dofus entière du dossier :
    ///
    ///     SYNFUS_CAPTURES_DOSSIER=~/Library/Logs/Synfus/captures sh test.sh decoupeLueCommeCapture
    ///
    /// `SYNFUS_PLEIN_ECRAN=1` : captures sans barre de titre. Le texte n'est
    /// pas identique au caractère près : l'OCR du jeu bascule sur un demi-pixel
    /// de phase (« la »/« l1 », « forgeronne »/« torgeronne »), d'un côté comme
    /// de l'autre. Ce qui compte : mêmes lignes, une faute sur dix au plus, et
    /// la même position lue.
    @Test("Une zone découpée se lit comme la même zone capturée seule", .enabled(if: dossierCaptures != nil))
    func decoupeLueCommeCapture() async throws {
        let dossier = (try #require(Self.dossierCaptures) as NSString).expandingTildeInPath
        let pleinEcran = ProcessInfo.processInfo.environment["SYNFUS_PLEIN_ECRAN"] == "1"
        let fichiers = try FileManager.default.contentsOfDirectory(atPath: dossier).filter { $0.hasSuffix(".png") }.sorted()
        let moteur = MoteurOCR()
        await moteur.prechauffer()
        var (zones, pareilles, fautes, caracteres) = (0, 0, 0, 0)
        for fichier in fichiers {
            guard let pleine = SimulationCapture.charger(dossier + "/" + fichier), pleine.width > 2000,
                  let entiere = SimulationCapture.zone(.entiere, dans: pleine, pleinEcran: pleinEcran)
            else { Sortie.dire("\(fichier) : écartée (pas une fenêtre entière en Retina)"); continue }
            for genre in GenreLecture.allCases {
                let seule = try #require(SimulationCapture.zone(genre.parDefaut, dans: pleine, pleinEcran: pleinEcran))
                let coupe = try #require(CapturesCalibrage.decouper(genre.parDefaut, dans: entiere))
                let (a, b) = (await lignes(moteur, seule, genre), await lignes(moteur, coupe, genre))
                guard !(a.isEmpty && b.isEmpty) else { continue }
                zones += 1
                let (ta, tb) = (Ressemblance.normaliser(a.joined(separator: " ")), Ressemblance.normaliser(b.joined(separator: " ")))
                let d = Ressemblance.distanceDansTexte(ta, tb)
                fautes += d
                caracteres += ta.count
                if a == b { pareilles += 1; continue }
                Sortie.dire("\(fichier) \(genre), \(d) faute(s) : seule \(a)\n    découpée \(b)")
                #expect(a.count == b.count, "\(fichier) \(genre)")
                #expect(d <= max(2, ta.count / 10), "\(fichier) \(genre)")
                if genre == .position {
                    #expect(PositionCarte.lire(a)?.coordonnees == PositionCarte.lire(b)?.coordonnees)
                }
            }
        }
        Sortie.dire("\(zones) zones lues : \(pareilles) au caractère près, \(fautes) faute(s) sur \(caracteres) caractères")
    }

    private func lignes(_ moteur: MoteurOCR, _ image: CGImage, _ genre: GenreLecture) async -> [String] {
        guard case .lue(_, let lignes, _, _) = await moteur.lire(image: image, precedente: nil, mesure: genre.mesure)
        else { return [] }
        return lignes.map { $0.trimmingCharacters(in: .whitespaces) }
    }
}
