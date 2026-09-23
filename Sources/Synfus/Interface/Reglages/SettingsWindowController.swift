import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    /// La fenêtre est en cours de placement automatique : tant que ce drapeau
    /// tient, chaque changement de taille la replace. Un déplacement à la souris
    /// y met fin — l'utilisateur a dit où il la voulait.
    private var placing = false
    /// Distingue notre propre `setFrameOrigin` d'un geste de l'utilisateur, comme
    /// le fait `FloatingBarController` pour la barre.
    private var repositioning = false

    private override init() { super.init() }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = L("reglages.titre")
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            self.window = window

            for (note, action) in [
                (NSWindow.didResizeNotification, #selector(windowResized)),
                (NSWindow.didMoveNotification, #selector(windowMoved)),
            ] {
                NotificationCenter.default.addObserver(
                    self, selector: action, name: note, object: window
                )
            }
        }
        guard let window else { return }

        // À chaque (ré)ouverture, la fenêtre se place sous la barre flottante :
        // c'est de là qu'on l'invoque, autant qu'elle apparaisse sous les yeux.
        // Tant qu'elle reste ouverte, en revanche, on ne la déplace pas.
        if !window.isVisible {
            placing = true
            // La taille définitive n'est connue qu'une fois SwiftUI passé. Placer
            // avant revenait à calculer sur une fenêtre encore vide : elle
            // grandissait ensuite vers le haut — AppKit ancre au coin bas gauche —
            // et se retrouvait n'importe où sauf sous la barre. D'où la mise en
            // page forcée, doublée du replacement à chaque redimensionnement :
            // changer d'onglet change aussi la hauteur.
            window.layoutIfNeeded()
            position(window)
        }

        // L'app tourne en accessory : sans activation explicite, la fenêtre
        // s'ouvrirait derrière le jeu.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func windowResized() {
        guard placing, let window else { return }
        position(window)
    }

    @objc private func windowMoved() {
        guard !repositioning else { return }
        placing = false
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

        repositioning = true
        window.setFrameOrigin(origin)
        // `didMove` peut arriver au tour de boucle suivant : on ne relâche le
        // drapeau qu'une fois la notification passée.
        DispatchQueue.main.async { self.repositioning = false }
    }

    /// Écart entre la barre et le haut de la fenêtre de réglages.
    private static let gap: CGFloat = 12
}
