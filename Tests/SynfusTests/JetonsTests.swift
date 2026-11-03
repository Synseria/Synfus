import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Synfus

/// Les jetons d'interface tiennent parce qu'un test les vérifie dans les
/// sources : une couleur ou une taille hors de ces listes se voit à la revue
/// des captures, jamais à la compilation.
struct JetonsTests {

    /// 9 pt est la taille des marques (initiales, numéros, chevrons), pas d'un texte.
    private static let echelle: Set<Int> = [9, 11, 12, 13, 15, 20]

    private func sources() throws -> [(chemin: String, lignes: [Substring])] {
        let racine = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/Synfus")
        let fichiers = FileManager.default.enumerator(at: racine, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        return try fichiers.map {
            ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8).split(separator: "\n"))
        }
    }

    /// Luminance relative WCAG d'une couleur.
    private func luminance(_ couleur: Color) throws -> Double {
        let rgb = try #require(NSColor(couleur).usingColorSpace(.sRGB))
        func canal(_ valeur: CGFloat) -> Double {
            let v = Double(valeur)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canal(rgb.redComponent) + 0.7152 * canal(rgb.greenComponent)
            + 0.0722 * canal(rgb.blueComponent)
    }

    @Test("Le texte blanc se lit sur l'aplat d'accent")
    func contrasteDeLAplat() throws {
        #expect(1.05 / (try luminance(Couleurs.accentPlein) + 0.05) >= 4.5)
    }

    @Test("Aucune vue ne prend l'accent du système ni l'orange hors de Couleurs")
    func couleursParLesJetons() throws {
        for (chemin, lignes) in try sources() where chemin != "Couleurs.swift" {
            for ligne in lignes where !ligne.contains("///") {
                #expect(!ligne.contains("accentColor"), "\(chemin) : \(ligne)")
                #expect(!ligne.contains(".orange"), "\(chemin) : \(ligne)")
            }
        }
    }

    @Test("Toute taille de police écrite en dur est sur l'échelle")
    func taillesSurLEchelle() throws {
        let motif = /\.system\(size: (\d+)/
        for (chemin, lignes) in try sources() {
            for ligne in lignes {
                for correspondance in ligne.matches(of: motif) {
                    #expect(Self.echelle.contains(Int(correspondance.1) ?? 0), "\(chemin) : \(ligne)")
                }
            }
        }
    }
}
