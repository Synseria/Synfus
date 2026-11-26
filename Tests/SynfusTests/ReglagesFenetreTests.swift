import AppKit
import SwiftUI
import Testing
@testable import Synfus
import SynseriaDesign

/// La fenêtre des réglages telle que bâtie : la taille commune, que le volet remplit jusqu'en bas.
@MainActor
struct ReglagesFenetreTests {
    private func defilement(_ vue: NSView) -> NSScrollView? {
        vue as? NSScrollView ?? vue.subviews.lazy.compactMap(defilement).first
    }

    @Test func leVoletRemplitLaFenetre() throws {
        let fenetre = SettingsWindowController.batir(SettingsView(onglet: OngletReglages(.propre(.barre))))
        defer { fenetre.close() }
        let vue = try #require(fenetre.contentView)
        vue.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        vue.layoutSubtreeIfNeeded()
        #expect(fenetre.contentRect(forFrameRect: fenetre.frame).size == FenetreDeReglages.taille)
        let page = try #require(defilement(vue))
        let cadre = vue.convert(page.bounds, from: page)
        let bas = vue.isFlipped ? vue.bounds.height - cadre.maxY : cadre.minY
        // La plaque s'arrête à `espace-2` du bas, jamais plus haut.
        #expect(bas <= Jetons.espace2 + 1, "bande vide sous le volet : \(cadre) dans \(vue.bounds)")
    }
}
