import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Synfus

/// Les jetons d'interface. Une couleur ou une police hors des jetons compile très
/// bien : seul ce relevé des sources l'arrête.
struct JetonsTests {

    /// Une ligne sans son commentaire (`//` précédé de `:` est une URL).
    private func sansCommentaire(_ ligne: Substring) -> Substring {
        var reste = ligne
        while let debut = reste.range(of: "//") {
            if debut.lowerBound == ligne.startIndex || ligne[ligne.index(before: debut.lowerBound)] != ":" {
                return ligne[..<debut.lowerBound]
            }
            reste = ligne[debut.upperBound...]
        }
        return ligne
    }

    private func code(_ url: URL) throws -> [Substring] {
        try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
            .map(sansCommentaire).filter { !$0.allSatisfy(\.isWhitespace) }
    }

    private func fichiers(sauf exclus: Set<String>) throws -> [URL] {
        let tous = SourcesDuDepot.fichiers()
        try #require(!tous.isEmpty)
        return tous.filter { !exclus.contains($0.lastPathComponent) }
    }

    private func lignes(sauf exclus: Set<String>) throws -> [(fichier: String, ligne: Substring)] {
        try fichiers(sauf: exclus).flatMap { url in try code(url).map { (url.lastPathComponent, $0) } }
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
        // Un appel, sur une ou plusieurs lignes : jusqu'à la fin de ses modificateurs.
        let motif = /rootView:\s*[^\n]*(\n\s*\.[^\n]*)*/
        // `ImagesCarte` n'héberge qu'une image, sans contrôle.
        for url in try fichiers(sauf: ["ImagesCarte.swift"]) {
            for racine in try code(url).joined(separator: "\n").matches(of: motif) {
                #expect(racine.output.0.contains(".racineSynfus()"), "\(url.lastPathComponent) : \(racine.output.0)")
            }
        }
    }
}
