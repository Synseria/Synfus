import AppKit
import Foundation
import Testing
@testable import Synfus

/// Les vues s'écrivent sur les jetons : aucune valeur de décor en dur, et le langage d'état tient.
@MainActor
struct ComposantsTests {
    @Test("Aucune couleur, rayon, espace ni police chiffrés dans une vue")
    func vuesSurLesJetons() throws {
        // Hors vues : les fichiers engendrés (jetons, trousse), la marque dessinée en CoreGraphics, les
        // couleurs des classes du jeu, les mesures de la lecture d'écran et le banc de mesure.
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
                || chemin.contains("/Lecture/") || chemin.contains("/Classes/") || chemin.contains("/Trousse/") { continue }
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

    /// Les délais du signal, ouverts à la main : aucune horloge.
    @MainActor private final class Delais {
        private var attentes: [CheckedContinuation<Void, Never>] = []
        var enAttente: Int { attentes.count }
        func attendre() async { await withCheckedContinuation { attentes.append($0) } }
        func echoir(_ rang: Int) { attentes[rang].resume() }
    }

    @Test("Le signal de copie marque une ligne, s'efface, et une nouvelle copie n'est pas effacée par l'ancien délai")
    func signalDeCopie() async {
        let delais = Delais()
        let signal = SignalCopie(attendre: { await delais.attendre() })
        signal.signaler("a")
        #expect(signal.affiche("a") && !signal.affiche("b"))
        while delais.enAttente < 1 { await Task.yield() }
        signal.signaler("b")
        #expect(signal.affiche("b") && !signal.affiche("a"))
        while delais.enAttente < 2 { await Task.yield() }
        // Le délai de « a » échoit : « b » reste.
        delais.echoir(0)
        for _ in 0..<20 { await Task.yield() }
        #expect(signal.affiche("b"))
        delais.echoir(1)
        while signal.ligne != nil { await Task.yield() }
    }

    @Test("Le choix s'écrit en accent, le désactivé et le plein changent d'encre")
    func voix() {
        #expect(EtatVisuel.choisi.encre != EtatVisuel.inactif.encre)
        #expect(EtatVisuel.desactive.encre != EtatVisuel.repos.encre)
        #expect(EtatVisuel.courant.encre != EtatVisuel.repos.encre)
    }

    @Test("Sans le clavier, un choix perd sa voix")
    func choixInactif() {
        #expect(EtatVisuel.choix(auClavier: true) == .choisi)
        #expect(EtatVisuel.choix(.courant, auClavier: true) == .courant)
        #expect(EtatVisuel.choix(auClavier: false) == .inactif)
        #expect(EtatVisuel.choix(.courant, auClavier: false) == .inactif)
    }

    @Test("Le décompte du tour devient critique à cinq secondes, pas avant")
    func decompteCritique() {
        #expect(!CombatBadge.estCritique(6))
        #expect(CombatBadge.estCritique(5))
        #expect(CombatBadge.estCritique(0))
    }

    /// L'À propos montre l'emblème de `marque/` du SDS, posé dans les ressources : une copie perdue
    /// laisserait un rond plein à sa place.
    @Test("L'emblème Synseria de l'À propos est dans les ressources et se lit")
    func emblemeSynseria() throws {
        let url = try #require(Ressources.url("synseria-embleme-synfus.svg"))
        let image = try #require(NSImage(contentsOf: url))
        #expect(image.isValid && image.size.width > 0)
    }
}
