import AppKit
import SwiftUI
import SynseriaDesign

/// Les onglets propres à Synfus, dans l'ordre de leur barre ; Général et Thème, communs, la trousse les
/// range après eux (`CadreDesReglages`). Chacun est une suite de sections (Classes dans Personnages,
/// Enchaîner et Attention dans Raccourcis, Invitations dans Palette, Zaaps, Lieux, Trajets, Quêtes et PNJ
/// dans Données, Diagnostic dans Lecture).
enum SettingsSection: String, CaseIterable, Identifiable {
    case personnages, barre, raccourcis
    case palette, donnees, aides
    case lecture

    var id: String { rawValue }

    var label: String {
        switch self {
        case .personnages: return L("reglages.personnages")
        case .barre: return L("reglages.barre")
        case .raccourcis: return L("reglages.raccourcis")
        case .palette: return L("reglages.palette")
        case .donnees: return L("reglages.donnees")
        case .aides: return L("reglages.aides")
        case .lecture: return L("reglages.lecture")
        }
    }

    var icon: String {
        switch self {
        case .personnages: return "person.2.fill"
        case .barre: return "line.3.horizontal"
        case .raccourcis: return "keyboard.fill"
        case .palette: return BoutonBarre.palette.symbole
        case .donnees: return "map.fill"
        case .aides: return BoutonBarre.boss.symbole
        case .lecture: return "text.viewfinder"
        }
    }
}

/// Un onglet de la fenêtre : ceux de Synfus, puis Général et Thème.
typealias OngletSynfus = OngletDesReglages<SettingsSection>

/// L'onglet montré : d'autres écrans y mènent d'un clic
/// (`SettingsWindowController.show(onglet:)`) plutôt que de dire
/// « Réglages › … ».
@MainActor
final class OngletReglages: ObservableObject {
    static let shared = OngletReglages()

    @Published var onglet: OngletSynfus

    init(_ onglet: OngletSynfus = .general) {
        self.onglet = onglet
    }
}

/// La fenêtre des réglages, celle de toutes les apps Synseria (`CadreDesReglages`) : l'en-tête en verre et
/// ses onglets, puis le volet sur sa plaque. Synfus n'y met que ses volets et ses mots.
struct SettingsView: View {
    @ObservedObject private var onglet: OngletReglages
    @ObservedObject private var prefs = Preferences.shared
    private let hauteur: CGFloat?

    /// `hauteur` : les captures, hors fenêtre, fixent la leur ; dans la fenêtre, la vue la remplit.
    init(onglet: OngletReglages = .shared, hauteur: CGFloat? = nil) {
        self.onglet = onglet
        self.hauteur = hauteur
    }

    /// Les mots communs, dans la langue où Synfus s'affiche.
    static var libelles: Jetons.LibellesDesReglages { .langue(L10n.courante.langue.rawValue) }

    var body: some View {
        CadreDesReglages(propres: SettingsSection.allCases.map { .init(valeur: $0, libelle: $0.label, symbole: $0.icon) },
                         selection: $onglet.onglet, theme: $prefs.themeDeLApp, libelles: Self.libelles,
                         libellesDuTheme: .synfus, colonne: Jetons.largeurColonne) {
            GeneralSettings()
        } volet: { section in
            switch section {
            case .personnages: CharactersSettings()
            case .barre: BarreSettings()
            case .raccourcis: ShortcutsSettings()
            case .palette: PaletteSettings()
            case .donnees: DonneesSettings()
            case .aides: AidesSettings()
            case .lecture: LectureSettings()
            }
        }
        .frame(width: hauteur == nil ? nil : FenetreDeReglages.taille.width, height: hauteur)
    }
}
