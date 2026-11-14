import AppKit
import SwiftUI

/// Ce que partagent les panneaux posés sur le jeu — quêtes, chasse, aide aux
/// boss : quand ils se montrent, et les boutons de leur en-tête.
@MainActor
enum PanneauxJeu {
    /// Chaque panneau revoit s'il se montre — au changement d'app (`force`),
    /// par le filet de `WindowManager`, quand le réglage change. Le seul
    /// endroit qui les énumère : un panneau de plus ne s'oublie nulle part.
    static func revoir(force: Bool) {
        QuetePanel.shared.revoirVisibilite(force: force)
        ChassePanel.shared.revoirVisibilite(force: force)
        BossPanel.shared.revoirVisibilite(force: force)
    }

    /// Remet à leur place d'origine les panneaux ouverts, avec la barre : le geste du menu pour un
    /// panneau que rien ne ramène — sans bordure ni barre de titre, macOS ne le fait pas.
    static func recentrerBarreEtPanneaux() {
        FloatingBarController.shared.recenter()
        QuetePanel.shared.recentrer()
        ChassePanel.shared.recentrer()
        BossPanel.shared.recentrer()
    }

    // MARK: - Place d'un panneau

    /// Où paraît un panneau qui n'a pas de place gardée, ou que son écran a quittée : le coin haut
    /// gauche de son cadre, sur la zone visible de l'écran principal et pour sa taille.
    typealias PlaceParDefaut = (_ zoneVisible: NSRect, _ taille: NSSize) -> NSPoint

    /// La marge dont un point peut déborder d'un écran et compter encore dessus, et la taille du
    /// bandeau d'un panneau qui doit rester sur un écran pour rester saisissable.
    nonisolated private static let margeEcran: CGFloat = 40

    /// Un point est-il sur l'un des écrans ? La règle de la barre, qui évite de restaurer sa position
    /// sur un écran débranché depuis.
    nonisolated static func surUnEcran(_ point: CGPoint, ecrans: [CGRect]) -> Bool {
        ecrans.contains { $0.insetBy(dx: -margeEcran, dy: -margeEcran).contains(point) }
    }

    static func surUnEcran(_ point: CGPoint) -> Bool {
        surUnEcran(point, ecrans: NSScreen.screens.map(\.frame))
    }

    /// Un panneau se tient par son bandeau, en haut : il est atteignable tant qu'une part de ce
    /// bandeau — au moins la marge de large — reste sur un écran, même poussé à moitié hors de l'autre.
    nonisolated static func bandeauAtteignable(de cadre: NSRect, ecrans: [CGRect]) -> Bool {
        let bandeau = CGRect(x: cadre.minX, y: cadre.maxY - margeEcran, width: cadre.width, height: margeEcran)
        return ecrans.contains {
            let commun = $0.intersection(bandeau)
            return !commun.isNull && commun.width >= margeEcran && commun.height >= margeEcran / 2
        }
    }

    /// Pose le panneau à sa place d'origine.
    static func placer(_ panel: NSPanel, parDefaut: PlaceParDefaut) {
        guard let zone = NSScreen.main?.visibleFrame else { return }
        panel.setFrameTopLeftPoint(parDefaut(zone, panel.frame.size))
    }

    /// Un panneau dont le bandeau n'est sur aucun écran — l'écran où il était est débranché — reprend
    /// sa place d'origine ; un autre reste où il est.
    static func rattraper(_ panel: NSPanel, parDefaut: PlaceParDefaut) {
        if !bandeauAtteignable(de: panel.frame, ecrans: NSScreen.screens.map(\.frame)) {
            placer(panel, parDefaut: parDefaut)
        }
    }

    /// Montre ou cache un panneau voulu `ouvert` : devant Dofus (`visible`),
    /// ou `impose` — ouvert depuis une autre app (menu, bouton de la barre),
    /// il reste là jusqu'au prochain changement d'app plutôt que de ne pas
    /// paraître. Construit à sa première apparition, rattrapé s'il paraît hors
    /// de tout écran ; `cache` suit le masquage d'un panneau qui était à
    /// l'écran. Rend s'il est montré.
    @discardableResult
    static func appliquer(_ panel: inout NSPanel?, ouvert: Bool, impose: Bool, force: Bool,
                          parDefaut: PlaceParDefaut, construire: () -> NSPanel, cache: () -> Void = {}) -> Bool {
        let montre = visible(ouvert: ouvert) || (ouvert && impose)
        if montre {
            let affiche = panel ?? construire()
            panel = affiche
            if force || !affiche.isVisible {
                rattraper(affiche, parDefaut: parDefaut)
                affiche.orderFrontRegardless()
            }
        } else if let panel, panel.isVisible {
            panel.orderOut(nil)
            cache()
        }
        return montre
    }

