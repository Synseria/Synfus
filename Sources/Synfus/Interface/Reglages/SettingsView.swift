import SwiftUI

/// Sections des réglages, listées dans la barre latérale.
private enum SettingsSection: String, CaseIterable, Identifiable {
    case general, raccourcis, persos, sorts, classes, diagnostic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return "Général"
        case .raccourcis: return "Raccourcis"
        case .persos: return "Persos"
        case .sorts: return "Sorts"
        case .classes: return "Classes"
        case .diagnostic: return "Diagnostic"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .raccourcis: return "keyboard"
        case .persos: return "person.3"
        case .sorts: return "wand.and.stars"
        case .classes: return "paintpalette"
        case .diagnostic: return "stethoscope"
        }
    }
}

struct SettingsView: View {
    @State private var section: SettingsSection = .general

    /// Barre latérale à gauche, contenu à droite : les quatre sections en
    /// onglets faisaient défiler des formulaires interminables — le menu
    /// vertical garde tout sous les yeux.
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 680, height: 480)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(SettingsSection.allCases) { item in
                sidebarRow(item)
            }
            Spacer()
        }
        .padding(8)
        .frame(width: 150)
        .background(Color.primary.opacity(0.035))
    }

    private func sidebarRow(_ item: SettingsSection) -> some View {
        Button {
            section = item
        } label: {
            Label(item.label, systemImage: item.icon)
                .font(.system(size: 12, weight: section == item ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(section == item ? Color.accentColor : Color.clear)
                )
                .foregroundStyle(section == item ? Color.white : Color.primary)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .general: GeneralSettings()
        case .raccourcis: ShortcutsSettings()
        case .persos: CharactersSettings()
        case .sorts: SpellsSettings()
        case .classes: ClassesSettings()
        case .diagnostic: DiagnosticSettings()
        }
    }
}
