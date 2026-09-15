import SwiftUI

/// Onglet Persos : ordre des persos connus, fermeture des clients gelés.
struct CharactersSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Ordre des persos").font(.system(size: 12, weight: .semibold))
                HelpTip("L'ordre décide de la numérotation des emplacements. Les persos non connectés "
                        + "sont sautés : garde-en autant que tu veux. Glisse une ligne, ou utilise les flèches.")
                Text("·").foregroundStyle(.tertiary)
                Text("Équipes").font(.system(size: 12, weight: .semibold))
                HelpTip("Jusqu'à quatre équipes, composées ici ou en glissant une pastille sur la rangée "
                        + "qui apparaît sous la barre — sur « + » pour en créer une, sur « Tous » pour en "
                        + "sortir. L'équipe active restreint la barre, ⌘1…⌘n, suivant/précédent, le rangement "
                        + "et l'aperçu d'ensemble ; les autres persos restent sous « Tous ». Synfus démarre "
                        + "toujours sur « Tous ».")
            }
            .padding(12)

            List {
                ForEach(Array(prefs.characterOrder.enumerated()), id: \.element) { index, name in
                    characterRow(index: index, name: name)
                }
                .onMove { offsets, destination in
                    prefs.move(fromOffsets: offsets, toOffset: destination)
                    manager.resort()
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

            HStack(spacing: 6) {
                Toggle("Achever les clients gelés à la fermeture", isOn: $prefs.killFrozenClients)
                HelpTip("Un client qui gèle en se fermant reste vivant sans aucune fenêtre. Synfus le sonde "
                        + "et, muet trois fois de suite (~15 s), le force à quitter — que la fermeture soit "
                        + "passée par Synfus ou par le jeu. Les abattages sont consignés dans le Diagnostic.")
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
            teamPicker(for: name)
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

    /// « — » ou le numéro de l'équipe ; une entrée de plus tant qu'une équipe
    /// peut encore être créée. Tag 0 = aucune, n = équipe n.
    private func teamPicker(for name: String) -> some View {
        let count = prefs.equipes.count
        let choix = count < Equipes.maximum ? count + 1 : count
        return Picker("Équipe", selection: Binding(
            get: { (Equipes.indexEquipe(de: name, dans: prefs.equipes) ?? -1) + 1 },
            set: { prefs.affecter(name, aEquipe: $0 == 0 ? nil : $0 - 1) }
        )) {
            Text("—").tag(0)
            ForEach(1...max(choix, 1), id: \.self) { Text("Équipe \($0)").tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .font(.system(size: 10))
        .help("Équipe du perso")
    }

    private func moveCharacter(at index: Int, by delta: Int) {
        let target = index + delta
        guard target >= 0, target < prefs.characterOrder.count else { return }
        // `toOffset` désigne un interstice, pas une case : descendre d'un cran
        // veut dire viser l'interstice situé après la ligne suivante.
        prefs.move(fromOffsets: IndexSet(integer: index), toOffset: delta > 0 ? target + 1 : target)
        manager.resort()
    }

    // MARK: - Utilitaires

    /// Le numéro affiché dans la barre : celui de l'effectif.
    private func slotOf(_ name: String) -> Int? {
        manager.effectif.firstIndex { $0.name == name }
    }

    private func isOnline(_ name: String) -> Bool {
        manager.clients.contains { $0.name == name }
    }
}
