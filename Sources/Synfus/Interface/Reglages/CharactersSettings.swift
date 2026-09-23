import SwiftUI

/// Onglet Persos : ordre des persos connus, fermeture des clients gelés.
struct CharactersSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @State private var confirmerOubli = false

    /// Les persos connus qu'aucun client ne porte en ce moment.
    private var horsLigne: [String] {
        prefs.characterOrder.filter { !isOnline($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(L("persos.ordre")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("persos.ordre.aide"))
                Text("·").foregroundStyle(.tertiary)
                Text(L("persos.equipes")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("persos.equipes.aide"))
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
                Text(L("persos.connectesSurConnus", manager.clients.count, prefs.characterOrder.count))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                // Une seule écriture pour toute la fournée, et un dernier mot
                // avant : la liste des persos est ce qui fixe la numérotation
                // des emplacements, la vider par mégarde décale tous les
                // raccourcis.
                Button(L("persos.oublierHorsLigne")) { confirmerOubli = true }
                    .font(.system(size: 11))
                    .disabled(horsLigne.isEmpty)
                    .confirmationDialog(
                        L("persos.oublierHorsLigne.confirmation", horsLigne.count),
                        isPresented: $confirmerOubli, titleVisibility: .visible
                    ) {
                        Button(L("persos.oublierHorsLigne"), role: .destructive) {
                            prefs.forget(names: horsLigne)
                        }
                        Button(L("commun.annuler"), role: .cancel) {}
                    }
            }
            .padding(12)

            Divider()

            HStack(spacing: 6) {
                Toggle(L("persos.acheverGeles"), isOn: $prefs.killFrozenClients)
                HelpTip(L("persos.acheverGeles.aide"))
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
            Text(isOnline(name) ? L("persos.connecte") : L("persos.horsLigne"))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)

            HStack(spacing: 2) {
                Button { moveCharacter(at: index, by: -1) } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                .help(L("persos.monter"))

                Button { moveCharacter(at: index, by: 1) } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == prefs.characterOrder.count - 1)
                .help(L("persos.descendre"))
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10, weight: .semibold))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .contextMenu {
            Button(L("persos.retirer")) { prefs.forget(name: name) }
        }
    }

    /// « — » ou le numéro de l'équipe ; une entrée de plus tant qu'une équipe
    /// peut encore être créée. Tag 0 = aucune, n = équipe n.
    private func teamPicker(for name: String) -> some View {
        let count = prefs.equipes.count
        let choix = count < Equipes.maximum ? count + 1 : count
        return Picker(L("persos.equipe"), selection: Binding(
            get: { (Equipes.indexEquipe(de: name, dans: prefs.equipes) ?? -1) + 1 },
            set: { prefs.affecter(name, aEquipe: $0 == 0 ? nil : $0 - 1) }
        )) {
            Text("—").tag(0)
            ForEach(1...max(choix, 1), id: \.self) { Text(L("persos.equipeN", $0)).tag($0) }
        }
        .labelsHidden()
        .fixedSize()
        .font(.system(size: 10))
        .help(L("persos.equipeDuPerso"))
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
