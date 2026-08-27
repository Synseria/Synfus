import SwiftUI
import UniformTypeIdentifiers

/// Sections des réglages, listées dans la barre latérale.
private enum SettingsSection: String, CaseIterable, Identifiable {
    case raccourcis, persos, classes, diagnostic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .raccourcis: return "Raccourcis"
        case .persos: return "Persos"
        case .classes: return "Classes"
        case .diagnostic: return "Diagnostic"
        }
    }

    var icon: String {
        switch self {
        case .raccourcis: return "keyboard"
        case .persos: return "person.3"
        case .classes: return "paintpalette"
        case .diagnostic: return "stethoscope"
        }
    }
}

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var probe = AttentionProbe.shared
    @ObservedObject private var watcher = AttentionWatcher.shared
    @ObservedObject private var icons = ClassIconStore.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared
    @ObservedObject private var arranger = WindowArranger.shared
    @ObservedObject private var freezes = FreezeWatcher.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var section: SettingsSection = .raccourcis

    /// Barre latérale à gauche, contenu à droite : les quatre sections en
    /// onglets faisaient défiler des formulaires interminables — le menu
    /// vertical garde tout sous les yeux.
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 480)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { item in
                sidebarRow(item)
            }
            Spacer()
            // Sélectionnable : les binaires publiés sont signés ad-hoc, il faut
            // réautoriser l'Accessibilité à chaque version, et c'est donc la
            // première chose à savoir sur un rapport de bug.
            Text(AppIntegrity.displayName)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
                .padding(.horizontal, 8)
        }
        .padding(8)
        .frame(width: 150)
        .background(Color.primary.opacity(0.035))
    }

    private func sidebarRow(_ item: SettingsSection) -> some View {
        Button {
            section = item
        } label: {
            Label(item.label, systemImage: item.icon)
                .font(.system(size: 12, weight: section == item ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(section == item ? Color.accentColor : Color.clear)
                )
                .foregroundStyle(section == item ? Color.white : Color.primary)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .raccourcis: shortcutsTab
        case .persos: charactersTab
        case .classes: classesTab
        case .diagnostic: diagnosticTab
        }
    }

    // MARK: - Raccourcis

    private var shortcutsTab: some View {
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
                Text("Les dispositions — côte à côte, mosaïque, un grand + vignettes — "
                     + "s'appliquent depuis le menu de la barre de menus ou le clic droit "
                     + "sur la barre. Le raccourci rejoue la dernière employée. Sans "
                     + "valeur par défaut : à toi de choisir la combinaison.")
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

    // MARK: - Persos

    private var charactersTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("L'ordre ci-dessous décide de la numérotation. Les persos non connectés "
                 + "sont simplement sautés : tu peux en garder autant que tu veux dans la liste. "
                 + "Glisse une ligne, ou utilise les flèches, pour réordonner.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(12)

            List {
                ForEach(Array(prefs.characterOrder.enumerated()), id: \.element) { index, name in
                    characterRow(index: index, name: name)
                }
                .onMove { offsets, destination in
                    prefs.move(fromOffsets: offsets, toOffset: destination)
                    manager.refresh()
                }
            }

            HStack {
                Text("\(manager.clients.count) connecté(s) sur \(prefs.characterOrder.count) connu(s)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Oublier les hors ligne") {
                    for name in prefs.characterOrder where !isOnline(name) {
                        prefs.forget(name: name)
                    }
                }
                .font(.system(size: 11))
            }
            .padding(12)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Achever les clients gelés à la fermeture", isOn: $prefs.killFrozenClients)
                Text("Un client qui gèle en se fermant reste en mémoire sans aucune fenêtre. "
                     + "Synfus le sonde et, muet trois fois de suite (~15 s), le force à "
                     + "quitter — que la fermeture soit passée par Synfus ou par le jeu. "
                     + "Les abattages sont consignés dans le Diagnostic.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
        }
    }

    /// Une ligne de la liste des persos. `contentShape` étend la zone de prise
    /// du glisser à toute la ligne — viser le seul texte demandait une précision
    /// pénible — et les flèches offrent un déplacement au clic, infaillible.
    private func characterRow(index: Int, name: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Circle()
                .fill(isOnline(name) ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 7, height: 7)
            Text(name)
            Spacer()
            if let slot = slotOf(name) {
                Text("\(slot + 1)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Text(isOnline(name) ? "connecté" : "hors ligne")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                Button { moveCharacter(at: index, by: -1) } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                .help("Monter dans l'ordre")

                Button { moveCharacter(at: index, by: 1) } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == prefs.characterOrder.count - 1)
                .help("Descendre dans l'ordre")
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10, weight: .semibold))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Retirer de la liste") { prefs.forget(name: name) }
        }
    }

    private func moveCharacter(at index: Int, by delta: Int) {
        let target = index + delta
        guard target >= 0, target < prefs.characterOrder.count else { return }
        // `toOffset` désigne un interstice, pas une case : descendre d'un cran
        // veut dire viser l'interstice situé après la ligne suivante.
        prefs.move(fromOffsets: IndexSet(integer: index), toOffset: delta > 0 ? target + 1 : target)
        manager.refresh()
    }

    // MARK: - Classes

    /// Synfus n'embarque aucune image de classe : les portraits du jeu
    /// appartiennent à Ankama. Chacun met donc les siennes, par glisser-déposer
    /// ou en remplissant le dossier à la main.
    private var classesTab: some View {
        Form {
            Section {
                Text("Chaque classe peut recevoir l'image de ton choix : un portrait, "
                     + "une capture d'écran, n'importe quel PNG ou JPEG. Sans image, "
                     + "Synfus affiche la pastille colorée.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Ouvrir le dossier") { NSWorkspace.shared.open(icons.directory) }
                    Button("Recharger") { icons.reloadAll() }
                    Spacer()
                }
                .font(.system(size: 11))

                Text("Tu peux aussi y déposer les fichiers directement, nommés d'après "
                     + "la classe : iop.png, cra.png, xelor.png… puis « Recharger ».")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Emblèmes officiels") {
                Text("Le script Tools/fetch-class-icons.sh du dépôt remplit ce dossier "
                     + "avec les emblèmes des 19 classes. Synfus ne redistribue aucune "
                     + "image du jeu : c'est ta machine qui les télécharge, pour ton "
                     + "usage personnel.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Certaines illustrations sont la propriété d'Ankama Studio et de "
                     + "Dofus — Tous droits réservés.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Icônes") {
                ForEach(DofusClass.breeds) { breed in
                    classRow(breed)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func classRow(_ breed: DofusClass.Breed) -> some View {
        let custom = icons.icon(forKey: breed.key)

        return HStack(spacing: 10) {
            ZStack {
                if let custom {
                    Image(nsImage: custom)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Circle().fill(breed.color)
                    Text(String(breed.key.prefix(2)).capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)

            Text(breed.label)

            Spacer()

            if custom != nil {
                Button("Retirer") { icons.removeIcon(forKey: breed.key) }
                    .font(.system(size: 11))
            }
            Button(custom == nil ? "Choisir…" : "Remplacer…") { chooseIcon(for: breed) }
                .font(.system(size: 11))
        }
        .padding(.vertical, 1)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            drop(providers, for: breed)
        }
    }

    private func chooseIcon(for breed: DofusClass.Breed) {
        let panel = NSOpenPanel()
        panel.title = "Icône pour \(breed.label)"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !icons.setIcon(from: url, forKey: breed.key) {
            NSSound.beep()
        }
    }

    private func drop(_ providers: [NSItemProvider], for breed: DofusClass.Breed) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                if !icons.setIcon(from: url, forKey: breed.key) { NSSound.beep() }
            }
        }
        return true
    }

    // MARK: - Diagnostic

    private var diagnosticTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Titres bruts des fenêtres détectées")
                .font(.system(size: 12, weight: .semibold))
            Text("Si le nom affiché ne correspond pas à ton perso, c'est que le client Dofus "
                 + "n'expose pas le nom dans le titre de sa fenêtre. Dans ce cas la "
                 + "numérotation suit l'ordre de lancement, que tu peux réorganiser dans "
                 + "l'onglet Persos.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if manager.clients.isEmpty {
                Text(manager.accessibilityGranted
                     ? "Aucune fenêtre Dofus détectée. Le jeu est-il lancé ?"
                     : AppIntegrity.isQuarantined
                       ? "Autorisation Accessibilité manquante — et cette copie est "
                         + "en quarantaine, ce qui l'empêchera de prendre effet. "
                         + "Voir l'onglet Raccourcis."
                       : "Autorisation Accessibilité manquante.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.top, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(manager.clients) { client in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text("titre : \"\(client.rawTitle)\"")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text("pid \(client.pid)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                if previews.authorized {
                                    Text(previews.unmatched.contains(client.slotKey)
                                         ? "aperçu : fenêtre introuvable à la capture"
                                         : previews.previews[client.slotKey] != nil
                                           ? "aperçu : capturé"
                                           : "aperçu : pas encore demandé")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                        }
                    }
                }
            }

            Divider().padding(.vertical, 4)
            arrangementSection

            if !freezes.journal.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clients gelés achevés")
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(freezes.journal.suffix(5)) { abattu in
                        Text("\(abattu.date.formatted(date: .omitted, time: .standard))  "
                             + "\(abattu.nom) (pid \(abattu.pid)) — sans fenêtre et muet "
                             + "à trois sondes, forcé à quitter")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider().padding(.vertical, 4)
            attentionProbeSection

            Spacer()
            HStack {
                Button("Rafraîchir") { manager.refresh() }
                Spacer()
                Text("Synfus — barre et raccourcis de fenêtres")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }

    /// Ce que le dernier rangement a réellement fait. Il repose sur des
    /// hypothèses — l'écran cible, la bonne volonté du client — et laisse des
    /// fenêtres de côté par principe : tout cela doit se lire quelque part.
    private var arrangementSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Dernier rangement des fenêtres")
                .font(.system(size: 12, weight: .semibold))

            if let rapport = arranger.dernierRapport {
                Text("\(rapport.disposition.label) — écran « \(rapport.ecran) » — "
                     + rapport.date.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !rapport.rangees.isEmpty {
                    Text("Rangés : \(rapport.rangees.joined(separator: ", "))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ForEach(rapport.ecartees) { ecartee in
                    Text("Écarté : \(ecartee.nom) — \(ecartee.raison)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Aucun rangement pour l'instant — menu « Ranger les fenêtres » "
                     + "de la barre de menus, ou clic droit sur la barre.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Text("Une fenêtre en plein écran n'est jamais déplacée, et un perso d'un "
                 + "autre bureau est hors de portée de l'Accessibilité — bascule dessus, "
                 + "puis relance le rangement.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    private var attentionProbeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Appels d'attention")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Button(probe.running ? "Arrêter" : "Démarrer la sonde") { probe.toggle() }
                    .font(.system(size: 11))
            }

            Text("Surveille les deux seuls signaux qu'une app peut émettre vers l'extérieur : "
                 + "le titre de sa fenêtre et la pastille de son icône du Dock. Démarre la sonde, "
                 + "joue un combat, et regarde si quelque chose bouge quand ton tour arrive.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            if !watcher.pairing.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appariement icône du Dock → perso")
                        .font(.system(size: 11, weight: .medium))
                    ForEach(Array(watcher.pairing.enumerated()), id: \.offset) { _, pair in
                        Text("\(pair.dock)  →  \(pair.character)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text("Tes clients s'intitulent tous « Dofus » dans le Dock : l'appariement "
                         + "suppose que l'ordre des icônes suit l'ordre de lancement. Vérifie "
                         + "ici que le bon perso est signalé.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 4)
            }

            if let lecture = watcher.dockReading {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Relevé du Dock")
                        .font(.system(size: 11, weight: .medium))
                    Text(lecture)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("Un rebond éloigne une icône de son bandeau ; un Dock qui se masque ou "
                         + "se dévoile les emporte ensemble. C'est ce qui les distingue, et c'est "
                         + "pourquoi la mesure se fait sur l'écart et non sur l'ordonnée à "
                         + "l'écran — avec le masquage automatique, les icônes reposent sous le "
                         + "bord de l'écran. Au repos, ces écarts ne doivent pas bouger.")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 4)
            }

            if !probe.watchedItems.isEmpty {
                Text("Icônes surveillées : " + probe.watchedItems.joined(separator: ", "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Ouvrir le journal") { probe.revealLog() }
                    .font(.system(size: 11))
                Text(AttentionProbe.logURL.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .textSelection(.enabled)
            }

            if probe.events.isEmpty {
                if probe.running {
                    Text("En écoute…")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(probe.events) { event in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(event.time.formatted(date: .omitted, time: .standard))  \(event.label)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                Text(event.detail)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 130)
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

    private func rebind() {
        HotKeyManager.shared.rebind()
    }

    private func nameForSlot(_ slot: Int) -> String {
        slot < manager.clients.count ? manager.clients[slot].name : "—"
    }

    private func slotOf(_ name: String) -> Int? {
        manager.clients.firstIndex { $0.name == name }
    }

    private func isOnline(_ name: String) -> Bool {
        manager.clients.contains { $0.name == name }
    }
}

@MainActor
final class SettingsWindowController: NSObject {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    /// La fenêtre est en cours de placement automatique : tant que ce drapeau
    /// tient, chaque changement de taille la replace. Un déplacement à la souris
    /// y met fin — l'utilisateur a dit où il la voulait.
    private var placing = false
    /// Distingue notre propre `setFrameOrigin` d'un geste de l'utilisateur, comme
    /// le fait `FloatingBarController` pour la barre.
    private var repositioning = false

    private override init() { super.init() }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Réglages Synfus"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            self.window = window

            for (note, action) in [
                (NSWindow.didResizeNotification, #selector(windowResized)),
                (NSWindow.didMoveNotification, #selector(windowMoved)),
            ] {
                NotificationCenter.default.addObserver(
                    self, selector: action, name: note, object: window
                )
            }
        }
        guard let window else { return }

        // À chaque (ré)ouverture, la fenêtre se place sous la barre flottante :
        // c'est de là qu'on l'invoque, autant qu'elle apparaisse sous les yeux.
        // Tant qu'elle reste ouverte, en revanche, on ne la déplace pas.
        if !window.isVisible {
            placing = true
            // La taille définitive n'est connue qu'une fois SwiftUI passé. Placer
            // avant revenait à calculer sur une fenêtre encore vide : elle
            // grandissait ensuite vers le haut — AppKit ancre au coin bas gauche —
            // et se retrouvait n'importe où sauf sous la barre. D'où la mise en
            // page forcée, doublée du replacement à chaque redimensionnement :
            // changer d'onglet change aussi la hauteur.
            window.layoutIfNeeded()
            position(window)
        }

        // L'app tourne en accessory : sans activation explicite, la fenêtre
        // s'ouvrirait derrière le jeu.
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func windowResized() {
        guard placing, let window else { return }
        position(window)
    }

    @objc private func windowMoved() {
        guard !repositioning else { return }
        placing = false
    }

    /// Au milieu de l'écran, sous la barre flottante, bornée à l'écran.
    ///
    /// Le centrage horizontal se fait sur l'écran et non sur la barre : celle-ci
    /// se déplace à la main, la fenêtre de réglages n'a pas à la suivre de biais.
    /// Et sur `frame` plutôt que `visibleFrame`, comme le fait la barre — un Dock
    /// posé sur un côté décalerait sinon les deux ensemble.
    private func position(_ window: NSWindow) {
        let bar = FloatingBarController.shared.visibleBarFrame
        let screen = bar.flatMap { rect in NSScreen.screens.first { $0.frame.intersects(rect) } }
            ?? NSScreen.main
        guard let screen else { return }

        let size = window.frame.size
        let visible = screen.visibleFrame

        var origin = CGPoint(
            x: (screen.frame.midX - size.width / 2).rounded(),
            // Sous la barre quand elle est là ; à mi-hauteur sinon.
            y: ((bar.map { $0.minY - Self.gap } ?? visible.midY + size.height / 2) - size.height)
                .rounded()
        )
        origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - size.width - 8)
        origin.y = min(max(origin.y, visible.minY + 8), visible.maxY - size.height - 8)

        repositioning = true
        window.setFrameOrigin(origin)
        // `didMove` peut arriver au tour de boucle suivant : on ne relâche le
        // drapeau qu'une fois la notification passée.
        DispatchQueue.main.async { self.repositioning = false }
    }

    /// Écart entre la barre et le haut de la fenêtre de réglages.
    private static let gap: CGFloat = 12
}
