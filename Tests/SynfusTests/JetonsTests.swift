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

    /// Les fichiers où une couleur ou une police peut se construire sans jeton : le fichier engendré et
    /// ce qui fournit le thème courant, la marque et les classes (dessinées à part), les mesures de la
    /// lecture d'écran, les zones de calibrage (reconnues à leur teinte), le rose du bouton « Fin de
    /// tour » du jeu, et le menu système, dont le texte secondaire s'inverse tout seul à la sélection.
    private let horsJetons: Set<String> = ["Jetons.swift", "ThemeCourant.swift", "SynfusMark.swift", "Couvee.swift",
                                           "SigneSynseria.swift", "DofusClass.swift", "CalibrationZonesView.swift",
                                           "BarControls.swift", "MenuBarController.swift"]

    @Test("Aucune couleur ne se construit hors des jetons")
    func couleursParLesJetons() throws {
        // swiftlint:disable:next accent_systeme - le motif nomme ce qu'il interdit
        let motif = /accentColor|Color\(\.sRGB|Color\(red:|Color\(white:|Color\(hue:|NSColor\((srgbRed|red|white|calibrated|deviceRed)|Color\.(white|black|orange|green|yellow|mint|red|blue)\b|[^a-zA-Z.]\.(orange|green|yellow|mint)\b|NSColor\.(label|secondaryLabel|tertiaryLabel|controlAccent|system[A-Z])/
        for (fichier, ligne) in try lignes(sauf: horsJetons) {
            #expect(!ligne.contains(motif), "\(fichier) : \(ligne)")
        }
    }

    @Test("Aucun accès à un jeton ne contourne Jetons")
    func accesParJetons() throws {
        // Les anciens points de passage (façade `Couleurs`, `Font.synfus`) et toute liste de jetons recopiée
        // (`static var primaire: Color`) : un jeton se lit par son chemin dans le thème courant.
        let motif = /\bCouleurs\b|Typographie|\.synfus\(|static (var|let) (fenetre|surface|creux|filet|encre|primaire|safran|danger|alerte|succes|nuit)\w*\b/
        for (fichier, ligne) in try lignes(sauf: ["Jetons.swift"]) {
            #expect(!ligne.contains(motif), "\(fichier) : \(ligne)")
        }
    }

    @Test("Toute police de vue passe par l'échelle")
    func policesParLEchelle() throws {
        let motif = /\.system\(size|weight:|\.fontWeight\(\.(?!semibold)|\.font\(\.(caption|footnote|subheadline|callout|headline|title|body)/
        // Le menu de la barre de menus est en `NSFont`, hors de SwiftUI ; le mot du signe suit la taille de son emblème.
        for (fichier, ligne) in try lignes(sauf: ["Jetons.swift", "SynfusMark.swift", "MenuBarController.swift", "SigneSynseria.swift"]) {
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

    @Test("Un bouton prend un des quatre rangs, un segment le composant commun")
    func boutonsEtSegments() throws {
        // Les réglages héritent du rang secondaire posé sur leur volet (`SettingsView`) ; les barres d'icônes
        // et le menu contextuel de la palette sont hors rangs.
        let heritent: Set<String> = ["Reglages", "Barre", "PaletteVue.swift"]
        let racine = try String(contentsOf: SourcesDuDepot.dossier.appendingPathComponent("Interface/Reglages/SettingsView.swift"),
                                encoding: .utf8)
        #expect(racine.contains(".buttonStyle(.bouton(.secondaire))"))
        for url in SourcesDuDepot.fichiers() {
            let texte = try code(url).joined(separator: "\n")
            #expect(!texte.contains(".pickerStyle(.segmented)"), "\(url.lastPathComponent) : utiliser `Segments`")
            let exempt = url.pathComponents.contains { heritent.contains($0) } || heritent.contains(url.lastPathComponent)
            if !exempt, texte.contains(/(^|[^A-Za-z])Button\s*[({]/) {
                #expect(texte.contains(".buttonStyle("), "\(url.lastPathComponent) : un bouton sans rang")
            }
        }
    }

    @Test("Les points de suspension sont le caractère « … », jamais trois points")
    func pointsDeSuspension() throws {
        let tables = SourcesDuDepot.dossier.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Localisation")
        for langue in ["fr", "en", "es"] {
            let texte = try String(contentsOf: tables.appendingPathComponent("\(langue).json"), encoding: .utf8)
            #expect(!texte.contains("..."), "\(langue).json")
        }
    }
}
