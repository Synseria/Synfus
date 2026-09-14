import SwiftUI

/// Onglet Raccourcis : rien que des combinaisons, une par ligne.
struct ShortcutsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared

    var body: some View {
        Form {
            Section {
                ForEach(0..<prefs.slotCount, id: \.self) { slot in
                    ShortcutRow(label: "Perso \(slot + 1)", detail: nameForSlot(slot), hotKey: binding(forSlot: slot))
                }
                Stepper("Emplacements : \(prefs.slotCount)",
                        value: Binding(get: { prefs.slotCount }, set: { prefs.slotCount = $0; rebind() }),
                        in: 1...10)
            } header: {
                SectionTitle("Aller à un perso", help: "Les emplacements suivent l'ordre de l'onglet Persos ; "
                             + "les persos non connectés sont sautés, les numéros restent stables.")
            }

            Section {
                ShortcutRow(label: "Perso suivant", hotKey: hotKey(\.cycleNext))
                ShortcutRow(label: "Perso précédent", hotKey: hotKey(\.cyclePrevious))
                ShortcutRow(label: "Afficher / masquer la barre", hotKey: hotKey(\.toggleBar))
                ShortcutRow(label: "Voir tous les persos", help: "Les aperçus restent affichés tant que la "
                            + "combinaison est maintenue. Elle doit comporter un modificateur, et demande "
                            + "l'autorisation d'enregistrement de l'écran.",
                            hotKey: Binding(
                                get: { prefs.previewHotKey },
                                set: { value in
                                    prefs.previewHotKey = value
                                    rebind()
                                    if value != nil, !WindowPreviewService.shared.authorized {
                                        WindowPreviewService.shared.requestAuthorization()
                                    }
                                }))
            } header: {
                SectionTitle("Naviguer")
            }

            Section {
                ShortcutRow(label: "Ranger les fenêtres", help: "Rejoue la dernière disposition employée — "
                            + "côte à côte, mosaïque, un grand + vignettes, empilés — choisie depuis le bouton "
                            + "de la barre, la barre de menus ou le clic droit. Sans défaut : à toi de choisir.",
                            hotKey: hotKey(\.arrangeHotKey))
                ShortcutRow(label: "Lancer la session", help: "Le geste du matin : range selon la dernière "
                            + "disposition, bascule sur le perso 1, arme l'enchaînement si le mode est disponible.",
                            hotKey: hotKey(\.sessionHotKey))
            } header: {
                SectionTitle("Fenêtres")
            }

            Section {
                Toggle("Mode « enchaîner » disponible", isOn: Binding(
                    get: { prefs.advanceOnClick },
                    set: { prefs.advanceOnClick = $0; ClickAdvanceWatcher.shared.apply(); rebind() }
                ))
                if prefs.advanceOnClick {
                    ShortcutRow(label: "Activer / couper le mode", hotKey: hotKey(\.advanceArmHotKey))
                    HStack {
                        Text("Clics captés : \(clicks.seenClicks)")
                            .font(.system(size: 11))
                            .foregroundStyle(clicks.seenClicks == 0 ? Color.orange : Color.secondary)
                        if clicks.seenClicks == 0 {
                            HelpTip("S'il reste à zéro après avoir cliqué dans le jeu, macOS ne livre pas les "
                                    + "évènements : Réglages Système → Confidentialité et sécurité → Surveillance de la saisie.")
                        }
                    }
                }
            } header: {
                SectionTitle("Enchaîner les persos", help: "Mode actif — par le raccourci ou la flèche verte de la "
                             + "barre —, chaque clic sur un client part normalement, puis Synfus bascule sur le perso "
                             + "suivant. Le clic est nu : le jeu reçoit exactement ce qu'il attend. Tu cliques toujours "
                             + "une fois par perso ; seul le changement de fenêtre est automatique. Synfus n'émet ni ne "
                             + "rejoue aucun clic. Le mode reste actif jusqu'à ce que tu le coupes.")
            }

            Section {
                Picker("Réaction", selection: $prefs.attentionAction) {
                    ForEach(AttentionAction.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                ShortcutRow(label: "Activer / désactiver le passage auto", hotKey: hotKey(\.toggleAutoFocus))
            } header: {
                SectionTitle("Quand un perso réclame l'attention", help: prefs.attentionAction.explanation
                             + " Détecté au rebond de l'icône dans le Dock, le seul signal qu'une app peut émettre "
                             + "vers l'extérieur ; Synfus ne lit rien du jeu lui-même.")
            }

            if !HotKeyManager.shared.rejected.isEmpty {
                Section {
                    Label("Refusées par le système (déjà prises par une autre app) : "
                          + HotKeyManager.shared.rejected.map(\.displayString).joined(separator: ", "),
                          systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Utilitaires

    private func hotKey(_ keyPath: ReferenceWritableKeyPath<Preferences, HotKey?>) -> Binding<HotKey?> {
        Binding(get: { prefs[keyPath: keyPath] }, set: { prefs[keyPath: keyPath] = $0; rebind() })
    }

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
        slot < manager.clients.count ? manager.clients[slot].name : "—"
    }
}
