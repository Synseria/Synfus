import SwiftUI

/// Onglet Sorts : le profil de chaque perso — ses barres, comme dans le jeu,
/// douze cases sur une ligne — et les touches que le jeu attend.
struct SpellsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var store = SpellProfileStore.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var link = StreamDeckLink.shared
    @State private var perso: String = ""
    @State private var message = ""

    private var classe: String? {
        manager.clients.first { $0.name == perso }?.characterClass ?? store.profiles[perso]?.classe
    }

    private var profile: SpellProfile { store.profile(for: perso, classe: classe) }

    var body: some View {
        Form {
            Section {
                HStack {
                    PersoPicker(perso: $perso)
                    if !perso.isEmpty {
                        Text(classe ?? "classe inconnue")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button { recognize() } label: { Label("Reconnaître les barres affichées", systemImage: "wand.and.stars") }
                        .font(.system(size: 11))
                        .disabled(!previews.authorized || !isConnected)
                        .help(previews.authorized
                              ? "Capture la fenêtre du perso, lit les trois rangées de sorts et remplit les barres"
                              : "Autorise d'abord l'enregistrement de l'écran (onglet Général)")
                }
            } header: {
                SectionTitle("Profil de sorts", help: "Un profil par perso : trois barres de douze cases, "
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
                        Text(prefs.spellKeyMap.barres[bar].map { $0?.displayString ?? "·" }.joined(separator: " "))
                            .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    }
                }
                ShortcutRow(label: "Corps à corps", help: "La touche qui attaque avec l'arme équipée. Sans défaut : "
                            + "à relever dans les raccourcis du jeu.", allowsBareKeys: true,
                            hotKey: Binding(
                                get: { prefs.spellKeyMap.corpsACorps },
                                set: { prefs.spellKeyMap.corpsACorps = $0 }
                            ))
                ShortcutRow(label: "Fin de tour", help: "La touche « fin de tour » du jeu (Options → Raccourcis). "
                            + "Sans défaut tant que tu ne l'as pas confirmée : une touche fausse en combat coûte cher.",
                            allowsBareKeys: true,
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
                ForEach(prefs.gameCommands.indices, id: \.self) { i in
                    HStack {
                        Image(systemName: prefs.gameCommands[i].symbole).frame(width: 18)
                        ShortcutRow(label: prefs.gameCommands[i].nom, allowsBareKeys: true, hotKey: Binding(
                            get: { prefs.gameCommands[i].touche },
                            set: { prefs.gameCommands[i].touche = $0 }
                        ))
                    }
                }
                Button("Remettre les touches par défaut") { prefs.gameCommands = GameCommands.defaults }
                    .font(.system(size: 11))
            } header: {
                SectionTitle("Commandes du jeu", help: "Les raccourcis du jeu que la touche « Menu » du Stream Deck "
                             + "affiche à la place des sorts : inventaire, caractéristiques, suivi du perso… Les défauts "
                             + "sont ceux du jeu tels qu'on les connaît — vérifie-les dans Options → Raccourcis.")
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
            // Les douze cases sur une ligne, comme la barre du jeu.
            HStack(spacing: 4) {
                ForEach(0..<SpellProfile.slotsPerBar, id: \.self) { position in
                    slotView(bar: bar, position: position)
                }
            }
            .padding(.vertical, 4)
        } header: {
            HStack(spacing: 8) {
                Text(profile.barres[bar].nom).font(.system(size: 12, weight: .semibold))
                Text(SpellKeyMap.modifierChoices.first { $0.value == (prefs.spellKeyMap.barres[bar].first??.modifiers ?? 0) }?.label ?? "")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                if link.mode.kind != .parRangee, link.mode.barreActive(page: link.page, colonnes: DeckLayout.defaultColumns, lignes: DeckLayout.defaultRows) == bar {
                    Text("sur le Stream Deck").font(.system(size: 10)).foregroundStyle(Color.accentColor)
                }
                Spacer()
                Button { var p = profile; p.barres[bar] = .empty(nom: p.barres[bar].nom); store.save(p) } label: {
                    Image(systemName: "trash")
                }
                .font(.system(size: 11))
                .help("Vider cette barre")
            }
        }
    }

    private var isConnected: Bool { manager.clients.contains { $0.name == perso } }

    /// Une case : l'icône en carré, le nom, la touche. Un clic ouvre le choix
    /// du sort — la façon manuelle, toujours disponible.
    private func slotView(bar: Int, position: Int) -> some View {
        let slot = profile.slot(bar: bar, position: position)
        let key = prefs.spellKeyMap.key(bar: bar, position: position)
        return SpellSlotCell(slot: slot, keyLabel: key?.displayString, position: position,
                             icon: slot.flatMap { slotIconURL($0) }.flatMap { NSImage(contentsOf: $0) },
                             choices: classSpells,
                             iconFor: { SpellIndex.shared?.iconURL(id: $0).flatMap { NSImage(contentsOf: $0) } },
                             onSelect: { entry in set(entry.map { SpellSlot(sortId: $0.id, nom: $0.nom) }, bar: bar, position: position) })
    }

    private func slotIconURL(_ slot: SpellSlot) -> URL? {
        if let id = slot.sortId, let url = SpellIndex.shared?.iconURL(id: id) { return url }
        return slot.vignette.map { store.thumbnailURL(perso: perso, name: $0) }
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

    /// Capture la fenêtre du perso sélectionné, reconnaît les rangées
    /// affichées à l'écran — jusqu'à trois, une par barre — et remplit les
    /// cases sûres ; les autres restent à choisir au clic.
    private func recognize() {
        guard let client = manager.clients.first(where: { $0.name == perso }) else { return }
        message = "Capture en cours…"
        Task { message = await store.recognize(client) }
    }

    private func modifiersBinding(_ bar: Int) -> Binding<UInt32> {
        Binding(
            get: { prefs.spellKeyMap.barres[bar].first??.modifiers ?? 0 },
            set: { mods in prefs.spellKeyMap.barres[bar] = SpellKeyMap.row(modifiers: mods) }
        )
    }
}

/// Une case de barre : carré d'icône, nom, touche ; au clic, la liste des
/// sorts de la classe avec leurs icônes, et « Vider ».
private struct SpellSlotCell: View {
    let slot: SpellSlot?
    let keyLabel: String?
    let position: Int
    let icon: NSImage?
    let choices: [SpellIndex.Entry]
    let iconFor: (Int) -> NSImage?
    let onSelect: (SpellIndex.Entry?) -> Void
    @State private var choosing = false
    @State private var filter = ""

    var body: some View {
        Button { choosing.toggle() } label: {
            VStack(spacing: 3) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(slot == nil ? 0.05 : 0.1))
                    if let icon {
                        Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        Image(systemName: "plus").font(.system(size: 14, weight: .light)).foregroundStyle(.tertiary)
                    }
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                }
                .frame(width: 44, height: 44)
                .overlay(alignment: .topLeading) {
                    Text("\(position + 1)")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 3).padding(.vertical, 1)
                        .background(Capsule().fill(Color.black.opacity(0.45)))
                        .foregroundStyle(.white)
                        .padding(2)
                }
                Text(slot?.nom ?? "—").font(.system(size: 8)).lineLimit(1).frame(width: 50)
                Text(keyLabel ?? " ").font(.system(size: 8, design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
        .help(slot.map { "\($0.nom) — cliquer pour changer" } ?? "Cliquer pour choisir un sort")
        .popover(isPresented: $choosing, arrowEdge: .bottom) { picker }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Filtrer", text: $filter).textFieldStyle(.roundedBorder)
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(choices.filter { filter.isEmpty || $0.nom.localizedCaseInsensitiveContains(filter) }, id: \.id) { entry in
                        Button { onSelect(entry); choosing = false } label: {
                            HStack(spacing: 8) {
                                if let image = iconFor(entry.id) {
                                    Image(nsImage: image).resizable().frame(width: 24, height: 24).cornerRadius(4)
                                }
                                Text(entry.nom).font(.system(size: 12))
                                Spacer()
                                if slot?.sortId == entry.id { Image(systemName: "checkmark") }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 2)
                    }
                }
            }
            .frame(width: 240, height: 260)
            if slot != nil {
                Divider()
                Button("Vider la case") { onSelect(nil); choosing = false }.font(.system(size: 11))
            }
            if choices.isEmpty {
                Text("Aucune icône de sort pour cette classe — lance Tools/fetch-ankama-assets.sh puis ./build.sh --install.")
                    .font(.system(size: 10)).foregroundStyle(.secondary).frame(width: 240)
            }
        }
        .padding(10)
    }
}
