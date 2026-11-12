import AppKit
import SwiftUI

/// « À propos de Synfus » : le signe Synseria, la version et l'état de la mise à jour.
struct AProposVue: View {
    @ObservedObject private var miseAJour = MiseAJour.shared

    var body: some View {
        VStack(spacing: Jetons.Espace.quatre) {
            SigneSynseria(hauteur: 44)
            VStack(spacing: Jetons.Espace.deux) {
                Text(AppIntegrity.displayName).font(Jetons.Typo.corpsFort.police).foregroundStyle(Color.jeton(\.encre))
                if let etat = miseAJour.etat.libelle {
                    Text(etat).font(Jetons.Typo.note.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                        .multilineTextAlignment(.center)
                }
            }
            ActionMiseAJour()
        }
        .padding(Jetons.Espace.six)
        .frame(width: 340)
        .background(Color.jeton(\.fenetre))
    }
}

/// La fenêtre unique de « À propos » : rouverte, elle revient devant au lieu de se doubler.
@MainActor
final class AProposController {
    static let shared = AProposController()
    private var fenetre: NSWindow?

    func afficher() {
        if fenetre == nil {
            let nouvelle = NSWindow(contentViewController: NSHostingController(rootView: AProposVue().racineSynfus()))
            nouvelle.styleMask = [.titled, .closable]
            nouvelle.title = L("apropos.titre")
            nouvelle.isReleasedWhenClosed = false
            nouvelle.center()
            fenetre = nouvelle
        }
        NSApp.activate(ignoringOtherApps: true)
        fenetre?.makeKeyAndOrderFront(nil)
    }
}
