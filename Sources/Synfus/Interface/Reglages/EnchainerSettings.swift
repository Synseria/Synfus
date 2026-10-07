import SwiftUI

/// Onglet Enchaîner : passer au perso suivant après un clic, touche tenue.
struct EnchainerSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared

    var body: some View {
        PageReglages(titre: L("reglages.enchainer"), sousTitre: L("enchainer.sousTitre"),
                     aide: L("raccourcis.enchainer.aide")) {
            Section {
                Interrupteur(titre: L("raccourcis.enchainer.bascule"), isOn: Binding(
                    get: { prefs.advanceOnClick },
                    set: { prefs.advanceOnClick = $0; ClickAdvanceWatcher.shared.apply() }
                ))
                if prefs.advanceOnClick {
                    Ligne(titre: L("raccourcis.enchainer.touche"), aide: L("raccourcis.enchainer.touche.aide")) {
                        Picker(L("raccourcis.enchainer.touche"), selection: $prefs.advanceModifier) {
                            ForEach(ClickModifier.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                    Ligne(titre: L("raccourcis.enchainer.clicsCaptes"),
                          sousTexte: clicks.lastModifiers.map { L("raccourcis.enchainer.dernierClic", $0) },
                          aide: clicks.seenClicks == 0 ? L("raccourcis.enchainer.clicsCaptes.aide") : nil) {
                        Text("\(clicks.seenClicks)")
                            .monospacedDigit()
                            .foregroundStyle(clicks.seenClicks == 0 ? Color.orange : Color.secondary)
                    }
                }
            }
        }
    }
}
