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
                Interrupteur(titre: L("raccourcis.signalerBascule"), aide: L("raccourcis.signalerBascule.aide"),
                             isOn: $prefs.signalerBascule)
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
                ShortcutRow(label: prefs.inviteGroupee ? L("raccourcis.invitation.toutes") : L("raccourcis.invitation"),
                            help: prefs.inviteGroupee ? L("raccourcis.invitation.toutes.aide") : L("raccourcis.invitation.aide"),
                            conflit: enConflit(prefs.inviteHotKey), hotKey: hotKey(\.inviteHotKey))
                Interrupteur(titre: L("raccourcis.invitation.groupee"), isOn: $prefs.inviteGroupee)
                Ligne(titre: L("raccourcis.invitation.format"), aide: L("raccourcis.invitation.format.aide")) {
                    TextField(L("raccourcis.invitation.format"), text: $prefs.inviteFormat)
                        .labelsHidden()
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 180)
                }
            } header: {
                SectionTitle(L("raccourcis.inviter"), help: L("raccourcis.inviter.aide"))
            }

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
            } header: {
                SectionTitle(L("raccourcis.enchainer"), help: L("raccourcis.enchainer.aide"))
            }

            Section {
                Ligne(titre: L("raccourcis.attention.reaction")) {
                    Picker(L("raccourcis.attention.reaction"), selection: $prefs.attentionAction) {
                        ForEach(AttentionAction.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                ShortcutRow(label: L("raccourcis.attention.bascule"), conflit: enConflit(prefs.toggleAutoFocus), hotKey: hotKey(\.toggleAutoFocus))
            } header: {
                SectionTitle(L("raccourcis.attention"), help: prefs.attentionAction.explanation
                             + " " + L("raccourcis.attention.aide"))
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
