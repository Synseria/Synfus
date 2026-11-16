import SwiftUI

/// Les conseils de Dofus pour les noobs pour un combat : une phrase par
/// conseil, l'explication du site en infobulle, la source pour finir.
struct ConseilsVue: View {
    let conseils: [ConseilCombat]

    var body: some View {
        ForEach(Array(conseils.enumerated()), id: \.offset) { _, conseil in
            Text("• " + conseil.titre)
                .font(Jetons.Typo.petit.police)
                .fixedSize(horizontal: false, vertical: true)
                .help(conseil.detail)
        }
        Text(L("donjon.conseils.source"))
            .font(Jetons.Typo.petit.police)
            .foregroundStyle(Color.jeton(\.encreTertiaire))
    }
}
