import SwiftUI

/// Onglet Raccourcis : raccourcis globaux, enchaînement au clic, aperçus, démarrage.
struct ShortcutsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var attention = AttentionDiagnostics.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            if !manager.accessibilityGranted {
                Section {
                    accessibilityWarning
                }
            }

            Section("Aller directement à un perso") {
                ForEach(0..<prefs.slotCount, id: \.self) { slot in
                    HStack {
                        Text("Perso \(slot + 1)")
                        Spacer()
                        Text(nameForSlot(slot))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        ShortcutRecorder(hotKey: binding(forSlot: slot))
                    }
                }

                Stepper(
                    "Nombre de slots : \(prefs.slotCount)",
                    value: Binding(get: { prefs.slotCount }, set: { prefs.slotCount = $0; rebind() }),
                    in: 1...10
                )
            }

            Section("Naviguer") {
                HStack {
                    Text("Perso suivant")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.cycleNext },
                        set: { prefs.cycleNext = $0; rebind() }
                    ))
                }
                HStack {
                    Text("Perso précédent")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.cyclePrevious },
                        set: { prefs.cyclePrevious = $0; rebind() }
                    ))
                }
            }

            Section("Ranger les fenêtres") {
                HStack {
                    Text("Appliquer la dernière disposition")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.arrangeHotKey },
                        set: { prefs.arrangeHotKey = $0; rebind() }
                    ))
                }
                Text("Les dispositions — côte à côte, mosaïque, un grand + vignettes, "
                     + "empilés plein cadre, et les bascules de plein écran — s'appliquent "
                     + "depuis le bouton de la barre flottante, la barre de menus ou le "
                     + "clic droit. Le raccourci rejoue la dernière disposition employée. "
                     + "Sans valeur par défaut : à toi de choisir la combinaison.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                HStack {
                    Text("Lancer la session")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.sessionHotKey },
                        set: { prefs.sessionHotKey = $0; rebind() }
                    ))
                }
                Text("Le geste du matin : range selon la dernière disposition, bascule "
                     + "sur le perso 1, et arme l'enchaînement si le mode est disponible.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Enchaîner les persos") {
                Toggle("Rendre le mode « enchaîner » disponible", isOn: Binding(
                    get: { prefs.advanceOnClick },
                    set: {
                        prefs.advanceOnClick = $0
                        ClickAdvanceWatcher.shared.apply()
                        rebind()
                    }
                ))

                HStack {
                    Text("Activer / couper le mode")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.advanceArmHotKey },
                        set: { prefs.advanceArmHotKey = $0; rebind() }
                    ))
                }
                .disabled(!prefs.advanceOnClick)

                Text(advanceExplanation)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                if prefs.advanceOnClick {
                    Text(advanceClickCount)
                        .font(.system(size: 10))
                        .foregroundStyle(clicks.seenClicks == 0 ? Color.orange : Color.secondary)
                }
            }

            Section("Quand un perso réclame l'attention") {
                Picker("Réaction", selection: $prefs.attentionAction) {
                    ForEach(AttentionAction.allCases) { action in
                        Text(action.label).tag(action)
                    }
                }
                .pickerStyle(.radioGroup)
                Text(prefs.attentionAction.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                HStack {
                    Text("Activer / désactiver le passage auto")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.toggleAutoFocus },
                        set: { prefs.toggleAutoFocus = $0; rebind() }
                    ))
                }
                Text("Détecté au rebond de l'icône dans le Dock, le seul signal qu'une app "
                     + "peut émettre vers l'extérieur. Synfus ne lit rien du jeu lui-même.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Apparence") {
                Toggle("Afficher la barre flottante", isOn: Binding(
                    get: { prefs.barVisible },
                    set: { prefs.barVisible = $0; FloatingBarController.shared.apply() }
                ))
                Toggle("Afficher les numéros dans la barre", isOn: $prefs.showNumbers)
                Toggle("Afficher la classe sous le nom", isOn: $prefs.showClasses)
                Toggle("N'afficher la barre que sur Dofus", isOn: Binding(
                    get: { prefs.barOnlyWithDofus },
                    set: { prefs.barOnlyWithDofus = $0; FloatingBarController.shared.updateVisibility() }
                ))
                HStack {
                    Text("Afficher / masquer la barre")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.toggleBar },
                        set: { prefs.toggleBar = $0; rebind() }
                    ))
                }
                HStack {
                    Text("Position de la barre")
                    Spacer()
                    Button("Recentrer en haut") { FloatingBarController.shared.recenter() }
                        .font(.system(size: 11))
                }
                Picker("Icône dans la barre de menus", selection: Binding(
                    get: { prefs.menuBarIcon },
                    set: { prefs.menuBarIcon = $0; MenuBarController.shared.refreshIcon() }
                )) {
                    ForEach(MenuBarIcon.allCases) { choix in
                        Text(choix.label).tag(choix)
                    }
                }
                Toggle("Démarrer Synfus avec la session", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
            }

            Section("Aperçus des fenêtres") {
                Toggle("Aperçu au survol d'un perso", isOn: Binding(
                    get: { prefs.showPreviewOnHover },
                    set: { value in
                        prefs.showPreviewOnHover = value
                        if value { previews.requestAuthorization() }
                    }
                ))
                HStack {
                    Text("Voir tous les persos (à maintenir)")
                    Spacer()
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.previewHotKey },
                        set: { value in
                            prefs.previewHotKey = value
                            rebind()
                            if value != nil { previews.requestAuthorization() }
                        }
                    ))
                }
                Text("Les aperçus restent affichés tant que la combinaison est maintenue. "
                     + "Elle doit comporter un modificateur : le système ne réserve pas "
                     + "une touche seule.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)

                if !previews.authorized {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "rectangle.on.rectangle")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Autorisation « Enregistrement de l'écran » requise")
                                .font(.system(size: 11, weight: .semibold))
                            Text("C'est une seconde autorisation, distincte de l'Accessibilité. "
                                 + "Sans elle, les aperçus restent vides. macOS demande en général "
                                 + "de relancer Synfus après l'avoir accordée.")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            Button("Ouvrir les Réglages Système…") { previews.requestAuthorization() }
                                .font(.system(size: 11))
                        }
                    }
                }

                Text("Un perso sur un autre bureau ou en plein écran ailleurs est capturable, "
                     + "mais son image peut dater de son dernier affichage : macOS ne redessine "
                     + "pas une fenêtre qu'il ne montre pas.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            if !HotKeyManager.shared.rejected.isEmpty {
                Section {
                    Label(
                        "Certaines combinaisons ont été refusées par le système : "
                        + HotKeyManager.shared.rejected.map(\.displayString).joined(separator: ", ")
                        + ". Une autre application les utilise déjà.",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
    }

    /// Sortie de la vue : les concaténations longues mêlées d'interpolations
    /// font exploser le temps d'inférence de SwiftUI.
    private var advanceExplanation: String {
        let bascule = prefs.advanceArmHotKey?.displayString ?? "le raccourci ci-dessus"
        let suivant = prefs.cycleNext?.displayString ?? "le raccourci « perso suivant »"
        return """
        Une fois le mode actif — par \(bascule) ou la flèche verte de la barre —, chaque clic \
        sur un client de jeu part normalement, puis Synfus bascule sur le perso suivant. Le clic \
        est nu : le jeu reçoit exactement ce qu'il attend, contrairement à un clic modifié qu'il \
        ne traite pas comme un clic ordinaire. Tu cliques donc toujours une fois par perso — seul \
        le changement de fenêtre est automatique, comme le fait déjà \(suivant). Synfus n'émet \
        aucun clic et n'en rejoue aucun. Le mode reste actif jusqu'à ce que tu le coupes.
        """
    }

    private var advanceClickCount: String {
        let suite = clicks.seenClicks == 0
            ? "S'il reste à zéro après avoir cliqué dans le jeu, macOS ne nous livre pas les "
              + "évènements — regarde Réglages Système → Confidentialité et sécurité → "
              + "Surveillance de la saisie."
            : "La flèche verte de la barre indique si le mode est actif."
        return "Clics captés depuis l'activation : \(clicks.seenClicks). " + suite
    }

    private var accessibilityWarning: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lock.shield")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Accès Accessibilité requis")
                    .font(.system(size: 12, weight: .semibold))
                Text("Synfus en a besoin pour lister les fenêtres de Dofus et les activer. "
                     + "Sans cette autorisation, aucun perso n'apparaîtra.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Button("Ouvrir les Réglages Système…") {
                    manager.requestAccessibility()
                }
                .padding(.top, 2)

                if AppIntegrity.isQuarantined {
                    quarantineWarning.padding(.top, 8)
                }
            }
        }
    }

    /// Sans cet avertissement, l'utilisateur coche la case dans les Réglages,
    /// voit Synfus continuer à réclamer l'autorisation, et n'a aucun moyen de
    /// deviner pourquoi : l'app se lance normalement, rien n'indique qu'elle est
    /// en quarantaine.
    private var quarantineWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Cette copie est en quarantaine")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
            Text("Elle a été téléchargée, et macOS la marque comme non vérifiée. "
                 + "Tant que cette marque est là, cocher Synfus dans les Réglages "
                 + "reste sans effet. À exécuter dans le Terminal, puis relancer Synfus :")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            commandLine(AppIntegrity.quarantineFix)

            Text("Si Synfus a déjà été autorisé avant, réinitialiser l'entrée :")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            commandLine(AppIntegrity.resetCommand)
        }
    }

    /// Commande sélectionnable et copiable d'un clic — la recopier à la main
    /// depuis une capture d'écran est le meilleur moyen de se tromper.
    private func commandLine(_ command: String) -> some View {
        HStack(spacing: 6) {
            Text(command)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copier la commande")
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
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

    private func rebind() {
        HotKeyManager.shared.rebind()
    }

    private func nameForSlot(_ slot: Int) -> String {
        slot < manager.clients.count ? manager.clients[slot].name : "—"
    }
}
