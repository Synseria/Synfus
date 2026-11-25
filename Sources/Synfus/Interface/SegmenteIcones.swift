import SwiftUI

/// Des onglets en segmenté pleine largeur, chacun une icône et un libellé (`SegmenteTexte` n'a que du
/// texte et prend le focus) : la pilule et le filet du segmenté, le choisi sur le fond du choix.
/// Aucun cran ne prend le focus : le clavier reste là où il est tenu (la palette : ←/→).
struct SegmenteIcones<Valeur: Hashable>: View {
    struct Option {
        let valeur: Valeur
        let titre: String
        let symbole: String
        var aide: String?
    }

    let titre: String
    let options: [Option]
    let selection: Valeur?
    let choisir: (Valeur) -> Void

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            ForEach(options, id: \.valeur) { option in
                let choisi = option.valeur == selection
                Button { choisir(option.valeur) } label: {
                    Label(option.titre, systemImage: option.symbole)
                        .font(Jetons.typoMeta.font)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, Jetons.espace2)
                        // Les crans se partagent la largeur ; aucun ne descend sous son libellé.
                        .frame(maxWidth: .infinity)
                        .frame(height: Jetons.hauteurCase)
                        .contentShape(Capsule(style: .circular))
                }
                .buttonStyle(.etat(choisi: choisi, rayon: Jetons.hauteurCase / 2, nue: true))
                .elementDeGroupe()
                .help(option.aide ?? option.titre)
                .accessibilityAddTraits(choisi ? .isSelected : [])
            }
        }
        // Le filet entoure l'air du segmenté, il ne le mange pas, comme `SegmenteTexte`. Des bouts ronds :
        // en coins continus, une pilule si large finit en galet.
        .padding(Jetons.espace1 + Jetons.epaisseurFilet)
        .background(Color.jeton(\.fondFenetre), in: Capsule(style: .circular))
        .overlay { Capsule(style: .circular).strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(titre)
    }
}
