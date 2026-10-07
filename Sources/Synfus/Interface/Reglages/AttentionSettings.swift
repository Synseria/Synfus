import SwiftUI

/// Onglet Attention : que faire quand un perso réclame la main.
struct AttentionSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.attention"), sousTitre: L("raccourcis.attention")) {
            Section {
                Ligne(titre: L("raccourcis.attention.reaction"),
                      sousTexte: prefs.attentionAction.explanation, aide: L("raccourcis.attention.aide")) {
                    Picker(L("raccourcis.attention.reaction"), selection: $prefs.attentionAction) {
                        ForEach(AttentionAction.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                RaccourciReglable(label: L("raccourcis.attention.bascule"), chemin: \.toggleAutoFocus)
            }
        }
    }
}
