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
        HStack(spacing: Jetons.espace1) {
            if enFermeture {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: Jetons.diametreRond + Jetons.epaisseurFocus, height: Jetons.diametreRond + Jetons.epaisseurFocus)
            } else if affichage.embleme {
                EmblemeClasse(classe: classe,
                              contour: devant ? Color.jeton(\.texteSurAccent) : Color.jeton(\.filet))
            }

            if affichage.nom {
                VStack(alignment: .leading, spacing: 0) {
                    Text(nom)
                        .font(Jetons.typoCorps.font)
                        .lineLimit(1)
                        .fixedSize()
                    // Nom et classe : une pastille dit les deux ; `showClasses` ne règle que l'emblème.
                    if affichage.classe, let classe = libelleClasse ?? classe {
                        Text(classe)
                            .font(Jetons.typoMeta.font)
                            .foregroundStyle(devant ? Color.jeton(\.texteSurAccent) : Color.jeton(\.encre2))
                            .lineLimit(1)
                    }
                }
            }

            // Le numéro est la touche qui mène à ce perso : dessiné comme elle, avec le raccourci réel.
            if affichage.touche {
                ToucheDeClavier(touche: touche, surUnPlein: devant)
            }
        }
        .padding(.horizontal, affichage.nom ? Jetons.espace2 : Jetons.espace1)
        .padding(.vertical, Jetons.espace1)
        .fixedSize(horizontal: true, vertical: false)
        .fondEtat(devant ? .courant : enFermeture ? .desactive : EtatVisuel(survole: survole), rayon: Jetons.rayon2)
        .foregroundStyle(devant ? EtatVisuel.courant.encre : dormant ? Color.jeton(\.encre2) : Color.jeton(\.encre))
    }
}
