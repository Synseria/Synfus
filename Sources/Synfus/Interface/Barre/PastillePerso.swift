import SwiftUI

/// Ce que dit une pastille de perso — emblème, nom, classe, touche — sur son fond d'état : la barre la
/// pose dans son bouton, l'aperçu du thème la montre telle quelle.
struct PastillePerso: View {
    let nom: String
    let classe: String?
    /// Ce que la pastille écrit de la classe, quand ce n'est pas le nom lu dans le titre du jeu.
    var libelleClasse: String?
    let devant: Bool
    /// Fermeture en cours : elle prend la place de l'emblème, le geste a été entendu.
    var enFermeture = false
    /// Un perso sur un autre bureau : son nom est en retrait.
    var dormant = false
    let touche: String
    let affichage: AffichagePastille
    var survole = false

    var body: some View {
        HStack(spacing: Jetons.Espace.un) {
            if enFermeture {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: Jetons.Taille.touche + Jetons.Trait.focus, height: Jetons.Taille.touche + Jetons.Trait.focus)
            } else if affichage.embleme {
                EmblemeClasse(classe: classe,
                              contour: devant ? Color.jeton(\.encreSurPrimaire) : Color.jeton(\.filet))
            }

            if affichage.nom {
                VStack(alignment: .leading, spacing: 0) {
                    Text(nom)
                        .font((devant ? Jetons.Typo.corpsFort : Jetons.Typo.corps).police)
                        .lineLimit(1)
                        .fixedSize()
                    // Nom et classe : une pastille dit les deux ; `showClasses` ne règle que l'emblème.
                    if affichage.classe, let classe = libelleClasse ?? classe {
                        Text(classe)
                            .font(Jetons.Typo.petit.police)
                            .foregroundStyle(devant ? Color.jeton(\.encreSurPrimaire) : Color.jeton(\.encreSecondaire))
                            .lineLimit(1)
                    }
                }
            }

            // Le numéro est la touche qui mène à ce perso : dessiné comme elle, avec le raccourci réel.
            if affichage.touche {
                ToucheRaccourci(touche)
            }
        }
        .padding(.horizontal, affichage.nom ? Jetons.Espace.deux : Jetons.Espace.un)
        .padding(.vertical, Jetons.Espace.un)
        .fixedSize(horizontal: true, vertical: false)
        .fondEtat(devant ? .courant : enFermeture ? .desactive : EtatVisuel(survole: survole))
        .foregroundStyle(devant ? EtatVisuel.courant.encre : dormant ? Color.jeton(\.encreSecondaire) : Color.jeton(\.encre))
    }
}
