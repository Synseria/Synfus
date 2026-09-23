import SwiftUI

/// Onglet Raccourcis : rien que des combinaisons, une par ligne.
struct ShortcutsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared
    @ObservedObject private var hotKeys = HotKeyManager.shared

    /// Les combinaisons données deux fois : le système n'en enregistre qu'une,
    /// et l'autre ligne restait affichée comme si elle marchait.
    private var doublons: Set<HotKey> {
        HotKeyConflicts.doublons(prefs.hotKeys + [
            prefs.cycleNext, prefs.cyclePrevious, prefs.toggleBar, prefs.previewHotKey,
            prefs.arrangeHotKey, prefs.sessionHotKey, prefs.equipeSuivanteHotKey,
            prefs.inviteHotKey, prefs.toggleAutoFocus,
        ])
    }

    private func enConflit(_ hotKey: HotKey?) -> Bool {
        hotKey.map(doublons.contains) ?? false
    }

    var body: some View {
        Form {
            Section {
                ForEach(0..<prefs.slotCount, id: \.self) { slot in
                    ShortcutRow(label: L("raccourcis.perso", slot + 1), detail: nameForSlot(slot),
                                conflit: enConflit(slot < prefs.hotKeys.count ? prefs.hotKeys[slot] : nil),
                                hotKey: binding(forSlot: slot))
                }
                Stepper(L("raccourcis.emplacements", prefs.slotCount),
                        value: Binding(get: { prefs.slotCount }, set: { prefs.slotCount = $0; rebind() }),
                        in: 1...10)
            } header: {
                SectionTitle(L("raccourcis.allerAUnPerso"), help: L("raccourcis.allerAUnPerso.aide"))
            }

            Section {
                ShortcutRow(label: L("raccourcis.persoSuivant"), conflit: enConflit(prefs.cycleNext), hotKey: hotKey(\.cycleNext))
                ShortcutRow(label: L("raccourcis.persoPrecedent"), conflit: enConflit(prefs.cyclePrevious), hotKey: hotKey(\.cyclePrevious))
                ShortcutRow(label: L("raccourcis.afficherMasquerBarre"), conflit: enConflit(prefs.toggleBar), hotKey: hotKey(\.toggleBar))
                ShortcutRow(label: L("raccourcis.voirTous"), help: L("raccourcis.voirTous.aide"),
                            conflit: enConflit(prefs.previewHotKey),
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
                SectionTitle(L("raccourcis.naviguer"))
            }

            Section {
                ShortcutRow(label: L("raccourcis.ranger"), help: L("raccourcis.ranger.aide"),
                            conflit: enConflit(prefs.arrangeHotKey), hotKey: hotKey(\.arrangeHotKey))
                ShortcutRow(label: L("raccourcis.lancerSession"), help: L("raccourcis.lancerSession.aide"),
                            conflit: enConflit(prefs.sessionHotKey), hotKey: hotKey(\.sessionHotKey))
                if !prefs.equipes.isEmpty {
                    ShortcutRow(label: L("raccourcis.equipeSuivante"), help: L("raccourcis.equipeSuivante.aide"),
                                conflit: enConflit(prefs.equipeSuivanteHotKey), hotKey: hotKey(\.equipeSuivanteHotKey))
                }
            } header: {
                SectionTitle(L("raccourcis.fenetres"))
            }

            Section {
                ShortcutRow(label: L("raccourcis.invitation"), help: L("raccourcis.invitation.aide"),
                            conflit: enConflit(prefs.inviteHotKey), hotKey: hotKey(\.inviteHotKey))
                HStack {
                    Text(L("raccourcis.invitation.format"))
                    HelpTip(L("raccourcis.invitation.format.aide"))
                    Spacer()
                    TextField("", text: $prefs.inviteFormat)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 180)
                }
            } header: {
                SectionTitle(L("raccourcis.inviter"), help: L("raccourcis.inviter.aide"))
            }

            Section {
                Toggle(L("raccourcis.enchainer.bascule"), isOn: Binding(
                    get: { prefs.advanceOnClick },
                    set: { prefs.advanceOnClick = $0; ClickAdvanceWatcher.shared.apply() }
                ))
                if prefs.advanceOnClick {
                    HStack {
                        Text(L("raccourcis.enchainer.touche"))
                        HelpTip(L("raccourcis.enchainer.touche.aide"))
                        Spacer()
                        Picker("", selection: $prefs.advanceModifier) {
                            ForEach(ClickModifier.allCases) { Text($0.label).tag($0) }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                    HStack {
                        Text(L("raccourcis.enchainer.clicsCaptes", clicks.seenClicks))
                            .font(.system(size: 11))
                            .foregroundStyle(clicks.seenClicks == 0 ? Color.orange : Color.secondary)
                        if clicks.seenClicks == 0 {
                            HelpTip(L("raccourcis.enchainer.clicsCaptes.aide"))
                        }
                        if let dernier = clicks.lastModifiers {
                            Text(L("raccourcis.enchainer.dernierClic", dernier))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                SectionTitle(L("raccourcis.enchainer"), help: L("raccourcis.enchainer.aide"))
            }

            Section {
                Picker(L("raccourcis.attention.reaction"), selection: $prefs.attentionAction) {
                    ForEach(AttentionAction.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                ShortcutRow(label: L("raccourcis.attention.bascule"), conflit: enConflit(prefs.toggleAutoFocus), hotKey: hotKey(\.toggleAutoFocus))
            } header: {
                SectionTitle(L("raccourcis.attention"), help: prefs.attentionAction.explanation
                             + " " + L("raccourcis.attention.aide"))
            }

            Section {
                Button(L("raccourcis.retablir")) {
                    prefs.resetShortcuts()
                    rebind()
                }
                .font(.system(size: 11))
            }

            if !hotKeys.rejected.isEmpty {
                Section {
                    Label(L("raccourcis.refusees",
                            hotKeys.rejected.map(\.displayString).joined(separator: ", ")),
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
        slot < manager.effectif.count ? manager.effectif[slot].name : "—"
    }
}
