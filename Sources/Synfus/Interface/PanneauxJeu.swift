import AppKit
import SwiftUI

/// Ce que partagent les panneaux posés sur le jeu — quêtes et chasse : quand
/// ils se montrent, et les boutons de leur en-tête.
@MainActor
enum PanneauxJeu {
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

/// Un bouton d'en-tête de panneau : une cible de 22 pt, quelle que soit
/// l'icône, au même dessin partout.
struct BoutonEnTete: View {
    let icone: String
    let aide: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(aide)
    }
}

/// L'en-tête d'une ligne d'un panneau posé sur le jeu : l'icône, le titre,
/// l'espace libre, les boutons. Seuls l'icône et l'espace libre déplacent le
/// panneau : `WindowDragArea` est une `NSView`, et posée sous un bouton
/// SwiftUI d'un panneau jamais clé, c'est elle qui reçoit le clic.
struct EnTetePanneau<Titre: View, Boutons: View>: View {
    let icone: String
    let teinte: Color
    @ViewBuilder let titre: Titre
    @ViewBuilder let boutons: Boutons

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: icone)
                .foregroundStyle(teinte)
                .padding(.leading, 10)
                .padding(.trailing, 4)
                .frame(maxHeight: .infinity)
                .background(WindowDragArea())
            // Le titre d'abord : sans priorité, la zone de glisser, flexible
            // elle aussi, lui prenait la moitié de la place et le tronquait.
            titre.layoutPriority(1)
            WindowDragArea().frame(minWidth: 4, maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 4) { boutons }
                .padding(.vertical, 3)
        }
        .padding(.trailing, 4)
        .font(.system(size: 12))
        // Les zones de glisser prennent la hauteur des boutons, sans tirer
        // l'en-tête vers le bas.
        .fixedSize(horizontal: false, vertical: true)
    }
}
