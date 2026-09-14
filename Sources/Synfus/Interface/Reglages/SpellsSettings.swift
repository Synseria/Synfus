import SwiftUI

/// Onglet Sorts : le profil de chaque perso — ses barres, ses cases —, les
/// touches que le jeu attend, et la liaison Stream Deck.
struct SpellsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var store = SpellProfileStore.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var link = StreamDeckLink.shared
    @ObservedObject private var combat = CombatWatcher.shared
    @State private var perso: String = ""
    @State private var message = ""

    /// Persos connus : ceux de l'ordre enregistré, plus ceux connectés.
    private var persos: [String] {
        var names = prefs.characterOrder
        for client in manager.clients
        where WindowTitle.isPersistableName(client.name) && !names.contains(client.name) {
            names.append(client.name)
        }
        return names
    }

    private var classe: String? {
        manager.clients.first { $0.name == perso }?.characterClass ?? store.profiles[perso]?.classe
    }

    private var profile: SpellProfile { store.profile(for: perso, classe: classe) }

    var body: some View {
        Form {
            Section {
                HStack {
                    Picker("Perso", selection: $perso) {
                        ForEach(persos, id: \.self) { Text($0).tag($0) }
                    }
                    .onAppear { if perso.isEmpty { perso = persos.first ?? "" } }
                    if !perso.isEmpty {
                        Text(classe ?? "classe inconnue")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
            } header: {
                SectionTitle("Profil de sorts", help: "Un profil par perso : trois barres de dix cases, "
                             + "enregistré dans Application Support/Synfus/Profils/<perso>.json. Clique une case "
                             + "pour y mettre un sort de la classe, ou laisse « Reconnaître » lire la barre affichée "
                             + "à l'écran — le perso doit être connecté et sa fenêtre visible. La classe se lit sur "
                             + "la fenêtre du perso connecté.")
            }

            if !perso.isEmpty {
                ForEach(profile.barres.indices, id: \.self) { bar in
                    barSection(bar)
                }
            }

            Section {
                ForEach(prefs.spellKeyMap.barres.indices, id: \.self) { bar in
                    HStack {
                        Text("Barre \(bar + 1)").frame(width: 60, alignment: .leading)
                        Picker("", selection: modifiersBinding(bar)) {
                            ForEach(SpellKeyMap.modifierChoices, id: \.value) { Text($0.label).tag($0.value) }
                        }
                        .labelsHidden().frame(width: 110)
                        Text(prefs.spellKeyMap.barres[bar].map(\.displayString).joined(separator: " "))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                ShortcutRow(label: "Fin de tour", help: "La touche « fin de tour » du jeu (Options → Raccourcis). "
                            + "Sans défaut tant que tu ne l'as pas confirmée : une touche fausse en combat coûte cher.",
                            hotKey: Binding(
                                get: { prefs.spellKeyMap.finDeTour },
                                set: { prefs.spellKeyMap.finDeTour = $0 }
                            ))
            } header: {
                SectionTitle("Touches du jeu", help: "Ce que le Stream Deck frappe pour chaque case : la rangée "
                             + "de chiffres, avec le modificateur de la barre. Ce sont des positions de touches, pas "
                             + "des caractères — sur AZERTY la touche « 1 » tape &, c'est bien elle qui est frappée.")
            }

            Section {
                Toggle("Liaison active", isOn: $prefs.streamDeckEnabled)
                if prefs.streamDeckEnabled {
                    Text(link.status)
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
            } header: {
                SectionTitle("Stream Deck", help: "Ouvre un socket local, réservé à ton compte, sur lequel le "
                             + "plugin SynfusDeck lit le perso actif et ses sorts. Il ne peut demander que ce que "
                             + "fait la barre : perso suivant, précédent, barre suivante. Le plugin s'installe en "
                             + "ouvrant dist/fr.synseria.synfus.sdPlugin.\n\n" + StreamDeckLink.socketURL.path)
            }

            Section {
                HStack {
                    Button("Référence en combat") { calibrate(true) }
                    Button("Référence hors combat") { calibrate(false) }
                    Spacer()
                    Text(combat.calibrated ? combat.status : "non calibrée")
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
                .font(.system(size: 11))
                .disabled(!previews.authorized)
                if let reading = combat.lastReading {
                    Text(String(format: "dernier relevé : combat %.2f · hors combat %.2f · %d ms",
                                reading.correlationCombat, reading.correlationHors, Int(combat.lastDuration * 1000)))
                        .font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
                }
            } header: {
                SectionTitle("Détection de combat", help: "Le Stream Deck peut changer de page à l'entrée en "
                             + "combat. Le jeu ne le dit pas : Synfus compare, une fois par seconde, la bande basse "
                             + "de la fenêtre à deux références que tu captures toi-même — une fois en combat, une "
                             + "fois hors combat, perso devant. Le coût du relevé s'affiche ici.")
            }

            if !message.isEmpty {
                Text(message).font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Barres

    private func barSection(_ bar: Int) -> some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 6) {
                ForEach(0..<SpellProfile.slotsPerBar, id: \.self) { position in
                    slotView(bar: bar, position: position)
                }
            }
        } header: {
            HStack {
                Text(profile.barres[bar].nom)
                Spacer()
                Button { recognize(into: bar) } label: { Label("Reconnaître", systemImage: "wand.and.stars") }
                    .font(.system(size: 11))
                    .disabled(!previews.authorized || !isConnected)
                    .help(previews.authorized
                          ? "Lit la barre affichée à l'écran et remplit celle-ci"
                          : "Autorise d'abord l'enregistrement de l'écran (onglet Général)")
                Button { var p = profile; p.barres[bar] = .empty(nom: p.barres[bar].nom); store.save(p) } label: {
                    Image(systemName: "trash")
                }
                .font(.system(size: 11))
                .help("Vider cette barre")
            }
        }
    }

    private var isConnected: Bool { manager.clients.contains { $0.name == perso } }

    private func slotView(bar: Int, position: Int) -> some View {
        let slot = profile.slot(bar: bar, position: position)
        let key = prefs.spellKeyMap.key(bar: bar, position: position)
        return Menu {
            Button("Vider") { set(nil, bar: bar, position: position) }
                .disabled(slot == nil)
            Divider()
            ForEach(classSpells, id: \.id) { entry in
                Button(entry.nom) { set(SpellSlot(sortId: entry.id, nom: entry.nom), bar: bar, position: position) }
            }
        } label: {
            VStack(spacing: 2) {
                if let slot, let url = SpellIndex.shared?.iconURL(id: slot.sortId),
                   let image = NSImage(contentsOf: url) {
                    Image(nsImage: image).resizable().frame(width: 32, height: 32).cornerRadius(4)
                } else {
                    RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.06)).frame(width: 32, height: 32)
                        .overlay(Text("\(position + 1)").font(.system(size: 11)).foregroundStyle(.tertiary))
                }
                Text(slot?.nom ?? "—").font(.system(size: 9)).lineLimit(1)
                Text(key?.displayString ?? "").font(.system(size: 9, design: .monospaced)).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }

    private var classSpells: [SpellIndex.Entry] {
        guard let key = DofusClass.key(for: classe), let index = SpellIndex.shared else { return [] }
        return index.entries(forClass: key).sorted { $0.nom < $1.nom }
    }

    private func set(_ slot: SpellSlot?, bar: Int, position: Int) {
        var p = profile
        p.classe = classe ?? p.classe
        p.set(slot, bar: bar, position: position)
        store.save(p)
    }

    /// Capture la fenêtre du perso sélectionné, reconnaît la barre affichée
    /// à l'écran et remplit `bar` avec les cases sûres — les autres restent
    /// à choisir dans le menu.
    private func recognize(into bar: Int) {
        guard let client = manager.clients.first(where: { $0.name == perso }) else { return }
        message = "Capture en cours…"
        Task {
            guard let image = await WindowPreviewService.shared.capture(client),
                  let luma = LumaBitmap(cgImage: image)
            else { message = "Capture impossible : " + (WindowPreviewService.shared.lastCaptureError ?? "raison inconnue"); return }
            let analysis = SpellRecognition.analyze(luma, classe: classe)
            guard let found = analysis.bar else {
                message = "Aucune barre de sorts trouvée dans la capture (voir Diagnostic pour les détails)."
                return
            }
            guard analysis.candidateCount > 0 else {
                message = "Aucune icône de sort connue pour cette classe — lancer Tools/fetch-ankama-assets.sh puis ./build.sh --install."
                return
            }
            var p = profile
            p.classe = classe ?? p.classe
            var filled = 0
            for cell in analysis.cells.prefix(SpellProfile.slotsPerBar) {
                guard let match = cell.match, match.isConfident else { continue }
                p.set(SpellSlot(sortId: match.id, nom: match.nom), bar: bar, position: cell.position)
                filled += 1
            }
            store.save(p)
            message = "\(found.cells.count) cases trouvées, \(filled) reconnues avec certitude → \(p.barres[bar].nom). "
                + "Les autres se choisissent au clic."
        }
    }

    private func calibrate(_ enCombat: Bool) {
        Task { message = await CombatWatcher.shared.calibrate(enCombat: enCombat) }
    }

    private func modifiersBinding(_ bar: Int) -> Binding<UInt32> {
        Binding(
            get: { prefs.spellKeyMap.barres[bar].first?.modifiers ?? 0 },
            set: { mods in prefs.spellKeyMap.barres[bar] = HotKey.digitRow.map { HotKey(keyCode: $0, modifiers: mods) } }
        )
    }
}
