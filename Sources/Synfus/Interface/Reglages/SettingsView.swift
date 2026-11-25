import AppKit
import SwiftUI
import SynseriaDesign

/// Les onglets des réglages, dans l'ordre de leur barre : neuf pages, chacune une suite de sections
/// (Statistiques dans Général, Classes dans Personnages, Enchaîner et Attention dans Raccourcis,
/// Invitations dans Palette, Zaaps, Lieux, Trajets, Quêtes et PNJ dans Données, Diagnostic dans
/// Lecture).
enum SettingsSection: String, CaseIterable, Identifiable {
    case general, theme
    case personnages, barre, raccourcis
    case palette, donnees, aides
    case lecture

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: return L("reglages.general")
        case .theme: return L("reglages.theme")
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
        case .general: return "gearshape.fill"
        case .theme: return "paintpalette.fill"
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

/// La fenêtre des réglages, comme celles de toutes les apps Synseria : les onglets sans titre en haut
/// (`BarreDesOnglets`, ils disent où l'on est), puis la page, une colonne centrée, une seule taille pour
/// tous les onglets. La vue remplit la fenêtre : une hauteur fixée dans la vue, plus courte que la
/// fenêtre de toute sa barre de titre, laissait une bande vide sous la plaque.
struct SettingsView: View {
    @ObservedObject private var onglet: OngletReglages
    private let hauteur: CGFloat?

    /// La taille de la fenêtre, barre de titre comprise, la même pour tous les onglets : Général
    /// (hors compteurs des statistiques, qui grandissent avec l'usage) y tient presque, les pages plus
    /// longues défilent ; bornée à l'écran par `SettingsWindowController`.
    static let taille = CGSize(width: Jetons.largeurReglages, height: 760)

    /// Largeur des trois feux de la fenêtre (fermer, réduire, zoom) à gauche de la barre de titre.
    private static let margeFeuxTricolores: CGFloat = 78

    /// `hauteur` : les captures, hors fenêtre, fixent la leur ; dans la fenêtre, la vue la remplit.
    init(onglet: OngletReglages = .shared, hauteur: CGFloat? = nil) {
        self.onglet = onglet
        self.hauteur = hauteur
    }

    var body: some View {
        VStack(spacing: 0) {
            BarreDesOnglets(onglets: SettingsSection.allCases.map { .init(valeur: $0, libelle: $0.label, symbole: $0.icon) },
                            selection: Binding(get: { onglet.section }, set: { onglet.section = $0 }))
                // La barre de titre est transparente et les onglets montent à hauteur
                // des boutons de la fenêtre : le premier onglet passerait sous les
                // trois feux — une marge à gauche les en dégage.
                .padding(.leading, Self.margeFeuxTricolores)
            // La page sur sa plaque pleine, sous les onglets posés sur le fond de la fenêtre.
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                // Le rang par défaut d'un bouton des réglages, y compris hors d'un formulaire (Diagnostic, listes).
                .buttonStyle(BoutonBorde())
                .background(Color.jeton(\.plaque))
                .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon3, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Jetons.rayon3, style: .continuous)
                        .strokeBorder(Color.traitSurVerre, lineWidth: Jetons.epaisseurFilet)
                }
                .padding([.horizontal, .bottom], Jetons.espace2)
        }
        .frame(width: Self.taille.width, height: hauteur)
        .frame(maxHeight: .infinity)
        // Les onglets montent sous la barre de titre transparente, à hauteur des boutons de la fenêtre.
        .ignoresSafeArea(.container, edges: .top)
        .background { FondDeFenetre() }
    }

    @ViewBuilder
    private var detail: some View {
        switch onglet.section {
        case .general: GeneralSettings()
        case .theme: ThemeSettings()
        case .personnages: CharactersSettings()
        case .barre: BarreSettings()
        case .raccourcis: ShortcutsSettings()
        case .palette: PaletteSettings()
        case .donnees: DonneesSettings()
        case .aides: AidesSettings()
        case .lecture: LectureSettings()
        }
    }
}

/// Le fond d'une fenêtre, sous tout son contenu, barre de titre comprise : le matériau du système
/// flouté sur ce qui est derrière, voilé de la page (`UsageDuVerre.clavier`, la même focus ou pas) —
/// le fond de la barre de titre des notes de Synthetic. Le verre nu laissait trop voir le décor autour de
/// la plaque. Transparence réduite, contraste augmenté et captures : le fond plein.
struct FondDeFenetre: View {
    @Environment(\.couleursSynseria) private var c
    @Environment(\.accessibilityReduceTransparency) private var transparenceReduite
    @Environment(\.colorSchemeContrast) private var contraste

    var body: some View {
        if transparenceReduite || contraste == .increased || Ressources.captureDocumentation {
            Color.jeton(\.fondFenetre).ignoresSafeArea()
        } else {
            MateriauDeFenetre()
                .overlay { Rectangle().fill(UsageDuVerre.clavier.teinte(c).couleur).allowsHitTesting(false) }
                .ignoresSafeArea()
        }
    }
}

/// Le matériau du système, toujours actif, même fenêtre non clé : la teinte posée dessus dit le focus.
private struct MateriauDeFenetre: NSViewRepresentable {
    func makeNSView(context _: Context) -> NSVisualEffectView {
        let vue = NSVisualEffectView()
        vue.material = .underWindowBackground
        vue.blendingMode = .behindWindow
        vue.state = .active
        return vue
    }

    func updateNSView(_: NSVisualEffectView, context _: Context) {}
}
