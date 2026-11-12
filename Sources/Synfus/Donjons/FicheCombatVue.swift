import SwiftUI

/// Niveau, vie, PA et PM d'un monstre à son plus haut grade, ses
/// résistances, et les éléments à frapper ou à éviter qu'elles disent : le
/// panneau d'aide aux boss et la fiche d'un donjon.
struct FicheCombatVue: View {
    let fiche: FicheCombat

    var body: some View {
        let res = fiche.resistances
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            Text(L("combat.fiche", fiche.niveau, fiche.vie.formatted(), fiche.pa, fiche.pm))
                .font(.synfus(.raccourci))
            Text(L("combat.fiche.resistances", res[.neutre] ?? 0, res[.terre] ?? 0, res[.feu] ?? 0,
                   res[.eau] ?? 0, res[.air] ?? 0))
                .font(.synfus(.petit))
                .foregroundStyle(Couleurs.encreSecondaire)
                .fixedSize(horizontal: false, vertical: true)
            let elements = fiche.elements
            if !elements.frapper.isEmpty {
                Text(L("combat.fiche.elements", Self.noms(elements.frapper), Self.noms(elements.eviter)))
                    .font(.synfus(.petit))
                    .foregroundStyle(Couleurs.primaireEncre)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .help(L("combat.fiche.aide"))
    }

    private static func noms(_ elements: [FicheCombat.Element]) -> String {
        elements.map { element in
            switch element {
            case .neutre: return L("element.neutre")
            case .terre: return L("element.terre")
            case .feu: return L("element.feu")
            case .eau: return L("element.eau")
            case .air: return L("element.air")
            }
        }
        .joined(separator: ", ")
    }
}
