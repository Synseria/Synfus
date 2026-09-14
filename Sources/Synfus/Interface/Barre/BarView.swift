import SwiftUI

struct BarView: View {
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var watcher = AttentionWatcher.shared
    @ObservedObject private var icons = ClassIconStore.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared
    @State private var dragging: String?
    @State private var chipFrames: [String: CGRect] = [:]
    /// Ouverture différée de l'aperçu, annulée dès que le curseur ressort.
    @State private var hoverTask: Task<Void, Never>?
    /// Perso pour lequel cette attente a été lancée. Cf. `hover(_:inside:)`.
    @State private var hoverTarget: String?

    /// Repère commun aux cadres des pastilles et au geste de réordonnancement.
    private static let barSpace = "synfusBar"

    var body: some View {
        HStack(spacing: 4) {
            handle
            content
            settingsButton
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .coordinateSpace(name: Self.barSpace)
        .background(WindowDragArea())   // tout le fond libre déplace la barre
        .modifier(BarBackground())
        .fixedSize()
        .contextMenu { contextMenu }
        .onChange(of: manager.clients) { _, clients in pruneChipFrames(clients) }
    }

    /// Poignée de déplacement : le grip de points, affordance universelle du
    /// « saisis-moi ». Le glyphe de la marque l'a occupée un temps, mais il ne
    /// disait rien du déplacement — la marque vit dans la barre de menus et
    /// l'icône du bundle, un overlay de jeu reste un outil. La zone sensible,
    /// le curseur en main ouverte et l'infobulle sont inchangés.
    private var handle: some View {
        HStack(spacing: 3) {
            ForEach(0..<2, id: \.self) { _ in
                VStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { _ in
                        Circle()
                            .fill(Color.primary.opacity(0.28))
                            .frame(width: 2.5, height: 2.5)
                    }
                }
            }
        }
        .frame(width: 15, height: 26)
        .overlay(WindowDragArea())
        .help("Glisser pour déplacer la barre")
    }

    /// Trait qui sépare le territoire des persos de celui des modes : sans lui,
    /// les bascules se lisaient comme une pastille de plus.
    private var separator: some View {
        Capsule()
            .fill(Color.primary.opacity(0.15))
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
            .allowsHitTesting(false)
    }

    /// Porte vers les réglages — sans elle, il fallait deviner le clic droit ou
    /// passer par la barre de menus. Hors du contenu conditionnel : c'est quand
    /// rien ne marche qu'on cherche les réglages.
    private var settingsButton: some View {
        GearButton().padding(.leading, 2)
    }

    @ViewBuilder
    private var content: some View {
        if !manager.accessibilityGranted {
            Button {
                manager.requestAccessibility()
            } label: {
                Label("Autoriser Synfus", systemImage: "lock.shield")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.plain)
            .help("Synfus a besoin de l'accès Accessibilité pour lister et activer les fenêtres")
        } else if manager.clients.isEmpty {
            Text("Aucun perso connecté")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
        } else {
            ForEach(Array(manager.clients.enumerated()), id: \.element.id) { index, client in
                chip(index: index, client: client)
            }
            separator
            arrangeMenu
            if prefs.advanceOnClick { armToggle }
            autoFocusToggle
        }
    }

    /// Le rangement, sous la main : dispositions et bascules de plein écran,
    /// là où on les cherche — cachés dans le seul clic droit, ils étaient
    /// introuvables.
    private var arrangeMenu: some View {
        ArrangeMenuButton()
    }

    /// Bascule du mode « enchaîner » : tant qu'il est actif, un clic **nu** sur
    /// un client de jeu passe au perso suivant. C'est aussi le seul témoin d'un
    /// mode qui ne s'éteint pas tout seul — d'où la couleur franche.
    private var armToggle: some View {
        let on = clicks.armed
        return ModeButton(
            icone: on ? "arrow.right.circle.fill" : "arrow.right.circle",
            teinte: .green,
            actif: on,
            aide: on
                ? "Enchaînement actif — chaque clic sur le jeu passe au perso suivant, "
                  + "jusqu'à ce que tu le coupes (\(armShortcut))"
                : "Activer l'enchaînement : chaque clic sur le jeu passera au perso "
                  + "suivant (\(armShortcut))"
        ) {
            ClickAdvanceWatcher.shared.toggleArmed()
        }
    }

    private var armShortcut: String {
        prefs.advanceArmHotKey?.displayString ?? "aucun raccourci"
    }

