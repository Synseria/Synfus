import AppKit
import SwiftUI
import Testing
@testable import Synfus

/// La fenêtre des réglages telle que bâtie : une taille commune, que Général remplit sans défiler ni
/// laisser de vide sous sa page.
@MainActor
struct ReglagesFenetreTests {
    private func fenetre(_ section: SettingsSection) throws -> (NSWindow, NSView) {
        let fenetre = SettingsWindowController.batir(SettingsView(onglet: OngletReglages(section)))
        let vue = try #require(fenetre.contentView)
        vue.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        vue.layoutSubtreeIfNeeded()
        return (fenetre, vue)
    }

    private func defilement(_ vue: NSView) -> NSScrollView? {
        vue as? NSScrollView ?? vue.subviews.lazy.compactMap(defilement).first
    }

    /// La fenêtre a la taille commune, barre de titre comprise, et la vue la remplit jusqu'en bas.
    @Test func laVueRemplitLaFenetre() throws {
        let (fenetre, vue) = try fenetre(.theme)
        defer { fenetre.close() }
        #expect(fenetre.frame.size == SettingsView.taille)
        let page = try #require(defilement(vue))
        let basDeLaPage = vue.convert(page.bounds, from: page).minY
        // La page s'arrête à sa marge du bas de la fenêtre, pas plus haut.
        #expect(abs(min(basDeLaPage, vue.bounds.height - vue.convert(page.bounds, from: page).maxY) - Jetons.espace2) < 1,
                "bande vide sous la page : \(vue.convert(page.bounds, from: page)) dans \(vue.bounds)")
    }

    @Test func generalTientSansDefiler() throws {
        let (fenetre, vue) = try fenetre(.general)
        defer { fenetre.close() }
        let page = try #require(defilement(vue)), contenu = try #require(page.documentView).frame.height
        let visible = page.contentView.bounds.height
        #expect(contenu <= visible, "Général défile : \(contenu) pour \(visible)")
        #expect(visible - contenu < Jetons.espace4, "un vide sous Général : \(contenu) pour \(visible)")
    }
}
