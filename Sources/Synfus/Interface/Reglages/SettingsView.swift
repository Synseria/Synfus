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
    case general, theme, barre
    case raccourcis, attention, enchainer, invitations
    case palette, trajets, chasse, boss
    case zaaps, lieux, quetes, pnj
    case persos, classes
    case lecture, diagnostic, usage

    var id: String { rawValue }

    var groupe: GroupeReglages {
        switch self {
        case .general, .theme, .barre: return .synfus
        case .raccourcis, .attention, .enchainer, .invitations: return .clavier
        case .palette, .trajets, .chasse, .boss: return .jeu
        case .zaaps, .lieux, .quetes, .pnj: return .donnees
        case .persos, .classes: return .persos
        case .lecture, .diagnostic, .usage: return .avance
        }
    }

    var label: String {
        switch self {
        case .general: return L("reglages.general")
        case .theme: return L("reglages.theme")
        case .barre: return L("reglages.barre")
        case .raccourcis: return L("reglages.raccourcis")
        case .attention: return L("reglages.attention")
        case .enchainer: return L("reglages.enchainer")
        case .invitations: return L("reglages.invitations")
        case .palette: return L("reglages.palette")
        case .trajets: return L("reglages.trajets")
        case .chasse: return L("chasse.titre")
        case .boss: return L("boss.titre")
        case .zaaps: return L("reglages.zaaps")
        case .lieux: return L("reglages.lieux")
        case .quetes: return L("reglages.quetes")
        case .pnj: return L("reglages.pnj")
        case .persos: return L("reglages.persos")
        case .classes: return L("reglages.classes")
        case .lecture: return L("reglages.lecture")
        case .diagnostic: return L("reglages.diagnostic")
        case .usage: return L("reglages.usage")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .theme: return "swatchpalette"
        case .barre: return "rectangle.topthird.inset.filled"
        case .raccourcis: return "keyboard"
        case .attention: return "bolt"
        case .enchainer: return "cursorarrow.click"
        case .invitations: return "person.badge.plus"
        case .palette: return "command"
        case .trajets: return "arrow.triangle.turn.up.right.diamond"
        case .chasse: return "map"
        case .boss: return "scope"
        case .zaaps: return "point.3.connected.trianglepath.dotted"
        case .lieux: return "mappin.and.ellipse"
        case .quetes: return "scroll"
        case .pnj: return "person.wave.2"
        case .persos: return "person.3"
        case .classes: return "paintpalette"
        case .lecture: return "text.viewfinder"
        case .diagnostic: return "stethoscope"
        case .usage: return "chart.bar"
        }
    }
}

/// L'onglet montré : d'autres écrans y mènent d'un clic
/// (`SettingsWindowController.show(section:)`) plutôt que de dire
/// « Réglages › … ».
@MainActor
final class OngletReglages: ObservableObject {
    static let shared = OngletReglages()

    @Published var section: SettingsSection

    init(_ section: SettingsSection = .general) {
        self.section = section
    }
}

struct SettingsView: View {
    @ObservedObject private var onglet: OngletReglages
    @State private var survol: SettingsSection?

    init(onglet: OngletReglages = .shared) {
        self.onglet = onglet
    }

    private var section: SettingsSection { onglet.section }

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
        // La teinte des fonds choisie dans Thème : celle de la fenêtre, que le formulaire laisse voir.
        .background(Color.jeton(\.fenetre))
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                ForEach(GroupeReglages.allCases, id: \.self) { groupe in
                    if let titre = groupe.titre {
                        Text(titre)
                            .font(Jetons.Typo.raccourci.police)
                            .foregroundStyle(Color.jeton(\.encreSecondaire))
                            .padding(.horizontal, Jetons.Espace.deux)
                            .padding(.top, Jetons.Espace.deux)
                            .padding(.bottom, Jetons.Espace.un)
                    }
                    ForEach(SettingsSection.allCases.filter { $0.groupe == groupe }) { item in
                        sidebarRow(item)
                    }
                }
            }
            .padding(Jetons.Espace.deux)
        }
        .frame(width: 170)
        .background(Color.jeton(\.creux))
    }

    private func sidebarRow(_ item: SettingsSection) -> some View {
        Button {
            onglet.section = item
        } label: {
            HStack(spacing: Jetons.Espace.deux) {
                Image(systemName: item.icon).frame(width: Jetons.Taille.touche)
                Text(item.label)
            }
                .font((section == item ? Jetons.Typo.corpsFort : Jetons.Typo.corps).police)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Jetons.Espace.deux)
                .padding(.vertical, Jetons.Espace.un)
                .foregroundStyle((section == item ? EtatVisuel.courant : .repos).encre)
                .fondEtat(section == item ? .courant : (survol == item ? .survol : .repos))
        }
        .buttonStyle(.plain)
        .onHover { survol = $0 ? item : nil }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .general: GeneralSettings()
        case .theme: ThemeSettings()
        case .barre: BarreSettings()
        case .raccourcis: ShortcutsSettings()
        case .attention: AttentionSettings()
        case .enchainer: EnchainerSettings()
        case .invitations: InvitationsSettings()
        case .palette: PaletteSettings()
        case .trajets: TrajetsSettings()
        case .chasse: ChasseSettings()
        case .boss: BossSettings()
        case .zaaps: ZaapsSettings()
        case .lieux: LieuxSettings()
        case .quetes: QuetesSettings()
        case .pnj: PNJSettings()
        case .persos: CharactersSettings()
        case .classes: ClassesSettings()
        case .lecture: LectureSettings()
        case .diagnostic: DiagnosticSettings()
        case .usage: UsageSettings()
        }
    }
}
