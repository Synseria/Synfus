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
