import Testing
import Foundation
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
}
