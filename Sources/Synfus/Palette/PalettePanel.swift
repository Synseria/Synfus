import AppKit
import SwiftUI

/// Où est le caret du champ de recherche. Pur.
enum CaretPalette {
    /// Sans sélection, après le dernier caractère.
    static func auBout(longueur: Int, selection: NSRange) -> Bool {
        selection.length == 0 && selection.location >= longueur
    }
}

/// Un panneau sans cadre qui prend le clavier sans activer Synfus : Dofus
/// reste l'app active, et le texte copié se colle dès la palette fermée.
/// Flèches, Entrée, Tab (filtre), Échap, ⌘E (étiquette), ⌘D (favori) et ⌘T
/// (tri) vont au modèle, le reste au champ — ← et → aussi, hors de la grille
/// (onglets d'une fiche, positions d'un PNJ) ; → ne va au modèle que le caret au
/// bout du texte, sans sélection ni ⇧ : sinon il déplace le caret ou étend la sélection.
private final class PanneauPalette: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// → n'a plus rien à faire dans le champ : il ne ferait rien d'autre qu'aller à droite.
    private func caretAuBout(_ event: NSEvent) -> Bool {
        guard !event.modifierFlags.contains(.shift) else { return false }
        guard let champ = firstResponder as? NSTextView else { return true }
        return CaretPalette.auBout(longueur: (champ.string as NSString).length, selection: champ.selectedRange())
    }

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
                if modele.enCartes { return modele.deplacer(colonne: pas) }
                if pas < 0 || caretAuBout(event), modele.lateral(pas) { return }
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

    /// L'outil « Almanax » de la barre et du menu : la palette sur sa vue, ou fermée si elle y est.
    func basculerAlmanax() {
        if ouvert, PaletteModele.shared.surAlmanax { fermer() } else { ouvrir(vue: .almanax) }
    }

    /// `requete` : posée d'office, le curseur au bout pour la compléter ; `vue` : la vue d'arrivée,
    /// l'Accueil sinon.
    func ouvrir(vue: FiltrePalette = .tout) {
        let panel = panel ?? construire()
        PaletteModele.shared.ouvrir(vue: vue)
        UsageStore.shared.compter(.palette)
        placer(panel)
        panel.makeKeyAndOrderFront(nil)
        ouvert = true
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
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        self.panel = panel
        return panel
    }
}
