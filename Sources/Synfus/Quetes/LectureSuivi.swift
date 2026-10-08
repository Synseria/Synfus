import Foundation

/// Le suivi de quêtes du jeu, lu à la demande pour le panneau des quêtes :
/// au bouton « Lire le suivi » et à l'ouverture du panneau. Jamais au tour —
/// le suivi ne change que de la main du joueur.
@MainActor
final class LectureSuivi: ObservableObject {
    static let shared = LectureSuivi()

    enum Etat: Equatable {
        case jamaisLu
        case enCours
        /// Aucun perso à capturer, ou l'enregistrement de l'écran refusé.
        case illisible
        /// Les quêtes ne sont pas encore téléchargées.
        case sansQuetes
        case lu
    }

    @Published private(set) var reconnues: [SuiviQuetes.Reconnue] = []
    @Published private(set) var etat: Etat = .jamaisLu

    private init() {}

    func lire() {
        guard etat != .enCours else { return }
        etat = .enCours
        Task {
            guard let lignes = await LecteurEcran.shared.lireUneFois(.quetes) else { etat = .illisible; return }
            guard let quetes = await QuetesStore.shared.chargees() else { etat = .sansQuetes; return }
            // Deux mille noms dans trois langues, comparés à chaque ligne :
            // hors du main actor.
            reconnues = await Task.detached { SuiviQuetes.reconnaitre(lignes, dans: quetes) }.value
            etat = .lu
        }
    }

    /// Épingle la quête et la montre, à l'étape que le suivi désigne.
    func choisir(_ reconnue: SuiviQuetes.Reconnue) {
        if let etape = reconnue.etape { Preferences.shared.quetesEtape[String(reconnue.id)] = etape }
        QuetePanel.shared.ouvrir(reconnue.id)
    }
}
