import SwiftUI

/// Onglet Palette : son raccourci, son bouton dans la barre, son tri.
struct PaletteSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.palette"), sousTitre: L("palette.reglages.sousTitre")) {
            Section {
                RaccourciReglable(label: L("raccourcis.palette"), help: L("raccourcis.palette.aide"),
                                  chemin: \.paletteHotKey)
                Interrupteur(titre: L("zaap.bouton"), isOn: $prefs.zaapBouton)
                Ligne(titre: L("palette.reglages.tri"), sousTexte: L("palette.reglages.tri.sousTexte")) {
                    Picker(L("palette.reglages.tri"), selection: $prefs.paletteTri) {
                        ForEach(TriPalette.allCases, id: \.self) { Text($0.titre).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
            }
        }
    }
}
