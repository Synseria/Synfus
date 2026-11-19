import AppKit
import SwiftUI
import Testing
@testable import Synfus

/// La fenêtre des réglages telle que bâtie : une taille commune, que la vue remplit jusqu'en bas.
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

    /// Le fond, d'un seul tenant, descend sous les onglets jusqu'à la plaque : au-dessus d'elle le même
    /// `espace-2` que sur ses côtés et en bas, jamais une bande de plus entre la barre et la plaque.
    @Test func laPlaqueALaMemeMargePartout() throws {
        let (fenetre, vue) = try fenetre(.theme)
        defer { fenetre.close() }
        let barre = NSHostingView(rootView: BarreDesOnglets(
            onglets: SettingsSection.allCases.map { .init(valeur: $0, libelle: $0.label, symbole: $0.icon) },
            selection: .constant(SettingsSection.theme)).racineSynfus())
        let hauteurDeLaBarre = barre.fittingSize.height
        let page = try #require(defilement(vue))
        let cadre = vue.convert(page.bounds, from: page)
        let haut = vue.isFlipped ? cadre.minY : vue.bounds.height - cadre.maxY
        let bas = vue.isFlipped ? vue.bounds.height - cadre.maxY : cadre.minY
        let marges = [cadre.minX, vue.bounds.width - cadre.maxX, bas]
        #expect(marges.allSatisfy { abs($0 - Jetons.espace2) < 1 }, "marges \(marges) autour de \(cadre)")
        // Le bas de la barre porte déjà son `espace-2` : la plaque commence juste dessous.
        #expect(abs(haut - hauteurDeLaBarre) < 1, "plaque à \(haut) du haut, barre de \(hauteurDeLaBarre)")
    }
}
