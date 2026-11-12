import Foundation
import Testing
@testable import Synfus

/// Les vues s'écrivent sur les jetons : aucune valeur de décor en dur, et le langage d'état tient.
@MainActor
struct ComposantsTests {
    @Test("Aucune couleur, rayon, espace ni police chiffrés dans une vue")
    func vuesSurLesJetons() throws {
        // Hors vues : le fichier engendré, la marque dessinée en CoreGraphics, les couleurs des classes
        // du jeu, les mesures de la lecture d'écran et le banc de mesure.
        let horsVues = ["Jetons.swift", "BancCaptures.swift"]
        let interdits: [(motif: String, nom: String)] = [
            (#"cornerRadius: *[0-9]"#, "rayon chiffré"),
            (#"\.padding\([^)]*\b[1-9][0-9]*\)"#, "marge chiffrée"),
            (#"(?<![a-zA-Z])spacing: *[1-9]"#, "espace chiffré"),
            (#"Color\.(primary|secondary|gray)\b"#, "couleur du système"),
            (#"foregroundStyle\(\.(primary|secondary|tertiary)\)"#, "encre du système"),
            (#"\.font\(\.system|gras:"#, "police hors rôle"),
            (#"\.(easeIn|easeOut|easeInOut)\("#, "courbe hors jetons"),
            (#"\.opacity\(0\.[0-9]+\)\)\)"#, "voile de décor"),
        ]
        var fautes: [String] = []
        for fichier in SourcesDuDepot.fichiers() {
            let chemin = fichier.path
            if horsVues.contains(fichier.lastPathComponent) || chemin.contains("/Marque/")
                || chemin.contains("/Lecture/") || chemin.contains("/Classes/") { continue }
            let texte = try String(contentsOf: fichier, encoding: .utf8)
            for (numero, ligne) in texte.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                for interdit in interdits where ligne.range(of: interdit.motif, options: .regularExpression) != nil {
                    fautes.append("\(fichier.lastPathComponent):\(numero + 1) \(interdit.nom)")
                }
            }
        }
        #expect(fautes.isEmpty, "\(fautes.joined(separator: "\n"))")
    }

    @Test("Survol et pression passent avant le repos")
    func etatsDeBase() {
        #expect(EtatVisuel(survole: false) == .repos)
        #expect(EtatVisuel(survole: true) == .survol)
        #expect(EtatVisuel(survole: true, presse: true) == .presse)
    }

    @Test("Seul le teinté a un contour, seul le désactivé change d'encre")
    func voix() {
        #expect(EtatVisuel.choisi.contour != nil)
        for etat in [EtatVisuel.repos, .survol, .presse, .courant, .desactive] { #expect(etat.contour == nil) }
        #expect(EtatVisuel.desactive.encre != EtatVisuel.repos.encre)
        #expect(EtatVisuel.courant.encre != EtatVisuel.repos.encre)
    }
}
