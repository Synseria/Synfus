import SwiftUI

/// Champ d'enregistrement de raccourci : on clique, on presse la combinaison.
/// Pendant l'enregistrement, un moniteur local avale les frappes pour qu'elles
/// n'atteignent ni les menus ni les champs texte de la fenêtre.
struct ShortcutRecorder: View {
    @Binding var hotKey: HotKey?
    var placeholder = L("raccourci.aucun")
    /// Les touches du **jeu** peuvent être nues — `I` ouvre l'inventaire. Un
    /// raccourci global de Synfus, lui, exige un modificateur.
    var allowsBareKeys = false

    @State private var recording = false
    @State private var monitor: Any?

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

            Button {
                hotKey = nil
                stop()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(hotKey == nil ? 0 : 1)
            .disabled(hotKey == nil)
            .help(L("raccourci.supprimer"))
        }
        .onDisappear(perform: stop)
    }

    private var label: String {
        if recording { return L("raccourci.pressez") }
        return hotKey?.displayString ?? placeholder
    }

    private func toggle() {
        recording ? stop() : start()
    }

    private func start() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
            if event.keyCode == 53 {  // Échap annule
                stop()
                return nil
            }
            if let captured = HotKey(event: event) {
                hotKey = captured
                stop()
            } else if allowsBareKeys, event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
                hotKey = HotKey(keyCode: UInt32(event.keyCode), modifiers: 0)
                stop()
            }
            return nil  // on avale la frappe dans tous les cas
        }
    }

    private func stop() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
