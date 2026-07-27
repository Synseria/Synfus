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
    @State private var dragging: String?
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 3) {
            handle
            content
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(WindowDragArea())   // tout le fond libre déplace la barre
        .modifier(BarBackground())
        .fixedSize()
        .contextMenu { contextMenu }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }

    private var handle: some View {
        Image(systemName: "line.3.horizontal")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(.tertiary)
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

    private func chip(index: Int, client: DofusClient) -> some View {
        let active = manager.isFrontmost(client)
        let alerting = watcher.alerting.contains(client.slotKey)

        return Button {
            manager.focus(client)
        } label: {
            HStack(spacing: 5) {
                if prefs.showClasses {
                    // L'icône du Dock est la même pour tous les clients (même
                    // bundle) : une pastille teintée par classe distingue bien
                    // mieux les persos d'un coup d'œil.
                    Text(DofusClass.abbreviation(for: client.characterClass))
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(width: 19, height: 19)
                        .background(
                            Circle().fill(DofusClass.color(for: client.characterClass))
                        )
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(active ? 0.5 : 0.15), lineWidth: 1)
                        )
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
        .opacity(dragging == client.name ? 0.35 : 1)
        .onDrag {
            dragging = client.name
            return NSItemProvider(object: client.name as NSString)
        }
        .onDrop(of: [.text], delegate: ReorderDropDelegate(target: client.name, dragging: $dragging))
    }

    private func tooltip(index: Int, client: DofusClient) -> String {
        var lines = [client.name]
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
        Divider()
        Button("Rafraîchir") { manager.refresh() }
        Divider()
        Button("Quitter Synfus") { NSApp.terminate(nil) }
    }
}

/// Réorganisation par glisser-déposer : on permute la cible et l'élément glissé.
/// La permutation se fait dans l'ordre de préférence global, celui qui contient
/// aussi les persos déconnectés, pour que le classement survive à la session.
private struct ReorderDropDelegate: DropDelegate {
    let target: String
    @Binding var dragging: String?

    func dropEntered(info: DropInfo) {
        guard let source = dragging, source != target else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            Preferences.shared.swapOrder(source, target)
        }
        WindowManager.shared.refresh()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
