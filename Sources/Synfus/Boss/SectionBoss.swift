import SwiftUI

/// Une section du panneau d'aide, repliée sous son titre. Dépliée, elle défile
/// chez elle au-delà de `SectionBoss.plafond` : le panneau ne s'allonge pas
/// avec ce qu'elle contient.
struct SectionBoss<Accessoire: View, Contenu: View>: View {
    let titre: String
    var icone: String?
    /// Une réponse du combat plutôt qu'un titre de rangement.
    var forte = false
    var aide: String?
    @Binding var depliee: Bool
    /// Au bout de la ligne du titre, hors du bouton qui déplie.
    @ViewBuilder let accessoire: Accessoire
    @ViewBuilder let contenu: Contenu

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            HStack(spacing: Jetons.espace1) {
                // Le dépliable de la trousse : un clic sur le libellé ouvre aussi.
                EnTeteRepliable(deplie: depliee, basculer: { depliee.toggle() }) {
                    HStack(spacing: Jetons.espace1) {
                        if let icone { Image(systemName: icone) }
                        Text(titre).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .font((forte ? Jetons.typoTitreCarte : Jetons.typoMeta).font)
                    .foregroundStyle(forte ? Color.jeton(\.encre) : Color.jeton(\.encre2))
                }
                .help(aide ?? "")
                accessoire
            }
            if depliee {
                // Courte, elle garde sa hauteur ; longue, elle défile sous le plafond.
                ScrollView {
                    VStack(alignment: .leading, spacing: Jetons.espace1) { contenu }
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: PlafondSection.hauteur)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// Environ sept lignes de conseil : au-delà, la section défile.
enum PlafondSection {
    static let hauteur: CGFloat = 132
}

/// Le tour du combat compté chez le perso devant, posé à côté de la consigne
/// qui en dépend — nulle part ailleurs — et corrigé d'un clic.
struct CorrectionTour: View {
    @ObservedObject private var aide = AideBoss.shared
    @ObservedObject private var lecteur = LecteurEcran.shared

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            Text(aide.tour.map { L("boss.tour", $0) } ?? L("boss.tour.attente"))
                .font(Jetons.typoMeta.font.monospacedDigit())
                .foregroundStyle(Color.jeton(\.encre2))
                .fixedSize()
            PetitBouton(icone: "minus", aide: L("boss.tour.moins")) { aide.corrigerTour(-1) }
                .disabled((aide.tour ?? 1) <= 1)
            PetitBouton(icone: "plus", aide: L("boss.tour.plus")) { aide.corrigerTour(1) }
        }
        .help(L("boss.tour.aide"))
        .disabled(lecteur.persoDevant == nil)
    }
}

/// Une consigne qui dépend du tour, le tour au bout de sa ligne.
struct LigneDuTour<Contenu: View>: View {
    @ViewBuilder let contenu: Contenu

    var body: some View {
        // Sur la ligne de la consigne quand elle y tient entière, dessous sinon.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Jetons.espace1) {
                contenu
                Spacer(minLength: Jetons.espace2)
                CorrectionTour()
            }
            VStack(alignment: .trailing, spacing: Jetons.espace1) {
                contenu.frame(maxWidth: .infinity, alignment: .leading)
                CorrectionTour()
            }
        }
    }
}
