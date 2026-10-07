import SwiftUI

/// Onglet Raccourcis : rien que des combinaisons, une par ligne.
struct ShortcutsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var hotKeys = HotKeyManager.shared

    /// Les combinaisons données deux fois : le système n'en enregistre qu'une,
    /// et l'autre ligne restait affichée comme si elle marchait.
    private var doublons: Set<HotKey> {
        HotKeyConflicts.doublons(prefs.raccourcisGlobaux)
    }

    private func enConflit(_ hotKey: HotKey?) -> Bool {
        hotKey.map(doublons.contains) ?? false
    }

    var body: some View {
        PageReglages(titre: L("reglages.raccourcis"), sousTitre: L("raccourcis.sousTitre")) {
            Section {
                ForEach(0..<prefs.slotCount, id: \.self) { slot in
                    ShortcutRow(label: L("raccourcis.perso", slot + 1), detail: nameForSlot(slot),
                                conflit: enConflit(slot < prefs.hotKeys.count ? prefs.hotKeys[slot] : nil),
                                hotKey: binding(forSlot: slot))
                }
                Ligne(titre: L("raccourcis.emplacements")) {
                    Stepper("\(prefs.slotCount)",
                            value: Binding(get: { prefs.slotCount }, set: { prefs.slotCount = $0; rebind() }),
                            in: 1...10)
                }
            } header: {
                SectionTitle(L("raccourcis.allerAUnPerso"), help: L("raccourcis.allerAUnPerso.aide"))
            }

            Section {
                RaccourciReglable(label: L("raccourcis.persoSuivant"), chemin: \.cycleNext)
                RaccourciReglable(label: L("raccourcis.persoPrecedent"), chemin: \.cyclePrevious)
                RaccourciReglable(label: L("raccourcis.afficherMasquerBarre"), chemin: \.toggleBar)
                RaccourciReglable(label: L("raccourcis.voirTous"), help: L("raccourcis.voirTous.aide"),
                                  chemin: \.previewHotKey) { valeur in
                    if valeur != nil, !WindowPreviewService.shared.authorized {
                        WindowPreviewService.shared.requestAuthorization()
                    }
                }
                Interrupteur(titre: L("raccourcis.signalerBascule"), aide: L("raccourcis.signalerBascule.aide"),
                             isOn: $prefs.signalerBascule)
            } header: {
                SectionTitle(L("raccourcis.naviguer"))
            }

            Section {
                RaccourciReglable(label: L("raccourcis.ranger"), help: L("raccourcis.ranger.aide"), chemin: \.arrangeHotKey)
                RaccourciReglable(label: L("raccourcis.lancerSession"), help: L("raccourcis.lancerSession.aide"), chemin: \.sessionHotKey)
                if !prefs.equipes.isEmpty {
                    RaccourciReglable(label: L("raccourcis.equipeSuivante"), help: L("raccourcis.equipeSuivante.aide"), chemin: \.equipeSuivanteHotKey)
                }
            } header: {
                SectionTitle(L("raccourcis.fenetres"))
            }

            Section {
                if !hotKeys.rejected.isEmpty {
                    Avertissement(texte: L("raccourcis.refusees",
                                           hotKeys.rejected.map(\.displayString).joined(separator: ", ")))
                }
                Ligne(titre: L("raccourcis.retablir.titre")) {
                    Button(L("raccourcis.retablir")) {
                        prefs.resetShortcuts()
                        rebind()
                    }
                }
            }
        }
    }

    // MARK: - Utilitaires

    private func binding(forSlot slot: Int) -> Binding<HotKey?> {
        Binding(
            get: { slot < prefs.hotKeys.count ? prefs.hotKeys[slot] : nil },
            set: { newValue in
                guard slot < prefs.hotKeys.count else { return }
                prefs.hotKeys[slot] = newValue
                rebind()
            }
        )
    }

    private func rebind() { HotKeyManager.shared.rebind() }

    private func nameForSlot(_ slot: Int) -> String {
        slot < manager.effectif.count ? manager.effectif[slot].name : "—"
    }
}
