import SwiftUI

// Les briques de dessin propres à Synfus, écrites sur les jetons : voix d'état, surface qui flotte,
// retour de copie. Boutons, segmenté, touche et carte viennent de la trousse (`Interface/Trousse`).

// MARK: - Langage d'état

/// Les deux voix du design system et leurs états : le **plein** dit où je suis (un par zone), le
/// **choix** (`selection`, l'accent en texte) dit ce que j'ai choisi. Sélectionné, survolé et pressé
/// restent trois choses distinctes. Une fenêtre n'a qu'un choix à voix, celui que les flèches
/// déplacent : le choix d'un groupe qui n'a pas le clavier, ou d'un niveau parent, est `inactif` —
/// le même fond, tout en `encre`.
enum EtatVisuel: Equatable {
    case repos, survol, presse, choisi, courant, inactif, desactive

    /// Le choix d'un groupe selon qu'il a le clavier : `voix` (teinté ou plein), sinon `inactif`.
    static func choix(_ voix: EtatVisuel = .choisi, auClavier: Bool) -> EtatVisuel { auClavier ? voix : .inactif }

    /// Du survol d'une zone et de la pression d'un bouton à l'état d'un contrôle au repos.
    init(survole: Bool, presse: Bool = false) {
        self = presse ? .presse : survole ? .survol : .repos
    }

    @MainActor var fond: Color {
        switch self {
        case .repos: .clear
        case .survol: Color.jeton(\.survol)
        case .presse: Color.jeton(\.selection)
        case .choisi: Color.jeton(\.selection)
        case .courant: Color.jeton(\.accent)
        case .inactif: Color.jeton(\.selection)
        case .desactive: Color.jeton(\.creux)
        }
    }

    /// L'encre du contenu : un contenu à voix s'écrit en encres, jamais en blanc conditionnel.
    @MainActor var encre: Color {
        switch self {
        case .courant: Color.jeton(\.texteSurAccent)
        case .choisi: Color.jeton(\.accentTexte)
        case .desactive: Color.jeton(\.encre3)
        case .repos, .survol, .presse, .inactif: Color.jeton(\.encre)
        }
    }
}

extension View {
    /// Le fond d'un élément selon son état, au rayon de son cran ; seules la couleur et l'opacité s'animent.
    func fondEtat(_ etat: EtatVisuel, rayon: CGFloat = Jetons.rayon1) -> some View {
        let forme = RoundedRectangle(cornerRadius: rayon, style: .continuous)
        return background(forme.fill(etat.fond))
            .contentShape(forme)
            .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: etat)
    }

    /// Ce qui flotte sur le jeu : barre, palette, panneaux, aperçus. Le verre léger des flottants
    /// (la teinte `UsageDuVerre.inerte` dessous), sans liseré : le verre dessine son bord. Rayon `rayon3`,
    /// sans ombre (ni SwiftUI ni `hasShadow` de la fenêtre). Le texte long va sur une `plaquePleine`.
    func surfaceFlottante() -> some View {
        modifier(SurfaceFlottante())
    }

    /// Le contenu d'un flottant (résultats de la palette, corps d'un panneau) : la plaque pleine, son
    /// filet, `rayon2` — jamais de texte long sur le verre.
    func plaquePleine() -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        return background(Color.jeton(\.plaque), in: forme)
            .overlay { forme.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet) }
    }
}

private struct SurfaceFlottante: ViewModifier {
    @Environment(\.couleursSynseria) private var c
    @Environment(\.accessibilityReduceTransparency) private var transparenceReduite
    @Environment(\.colorSchemeContrast) private var contraste

    func body(content: Content) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon3, style: .continuous)
        // « Réduire la transparence » et « Augmenter le contraste » refusent le verre : le fond plein
        // reprend son filet. `cacheDisplay` (captures) ne dessine pas le verre, qui échantillonne l'écran.
        if transparenceReduite || contraste == .increased || Ressources.captureDocumentation {
            content
                .background(Color.jeton(\.fondFenetre), in: forme)
                .overlay(forme.strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet))
        } else {
            // La teinte sous le verre : au-dessus, elle couvrirait son reflet.
            content
                .glassEffect(.regular, in: .rect(cornerRadius: Jetons.rayon3))
                .background { forme.fill(UsageDuVerre.inerte.teinte(c).couleur).allowsHitTesting(false) }
        }
    }
}

// MARK: - Tuiles et puces

