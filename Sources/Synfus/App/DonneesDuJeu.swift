import Foundation

/// Les données du jeu tirées de DofusDB — carte, cartes intérieures, quêtes,
/// classes — relues au lancement par leurs stores, puis revues chaque jour :
/// chacune se redemande si elle a passé `DofusDB.peremption`. Sans ce tour,
/// un Synfus jamais relancé garderait des données de plusieurs mois.
@MainActor
enum DonneesDuJeu {
    private static var minuterie: Timer?

    static func start() {
        guard minuterie == nil else { return }
        minuterie = Timer.scheduledTimer(withTimeInterval: 24 * 3600, repeats: true) { _ in
            MainActor.assumeIsolated { rafraichir() }
        }
        minuterie?.tolerance = 3600
    }

    private static func rafraichir() {
        CarteStore.shared.rafraichir()
        QuetesStore.shared.preparer()
        ClassesStore.shared.rafraichir()
    }
}
