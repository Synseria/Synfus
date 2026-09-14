import SwiftUI

/// Les briques communes des réglages. La règle d'interface : **un réglage
/// par ligne, l'explication derrière un ⓘ** — le texte long ne vient qu'à la
/// demande, dans une bulle, jamais entre deux boutons.

/// Le ⓘ : une bulle d'aide, au clic.
struct HelpTip: View {
    let text: String
    @State private var showing = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 12))
                .padding(12)
                .frame(width: 300, alignment: .leading)
        }
    }
}

/// En-tête de section avec son ⓘ.
struct SectionTitle: View {
    let title: String
    let help: String?

    init(_ title: String, help: String? = nil) {
        self.title = title
        self.help = help
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let help { HelpTip(help) }
        }
    }
}

/// Une ligne « libellé — enregistreur de raccourci ».
struct ShortcutRow: View {
    let label: String
    var detail: String? = nil
    var help: String? = nil
    let hotKey: Binding<HotKey?>

    var body: some View {
        HStack {
            Text(label)
            if let help { HelpTip(help) }
            Spacer()
            if let detail {
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
            }
            ShortcutRecorder(hotKey: hotKey)
        }
    }
}

/// Une autorisation système : son état, et le bouton qui ouvre le bon panneau.
struct PermissionRow: View {
    let name: String
    let granted: Bool
    let help: String
    let open: () -> Void

    var body: some View {
        HStack {
            Circle().fill(granted ? Color.green : Color.orange).frame(width: 9, height: 9)
            Text(name)
            HelpTip(help)
            Spacer()
            Text(granted ? "accordée" : "manquante")
                .font(.system(size: 11)).foregroundStyle(granted ? Color.secondary : Color.orange)
            Button("Ouvrir les Réglages Système…", action: open)
                .font(.system(size: 11))
        }
    }
}

/// Commande sélectionnable et copiable d'un clic — la recopier à la main
/// depuis une capture d'écran est le meilleur moyen de se tromper.
struct CopiableCommand: View {
    let command: String

    var body: some View {
        HStack(spacing: 6) {
            Text(command)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copier la commande")
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
    }
}
