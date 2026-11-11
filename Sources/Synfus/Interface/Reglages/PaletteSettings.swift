import SwiftUI

/// Onglet Palette : son raccourci, son tri.
struct PaletteSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.palette")) {
            Section {
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
        }
    }
}
