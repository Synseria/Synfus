import SwiftUI

/// Qui a la parole pendant l'enregistrement d'un raccourci — **un seul champ à
/// la fois**, et un seul moniteur d'évènements.
///
/// Chaque champ posait le sien. Cliquer un second champ sans avoir terminé le
/// premier en laissait donc deux en place : le premier restait sur « Pressez… »
/// pour toujours, son moniteur survivait à la fenêtre, et la frappe suivante
/// pouvait être attribuée aux deux champs — dont l'un se faisait ensuite
/// refuser par le système pour doublon. Le moniteur vit ici, il est unique, et
/// prendre la parole la retire à qui l'avait.
@MainActor
final class ShortcutRecording: ObservableObject {
    static let shared = ShortcutRecording()

    /// Le champ qui écoute. `nil` quand personne n'enregistre.
    @Published private(set) var active: UUID?

    private var monitor: Any?

    private init() {}

    /// Donne la parole à ce champ. `capture` reçoit chaque frappe et rend
    /// `true` quand elle lui suffit — l'écoute s'arrête alors d'elle-même.
    /// La frappe est avalée dans tous les cas : elle ne doit atteindre ni les
    /// menus ni les champs texte de la fenêtre.
    func start(_ id: UUID, capture: @escaping @MainActor (NSEvent) -> Bool) {
        stop()
        active = id
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            var termine = false
            MainActor.assumeIsolated {
                // Échap annule, comme partout ailleurs sur macOS.
                termine = event.keyCode == 53 ? true : capture(event)
            }
            if termine { MainActor.assumeIsolated { ShortcutRecording.shared.stop() } }
            return nil
        }
    }

    /// Rend la parole. Avec un `id`, seulement si c'est bien lui qui l'avait —
    /// la disparition d'un champ ne doit pas couper l'écoute d'un autre.
    func stop(_ id: UUID? = nil) {
        if let id, active != id { return }
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if active != nil { active = nil }
    }
}

/// Champ d'enregistrement de raccourci : on clique, on presse la combinaison.
struct ShortcutRecorder: View {
    @Binding var hotKey: HotKey?
    var placeholder = L("raccourci.aucun")
    /// Les touches du **jeu** peuvent être nues — `I` ouvre l'inventaire. Un
    /// raccourci global de Synfus, lui, exige un modificateur.
    var allowsBareKeys = false

    @ObservedObject private var session = ShortcutRecording.shared
    /// L'identité du champ, stable d'un redessin à l'autre : c'est elle qui dit
    /// si c'est lui qui écoute.
    @State private var id = UUID()

    private var recording: Bool { session.active == id }

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(label)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(recording ? Color.accentColor : .primary)
                    .frame(minWidth: 92)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.primary.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(
                                        recording ? Color.accentColor : Color.primary.opacity(0.15),
                                        lineWidth: recording ? 1.5 : 0.5
                                    )
                            )
                    )
            }
            .buttonStyle(.plain)
            .help(recording ? L("raccourci.pressez.aide") : L("raccourci.enregistrer.aide"))

            Button {
                hotKey = nil
                session.stop(id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(hotKey == nil ? 0 : 1)
            .disabled(hotKey == nil)
            .help(L("raccourci.supprimer"))
        }
        .onDisappear { session.stop(id) }
    }

    private var label: String {
        if recording { return L("raccourci.pressez") }
        return hotKey?.displayString ?? placeholder
    }

    private func toggle() {
        recording ? session.stop(id) : start()
    }

    private func start() {
        session.start(id) { event in
            if let captured = HotKey(event: event) {
                hotKey = captured
                return true
            }
            if allowsBareKeys,
               event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                hotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: 0)
                return true
            }
            // Un modificateur seul, ou une frappe que `HotKey` refuse : on
            // continue d'écouter plutôt que de fermer sur un demi-geste.
            return false
        }
    }
}