    /// Bascule du passage automatique. Doublé par un raccourci global, pour
    /// pouvoir l'éteindre sans lâcher le combat des yeux.
    private var autoFocusToggle: some View {
        let on = prefs.attentionAction == .focus
        return ModeButton(
            icone: on ? "bolt.fill" : "bolt.slash",
            teinte: .orange,
            actif: on,
            aide: on
                ? "Passage automatique activé — Synfus bascule sur le perso dont l'icône rebondit (\(toggleShortcut))"
                : "Passage automatique désactivé — le perso est seulement signalé (\(toggleShortcut))"
        ) {
            let prefs = Preferences.shared
            prefs.attentionAction = prefs.attentionAction == .focus ? .highlight : .focus
        }
    }

    private var toggleShortcut: String {
        prefs.toggleAutoFocus?.displayString ?? "aucun raccourci"
    }

    /// Repère de classe : l'icône choisie dans les réglages, à défaut une
    /// pastille teintée. L'icône du Dock ne servirait à rien ici — tous les
    /// clients partagent le même bundle, donc la même image.
    @ViewBuilder
    private func classBadge(for className: String?, active: Bool) -> some View {
        ZStack {
            if let custom = icons.icon(for: className) {
                Image(nsImage: custom)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle().fill(DofusClass.color(for: className))
                Text(DofusClass.abbreviation(for: className))
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 20, height: 20)
        .overlay(
            Circle().strokeBorder(Color.white.opacity(active ? 0.5 : 0.15), lineWidth: 1)
        )
    }

    private func chip(index: Int, client: DofusClient) -> some View {
        let active = manager.isFrontmost(client)
        let alerting = watcher.alerting.contains(client.slotKey)
        let closing = manager.closingPIDs.contains(client.pid)

        return Button {
            manager.focus(client)
        } label: {
            HStack(spacing: 5) {
                // La fermeture en cours prend la place du badge : le geste a
                // été entendu, la pastille le dit — et disparaîtra seule.
                if closing {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 20, height: 20)
                } else if prefs.showClasses {
                    classBadge(for: client.characterClass, active: active)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(client.name)
                        .font(.system(size: 12, weight: active ? .semibold : .regular))
                        .lineLimit(1)
                        .fixedSize()
                    if prefs.showClasses, let className = client.characterClass {
                        Text(className)
                            .font(.system(size: 9))
                            .foregroundStyle(active ? Color.white.opacity(0.75) : Color.secondary)
                            .lineLimit(1)
                    }
                }

                if prefs.showNumbers {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(active ? Color.white.opacity(0.7) : Color.secondary.opacity(0.8))
                }

                // Rien de plus : le mode « enchaîner » suit l'ordre de la barre,
                // et le surlignage du perso courant dit déjà où l'on en est. Une
                // coche « déjà passé » n'ajoutait qu'un clignotement de plus.
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Color.accentColor : Color.clear)
            )
            .overlay { if alerting { AlertPulse() } }
            .foregroundStyle(active ? Color.white : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(closing)
        // Fermer depuis la barre : le client gèle souvent quand on le quitte
        // par sa propre fenêtre, et il fallait alors « Forcer à quitter » à la
        // main. Ici la fermeture escalade toute seule si le client ne répond
        // plus (cf. `WindowManager.close`).
        .contextMenu {
            if closing {
                Button("Fermeture en cours…") {}.disabled(true)
            } else {
                Button("Fermer « \(client.name) »") { manager.close(client) }
            }
        }
        .help(tooltip(index: index, client: client))
        // Un perso sur un autre espace reste cliquable, mais on ne le donne pas
        // pour présent : sa vignette et son titre datent de sa dernière visite.
        .opacity(dragging == client.name ? 0.35 : (closing ? 0.45 : client.dormant ? 0.55 : 1))
        .scaleEffect(dragging == client.name ? 1.06 : 1)
        .background(chipFrameReader(for: client.name))
        .simultaneousGesture(reorderGesture(for: client))
        .onHover { inside in hover(client, inside: inside) }
    }

    /// Ouvre l'aperçu après un court délai : sans lui, le simple fait de
    /// traverser la barre pour aller ailleurs déclencherait une capture par
    /// pastille survolée au passage.
    ///
    /// L'attente est unique pour toute la barre, et la sortie d'une pastille
    /// n'est **pas** garantie d'arriver avant l'entrée dans la suivante :
    /// AppKit émet `mouseEntered` et `mouseExited` de deux zones de suivi
    /// voisines dans l'ordre qui l'arrange. Annuler sans regarder revenait, une
    /// fois sur deux, à tuer l'attente que la pastille d'à côté venait
    /// d'ouvrir — le premier aperçu s'affichait, les suivants jamais. D'où
    /// `hoverTarget` : une sortie n'annule que sa propre attente.
    private func hover(_ client: DofusClient, inside: Bool) {
        guard prefs.showPreviewOnHover else { return }

        guard inside else {
            if hoverTarget == client.slotKey {
                hoverTask?.cancel()
                hoverTask = nil
                hoverTarget = nil
            }
            PreviewPanelController.shared.hide(ifShowing: client)
            return
        }

        // Préchauffage : la capture part tout de suite, en parallèle de
        // l'attente, pour que l'aperçu s'ouvre avec son image plutôt que sur
        // le cadre « Capture en cours… ». Seulement si l'autorisation est déjà
        // là — `refresh` ne la demande jamais, un survol ne doit pas faire
        // surgir une invite système — et si aucune image n'est connue : une
        // vignette existante attend le rafraîchissement normal du panneau.
        let service = WindowPreviewService.shared
        if service.authorized, service.previews[client.slotKey] == nil {
            service.refresh(client)
        }

        hoverTask?.cancel()
        hoverTarget = client.slotKey
        hoverTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled,
                  let local = chipFrames[client.name],
                  let onScreen = FloatingBarController.shared.screenFrame(fromBarFrame: local)
            else { return }
            PreviewPanelController.shared.show(client, below: onScreen)
        }
    }

