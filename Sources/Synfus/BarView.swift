import SwiftUI

/// Poignée de déplacement adossée à AppKit.
///
/// `performDrag(with:)` confie le déplacement au gestionnaire de fenêtres du
/// système : la fenêtre suit le curseur au rythme du compositeur. Une version
/// SwiftUI à base de `DragGesture` qui repositionne la fenêtre à chaque
/// évènement reste toujours un cran derrière la souris — c'est ce qui rendait
/// la barre poussive.
private struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }
    }
}

/// Fond de la barre : Liquid Glass sur macOS 26, matériau translucide en deçà.
/// Un seul binaire couvre les deux — la bascule se fait à l'exécution, il n'y a
/// donc pas de build séparé à maintenir pour les versions antérieures.
private struct BarBackground: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(.regular, in: .rect(cornerRadius: 13))
        } else {
            content.background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
                    )
            )
        }
    }
}

struct BarView: View {
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var watcher = AttentionWatcher.shared
    @ObservedObject private var icons = ClassIconStore.shared
    @ObservedObject private var clicks = ClickAdvanceWatcher.shared
    @State private var dragging: String?
    @State private var chipFrames: [String: CGRect] = [:]
    @State private var pulse = false
    /// Ouverture différée de l'aperçu, annulée dès que le curseur ressort.
    @State private var hoverTask: Task<Void, Never>?
    /// Perso pour lequel cette attente a été lancée. Cf. `hover(_:inside:)`.
    @State private var hoverTarget: String?

    /// Repère commun aux cadres des pastilles et au geste de réordonnancement.
    private static let barSpace = "synfusBar"

    var body: some View {
        HStack(spacing: 3) {
            handle
            content
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .coordinateSpace(name: Self.barSpace)
        .background(WindowDragArea())   // tout le fond libre déplace la barre
        .modifier(BarBackground())
        .fixedSize()
        .contextMenu { contextMenu }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onChange(of: manager.clients) { _, clients in pruneChipFrames(clients) }
    }

    /// Poignée de déplacement, et signature de l'app sur l'overlay. Le curseur
    /// en main ouverte et l'infobulle portent l'affordance que les trois traits
    /// donnaient auparavant ; la zone sensible reste la même.
    private var handle: some View {
        SynfusGlyphView()
            .foregroundStyle(.tertiary)
            .frame(height: 15)
            .frame(width: 15, height: 26)
            .contentShape(Rectangle())
            .background(WindowDragArea())
            .help("Glisser pour déplacer la barre")
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
            autoFocusToggle
        }
    }

    /// Bascule du passage automatique. Doublé par un raccourci global, pour
    /// pouvoir l'éteindre sans lâcher le combat des yeux.
    private var autoFocusToggle: some View {
        let on = prefs.attentionAction == .focus
        return Button {
            prefs.attentionAction = on ? .highlight : .focus
        } label: {
            Image(systemName: on ? "bolt.fill" : "bolt.slash")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? Color.orange : Color.secondary)
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(on ? Color.orange.opacity(0.18) : Color.primary.opacity(0.05))
                )
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(on
              ? "Passage automatique activé — Synfus bascule sur le perso dont l'icône rebondit (\(toggleShortcut))"
              : "Passage automatique désactivé — le perso est seulement signalé (\(toggleShortcut))")
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

        return Button {
            manager.focus(client)
        } label: {
            HStack(spacing: 5) {
                if prefs.showClasses {
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

                // La coche garde sa place même absente : sans quoi la barre
                // changerait de largeur à chaque perso passé, et se recentrerait
                // sous le curseur au milieu d'un enchaînement.
                if prefs.advanceOnClick {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(active ? Color.white : Color.green)
                        .opacity(clicks.visited.contains(client.slotKey) ? 1 : 0)
                        .frame(width: 9)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(active ? Color.accentColor : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.orange, lineWidth: 2)
                    .opacity(alerting ? (pulse ? 1 : 0.2) : 0)
            )
            .foregroundStyle(active ? Color.white : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip(index: index, client: client))
        // Un perso sur un autre espace reste cliquable, mais on ne le donne pas
        // pour présent : sa vignette et son titre datent de sa dernière visite.
        .opacity(dragging == client.name ? 0.35 : (client.dormant ? 0.55 : 1))
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
                }
                WindowManager.shared.refresh()
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
        if prefs.advanceOnClick {
            Button("Décocher tous les persos") { ClickAdvanceWatcher.shared.resetVisited() }
        }
        Button("Recentrer la barre") { FloatingBarController.shared.recenter() }
        Button("Masquer la barre") { FloatingBarController.shared.toggle() }
        Divider()
        Button("Rafraîchir") { manager.refresh() }
        Divider()
        Button("Quitter Synfus") { NSApp.terminate(nil) }
    }
}
