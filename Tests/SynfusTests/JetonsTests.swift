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

    @Test("Aucune vue ne prend une couleur d'état ni l'accent du système hors de Couleurs")
    func couleursParLesJetons() throws {
        let motif = /accentColor|[^a-zA-Z.]\.(orange|green|yellow|mint)\b|Color\.(orange|green|yellow|mint)\b/
        // Les zones se reconnaissent à leur teinte, et la marque a sa palette.
        for (fichier, ligne) in try lignes(sauf: ["Couleurs.swift", "Jetons.swift", "CalibrationZonesView.swift", "SynfusMark.swift"]) {
            #expect(!ligne.contains(motif), "\(fichier) : \(ligne)")
        }
    }

    @Test("Toute police de vue passe par l'échelle")
    func policesParLEchelle() throws {
        let motif = /\.system\(size|weight:|\.fontWeight\(\.(?!semibold)|\.font\(\.(caption|footnote|subheadline|callout|headline|title|body)/
        // Le menu de la barre de menus est en `NSFont`, hors de SwiftUI ; le mot du signe suit la taille de son emblème.
        for (fichier, ligne) in try lignes(sauf: ["Typographie.swift", "Jetons.swift", "SynfusMark.swift", "MenuBarController.swift",
                                                  "SigneSynseria.swift"]) {
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
