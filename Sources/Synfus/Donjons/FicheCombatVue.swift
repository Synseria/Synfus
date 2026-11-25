import SwiftUI

/// Niveau, vie, PA et PM d'un monstre à son plus haut grade, puis ses
/// résistances en cinq colonnes, les éléments à frapper et à éviter marqués :
/// le panneau d'aide aux boss et la fiche d'un donjon.
struct FicheCombatVue: View {
    let fiche: FicheCombat

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            Text(L("combat.fiche", fiche.niveau, fiche.vie.formatted(), fiche.pa, fiche.pm))
                .font(Jetons.typoMeta.font.weight(.semibold))
                .foregroundStyle(Color.jeton(\.encre))
            HStack(spacing: Jetons.espace1) {
                ForEach(FicheCombat.Element.allCases, id: \.self) { colonne($0) }
            }
        }
        .help(aide)
    }

    /// Un élément : son signe en couleur, sa résistance dessous. À frapper, sur un fond de sélection
    /// à l'accent ; à éviter, effacé. Le nom de l'élément au survol : écrit en tête, il se coupait.
    private func colonne(_ element: FicheCombat.Element) -> some View {
        let role = fiche.role(element)
        let resistance = fiche.resistances[element] ?? 0
        return VStack(spacing: 0) {
            Image(systemName: element.symbole)
                .resizable().scaledToFit()
                .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
                .foregroundStyle(element.teinte)
            Text(L("combat.fiche.pourcentage", resistance))
                .font(Jetons.typoTitreCarte.font.monospacedDigit())
                .foregroundStyle(role == .frapper ? Color.jeton(\.accentTexte)
                                 : role == .eviter ? Color.jeton(\.encre3) : Color.jeton(\.encre))
        }
        .lineLimit(1)
        .padding(.vertical, Jetons.espace1)
        .frame(maxWidth: .infinity)
        .background {
            if role == .frapper { RoundedRectangle(cornerRadius: Jetons.rayon1).fill(Color.jeton(\.selection)) }
        }
        .opacity(role == .eviter ? 0.6 : 1)
        .help(L("combat.fiche.resistance", Self.nom(element), resistance))
        .accessibilityElement(children: .combine)
    }

    /// Ce que les résistances disent de frapper, à défaut le grade lu.
    private var aide: String {
        let elements = fiche.elements
        guard !elements.frapper.isEmpty else { return L("combat.fiche.aide") }
        return L("combat.fiche.elements", Self.noms(elements.frapper), Self.noms(elements.eviter))
    }

    private static func noms(_ elements: [FicheCombat.Element]) -> String {
        elements.map(nom).joined(separator: ", ")
    }

    /// Au survol d'une colonne : la majuscule d'un titre.
    private static func nom(_ element: FicheCombat.Element) -> String {
        let nom: String
        switch element {
        case .neutre: nom = L("element.neutre")
        case .terre: nom = L("element.terre")
        case .feu: nom = L("element.feu")
        case .eau: nom = L("element.eau")
        case .air: nom = L("element.air")
        }
        return nom.prefix(1).uppercased() + nom.dropFirst()
    }
}

extension FicheCombat.Element {
    /// Le signe d'un élément, le même partout où un élément se montre.
    var symbole: String {
        switch self {
        case .neutre: "circle.circle"
        case .feu: "flame.fill"
        case .eau: "drop.fill"
        case .terre: "mountain.2.fill"
        case .air: "wind"
        }
    }

    /// Les éléments dans les teintes d'état du thème, au plus près de celles du jeu.
    @MainActor var teinte: Color {
        switch self {
        case .neutre: Color.jeton(\.encre2)
        case .feu: Color.jeton(\.danger)
        case .eau: Color.jeton(\.info)
        case .terre: Color.jeton(\.avertissement)
        case .air: Color.jeton(\.succes)
        }
    }
}
