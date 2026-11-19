import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    private override init() { super.init() }

    /// Le premier lancement et tant que l'accessibilité manque : les autorisations sont le premier bloc de Général.
    nonisolated static func ouvreAuLancement(premierLancement: Bool, accessibiliteAccordee: Bool) -> Bool {
        premierLancement || !accessibiliteAccordee
    }

    /// Sur cet onglet, s'il est donné.
    func show(section: SettingsSection? = nil) {
        UsageStore.shared.compter(.reglages)
        if let section { OngletReglages.shared.section = section }
        if window == nil {
            // La taille commune, bornée à la place utile de l'écran (sans le Dock ni la barre des menus).
            let utile = (FloatingBarController.shared.visibleBarFrame.flatMap { barre in
                NSScreen.screens.first { $0.frame.intersects(barre) } } ?? NSScreen.main)?.visibleFrame.height
            let hauteur = min(SettingsView.taille.height, (utile ?? SettingsView.taille.height) - Self.gap * 2)
            let window = Self.batir(SettingsView(), hauteur: hauteur)
            self.window = window
            NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose),
                                                   name: NSWindow.willCloseNotification, object: window)
        }
        guard let window else { return }

        // À chaque (ré)ouverture, la fenêtre se place sous la barre flottante : c'est de là qu'on
        // l'invoque. Ouverte, on ne la déplace pas. Sa taille est la même pour tous les onglets.
        if !window.isVisible {
            window.layoutIfNeeded()
            position(window)
        }

        // L'app tourne en accessory : sans activation explicite, la fenêtre
        // s'ouvrirait derrière le jeu.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// La fenêtre autour de `contenu`, l'unique façon de la bâtir : les captures jugent celle que
    /// l'utilisateur voit. Sans titre affiché : les onglets disent où l'on est ; le nom reste pour le
    /// menu Fenêtre et VoiceOver. Le fond monte sous la barre de titre, la fenêtre n'a pas le sien. La
    /// fenêtre a la taille commune, barre de titre comprise, et la vue la remplit : jamais l'inverse,
    /// la taille idéale de la vue poussait la fenêtre de la hauteur de sa barre de titre.
    static func batir(_ contenu: some View, hauteur: CGFloat = SettingsView.taille.height) -> NSWindow {
        let hote = NSHostingController(rootView: contenu.racineSynfus())
        hote.sizingOptions = []
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: CGSize(width: SettingsView.taille.width, height: hauteur)),
                              styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                              backing: .buffered, defer: true)
        window.contentViewController = hote
        window.setContentSize(CGSize(width: SettingsView.taille.width, height: hauteur))
        window.title = L("reglages.titre")
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false
        return window
    }

    /// La sonde d'attention se démarre à la main depuis l'onglet Diagnostic et
    /// n'a pas d'autre point d'arrêt : sans celui-ci, fermer les réglages sans
    /// l'éteindre la laisserait tourner à 4 Hz — Dock interrogé, journal
    /// grossissant — indéfiniment en arrière-plan. Une vue de carte agrandie
    /// ne survit pas non plus à la fenêtre de sa vignette.
    @objc private func windowWillClose() {
        if AttentionProbe.shared.running { AttentionProbe.shared.stop() }
        ApercuCarte.shared.cacher()
    }

    /// Au milieu de l'écran, sous la barre flottante, bornée à l'écran.
    ///
    /// Le centrage horizontal se fait sur l'écran et non sur la barre : celle-ci
    /// se déplace à la main, la fenêtre de réglages n'a pas à la suivre de biais.
    /// Et sur `frame` plutôt que `visibleFrame`, comme le fait la barre — un Dock
    /// posé sur un côté décalerait sinon les deux ensemble.
    private func position(_ window: NSWindow) {
        let bar = FloatingBarController.shared.visibleBarFrame
        let screen = bar.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } }
            ?? NSScreen.main
        guard let screen else { return }

        let size = window.frame.size
        let visible = screen.visibleFrame

        var origin = CGPoint(
            x: (screen.frame.midX - size.width / 2).rounded(),
            // Sous la barre quand elle est là ; à mi-hauteur sinon.
            y: ((bar.map { $0.minY - Self.gap } ?? visible.midY + size.height / 2) - size.height)
                .rounded()
        )
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)

        window.setFrameOrigin(origin)
    }

    /// Écart entre la barre et le haut de la fenêtre de réglages.
    private static let gap: CGFloat = 12
}