    /// Un panneau ouvert se montre-t-il ? Avec `panneauxSeulementDofus`,
    /// seulement devant Dofus (ou Synfus) : la règle de la barre réservée au
    /// jeu, sur `frontmostPID` — `NSWorkspace` a un tour de retard.
    static func visible(ouvert: Bool) -> Bool {
        let manager = WindowManager.shared
        return FloatingBarController.computeVisibility(
            barVisible: ouvert, onlyWithDofus: Preferences.shared.panneauxSeulementDofus,
            frontPID: manager.frontmostPID, frontIsDofus: manager.frontmostIsDofus,
            ownPID: ProcessInfo.processInfo.processIdentifier)
    }
}

/// Un bouton d'icône d'un panneau : une cible de 24 pt, quelle que soit l'icône, au même dessin partout.
/// `copie` : l'icône devient la coche de copie le temps du signal (`IconeCopie`) ; `discret` : encre
/// secondaire au repos, pleine au survol.
struct BoutonEnTete: View {
    let icone: String
    let aide: String
    var copie = false
    var discret = false
    let action: () -> Void
    @State private var survole = false

    var body: some View {
        Button(action: action) {
            IconeCopie(icone: icone, copie: copie)
                .font(Jetons.Typo.raccourci.police)
                .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
                .foregroundStyle(discret && !survole ? Color.jeton(\.encreSecondaire) : Color.jeton(\.encre))
        }
        .buttonStyle(.etat(nue: true))
        .onHover { survole = $0 }
        .aide(aide)
    }
}

/// L'en-tête d'une ligne d'un panneau posé sur le jeu : l'icône, le titre,
/// l'espace libre, les boutons. Tout, sauf les boutons, déplace le panneau ;
/// avec `menu`, un clic sur le titre l'ouvre et seul un glisser le déplace
/// (`WindowDragArea`). La zone est posée par-dessus l'icône et le titre — une
/// image ou un texte au-dessus d'une `NSView` lui prennent le clic — et jamais
/// sur un bouton, qu'elle priverait du sien.
struct EnTetePanneau<Titre: View, Boutons: View>: View {
    let icone: String
    let teinte: Color
    /// Le menu qu'ouvre un clic sur le titre.
    var menu: (@MainActor () -> NSMenu)?
    @ViewBuilder let titre: Titre
    @ViewBuilder let boutons: Boutons

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: icone)
                .foregroundStyle(teinte)
                .padding(.leading, Jetons.Espace.deux)
                .padding(.trailing, Jetons.Espace.un)
                .frame(maxHeight: .infinity)
                .overlay(WindowDragArea())
            // Le titre d'abord : sans priorité, la zone de glisser, flexible
            // elle aussi, lui prenait la moitié de la place et le tronquait.
            // Une seule zone sur tout le titre, indicateur de lecture compris :
            // le menu s'ouvre sous son bord gauche.
            HStack(spacing: 0) { titre }
                .frame(maxHeight: .infinity)
                .overlay(WindowDragArea(menu: menu))
                .layoutPriority(1)
            WindowDragArea().frame(minWidth: 4, maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: Jetons.Espace.un) { boutons }
                .padding(.vertical, Jetons.Espace.un)
        }
        .padding(.trailing, Jetons.Espace.un)
        .font(Jetons.Typo.note.police)
        // Les zones de glisser prennent la hauteur des boutons, sans tirer
        // l'en-tête vers le bas.
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// Les éléments du menu portent leur action (`representedObject`) : le menu
/// se reconstruit à chaque ouverture, une cible commune les déclenche.
@MainActor
final class CibleMenu: NSObject {
    static let shared = CibleMenu()

    private final class Action {
        let agir: @MainActor () -> Void
        init(_ agir: @escaping @MainActor () -> Void) { self.agir = agir }
    }

    func element(_ titre: String, raccourci: HotKey? = nil, agir: @escaping @MainActor () -> Void) -> NSMenuItem {
        let item = NSMenuItem(title: titre, action: #selector(declencher(_:)), keyEquivalent: "")
        item.target = self
        item.afficher(raccourci)
        item.representedObject = Action(agir)
        return item
    }

    @objc private func declencher(_ item: NSMenuItem) {
        (item.representedObject as? Action)?.agir()
    }
}
