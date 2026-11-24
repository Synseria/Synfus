import AppKit
import SwiftUI

/// Un panneau qui prend le clavier sans activer Synfus : on y tape l'indice
/// et le jeu reste l'app active — un clic dans le jeu lui rend la frappe.
/// Les flèches du clavier y choisissent la direction, jusque dans le champ
/// de l'indice (une ligne courte, le curseur n'y sert guère) ; Échap ferme.
/// Plié, les flèches ne choisissent plus rien : la direction changerait sans se voir.
private final class PanneauChasse: PanneauDeJeu {
    override var canBecomeKey: Bool { true }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            if !PanneauxJeu.plie(.chasse), let direction = Direction(toucheFleche: event.keyCode) {
                Chasses.shared.courant.choisir(direction)
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

    /// Ouvert, il se montre déplié : on l'ouvre pour s'en servir.
    func ouvrir() {
        if PanneauxJeu.plie(.chasse) { basculerPliage() }
        let panel = panel ?? construire()
        PanneauxJeu.rattraper(panel, parDefaut: Self.placeParDefaut)
        panel.makeKeyAndOrderFront(nil)
        if !ouvert { UsageStore.shared.compter(.chasse) }
        ouvert = true
        Chasses.shared.ouvrir()
    }

    /// Le panneau suit sa vue, bandeau seul ou entière ; `PanneauDeJeu` en garde le haut.
    func basculerPliage() {
        PanneauxJeu.basculerPliage(.chasse, hauteur: panel?.frame.height ?? 0)
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
            if force || !panel.isVisible {
                PanneauxJeu.rattraper(panel, parDefaut: Self.placeParDefaut)
                panel.orderFrontRegardless()
            }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    func windowWillClose(_: Notification) {
        ouvert = false
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: ChasseRacine().racineSynfus())
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
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        if !panel.setFrameAutosaveName("ChassePanel") || panel.frame.origin == .zero {
            PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut)
        }
        self.panel = panel
        return panel
    }

    /// Au centre de l'écran.
    private static let placeParDefaut: PanneauxJeu.PlaceParDefaut = { zone, taille in
        NSPoint(x: zone.midX - taille.width / 2, y: zone.midY + taille.height / 2)
    }

    /// Le panneau ouvert reprend sa place d'origine.
    func recentrer() {
        if ouvert, let panel { PanneauxJeu.placer(panel, parDefaut: Self.placeParDefaut) }
    }
}
