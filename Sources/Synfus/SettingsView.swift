import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var probe = AttentionProbe.shared
    @ObservedObject private var watcher = AttentionWatcher.shared
    @ObservedObject private var icons = ClassIconStore.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        TabView {
            shortcutsTab
                .tabItem { Label("Raccourcis", systemImage: "keyboard") }
            charactersTab
                .tabItem { Label("Persos", systemImage: "person.3") }
            classesTab
                .tabItem { Label("Classes", systemImage: "paintpalette") }
            diagnosticTab
                .tabItem { Label("Diagnostic", systemImage: "stethoscope") }
        }
        .frame(width: 520, height: 480)
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
            }
        }
    }

    // MARK: - Persos

    private var charactersTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("L'ordre ci-dessous décide de la numérotation. Les persos non connectés "
                 + "sont simplement sautés : tu peux en garder autant que tu veux dans la liste.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(12)

            List {
                ForEach(Array(prefs.characterOrder.enumerated()), id: \.element) { index, name in
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
                    }
                    .padding(.vertical, 1)
                    .contextMenu {
                        Button("Retirer de la liste") { prefs.forget(name: name) }
                    }
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
        }
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
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                        }
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
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hosting)
            window.title = "Réglages Synfus"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        // L'app tourne en accessory : sans activation explicite, la fenêtre
        // s'ouvrirait derrière le jeu.
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
