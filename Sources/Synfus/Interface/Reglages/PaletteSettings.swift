import SwiftUI

/// Onglet Palette : son raccourci, son tri, et les invitations qu'elle copie.
struct PaletteSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages {
            Bloc {
                Ligne(titre: L("palette.reglages.tri"), aide: L("palette.reglages.tri.aide")) {
                    SegmenteTexte(titre: L("palette.reglages.tri"), options: TriPalette.allCases.map { ($0, $0.titre) },
                                  selection: $prefs.paletteTri)
                }
                InterrupteurVuesCartes()
            }
            Bloc(L("reglages.invitations")) {
                LigneInterrupteur(titre: L("raccourcis.invitation.groupee"), aide: L("raccourcis.inviter.aide"),
                             isOn: $prefs.inviteGroupee)
                Ligne(titre: L("raccourcis.invitation.format"), aide: L("raccourcis.invitation.format.aide")) {
                    TextField(L("raccourcis.invitation.format"), text: $prefs.inviteFormat)
                        .labelsHidden()
                        .textFieldStyle(.roundedBorder)
                        .font(Jetons.typoCode.font)
                        .frame(width: 180)
                }
            }
        }
    }
}
