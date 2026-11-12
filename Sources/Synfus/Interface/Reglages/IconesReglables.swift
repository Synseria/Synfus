import SwiftUI

/// Les deux icônes : celle de l'app (Finder, alertes) et celle de la barre de menus.
struct IconesReglables: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Ligne(titre: L("general.iconeApp"), aide: L("general.iconeApp.aide")) {
            ChoixIconeApp(choix: Binding(
                get: { prefs.iconeApp },
                set: { prefs.iconeApp = $0; IconeAppliquee.appliquer($0) }
            ))
        }
        Ligne(titre: L("general.icone")) {
            Picker(L("general.icone"), selection: Binding(
                get: { prefs.menuBarIcon },
                set: { prefs.menuBarIcon = $0; MenuBarController.shared.refreshIcon() }
            )) {
                ForEach(MenuBarIcon.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// Les huit icônes de l'app, un motif par ligne, un fond par colonne : chacune
/// est son propre aperçu, la choisie teintée.
private struct ChoixIconeApp: View {
    @Binding var choix: IconeApp
    private let cote = Jetons.Espace.dix

    var body: some View {
        Grid(horizontalSpacing: Jetons.Espace.un, verticalSpacing: Jetons.Espace.un) {
            ForEach(IconeApp.Motif.allCases, id: \.self) { motif in
                GridRow {
                    ForEach(IconeApp.Fond.allCases, id: \.self) { fond in
                        vignette(IconeApp(motif: motif, fond: fond))
                    }
                }
            }
        }
    }

    private func vignette(_ icone: IconeApp) -> some View {
        Button { choix = icone } label: {
            Image(nsImage: IconeAppliquee.vignette(icone, cote: cote))
                .padding(Jetons.Espace.un)
        }
        .buttonStyle(.etat(choisi: icone == choix, nue: true))
        .aide(L("general.iconeApp.vignette", icone.motif.nom, icone.fond.nom))
        .accessibilityAddTraits(icone == choix ? .isSelected : [])
    }
}

private extension IconeApp.Motif {
    var nom: String {
        switch self {
        case .oeuf: L("general.iconeApp.oeuf")
        case .couvee: L("general.iconeApp.couvee")
        }
    }
}

private extension IconeApp.Fond {
    var nom: String {
        switch self {
        case .nuit: L("general.iconeApp.nuit")
        case .foret: L("general.iconeApp.foret")
        case .aube: L("general.iconeApp.aube")
        case .transparent: L("general.iconeApp.transparent")
        }
    }
}
