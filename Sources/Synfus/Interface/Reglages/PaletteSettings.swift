import SwiftUI

/// Onglet Palette : son raccourci, son tri, et les invitations qu'elle copie.
struct PaletteSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.palette")) {
            Bloc {
                RaccourciReglable(label: L("raccourcis.palette"), help: L("raccourcis.palette.aide"),
                                  chemin: \.paletteHotKey)
                Ligne(titre: L("palette.reglages.tri"), aide: L("palette.reglages.tri.aide")) {
                    Picker(L("palette.reglages.tri"), selection: $prefs.paletteTri) {
                        ForEach(TriPalette.allCases, id: \.self) { Text($0.titre).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                InterrupteurVuesCartes()
            }
            Bloc(L("reglages.invitations")) {
                RaccourciReglable(
                    label: prefs.inviteGroupee ? L("raccourcis.invitation.toutes") : L("raccourcis.invitation"),
                    help: prefs.inviteGroupee ? L("raccourcis.invitation.toutes.aide") : L("raccourcis.invitation.aide"),
                    chemin: \.inviteHotKey)
                Interrupteur(titre: L("raccourcis.invitation.groupee"), aide: L("raccourcis.inviter.aide"),
                             isOn: $prefs.inviteGroupee)
                Ligne(titre: L("raccourcis.invitation.format"), aide: L("raccourcis.invitation.format.aide")) {
                    TextField(L("raccourcis.invitation.format"), text: $prefs.inviteFormat)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(Jetons.Typo.codeInterface.police)
                        .frame(width: 180)
                }
            }
        }
    }
}
