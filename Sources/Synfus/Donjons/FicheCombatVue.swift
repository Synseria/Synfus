import SwiftUI

/// Niveau, vie, PA et PM d'un monstre à son plus haut grade, puis ses
/// résistances : le panneau d'aide aux boss et la fiche d'un donjon.
struct FicheCombatVue: View {
    let fiche: FicheCombat

    var body: some View {
        let res = fiche.resistances
        VStack(alignment: .leading, spacing: 2) {
            Text(L("combat.fiche", fiche.niveau, fiche.vie.formatted(), fiche.pa, fiche.pm))
                .font(.synfus(.petit, gras: true))
            Text(L("combat.fiche.resistances", res[.neutre] ?? 0, res[.terre] ?? 0, res[.feu] ?? 0,
                   res[.eau] ?? 0, res[.air] ?? 0))
                .font(.synfus(.petit))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(L("combat.fiche.aide"))
    }
}
