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

/// Gabarit commun des bascules de mode — flèche d'enchaînement, éclair du
/// passage automatique. Au repos le bouton est nu : le fond n'apparaît qu'au
/// survol ou quand le mode est actif, la barre ne montre plus une rangée de
/// carrés gris en permanence.
private struct ModeButton: View {
    let icone: String
    let teinte: Color
    let actif: Bool
    let aide: String
    let action: () -> Void
    @State private var survole = false

    var body: some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(actif ? teinte : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(fond)
                )
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .animation(.easeOut(duration: 0.15), value: survole)
        .animation(.easeOut(duration: 0.15), value: actif)
        .help(aide)
    }

    private var fond: Color {
        if actif { return teinte.opacity(survole ? 0.22 : 0.18) }
        return survole ? Color.primary.opacity(0.08) : .clear
    }
}

/// L'engrenage d'accès aux réglages. Plus discret que les bascules — pas de
/// fond, contour seulement — : c'est une porte, pas un état.
private struct GearButton: View {
    @State private var survole = false

    var body: some View {
        Button {
            SettingsWindowController.shared.show()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(survole ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                .frame(width: 22, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { survole = $0 }
        .help("Réglages de Synfus")
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
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
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
        .contentShape(Rectangle())
        .background(WindowDragArea())
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
            if prefs.advanceOnClick { armToggle }
            autoFocusToggle
        }
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
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.orange, lineWidth: 1.5)
                    .opacity(alerting ? (pulse ? 1 : 0.2) : 0)
            )
            .foregroundStyle(active ? Color.white : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        // Fermer depuis la barre : le client gèle souvent quand on le quitte
        // par sa propre fenêtre, et il fallait alors « Forcer à quitter » à la
        // main. Ici la fermeture escalade toute seule si le client ne répond
        // plus (cf. `WindowManager.close`).
        .contextMenu {
            Button("Fermer « \(client.name) »") { manager.close(client) }
        }
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
        Button("Recentrer la barre") { FloatingBarController.shared.recenter() }
        Button("Masquer la barre") { FloatingBarController.shared.toggle() }
        Menu("Ranger les fenêtres") {
            ForEach(Disposition.allCases) { disposition in
                Button {
                    WindowArranger.shared.appliquer(disposition)
                } label: {
                    Label(disposition.label, systemImage: disposition.symbolName)
                }
            }
        }
        Divider()
        Button("Rafraîchir") { manager.refresh() }
        Divider()
        Button("Fermer tous les persos") { manager.closeAll() }
            .disabled(manager.clients.isEmpty)
        Button("Quitter Synfus") { NSApp.terminate(nil) }
    }
}
