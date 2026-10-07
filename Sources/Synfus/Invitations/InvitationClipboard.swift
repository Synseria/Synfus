import AppKit

/// Les invitations par presse-papiers : tient le curseur du tour et pose le
/// texte. Tout ce qui décide est dans `InvitationComposer` ; ici, l'état de
/// session et le retour visuel de la barre.
@MainActor
final class InvitationClipboard: ObservableObject {
    static let shared = InvitationClipboard()

    /// `slotKey` des pastilles dont l'invitation vient d'être copiée — la
    /// barre les marque le temps de `dureeSignal`, puis les oublie.
    @Published private(set) var copiesRecentes: Set<String> = []

    /// Le chef du tour en cours — fixé au premier appui, relâché au dernier
    /// invité ou s'il quitte l'effectif. Cf. `InvitationComposer`.
    private var chefPID: pid_t?
    private var tourEnCours = false
    private var precedents: [String] = []
    private var curseur: Int?
    private var effacement: Task<Void, Never>?
    private static let dureeSignal: Duration = .seconds(1.2)

    private init() {}

    /// Le raccourci : toutes les invitations d'un coup (`inviteGroupee`), ou
    /// celle du prochain perso de l'effectif — sans le chef, celui qui est
    /// devant —, en tournant à chaque appui.
    func copierSuivante() {
        let manager = WindowManager.shared
        if Preferences.shared.inviteGroupee {
            copierTout(manager)
            return
        }
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
        signaler(manager.effectif.filter { WindowTitle.characterName(fromTitle: $0.rawTitle) == nom })
    }

    /// Sans tour : le chef est celui qui est devant, à chaque appui.
    private func copierTout(_ manager: WindowManager) {
        tourEnCours = false
        let candidats = InvitationComposer.candidats(manager.effectif, chefPID: manager.frontmostPID)
        guard let texte = InvitationComposer.groupee(format: Preferences.shared.inviteFormat, noms: candidats)
        else {
            NSSound.beep()
            return
        }
        PressePapiers.copier(texte)
        signaler(manager.effectif.filter {
            candidats.contains(WindowTitle.characterName(fromTitle: $0.rawTitle))
        })
    }

    /// Le clic droit : l'invitation de ce perso-là, sans toucher au tour.
    func copier(_ client: DofusClient) {
        poser(nom: WindowTitle.characterName(fromTitle: client.rawTitle))
        signaler([client])
    }

    private func poser(nom: String) {
        PressePapiers.copier(InvitationComposer.commande(format: Preferences.shared.inviteFormat, nom: nom))
    }

    private func signaler(_ clients: [DofusClient]) {
        effacement?.cancel()
        copiesRecentes = Set(clients.map(\.slotKey))
        effacement = Task {
            try? await Task.sleep(for: Self.dureeSignal)
            guard !Task.isCancelled else { return }
            copiesRecentes = []
        }
    }
}
