import SwiftUI

/// Les groupes de la barre latérale : peu de réglages par onglet, des
/// onglets rangés par sujet.
enum GroupeReglages: CaseIterable {
    case synfus, clavier, jeu, donnees, persos, avance

    var titre: String? {
        switch self {
        case .synfus: return nil
        case .clavier: return L("reglages.groupe.clavier")
        case .jeu: return L("reglages.groupe.jeu")
        case .donnees: return L("reglages.groupe.donnees")
        case .persos: return L("reglages.groupe.persos")
        case .avance: return L("reglages.groupe.avance")
        }
    }
}

/// Sections des réglages, listées dans la barre latérale.
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, barre
    case raccourcis, attention, enchainer, invitations
    case palette, trajets, chasse
    case zaaps, lieux, quetes, pnj
    case persos, classes
    case lecture, diagnostic

    var id: String { rawValue }

    var groupe: GroupeReglages {
        switch self {
        case .general, .barre: return .synfus
        case .raccourcis, .attention, .enchainer, .invitations: return .clavier
        case .palette, .trajets, .chasse: return .jeu
        case .zaaps, .lieux, .quetes, .pnj: return .donnees
        case .persos, .classes: return .persos
        case .lecture, .diagnostic: return .avance
        }
    }

    var label: String {
        switch self {
        case .general: return L("reglages.general")
        case .barre: return L("reglages.barre")
        case .raccourcis: return L("reglages.raccourcis")
        case .attention: return L("reglages.attention")
        case .enchainer: return L("reglages.enchainer")
        case .invitations: return L("reglages.invitations")
        case .palette: return L("reglages.palette")
        case .trajets: return L("reglages.trajets")
        case .chasse: return L("chasse.titre")
        case .zaaps: return L("reglages.zaaps")
        case .lieux: return L("reglages.lieux")
        case .quetes: return L("reglages.quetes")
        case .pnj: return L("reglages.pnj")
        case .persos: return L("reglages.persos")
        case .classes: return L("reglages.classes")
        case .lecture: return L("reglages.lecture")
        case .diagnostic: return L("reglages.diagnostic")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .barre: return "rectangle.topthird.inset.filled"
        case .raccourcis: return "keyboard"
        case .attention: return "bolt"
        case .enchainer: return "cursorarrow.click"
        case .invitations: return "person.badge.plus"
        case .palette: return "command"
        case .trajets: return "arrow.triangle.turn.up.right.diamond"
        case .chasse: return "map"
        case .zaaps: return "point.3.connected.trianglepath.dotted"
        case .lieux: return "mappin.and.ellipse"
        case .quetes: return "scroll"
        case .pnj: return "person.wave.2"
        case .persos: return "person.3"
        case .classes: return "paintpalette"
        case .lecture: return "text.viewfinder"
        case .diagnostic: return "stethoscope"
        }
    }
}

struct SettingsView: View {
    @State private var section: SettingsSection

    init(section: SettingsSection = .general) {
        _section = State(initialValue: section)
    }

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
        .frame(width: 920, height: 680)
        .tint(Couleurs.accent)
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(GroupeReglages.allCases, id: \.self) { groupe in
                    if let titre = groupe.titre {
                        Text(titre)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.top, 10)
                            .padding(.bottom, 2)
                    }
                    ForEach(SettingsSection.allCases.filter { $0.groupe == groupe }) { item in
                        sidebarRow(item)
                    }
                }
            }
            .padding(8)
        }
        .frame(width: 170)
        .background(Color.primary.opacity(0.035))
    }

    private func sidebarRow(_ item: SettingsSection) -> some View {
        Button {
            section = item
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon).frame(width: 18)
                Text(item.label)
            }
                .font(.system(size: 12, weight: section == item ? .semibold : .regular))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(section == item ? Couleurs.accent : Color.clear)
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
        case .barre: BarreSettings()
        case .raccourcis: ShortcutsSettings()
        case .attention: AttentionSettings()
        case .enchainer: EnchainerSettings()
        case .invitations: InvitationsSettings()
        case .palette: PaletteSettings()
        case .trajets: TrajetsSettings()
        case .chasse: ChasseSettings()
        case .zaaps: ZaapsSettings()
        case .lieux: LieuxSettings()
        case .quetes: QuetesSettings()
        case .pnj: PNJSettings()
        case .persos: CharactersSettings()
        case .classes: ClassesSettings()
        case .lecture: LectureSettings()
        case .diagnostic: DiagnosticSettings()
        }
    }
}
