import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Synfus

/// Les jetons d'interface. Une couleur ou une police hors des jetons compile très
/// bien : seul ce relevé des sources l'arrête.
struct JetonsTests {

    private func lignes(sauf exclus: Set<String>) throws -> [(fichier: String, ligne: Substring)] {
        try SourcesDuDepot.fichiers().filter { !exclus.contains($0.lastPathComponent) }.flatMap { url in
            try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
                .filter { !$0.contains("///") && !$0.contains("// ") }
                .map { (url.lastPathComponent, $0) }
        }
    }

    /// Luminance relative WCAG de la couleur, rendue sous une apparence.
    private func luminance(_ couleur: Color, _ apparence: NSAppearance.Name = .darkAqua) throws -> Double {
        var rgb: NSColor?
        try #require(NSAppearance(named: apparence)).performAsCurrentDrawingAppearance {
            rgb = NSColor(couleur).usingColorSpace(.sRGB)
        }
        let resolue = try #require(rgb)
        func canal(_ valeur: CGFloat) -> Double {
            let v = Double(valeur)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * canal(resolue.redComponent) + 0.7152 * canal(resolue.greenComponent)
            + 0.0722 * canal(resolue.blueComponent)
    }

    private func contraste(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    @Test("L'accent reste lisible : aplat sous du blanc, texte sur fond clair et sombre")
    func contrastes() throws {
        #expect(contraste(1, try luminance(Couleurs.accentPlein)) >= 4.5)
        #expect(contraste(1, try luminance(Couleurs.accentTexte, .aqua)) >= 4.5)
        let fenetreSombre = 0.013
        #expect(contraste(fenetreSombre, try luminance(Couleurs.accentTexte, .darkAqua)) >= 4.5)
    }

    @Test("Aucune vue ne prend une couleur d'état ni l'accent du système hors de Couleurs")
    func couleursParLesJetons() throws {
        let motif = /accentColor|[^a-zA-Z.]\.(orange|green|yellow|mint)\b|Color\.(orange|green|yellow|mint)\b/
        // Les zones se reconnaissent à leur teinte, et la marque a sa palette.
        for (fichier, ligne) in try lignes(sauf: ["Couleurs.swift", "CalibrationZonesView.swift", "SynfusMark.swift"]) {
            #expect(!ligne.contains(motif), "\(fichier) : \(ligne)")
        }
    }

    @Test("Toute police de vue passe par l'échelle")
    func policesParLEchelle() throws {
        let motif = /\.system\(size|weight:|\.fontWeight\(\.(?!semibold)|\.font\(\.(caption|footnote|subheadline|callout|headline|title|body)/
        // Le menu de la barre de menus est en `NSFont`, hors de SwiftUI.
        for (fichier, ligne) in try lignes(sauf: ["Typographie.swift", "SynfusMark.swift", "MenuBarController.swift"]) {
            #expect(!ligne.contains(motif), "\(fichier) : \(ligne)")
        }
    }

    @Test("Chaque fenêtre porte le jeton de racine")
    func racines() throws {
        // `ImagesCarte` n'héberge qu'une image, sans contrôle.
        for (fichier, ligne) in try lignes(sauf: ["ImagesCarte.swift"]) where ligne.contains("rootView:") {
            #expect(ligne.contains(".racineSynfus()"), "\(fichier) : \(ligne)")
        }
    }
}
