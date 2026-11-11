import AppKit
import SwiftUI

/// Un panneau sans cadre qui prend le clavier sans activer Synfus : Dofus
/// reste l'app active, et le texte copié se colle dès la palette fermée.
/// Flèches, Entrée, Tab (filtre), Échap, ⌘E (étiquette), ⌘D (favori) et ⌘T
/// (tri) vont au modèle, le reste au champ — ← et → aussi, hors de la grille
/// et d'une fiche dépliée.
private final class PanneauPalette: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        let modificateurs = event.modifierFlags.intersection([.command, .option, .control, .shift])
        if event.type == .keyDown, modificateurs == .command, PaletteModele.shared.edition == nil {
            switch event.keyCode {
            case 14: return PaletteModele.shared.etiqueterSelection()   // ⌘E
            case 2: return PaletteModele.shared.favoriSelection()       // ⌘D
            case 17: return PaletteModele.shared.triSuivant()           // ⌘T
            default: break
            }
        }
        if event.type == .keyDown, event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            let modele = PaletteModele.shared
            let enEdition = modele.edition != nil
            switch event.keyCode {
            case 125 where !enEdition: return modele.deplacer(ligne: 1)
            case 126 where !enEdition: return modele.deplacer(ligne: -1)
            case 123 where !enEdition, 124 where !enEdition:
                let pas = event.keyCode == 123 ? -1 : 1
                if modele.enGrille { return modele.deplacer(colonne: pas) }
                if modele.lateral(pas) { return }
            case 36, 76: return modele.valider()
            case 48 where !enEdition: return modele.tabulation(arriere: event.modifierFlags.contains(.shift))
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

    /// `requete` : posée d'office, le curseur au bout pour la compléter ;
    /// sinon la recherche d'avant revient, toute sélectionnée.
    func ouvrir(requete: String? = nil) {
        let panel = panel ?? construire()
        PaletteModele.shared.ouvrir(requete: requete)
        UsageStore.shared.compter(.palette)
        placer(panel)
        panel.makeKeyAndOrderFront(nil)
        ouvert = true
        // La recherche d'avant revient toute sélectionnée : une lettre ou ⌫ la
        // remplace. Le champ a gardé le clavier depuis la fermeture.
        let champ = panel.firstResponder as? NSTextView
        requete == nil ? champ?.selectAll(nil) : champ?.moveToEndOfDocument(nil)
    }

    func fermer() {
        panel?.orderOut(nil)
        // La vignette survolée ne disparaît pas avec le panneau caché.
        ApercuCarte.shared.cacher()
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
        let hosting = NSHostingController(rootView: PaletteVue().racineSynfus())
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
