import SwiftUI

/// Le bloc « Chasse au trésor » de l'onglet Zaap : ouvrir le panneau, son
/// raccourci, son bouton dans la barre, et la liste des indices de DofusDB.
struct ChasseSection: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var modele = ChasseModele.shared

    var body: some View {
        Section {
            ShortcutRow(label: L("chasse.raccourci"),
                        conflit: prefs.chasseHotKey.map(HotKeyConflicts.doublons(prefs.raccourcisGlobaux).contains) ?? false,
                        hotKey: Binding(get: { prefs.chasseHotKey },
                                        set: { prefs.chasseHotKey = $0; HotKeyManager.shared.rebind() }))
            Toggle(L("chasse.bouton"), isOn: $prefs.chasseBouton)
            HStack(spacing: 8) {
                Text(source)
                    .font(.system(size: 11))
                    .foregroundStyle(modele.echecIndices == nil ? Color.secondary : Color.orange)
                    .textSelection(.enabled)
                Spacer()
                if modele.chargementIndices { ProgressView().controlSize(.small) }
                Button(L("chasse.indices.maj")) { Task { await modele.chargerIndices(forcer: true) } }
                    .font(.system(size: 11))
                    .disabled(modele.chargementIndices)
                Button(L("chasse.ouvrir")) { ChassePanel.shared.ouvrir() }
                    .font(.system(size: 11))
            }
        } header: {
            SectionTitle(L("chasse.titre"), help: L("chasse.aide"))
        }
    }

    private var source: String {
        if let echec = modele.echecIndices { return L("chasse.indices.echec", echec) }
        guard let date = modele.dateIndices else { return L("chasse.indices.aucune") }
        return L("chasse.indices.date", modele.indices.count,
                 date.formatted(date: .abbreviated, time: .omitted))
    }
}