    /// Publie le cadre de la pastille dans le repère de la barre, pour que le
    /// geste de réordonnancement sache quelle pastille est survolée, et l'aperçu
    /// sous quelle pastille se placer.
    ///
    /// Le nettoyage se fait sur la liste des persos, et surtout pas dans un
    /// `onDisappear` : quand SwiftUI reconstruit une ligne, la disparition de
    /// l'ancienne peut arriver après l'apparition de la nouvelle, et effacerait
    /// un cadre parfaitement valide — la pastille perdait alors son aperçu sans
    /// que rien ne le laisse deviner.
    private func chipFrameReader(for name: String) -> some View {
        GeometryReader { geo in
            let frame = geo.frame(in: .named(Self.barSpace))
            Color.clear
                .onAppear { chipFrames[name] = frame }
                .onChange(of: frame) { _, new in chipFrames[name] = new }
        }
    }

    private func pruneChipFrames(_ clients: [DofusClient]) {
        let alive = Set(clients.map(\.name))
        chipFrames = chipFrames.filter { alive.contains($0.key) }
    }

    /// Réordonnancement au glisser, sans passer par le drag & drop système :
    /// une session `.onDrag` ne démarre pas de façon fiable depuis un panneau
    /// non activable, et sa vignette volante n'apporte rien ici. Un simple
    /// `DragGesture` suit la souris au plus près — dès que le curseur entre
    /// dans une autre pastille, les deux persos sont permutés. Le geste est
    /// simultané au bouton : un clic sans mouvement active toujours le perso.
    private func reorderGesture(for client: DofusClient) -> some Gesture {
        DragGesture(minimumDistance: 6, coordinateSpace: .named(Self.barSpace))
            .onChanged { value in
                dragging = client.name
                guard let target = chipFrames.first(where: { entry in
                    entry.key != client.name && entry.value.contains(value.location)
                })?.key else { return }
                withAnimation(.easeInOut(duration: 0.15)) {
                    Preferences.shared.swapOrder(client.name, target)
                    // Un tri, pas un inventaire : rien n'a changé côté clients.
                    WindowManager.shared.resort()
                }
            }
            .onEnded { _ in dragging = nil }
    }

    private func tooltip(index: Int, client: DofusClient) -> String {
        var lines = [client.name]
        if client.dormant {
            lines.append("Sur un autre bureau — cliquer pour y basculer")
        }
        if index < prefs.hotKeys.count, let hotKey = prefs.hotKeys[index] {
            lines.append("Raccourci : \(hotKey.displayString)")
        }
        if !client.rawTitle.isEmpty, client.rawTitle != client.name {
            lines.append("Fenêtre : \(client.rawTitle)")
        }
        return lines.joined(separator: "\n")
    }

    @ViewBuilder
    private var contextMenu: some View {
        Button("Réglages…") { SettingsWindowController.shared.show() }
        Button("Recentrer la barre") { FloatingBarController.shared.recenter() }
        Button("Masquer la barre") { FloatingBarController.shared.toggle() }
        Menu("Ranger les fenêtres") { ArrangementMenuItems() }
        Button("Lancer la session") { manager.lancerSession() }
        Divider()
        Button("Rafraîchir") { manager.refresh() }
        Divider()
        Button("Fermer tous les persos") { manager.closeAll() }
            .disabled(manager.clients.isEmpty)
        Button("Quitter Synfus") { NSApp.terminate(nil) }
    }
}
