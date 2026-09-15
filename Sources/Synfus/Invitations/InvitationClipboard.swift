import AppKit

/// Les invitations par presse-papiers : tient le curseur du tour et pose le
/// texte. Tout ce qui décide est dans `InvitationComposer` ; ici, l'état de
/// session et le retour visuel de la barre.
@MainActor
final class InvitationClipboard: ObservableObject {
    static let shared = InvitationClipboard()

    /// `slotKey` de la pastille dont l'invitation vient d'être copiée — la
    /// barre la marque le temps de `dureeSignal`, puis l'oublie.
    @Published private(set) var copieRecente: String?

    /// Le chef du tour en cours — fixé au premier appui, relâché au dernier
    /// invité ou s'il quitte l'effectif. Cf. `InvitationComposer`.
    private var chefPID: pid_t?
    private var tourEnCours = false
    private var precedents: [String] = []
    private var curseur: Int?
    private var effacement: Task<Void, Never>?
    private static let dureeSignal: Duration = .seconds(1.2)

    private init() {}

    /// Le raccourci : copie l'invitation du prochain perso de l'effectif —
    /// sans le chef, celui qui est devant —, et tourne à chaque appui.
    func copierSuivante() {
        let manager = WindowManager.shared
        if tourEnCours, let chef = chefPID, !manager.effectif.contains(where: { $0.pid == chef }) {
            tourEnCours = false
        }
        if !tourEnCours {
            chefPID = manager.frontmostPID
            curseur = nil
            tourEnCours = true
        }
        let candidats = InvitationComposer.candidats(manager.effectif, chefPID: chefPID)
        guard let (nom, index) = InvitationComposer.prochaine(
            candidats: candidats, precedents: precedents, curseur: curseur
        ) else {
            NSSound.beep()
            return
        }
        precedents = candidats
        curseur = index
        if InvitationComposer.tourTermine(curseur: index, nombre: candidats.count) { tourEnCours = false }
        poser(nom: nom)
        if let client = manager.effectif.first(where: {
            WindowTitle.characterName(fromTitle: $0.rawTitle) == nom
        }) {
            signaler(client.slotKey)
        }
    }

    /// Le clic droit : l'invitation de ce perso-là, sans toucher au tour.
    func copier(_ client: DofusClient) {
        poser(nom: WindowTitle.characterName(fromTitle: client.rawTitle))
        signaler(client.slotKey)
    }

    /// Le texte que le clic droit annonce, pour que le menu dise ce qu'il fera.
    func commande(pour client: DofusClient) -> String {
        InvitationComposer.commande(
            format: Preferences.shared.inviteFormat,
            nom: WindowTitle.characterName(fromTitle: client.rawTitle)
        )
    }

    private func poser(nom: String) {
        PressePapiers.copier(InvitationComposer.commande(format: Preferences.shared.inviteFormat, nom: nom))
    }

    private func signaler(_ slotKey: String) {
        effacement?.cancel()
        copieRecente = slotKey
        effacement = Task {
            try? await Task.sleep(for: Self.dureeSignal)
            guard !Task.isCancelled else { return }
            copieRecente = nil
        }
    }
}
