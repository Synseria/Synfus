import AppKit
import SwiftUI

/// Un panneau qui prend le clavier sans activer Synfus : on y tape l'indice
/// et le jeu reste l'app active — un clic dans le jeu lui rend la frappe.
/// Les flèches du clavier y choisissent la direction, jusque dans le champ
/// de l'indice (une ligne courte, le curseur n'y sert guère) ; Échap ferme.
private final class PanneauChasse: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            if let direction = Direction(toucheFleche: event.keyCode) {
                ChasseModele.shared.choisir(direction)
                return
            }
            if event.keyCode == 53 {
                ChassePanel.shared.fermer()
                return
            }
        }
        super.sendEvent(event)
    }
}

/// Ouvre et ferme le panneau de chasse : bouton de la barre, raccourci,
/// menu. Flottant au niveau de la barre, pour rester au-dessus d'un jeu en
/// plein écran ; sa position est gardée par AppKit (`frameAutosaveName`).
@MainActor
final class ChassePanel: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = ChassePanel()

    @Published private(set) var ouvert = false
    private var panel: NSPanel?

    private override init() { super.init() }

    func basculer() {
        ouvert ? fermer() : ouvrir()
    }

    func ouvrir() {
        let panel = panel ?? construire()
        panel.makeKeyAndOrderFront(nil)
        ouvert = true
        ChasseModele.shared.ouvrir()
    }

    func fermer() {
        panel?.orderOut(nil)
        ouvert = false
    }

    /// Ouvert, il se cache quand une autre app que Dofus passe devant et
    /// revient avec le jeu, sans reprendre le clavier (`PanneauxJeu`).
    func revoirVisibilite(force: Bool) {
        guard let panel, ouvert else { return }
        if PanneauxJeu.visible(ouvert: true) {
            if force || !panel.isVisible { panel.orderFrontRegardless() }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    func windowWillClose(_: Notification) {
        ouvert = false
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: ChasseVue())
        hosting.sizingOptions = [.preferredContentSize]
        let panel = PanneauChasse(
            contentRect: NSRect(x: 0, y: 0, width: 216, height: 360),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = false
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        if !panel.setFrameAutosaveName("ChassePanel") || panel.frame.origin == .zero { panel.center() }
        self.panel = panel
        return panel
    }
}
