import SwiftUI

/// Onglet Chasse : ouvrir le panneau, son raccourci, son bouton dans la
/// barre, et la liste des indices de DofusDB.
struct ChasseSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var modele = ChasseModele.shared

    var body: some View {
        PageReglages(titre: L("chasse.titre"), sousTitre: L("chasse.sousTitre"),
                     aide: L("chasse.aide")) {
            Section {
                RaccourciReglable(label: L("chasse.raccourci"), chemin: \.chasseHotKey)
                Interrupteur(titre: L("chasse.bouton"), isOn: $prefs.chasseBouton)
                Ligne(titre: L("chasse.indices"), sousTexte: source) {
                    HStack(spacing: 8) {
                        if modele.chargementIndices { ProgressView().controlSize(.small) }
                        Button(L("chasse.indices.maj")) { Task { await modele.chargerIndices(forcer: true) } }
                            .disabled(modele.chargementIndices)
                        Button(L("chasse.ouvrir")) { ChassePanel.shared.ouvrir() }
                    }
                }
            }
        }
    }

    private var source: String {
        if let echec = modele.echecIndices { return L("chasse.indices.echec", echec) }
        guard let date = modele.dateIndices else { return L("chasse.indices.aucune") }
        return L("chasse.indices.date", modele.indices.count,
                 date.formatted(date: .abbreviated, time: .omitted))
    }
}