/// Une tuile ou une puce cliquable : fond `creux` au repos, `survol`, `selection` pressée, puis le
/// choix si elle est choisie, pleine si elle dit où l'on est. Désactivée, `encre3` sur `creux`.
struct StyleEtat: ButtonStyle {
    var choisi = false
    var courant = false
    var rayon = Jetons.rayon1
    /// Une puce nue, sans tuile `creux` au repos.
    var nue = false

    func makeBody(configuration: Configuration) -> some View {
        Contenu(configuration: configuration, style: self)
    }

    private struct Contenu: View {
        let configuration: Configuration
        let style: StyleEtat
        @Environment(\.isEnabled) private var actif
        @Environment(\.groupeAuClavier) private var auClavier
        @State private var survole = false

        var body: some View {
            let etat: EtatVisuel = !actif ? .desactive : style.courant ? .courant : style.choisi ? .choix(auClavier: auClavier)
                : configuration.isPressed ? .presse : survole ? .survol : .repos
            configuration.label
                .foregroundStyle(etat.encre)
                .background {
                    if etat == .repos, !style.nue {
                        RoundedRectangle(cornerRadius: style.rayon, style: .continuous).fill(Color.jeton(\.creux))
                    }
                }
                // Une puce nue désactivée n'a pas de tuile : l'encre tertiaire suffit.
                .fondEtat(style.nue && etat == .desactive ? .repos : etat, rayon: style.rayon)
                .onHover { survole = $0 }
                // Ce qui se clique le montre, comme les boutons de la trousse.
                .curseurDeClic(actif)
        }
    }
}

extension ButtonStyle where Self == StyleEtat {
    static func etat(choisi: Bool = false, courant: Bool = false, rayon: CGFloat = Jetons.rayon1,
                     nue: Bool = false) -> StyleEtat {
        StyleEtat(choisi: choisi, courant: courant, rayon: rayon, nue: nue)
    }
}

extension View {
    /// Le texte d'un bouton sans texte : l'infobulle, et son nom pour VoiceOver,
    /// que `.help` ne donne pas.
    func aide(_ texte: String) -> some View { help(texte).accessibilityLabel(texte) }
}

// MARK: - Autorisation manquante

/// L'enregistrement de l'écran, qu'un panneau qui lit le jeu n'a pas : la même ligne partout, et le
/// même geste pour y remédier ; l'explication est son infobulle.
struct LigneAutorisation: View {
    var body: some View {
        HStack(spacing: Jetons.espace1) {
            Image(systemName: "lock").foregroundStyle(Color.jeton(\.encre2))
            Text(L("autorisation.lecture"))
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.encre2))
                // Dans un panneau étroit, le libellé passe sur deux lignes avant que le geste ne se coupe.
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button(L("autorisation.autoriser")) { WindowPreviewService.shared.requestAuthorization() }
                .buttonStyle(BoutonBorde())
                .fixedSize()
        }
        .help(L("autorisation.aide"))
    }
}

// MARK: - Retour de copie

/// « C'est dans le presse-papiers » : un seul signe, `IconeCopie`, pendant une seule durée, quelle que
/// soit la surface. Une surface porte un `SignalCopie` et dit quelle ligne vient d'être copiée ; une
/// nouvelle copie remplace la précédente sans que l'ancien délai ne l'efface.
@MainActor
final class SignalCopie: ObservableObject {
    /// `Jetons` est engendré et n'a pas de durée de ce genre : celle-ci est la seule de l'app.
    static let duree: Duration = .seconds(1.2)

    @Published private(set) var ligne: String?
    private let attendre: @MainActor () async -> Void
    private var effacement: Task<Void, Never>?

    /// `attendre` : le délai avant l'effacement, que les tests commandent à la main.
    init(attendre: @escaping @MainActor () async -> Void = { try? await Task.sleep(for: SignalCopie.duree) }) {
        self.attendre = attendre
    }

    func signaler(_ ligne: String) {
        effacement?.cancel()
        self.ligne = ligne
        effacement = Task {
            await attendre()
            guard !Task.isCancelled else { return }
            self.ligne = nil
        }
    }

    func affiche(_ ligne: String) -> Bool { self.ligne == ligne }
}

/// L'icône d'une ligne copiable, qui devient une coche le temps du signal. Les deux se superposent :
/// la place est celle de l'icône, le texte ne bouge pas. Sans `icone`, la coche seule, dans une place
/// réservée.
struct IconeCopie: View {
    let icone: String?
    let copie: Bool

    var body: some View {
        ZStack {
            if let icone { Image(systemName: icone).opacity(copie ? 0 : 1) }
            Image(systemName: "checkmark")
                .foregroundStyle(Color.jeton(\.accentTexte))
                .opacity(copie ? 1 : 0)
        }
    }
}
