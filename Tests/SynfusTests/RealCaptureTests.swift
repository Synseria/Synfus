import Testing
import Foundation
import AppKit
import ImageIO
@testable import Synfus

/// Le localisateur sur une **vraie** capture, hors dépôt : le chemin vient de
/// `SYNFUS_CAPTURE`, le test est ignoré sans elle. C'est le banc de calibrage
/// des seuils, à lancer à la main :
///
///     SYNFUS_CAPTURE=~/Library/Logs/Synfus/captures/x.png swift test --filter RealCapture
struct RealCaptureTests {
    static var capturePath: String? { ProcessInfo.processInfo.environment["SYNFUS_CAPTURE"] }

    @Test("La barre de sorts est trouvée sur la capture fournie", .enabled(if: capturePath != nil))
    func barreSurCaptureReelle() throws {
        let path = (try #require(Self.capturePath) as NSString).expandingTildeInPath
        let image = try #require(LumaBitmap(contentsOf: URL(fileURLWithPath: path)))
        print("capture \(image.width) × \(image.height)")
        let bar = SpellBarLocator.locate(in: image)
        if let bar {
            print("rangées : \(bar.rows.count), cases : \(bar.rows.map(\.count)), côté \(bar.side), pas \(bar.pitch)")
            for (i, row) in bar.rows.enumerated() {
                print("  rangée \(i + 1) : y \(Int(row[0].minY)) x \(row.map { Int($0.minX) })")
            }
        } else {
            print("aucune barre")
        }
        #expect(bar != nil)
    }

    @Test("Reconnaissance des sorts sur la capture fournie", .enabled(if: capturePath != nil))
    func reconnaissance() throws {
        let path = (try #require(Self.capturePath) as NSString).expandingTildeInPath
        let image = try #require(LumaBitmap(contentsOf: URL(fileURLWithPath: path)))
        let classe = ProcessInfo.processInfo.environment["SYNFUS_CLASSE"] ?? "Feca"
        let analysis = SpellRecognition.analyze(image, classe: classe)
        print("candidats : \(analysis.candidateCount), localisation \(Int(analysis.locateDuration * 1000)) ms, comparaison \(Int(analysis.matchDuration * 1000)) ms")
        for cell in analysis.cells {
            guard let m = cell.match else { print("  barre \(cell.row + 1) case \(cell.position + 1) : vide"); continue }
            print(String(format: "  barre %d case %2d : %@ %-26@ score %.2f marge %.2f", cell.row + 1, cell.position + 1, m.isConfident ? "✓" : "?", m.nom, m.score, m.margin))
        }
        print("sûres : \(analysis.confidentCount)/\(analysis.cells.count)")
    }

    /// Ce que fait la capture de la lecture de l'écran, rejoué sur un PNG de
    /// fenêtre en Retina : la zone prise dans le contenu (sans barre de titre,
    /// sauf `SYNFUS_PLEIN_ECRAN=1`), ramenée à la hauteur de référence.
    private func zoneCapturee(_ zone: ZoneEcran) throws -> Data {
        let path = (try #require(Self.capturePath) as NSString).expandingTildeInPath
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))
        let pleine = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pleinEcran = ProcessInfo.processInfo.environment["SYNFUS_PLEIN_ECRAN"] == "1"
        let points = CGSize(width: CGFloat(pleine.width) / 2, height: CGFloat(pleine.height) / 2)
        let contenu = ZoneEcran.contenu(fenetre: points, barreTitre: 28, pleinEcran: pleinEcran)
        let rect = ZoneEcran.source(zone.rect, contenu: contenu)
        let pixels = CGRect(x: rect.minX * 2, y: rect.minY * 2, width: rect.width * 2, height: rect.height * 2).integral
        let coin = try #require(pleine.cropping(to: pixels))
        let echelle = ZoneEcran.echelle(hauteurContenu: contenu.height, plafond: 2)
        let (w, h) = (Int(rect.width * echelle), Int(rect.height * echelle))
        let contexte = try #require(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        contexte.interpolationQuality = .high
        contexte.draw(coin, in: CGRect(x: 0, y: 0, width: w, height: h))
        let reduite = try #require(contexte.makeImage())
        print("zone \(w) × \(h) px")
        return try #require(NSBitmapImageRep(cgImage: reduite).representation(using: .png, properties: [:]))
    }

    @Test("La position est lue sur la capture fournie", .enabled(if: capturePath != nil))
    func positionSurCaptureReelle() async throws {
        let png = try zoneCapturee(.positionParDefaut)
        let moteur = MoteurOCR()
        await moteur.prechauffer()
        guard case .lue(let signature, let lignes, let duree, _) = await moteur.lire(png: png, precedente: nil, couleur: false)
        else { Issue.record("rien lu"); return }
        print("OCR \(Int(duree * 1000)) ms : \(lignes)")
        let position = PositionCarte.lire(lignes)
        print("position : \(position?.coordonnees ?? "—") — \(position?.zone ?? "—")")
        #expect(position != nil)
        // La même image ne repasse pas par l'OCR.
        guard case .inchangee = await moteur.lire(png: png, precedente: signature, couleur: false) else {
            Issue.record("la signature n'a pas reconnu la même image"); return
        }
    }

    @Test("L'état de combat est lu sur la capture fournie", .enabled(if: capturePath != nil))
    func combatSurCaptureReelle() async throws {
        // `SYNFUS_ZONE_ENTIERE=1` : la capture est déjà la zone (un recadrage
        // du bouton), on la lit telle quelle.
        let png: Data
        if ProcessInfo.processInfo.environment["SYNFUS_ZONE_ENTIERE"] == "1" {
            png = try Data(contentsOf: URL(fileURLWithPath: (try #require(Self.capturePath) as NSString).expandingTildeInPath))
        } else {
            png = try zoneCapturee(.combatParDefaut)
        }
        let moteur = MoteurOCR()
        await moteur.prechauffer()
        guard case .lue(let signature, let lignes, let duree, let bouton) = await moteur.lire(png: png, precedente: nil, couleur: true)
        else { Issue.record("rien lu"); return }
        let constat = LectureCombat.classer(lignes: lignes, couleur: bouton ?? signature.couleur ?? 0)
        print("OCR \(Int(duree * 1000)) ms : \(lignes) — zone colorée \(Int((signature.couleur ?? 0) * 100)) %, bouton \(bouton.map { "\(Int($0 * 100)) %" } ?? "—") → \(constat)")
        if let attendu = ProcessInfo.processInfo.environment["SYNFUS_COMBAT_ATTENDU"] {
            #expect("\(constat.genre)" == attendu)
        }
    }
}
