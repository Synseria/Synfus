import SwiftUI

/// Onglet Sorts : le profil de chaque perso — ses barres, ses cases —, les
/// touches que le jeu attend, et la liaison Stream Deck.
struct SpellsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var store = SpellProfileStore.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var link = StreamDeckLink.shared
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
            Section("Perso") {
                Picker("Perso", selection: $perso) {
                    ForEach(persos, id: \.self) { Text($0).tag($0) }
                }
                .onAppear { if perso.isEmpty { perso = persos.first ?? "" } }
                if !perso.isEmpty {
                    Text(classe.map { "Classe : \($0)" } ?? "Classe inconnue — connecte le perso pour la lire.")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }

            if !perso.isEmpty {
                ForEach(profile.barres.indices, id: \.self) { bar in
                    barSection(bar)
                }
            }

            Section("Touches du jeu") {
                Text("Ce que le Stream Deck frappe pour chaque case — des positions de touches, "
                     + "pas des caractères : la rangée de chiffres, quel que soit le clavier.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
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
                HStack {
                    Text("Fin de tour").frame(width: 60, alignment: .leading)
                    ShortcutRecorder(hotKey: Binding(
                        get: { prefs.spellKeyMap.finDeTour },
                        set: { prefs.spellKeyMap.finDeTour = $0 }
                    ))
                    Text("À confirmer en jeu (Options → Raccourcis).")
                        .font(.system(size: 10)).foregroundStyle(.tertiary)
                }
            }

            Section("Stream Deck") {
                Toggle("Activer la liaison Stream Deck", isOn: $prefs.streamDeckEnabled)
                Text("Ouvre un socket local (\(StreamDeckLink.socketURL.path)), réservé à ton compte, "
                     + "sur lequel le plugin SynfusDeck lit le perso actif et ses sorts. Il ne peut "
                     + "demander que ce que fait la barre : perso suivant, précédent, barre suivante.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                if prefs.streamDeckEnabled {
                    Text(link.status)
                        .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                }
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
                Button("Reconnaître la barre affichée") { recognize(into: bar) }
                    .font(.system(size: 11))
                    .disabled(!previews.authorized || !isConnected)
                    .help(previews.authorized
                          ? "Capture la fenêtre du perso et remplit cette barre avec les sorts reconnus"
                          : "Demande d'abord l'enregistrement de l'écran (onglet Raccourcis)")
                Button("Vider") { var p = profile; p.barres[bar] = .empty(nom: p.barres[bar].nom); store.save(p) }
                    .font(.system(size: 11))
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
                if let slot, let url = AnkamaAssets.spellIconURL(classe: DofusClass.key(for: classe) ?? "", id: slot.sortId),
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
        guard let key = DofusClass.key(for: classe), let index = SpellIndex.load() else { return [] }
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
            else { message = "Capture impossible — la fenêtre est-elle visible ?"; return }
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

    private func modifiersBinding(_ bar: Int) -> Binding<UInt32> {
        Binding(
            get: { prefs.spellKeyMap.barres[bar].first?.modifiers ?? 0 },
            set: { mods in prefs.spellKeyMap.barres[bar] = HotKey.digitRow.map { HotKey(keyCode: $0, modifiers: mods) } }
        )
    }
}
