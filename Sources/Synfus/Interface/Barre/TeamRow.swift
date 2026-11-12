import SwiftUI

/// Identité d'un secteur de la rangée des équipes — la clé de ses cadres
/// pour le geste de dépôt.
enum TeamSector: Hashable {
    case tous
    case equipe(Int)
    /// Le « + » : n'existe que comme cible de dépôt, tant qu'une équipe peut
    /// encore être créée.
    case nouvelle
}

/// Un secteur de la seconde rangée : « Tous », une équipe — son numéro et un
/// point par membre, à la couleur de sa classe —, ou « + ». Ni nom ni couleur
/// d'équipe : on la reconnaît à sa composition, comme on reconnaît une
/// pastille à son badge. Le secteur actif porte le fond accent de la pastille
/// active ; `cible` surligne pendant qu'une pastille le survole.
struct TeamSectorView: View {
    let secteur: TeamSector
    /// Les membres de l'équipe, dans l'ordre de la barre — pour les points.
    let membres: [TeamMember]
    let actif: Bool
    let cible: Bool
    /// Pendant un glisser, les secteurs s'élargissent et s'élèvent : une cible
    /// de dépôt se vise mieux qu'un onglet se lit.
    let agrandi: Bool
    let action: () -> Void
    @ObservedObject private var icons = ClassesStore.shared
    @State private var survole = false

    /// Ce qu'un point a besoin de savoir d'un membre.
    struct TeamMember: Hashable {
        let nom: String
        let classe: String?
        let connecte: Bool
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Jetons.Espace.un) {
                switch secteur {
                case .tous:
                    Image(systemName: "person.3")
                        .font(Jetons.Typo.petit.police)
                case .equipe(let index):
                    Text("\(index + 1)")
                        .font(Jetons.Typo.raccourci.police)
                        .padding(.trailing, Jetons.Espace.un)
                    ForEach(membres, id: \.self) { membre in
                        point(for: membre)
                    }
                case .nouvelle:
                    Image(systemName: "plus")
                        .font(Jetons.Typo.raccourci.police)
                }
            }
            .padding(.horizontal, agrandi ? Jetons.Espace.trois : Jetons.Espace.deux)
            // Le « + » est une cible, pas un libellé : il prend de la place.
            .frame(minWidth: secteur == .nouvelle ? (agrandi ? Jetons.Espace.dix + Jetons.Espace.deux : Jetons.Espace.huit) : 0)
            .frame(height: agrandi ? Jetons.Taille.cibleMin : Jetons.Taille.touche)
            .foregroundStyle(secteur == .nouvelle && etat == .repos ? Color.jeton(\.encreSecondaire) : etat.encre)
            .fondEtat(etat)
        }
        .buttonStyle(.plain)
        // Le « + » ne fait rien au clic : il attend qu'on y dépose un perso.
        .disabled(secteur == .nouvelle)
        .onHover { survole = $0 }
        .help(aide)
    }

    /// Plein : l'équipe active ; teinté : la cible du dépôt en cours.
    private var etat: EtatVisuel {
        actif ? .courant : cible ? .choisi : EtatVisuel(survole: survole)
    }

    /// Le point d'un membre : sa classe, un anneau vide s'il n'est pas connecté —
    /// même source de couleur et d'icône que le badge des pastilles.
    @ViewBuilder
    private func point(for membre: TeamMember) -> some View {
        Group {
            if !membre.connecte {
                Circle().strokeBorder(Color.jeton(\.encreTertiaire), lineWidth: Jetons.Trait.etat)
            } else if let custom = icons.icon(for: membre.classe) {
                Image(nsImage: custom)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle().fill(icons.catalogue.color(for: membre.classe))
            }
        }
        .frame(width: Jetons.Espace.trois, height: Jetons.Espace.trois)
    }

    private var aide: String {
        switch secteur {
        case .tous: return L("equipes.tousLesPersos")
        case .equipe(let index):
            return L("equipes.equipeMembres", index + 1, membres.map(\.nom).joined(separator: ", "))
        case .nouvelle: return L("equipes.glisserPourCreer")
        }
    }
}
