import SwiftUI

/// Onglet Personnages : leur ordre et leurs équipes, la fermeture des clients gelés, les icônes de classe.
struct CharactersSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @State private var confirmation: Confirmation?
    /// Le personnage qu'on tient par le grip, pour le réordonnancement au glisser.
    @State private var dragging: String?
    /// Cadres des lignes, dans le repère de la liste : le geste de glisser y vise la ligne d'arrivée.
    @State private var rowFrames: [String: CGRect] = [:]
    /// Le repère des cadres des lignes.
    private static let listeSpace = "synfusPersos"

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
                VStack(spacing: 0) {
                    ForEach(Array(prefs.characterOrder.enumerated()), id: \.element) { index, name in
                        characterRow(index: index, name: name)
                    }
                }
                .coordinateSpace(name: Self.listeSpace)
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
    private static let largeurFleches = Jetons.hauteurCase * 3 + 2 * Jetons.espace1

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

    /// Une ligne de la liste. Le grip se prend au doigt pour déplacer le
    /// personnage (un `DragGesture`, pas le drag & drop système : celui-ci
    /// ouvrait les sélecteurs d'équipe un à un au passage) ; les flèches
    /// offrent le même déplacement au clic ; la corbeille le retire de la liste.
    private func characterRow(index: Int, name: String) -> some View {
        HStack(spacing: Jetons.espace2) {
            Image(systemName: "line.3.horizontal")
                .font(Jetons.typoMicro.font)
                .foregroundStyle(Color.jeton(\.encre3))
                .curseurDeClic(true)
                .simultaneousGesture(deplacerGeste(name: name))
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

                Button { confirmerRetrait(name) } label: {
                    Image(systemName: "trash")
                }
                .aide(L("persos.retirer"))
            }
            .buttonStyle(BoutonTertiaire())
            .font(Jetons.typoMicro.font)
            .frame(width: Self.largeurFleches)
        }
        .rangee()
        .background(GeometryReader { geo in
            let frame = geo.frame(in: .named(Self.listeSpace))
            Color.clear
                .onAppear { rowFrames[name] = frame }
                .onChange(of: frame) { _, new in rowFrames[name] = new }
        })
    }

    /// Le geste du grip : dès que le curseur entre dans une autre ligne, le
    /// personnage y est déplacé. Un clic sans mouvement ne fait rien.
    private func deplacerGeste(name: String) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.listeSpace))
            .onChanged { value in
                if dragging == nil { dragging = name }
                guard let cible = rowFrames.first(where: { $0.key != name && $0.value.contains(value.location) })?.key,
                      let source = prefs.characterOrder.firstIndex(of: name),
                      let arrivee = prefs.characterOrder.firstIndex(of: cible) else { return }
                // `toOffset` désigne un interstice, pas une case.
                prefs.move(fromOffsets: IndexSet(integer: source),
                           toOffset: source < arrivee ? arrivee + 1 : arrivee)
                manager.resort()
            }
            .onEnded { _ in dragging = nil }
    }

    /// « Aucune » ou le numéro de l'équipe ; une entrée de plus tant qu'une équipe
    /// peut encore être créée. Un `Menu`, pas le sélecteur de la trousse : sa
    /// liste, posée sur toute la fenêtre, prenait les clics des boutons voisins
    /// (la corbeille ouvrait le sélecteur au lieu de confirmer). Tag 0 = aucune,
    /// n = équipe n.
    private func teamPicker(for name: String) -> some View {
        let nombre = prefs.equipes.count
        let rang = (Equipes.indexEquipe(de: name, dans: prefs.equipes) ?? -1) + 1
        return Menu {
            Picker(L("persos.equipe"), selection: Binding(
                get: { rang },
                set: { prefs.affecter(name, aEquipe: $0 == 0 ? nil : $0 - 1) }
            )) {
                Text(L("barre.equipe.aucune")).tag(0)
                ForEach(0..<nombre, id: \.self) { Text(L("persos.equipeN", $0 + 1)).tag($0 + 1) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
            if nombre < Equipes.maximum {
                Divider()
                Button(L("barre.equipe.nouvelle")) { prefs.affecter(name, aEquipe: nombre) }
            }
        } label: {
            HStack(spacing: Jetons.espace1) {
                Text(rang == 0 ? L("barre.equipe.aucune") : L("persos.equipeN", rang))
                    .lineLimit(1)
                Image(systemName: "chevron.down").imageScale(.small)
            }
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(BoutonBorde())
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
