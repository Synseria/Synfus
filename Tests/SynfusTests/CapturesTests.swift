import AppKit
import SwiftUI
import Testing
@testable import Synfus

/// Les captures de la documentation et des notes de version : les vues de
/// Synfus rendues hors écran, sur des données d'exemple — jamais un visuel du
/// jeu. Ignoré sans `SYNFUS_CAPTURES=<dossier>`.
@MainActor
struct CapturesTests {
    nonisolated private static let dossier = ProcessInfo.processInfo.environment["SYNFUS_CAPTURES"]

    private func contexte() -> ContextePalette {
        var contexte = ContextePalette()
        contexte.position = PositionCarte(x: -2, y: 0, zone: "Amakna (Village d'Amakna)")
        contexte.zaaps = CatalogueZaaps.actifs(base: Carte.integree.zaaps, ajoutes: [], choix: [:])
        contexte.lieux = Carte.integree.lieux
        contexte.etiquettes = ["1:-78,-41": "Fri 1", "1:-77,-73": "Fri 2", "1:39,-82": "Fri 3",
                               "1:-2,0": "Village", "1:-16,1": "Koalak", "1:5,7": "Bouftou",
                               "1:-31,-56": "Bonta", "1:-26,37": "Brâk"]
        contexte.favoris = ["1:-31,-56", "1:-26,37", "1:-78,-41"]
        contexte.phrases = [Phrase(nom: "Recrutement", texte: "[Guilde] recrute, niveau 150+ — MP !"),
                            Phrase(nom: "Besoin d'aide", texte: "Besoin d'aide en %souszone% (%pos%) !")]
        contexte.persos = [(nom: "Aeryn", slotKey: "1#0"), (nom: "Brok", slotKey: "2#0")]
        contexte.invitationEquipe = "/invite Brok; /invite Cid"
        contexte.invitations = [(nom: "Brok", commande: "/invite Brok"), (nom: "Cid", commande: "/invite Cid")]
        return contexte
    }

    @Test("Captures de la palette", .enabled(if: dossier != nil))
    func palette() throws {
        let dossier = URL(fileURLWithPath: try #require(Self.dossier), isDirectory: true)
        try FileManager.default.createDirectory(at: dossier, withIntermediateDirectories: true)
        for (nom, requete) in [("palette-zaaps", ""), ("palette-travel", "/travel banque bonta"),
                               ("palette-fm", "/travel fm"), ("palette-commandes", "/"),
                               ("palette-variables", "%"), ("palette-tout", "recru")] {
            let modele = PaletteModele(contexte: contexte(), requete: requete)
            let vue = PaletteVue(modele: modele)
                .padding(24)
                .background(Color(red: 0.11, green: 0.11, blue: 0.13))
                .environment(\.colorScheme, .dark)
            try ecrire(vue, vers: dossier.appending(path: nom + ".png"))
        }
    }

    /// Par une fenêtre hors écran : `ImageRenderer` ne dessine ni champ de
    /// texte ni défilement, qui sont des vues AppKit.
    private func ecrire(_ vue: some View, vers url: URL) throws {
        _ = NSApplication.shared
        let hote = NSHostingView(rootView: vue)
        hote.frame = NSRect(origin: .zero, size: hote.fittingSize)
        let fenetre = NSWindow(contentRect: hote.frame, styleMask: .borderless, backing: .buffered, defer: false)
        fenetre.contentView = hote
        fenetre.appearance = NSAppearance(named: .darkAqua)
        hote.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        let rep = try #require(hote.bitmapImageRepForCachingDisplay(in: hote.bounds))
        hote.cacheDisplay(in: hote.bounds, to: rep)
        let png = try #require(rep.representation(using: .png, properties: [:]))
        try png.write(to: url)
    }
}
