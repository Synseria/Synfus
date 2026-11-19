import AppKit
import SwiftUI

/// « À propos de Synfus » : le gabarit de la trousse — l'icône de l'app, son nom, « by » et le signe
/// Synseria —, puis la version et l'état de la mise à jour avec son geste.
struct AProposVue: View {
    var version = AppIntegrity.version
    private let miseAJour = MiseAJour.shared
    @ObservedObject private var prefs = Preferences.shared

    /// L'emblème de la marque, tel que `marque/` du SDS le dessine pour Synfus.
    private static let embleme: Image = {
        guard let url = Ressources.url("synseria-embleme-synfus.svg"), let image = NSImage(contentsOf: url) else {
            return Image(systemName: "circle.fill")
        }
        return Image(nsImage: image)
    }()

    var body: some View {
        GabaritAPropos(icone: Image(nsImage: icone), nom: AppIntegrity.displayName,
                       embleme: Self.embleme) {
            // L'état et son geste sur une ligne ; trop longs (une erreur), l'un sous l'autre.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Jetons.espace2) { etat; ActionMiseAJour(rechercher: L("maj.rechercherUne")) }
                VStack(spacing: Jetons.espace2) { etat; ActionMiseAJour(rechercher: L("maj.rechercherUne")) }
            }
        }
        .background(Color.jeton(\.fondFenetre))
    }

    /// L'icône choisie (Réglages ▸ Général), celle du Finder et des alertes.
    private var icone: NSImage {
        prefs.iconeApp == .duBundle ? NSApp.applicationIconImage : IconeAppliquee.vignette(prefs.iconeApp, cote: Jetons.espace7 * 2)
    }

    @ViewBuilder
    private var etat: some View {
        if let etat = MiseAJour.resume(version: version, etat: miseAJour.etat, verifiee: prefs.derniereVerificationMaj) {
            LigneDeVersion(texte: etat)
        }
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
