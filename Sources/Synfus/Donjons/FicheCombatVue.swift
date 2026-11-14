import SwiftUI

/// Niveau, vie, PA et PM d'un monstre à son plus haut grade, puis ses
/// résistances en cinq colonnes, les éléments à frapper et à éviter marqués :
/// le panneau d'aide aux boss et la fiche d'un donjon.
struct FicheCombatVue: View {
    let fiche: FicheCombat

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            Text(L("combat.fiche", fiche.niveau, fiche.vie.formatted(), fiche.pa, fiche.pm))
                .font(Jetons.Typo.raccourci.police)
            HStack(spacing: Jetons.Espace.un) {
                ForEach(FicheCombat.Element.allCases, id: \.self) { colonne($0) }
            }
        }
        .help(aide)
    }

    private func colonne(_ element: FicheCombat.Element) -> some View {
        let role = fiche.role(element)
        return VStack(spacing: 0) {
            HStack(spacing: 0) {
                if role == .frapper { Image(systemName: "arrow.down") }
                Text(Self.nom(element))
            }
            .font(Jetons.Typo.micro.police)
            .foregroundStyle(role == .frapper ? Color.jeton(\.primaireEncre) : Color.jeton(\.encreSecondaire))
            Text(L("combat.fiche.pourcentage", fiche.resistances[element] ?? 0))
                .font(Jetons.Typo.chiffre.police)
                .foregroundStyle(role == .frapper ? Color.jeton(\.primaireEncre)
                                 : role == .eviter ? Color.jeton(\.encreTertiaire) : Color.jeton(\.encre))
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity)
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

    /// En tête de colonne : la majuscule d'un titre.
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
