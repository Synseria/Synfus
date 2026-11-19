import SwiftUI

/// Onglet Personnages : leur ordre et leurs équipes, la fermeture des clients gelés, les icônes de classe.
struct CharactersSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @State private var confirmation: Confirmation?

    /// Les personnages connus qu'aucun client ne porte en ce moment.
    private var horsLigne: [String] {
        prefs.characterOrder.filter { !isOnline($0) }
    }

    /// Compté dans la liste, d'où il vient : un client sans nom de personnage (écran de connexion) n'y est pas.
    private var connectes: Int { prefs.characterOrder.count - horsLigne.count }

    /// Un dernier mot avant : la liste des personnages fixe la numérotation des emplacements, la vider par
    /// mégarde décale tous les raccourcis.
    private func confirmerOubli() {
        let noms = horsLigne
        confirmation = Confirmation(titre: L("persos.oublierHorsLigne.confirmation", nombre: noms.count, noms.count),
                                    detail: L("persos.oublierHorsLigne.detail"), verbe: L("commun.retirer")) {
            Preferences.shared.forget(names: noms)
        }
    }

    private func confirmerRetrait(_ nom: String) {
        confirmation = Confirmation(titre: L("persos.retirer.confirmation", nom), detail: L("persos.retirer.detail"),
                                    verbe: L("commun.retirer")) {
            Preferences.shared.forget(name: nom)
        }
    }

    var body: some View {
        PageReglages {
            Bloc(L("persos.ordre"), aide: L("persos.ordre.aide") + "\n\n" + L("persos.equipes.aide")) {
                if !prefs.characterOrder.isEmpty { enTetes }
                ForEach(Array(prefs.characterOrder.enumerated()), id: \.element) { index, name in
                    characterRow(index: index, name: name)
                }
                Ligne(titre: L("persos.connectes")) {
                    HStack(spacing: Jetons.espace2) {
                        Text(L("persos.connectesSurConnus", connectes, prefs.characterOrder.count))
                            .foregroundStyle(Color.jeton(\.encre2))
                        // Seul ce qui sert existe : sans personnage hors ligne, rien à retirer.
                        if !horsLigne.isEmpty {
                            Button(L("persos.oublierHorsLigne")) { confirmerOubli() }
                                .buttonStyle(BoutonDestructif())
                        }
                    }
                }
            }
            Bloc(L("persos.fermeture")) {
                LigneInterrupteur(titre: L("persos.acheverGeles"), aide: L("persos.acheverGeles.aide"),
                             isOn: $prefs.killFrozenClients)
            }
            BlocsClasses()
        }
        .confirmation($confirmation, annuler: L("commun.annuler"))
    }

    private static let largeurEquipe = Jetons.largeurNav * 0.9
    private static let largeurTouche: CGFloat = 88
    private static let largeurFleches = Jetons.hauteurCase * 2 + Jetons.espace1

    /// Les colonnes de la liste, nommées : le menu est l'équipe, la touche mène au personnage.
    private var enTetes: some View {
        HStack(spacing: Jetons.espace2) {
            Spacer()
            Text(L("persos.equipe")).frame(width: Self.largeurEquipe, alignment: .leading)
            Text(L("persos.raccourci")).lineLimit(1).frame(width: Self.largeurTouche, alignment: .leading)
            Color.clear.frame(width: Self.largeurFleches, height: 0)
        }
        .font(Jetons.typoMeta.font)
        .foregroundStyle(Color.jeton(\.encre2))
        .rangee()
    }

    /// Une ligne de la liste. Un glisser sur une autre ligne y place le personnage ; les flèches offrent le
    /// même déplacement au clic.
    private func characterRow(index: Int, name: String) -> some View {
        HStack(spacing: Jetons.espace2) {
            Image(systemName: "line.3.horizontal")
                .font(Jetons.typoMicro.font)
                .foregroundStyle(Color.jeton(\.encre3))
            Circle()
                .fill(isOnline(name) ? Color.jeton(\.succes) : Color.jeton(\.encre3))
                .frame(width: Jetons.espace2, height: Jetons.espace2)
                .accessibilityLabel(isOnline(name) ? L("persos.connecte") : L("persos.horsLigne"))
            Text(name)
            // Seul l'écart au normal s'écrit : un personnage connecté n'a pas besoin de le dire.
            if !isOnline(name) {
                Text(L("persos.horsLigne"))
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre3))
            }
            Spacer()
            teamPicker(for: name)
            // La touche réelle, celle de la barre ; un personnage hors ligne n'a pas d'emplacement.
            HStack {
                if let rang = slotOf(name) {
                    ToucheDeClavier(touche: BarView.toucheDuPerso(index: rang, raccourcis: prefs.hotKeys))
                        .aide(L("persos.raccourciDuPerso"))
                }
                Spacer(minLength: 0)
            }
            .frame(width: Self.largeurTouche)

            HStack(spacing: Jetons.espace1) {
                Button { moveCharacter(at: index, by: -1) } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(index == 0)
                .aide(L("persos.monter"))

                Button { moveCharacter(at: index, by: 1) } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(index == prefs.characterOrder.count - 1)
                .aide(L("persos.descendre"))
            }
            .buttonStyle(BoutonTertiaire())
            .font(Jetons.typoMicro.font)
            .frame(width: Self.largeurFleches)
        }
        .rangee()
        .draggable(name)
        .dropDestination(for: String.self) { noms, _ in
            guard let source = noms.first.flatMap(prefs.characterOrder.firstIndex(of:)) else { return false }
            prefs.move(fromOffsets: IndexSet(integer: source), toOffset: source < index ? index + 1 : index)
            manager.resort()
            return true
        }
        .contextMenu {
            Button(L("persos.retirer")) { confirmerRetrait(name) }
        }
    }

    /// « Aucune » ou le numéro de l'équipe ; une entrée de plus tant qu'une équipe
    /// peut encore être créée. Tag 0 = aucune, n = équipe n.
    private func teamPicker(for name: String) -> some View {
        let count = prefs.equipes.count
        let choix = count < Equipes.maximum ? count + 1 : count
        return SelecteurEnListe(L("persos.equipe"),
                                selection: Binding(get: { (Equipes.indexEquipe(de: name, dans: prefs.equipes) ?? -1) + 1 },
                                                   set: { prefs.affecter(name, aEquipe: $0 == 0 ? nil : $0 - 1) }),
                                options: [(0, L("barre.equipe.aucune"))] + (1...max(choix, 1)).map { ($0, L("persos.equipeN", $0)) })
            .frame(width: Self.largeurEquipe, alignment: .leading)
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
