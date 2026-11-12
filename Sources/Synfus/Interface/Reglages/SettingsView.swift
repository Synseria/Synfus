import SwiftUI

/// Les groupes de la barre latérale : quatre petits titres, jamais repliables.
enum GroupeReglages: CaseIterable {
    case synfus, personnages, jeu, avance

    var titre: String {
        switch self {
        case .synfus: return L("reglages.groupe.synfus")
        case .personnages: return L("reglages.groupe.personnages")
        case .jeu: return L("reglages.groupe.jeu")
        case .avance: return L("reglages.groupe.avance")
        }
    }
}

/// Sections des réglages, listées dans la barre latérale : dix entrées, chacune une page dont les blocs
/// reprennent les anciens onglets (Statistiques dans Général, Classes dans Personnages, Enchaîner et
/// Attention dans Raccourcis, Invitations dans Palette, Zaaps, Lieux et Trajets dans Carte, PNJ dans
/// Quêtes, Diagnostic dans Lecture de l'écran).
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, theme
    case personnages, barre, raccourcis
    case palette, carte, quetes, aides
    case lecture

    var id: String { rawValue }

    var groupe: GroupeReglages {
        switch self {
        case .general, .theme: return .synfus
        case .personnages, .barre, .raccourcis: return .personnages
        case .palette, .carte, .quetes, .aides: return .jeu
        case .lecture: return .avance
        }
    }

    var label: String {
        switch self {
        case .general: return L("reglages.general")
        case .theme: return L("reglages.theme")
        case .personnages: return L("reglages.personnages")
        case .barre: return L("reglages.barre")
        case .raccourcis: return L("reglages.raccourcis")
        case .palette: return L("reglages.palette")
        case .carte: return L("reglages.carte")
        case .quetes: return L("reglages.quetes")
        case .aides: return L("reglages.aides")
        case .lecture: return L("reglages.lecture")
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .theme: return "swatchpalette"
        case .personnages: return "person.3"
        case .barre: return "rectangle.topthird.inset.filled"
        case .raccourcis: return "keyboard"
        case .palette: return "command"
        case .carte: return "map"
        case .quetes: return "scroll"
        case .aides: return "scope"
        case .lecture: return "text.viewfinder"
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
    private let hauteur: CGFloat

    /// `hauteur` : celle de la fenêtre ; les captures d'une page longue la rendent entière.
    init(onglet: OngletReglages = .shared, hauteur: CGFloat = 680) {
        self.onglet = onglet
        self.hauteur = hauteur
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
                // Le rang par défaut d'un bouton des réglages, y compris hors d'un `Form` (Diagnostic, listes).
                .buttonStyle(.bouton(.secondaire))
        }
        .frame(width: 920, height: hauteur)
        // La teinte des fonds choisie dans Thème : celle de la fenêtre, que le formulaire laisse voir.
        .background(Color.jeton(\.fenetre))
    }

    private var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                ForEach(GroupeReglages.allCases, id: \.self) { groupe in
                    Text(groupe.titre)
                        .font(Jetons.Typo.raccourci.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                        .padding(.horizontal, Jetons.Espace.deux)
                        .padding(.top, Jetons.Espace.deux)
                        .padding(.bottom, Jetons.Espace.un)
                    ForEach(SettingsSection.allCases.filter { $0.groupe == groupe }) { item in
                        sidebarRow(item)
                    }
                }
            }
            .padding(Jetons.Espace.deux)
            .groupeSelection(L("reglages.titre"), selection: Binding(get: { onglet.section }, set: { onglet.section = $0 }),
                             parmi: GroupeReglages.allCases.flatMap { groupe in
                                 SettingsSection.allCases.filter { $0.groupe == groupe }
                             }, disposition: .verticale)
        }
        .frame(width: 196)
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
        .elementDeGroupe()
        .onHover { survol = $0 ? item : nil }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .general: GeneralSettings()
        case .theme: ThemeSettings()
        case .personnages: CharactersSettings()
        case .barre: BarreSettings()
        case .raccourcis: ShortcutsSettings()
        case .palette: PaletteSettings()
        case .carte: CarteSettings()
        case .quetes: QuetesSettings()
        case .aides: AidesSettings()
        case .lecture: LectureSettings()
        }
    }
}
