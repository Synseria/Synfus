import SwiftUI

/// Onglet Invitations : le raccourci qui copie les `/invite`, et leur forme.
struct InvitationsSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.invitations"), sousTitre: L("invitations.sousTitre"),
                     aide: L("raccourcis.inviter.aide")) {
            Section {
                RaccourciReglable(
                    label: prefs.inviteGroupee ? L("raccourcis.invitation.toutes") : L("raccourcis.invitation"),
                    help: prefs.inviteGroupee ? L("raccourcis.invitation.toutes.aide") : L("raccourcis.invitation.aide"),
                    chemin: \.inviteHotKey)
                Interrupteur(titre: L("raccourcis.invitation.groupee"), isOn: $prefs.inviteGroupee)
                Ligne(titre: L("raccourcis.invitation.format"), aide: L("raccourcis.invitation.format.aide")) {
                    TextField(L("raccourcis.invitation.format"), text: $prefs.inviteFormat)
                        .labelsHidden()
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 180)
                }
            }
        }
    }
}
