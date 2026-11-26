import AppKit
import SwiftUI
import SynseriaDesign

/// « À propos de Synfus » : le gabarit de la trousse — l'icône de l'app, son nom, « by » et le signe
/// Synseria —, puis la ligne de mise à jour commune, en colonne.
struct AProposVue: View {
    /// La version montrée : celle du bundle ; les captures fixent la leur.
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
        GabaritAPropos(icone: Image(nsImage: icone), nom: AppIntegrity.displayName, embleme: Self.embleme) {
            LigneDeMiseAJour(miseAJour: ligne, libelles: SettingsView.libelles, disposition: .colonne)
        }
        .background(Color.jeton(\.fondFenetre))
    }

    private var ligne: MiseAJourDesReglages {
        var ligne = miseAJour.reglages
        ligne.version = version ?? ligne.version
        return ligne
    }

    /// L'icône choisie (Réglages ▸ Général), celle du Finder et des alertes.
    private var icone: NSImage {
        prefs.iconeApp == .duBundle ? NSApp.applicationIconImage : IconeAppliquee.vignette(prefs.iconeApp, cote: Jetons.espace7 * 2)
    }
}

/// La fenêtre unique de « À propos » : rouverte, elle revient devant au lieu de se doubler. Le haut
/// laisse la rangée des feux, le contenu monte sous la barre de titre.
@MainActor
final class AProposController {
    static let shared = AProposController()
    private var fenetre: NSWindow?

    func afficher() {
        if fenetre == nil {
            let nouvelle = NSWindow(contentViewController: NSHostingController(rootView: AProposVue().racineSynfus()))
            nouvelle.styleMask = [.titled, .closable, .fullSizeContentView]
            nouvelle.titlebarAppearsTransparent = true
            nouvelle.titleVisibility = .hidden
            nouvelle.title = SettingsView.libelles.aPropos.replacingOccurrences(of: "%@", with: AppIntegrity.displayName)
            nouvelle.isReleasedWhenClosed = false
            nouvelle.center()
            fenetre = nouvelle
        }
        NSApp.activate(ignoringOtherApps: true)
        fenetre?.makeKeyAndOrderFront(nil)
    }
}
