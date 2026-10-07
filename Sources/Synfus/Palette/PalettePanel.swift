import AppKit
import SwiftUI

/// Un panneau sans cadre qui prend le clavier sans activer Synfus : Dofus
/// reste l'app active, et le texte copié se colle dès la palette fermée.
/// Flèches, Entrée, Tab et Échap vont au modèle, le reste au champ.
private final class PanneauPalette: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            let modele = PaletteModele.shared
            let enEdition = modele.edition != nil
            switch event.keyCode {
            case 125 where !enEdition: return modele.deplacer(ligne: 1)
            case 126 where !enEdition: return modele.deplacer(ligne: -1)
            case 123 where modele.enGrille && !enEdition: return modele.deplacer(colonne: -1)
            case 124 where modele.enGrille && !enEdition: return modele.deplacer(colonne: 1)
            case 36, 76: return modele.valider()
            case 48 where !enEdition: return modele.tabulation()
            case 53: return modele.echap()
            default: break
            }
        }
        super.sendEvent(event)
    }
}

/// Ouvre et ferme la palette : raccourci (⌘:), bouton de la barre, menu.
/// Centrée en haut de l'écran, au-dessus d'un jeu en plein écran ; elle se
/// ferme dès qu'elle perd le clavier.
@MainActor
final class PalettePanel: NSObject, ObservableObject, NSWindowDelegate {
    static let shared = PalettePanel()

    @Published private(set) var ouvert = false
    private var panel: NSPanel?

    static let largeur: CGFloat = 660

    private override init() { super.init() }

    func basculer() {
        ouvert ? fermer() : ouvrir()
    }

    func ouvrir() {
        let panel = panel ?? construire()
        PaletteModele.shared.ouvrir()
        placer(panel)
        panel.makeKeyAndOrderFront(nil)
        ouvert = true
    }

    func fermer() {
        panel?.orderOut(nil)
        ouvert = false
    }

    func windowDidResignKey(_: Notification) {
        fermer()
    }

    /// Le haut de l'écran de la souris, là où l'on regarde.
    private func placer(_ panel: NSPanel) {
        let souris = NSEvent.mouseLocation
        guard let ecran = NSScreen.screens.first(where: { $0.frame.contains(souris) }) ?? NSScreen.main else { return }
        let zone = ecran.visibleFrame
        let x = zone.midX - Self.largeur / 2
        let haut = zone.maxY - zone.height * 0.14
        panel.setFrameTopLeftPoint(NSPoint(x: x, y: haut))
    }

    private func construire() -> NSPanel {
        let hosting = NSHostingController(rootView: PaletteVue())
        hosting.sizingOptions = [.preferredContentSize]
        let panel = PanneauPalette(
            contentRect: NSRect(x: 0, y: 0, width: Self.largeur, height: 420),
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
        self.panel = panel
        return panel
    }
}
