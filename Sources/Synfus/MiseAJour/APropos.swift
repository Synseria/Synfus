import AppKit
import SwiftUI

/// « À propos de Synfus » : le signe Synseria, la version et l'état de la mise à jour.
struct AProposVue: View {
    var version = AppIntegrity.version
    @ObservedObject private var miseAJour = MiseAJour.shared
    @ObservedObject private var prefs = Preferences.shared

    /// L'emblème de la marque, tel que `marque/` du SDS le dessine pour Synfus.
    private static let embleme: Image = {
        guard let url = Ressources.url("synseria-embleme-synfus.svg"), let image = NSImage(contentsOf: url) else {
            return Image(systemName: "circle.fill")
        }
        return Image(nsImage: image)
    }()

    var body: some View {
        VStack(spacing: Jetons.espace4) {
            SigneSynseria(embleme: Self.embleme, hauteur: Jetons.espace7)
            VStack(spacing: Jetons.espace2) {
                Text(AppIntegrity.displayName).font(Jetons.typoTitreCarte.font).foregroundStyle(Color.jeton(\.encre))
                if let etat = MiseAJour.resume(version: version, etat: miseAJour.etat,
                                               verifiee: prefs.derniereVerificationMaj) {
                    Text(etat).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
                        .multilineTextAlignment(.center)
                        .textSelection(.enabled)
                }
            }
            ActionMiseAJour(rechercher: L("maj.rechercherUne"))
        }
        .padding(Jetons.espace5)
        .frame(width: Jetons.largeurApropos)
        .background(Color.jeton(\.fondFenetre))
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
