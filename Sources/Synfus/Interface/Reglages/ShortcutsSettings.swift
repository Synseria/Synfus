import SwiftUI

/// Onglet Raccourcis : toute combinaison globale s'y règle, une ligne par geste, puis l'enchaînement au clic et la réaction à l'attention.
struct ShortcutsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var hotKeys = HotKeyManager.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared

    /// Les combinaisons données deux fois : le système n'en enregistre qu'une,
    /// et l'autre ligne restait affichée comme si elle marchait.
    private var doublons: Set<HotKey> {
        HotKeyConflicts.doublons(prefs.raccourcisGlobaux)
    }

    private func enConflit(_ hotKey: HotKey?) -> Bool {
        hotKey.map(doublons.contains) ?? false
    }

    var body: some View {
        PageReglages(titre: L("reglages.raccourcis")) {
            // Une ligne par personnage connecté : les emplacements suivent l'effectif.
            Bloc(L("raccourcis.allerAUnPerso"), infobulle: L("raccourcis.allerAUnPerso.aide")) {
                ForEach(0..<min(manager.effectif.count, prefs.hotKeys.count), id: \.self) { slot in
                    ShortcutRow(label: L("raccourcis.perso", slot + 1), detail: manager.effectif[slot].name,
                                conflit: enConflit(prefs.hotKeys[slot]),
                                hotKey: binding(forSlot: slot))
                }
                if manager.effectif.isEmpty {
                    EtatDeBloc(texte: L("barre.aucunPerso"))
                }
            }

            Bloc(L("raccourcis.naviguer")) {
                RaccourciReglable(label: L("raccourcis.persoSuivant"), chemin: \.cycleNext)
                    .help(L("raccourcis.aide"))
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
            }

            Bloc(L("raccourcis.panneaux")) {
                RaccourciReglable(label: L("raccourcis.palette"), help: L("raccourcis.palette.aide"),
                                  chemin: \.paletteHotKey)
                RaccourciReglable(label: L("quetes.raccourci"), chemin: \.quetesHotKey)
                    .help(L("quetes.aide"))
                RaccourciReglable(label: L("chasse.raccourci"), chemin: \.chasseHotKey)
                    .help(L("chasse.aide"))
                RaccourciReglable(label: L("boss.raccourci"), chemin: \.bossHotKey)
                    .help(L("boss.aide"))
                RaccourciReglable(label: L("zaap.raccourci"), help: L("zaap.raccourci.aide"), chemin: \.zaapHotKey)
                    .help(L("zaap.reecriture.aide", ItineraireZaap.ecartZaapDuJeu))
                RaccourciReglable(
                    label: prefs.inviteGroupee ? L("raccourcis.invitation.toutes") : L("raccourcis.invitation"),
                    help: prefs.inviteGroupee ? L("raccourcis.invitation.toutes.aide") : L("raccourcis.invitation.aide"),
                    chemin: \.inviteHotKey)
            }

            Bloc(L("raccourcis.fenetres")) {
                RaccourciReglable(label: L("raccourcis.ranger"), help: L("raccourcis.ranger.aide"), chemin: \.arrangeHotKey)
                RaccourciReglable(label: L("raccourcis.lancerSession"), help: L("raccourcis.lancerSession.aide"), chemin: \.sessionHotKey)
                if !prefs.equipes.isEmpty {
                    RaccourciReglable(label: L("raccourcis.equipeSuivante"), help: L("raccourcis.equipeSuivante.aide"), chemin: \.equipeSuivanteHotKey)
                }
            }

            Bloc(L("reglages.enchainer")) {
                Ligne(titre: L("raccourcis.enchainer.bascule"),
                      aide: L("raccourcis.enchainer.aide") + "\n\n" + L("raccourcis.enchainer.touche.aide")) {
                    HStack(spacing: Jetons.Espace.deux) {
                        if prefs.advanceOnClick {
                            Picker(L("raccourcis.enchainer.touche"), selection: $prefs.advanceModifier) {
                                ForEach(ClickModifier.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden()
                            .fixedSize()
                        }
                        Toggle(L("raccourcis.enchainer.bascule"), isOn: Binding(
                            get: { prefs.advanceOnClick },
                            set: { prefs.advanceOnClick = $0; ClickAdvanceWatcher.shared.apply() }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                }
                if prefs.advanceOnClick {
                    Ligne(titre: L("raccourcis.enchainer.clicsCaptes"),
                          etat: clicks.lastModifiers.map { L("raccourcis.enchainer.dernierClic", $0) },
                          aide: clicks.seenClicks == 0 ? L("raccourcis.enchainer.clicsCaptes.aide") : nil) {
                        Text("\(clicks.seenClicks)")
                            .monospacedDigit()
                            .foregroundStyle(clicks.seenClicks == 0 ? Color.jeton(\.alerte) : Color.jeton(\.encreSecondaire))
                    }
                }
            }

            Bloc(L("reglages.attention")) {
                Ligne(titre: L("raccourcis.attention.reaction"), aide: aideAttention) {
                    Picker(L("raccourcis.attention.reaction"), selection: $prefs.attentionAction) {
                        ForEach(AttentionAction.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                RaccourciReglable(label: L("raccourcis.attention.bascule"), chemin: \.toggleAutoFocus)
            }

            Bloc {
                if !hotKeys.rejected.isEmpty {
                    Ligne(titre: L("raccourcis.refusees")) {
                        HStack(spacing: Jetons.Espace.un) {
                            ForEach(hotKeys.rejected.map(\.displayString), id: \.self) { ToucheRaccourci($0) }
                        }
                    }
                }
                Ligne(titre: L("raccourcis.tous")) {
                    Button(L("commun.retablir")) { confirmerRetablissement() }
                }
            }
        }
    }

    private func confirmerRetablissement() {
        Task {
            let demande = DemandeConfirmation(
                titre: L("raccourcis.retablir.confirmation"), detail: L("raccourcis.retablir.detail"),
                verbe: L("commun.retablir"))
            guard await Confirmation.demander(demande) else { return }
            prefs.resetShortcuts()
            rebind()
        }
    }

    private var aideAttention: String {
        let reactions = AttentionAction.allCases.map { "\($0.label)\n\($0.explanation)" }
        return ([L("raccourcis.attention.aide")] + reactions).joined(separator: "\n\n")
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
}
