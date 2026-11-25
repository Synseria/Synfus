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
    @State private var survole = false

    /// Ce qu'un point a besoin de savoir d'un membre.
    struct TeamMember: Hashable {
        let nom: String
        let classe: String?
        let connecte: Bool
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Jetons.espace1) {
                switch secteur {
                case .tous:
                    Image(systemName: "person.3")
                        .font(Jetons.typoMeta.font)
                case .equipe(let index):
                    Text("\(index + 1)")
                        .font(Jetons.typoMicro.font)
                        .padding(.trailing, Jetons.espace1)
                    ForEach(membres, id: \.self) { membre in
                        PointPerso(classe: membre.classe, connecte: membre.connecte)
                    }
                case .nouvelle:
                    Image(systemName: "plus")
                        .font(Jetons.typoMicro.font)
                }
            }
            .padding(.horizontal, agrandi ? Jetons.espace3 : Jetons.espace2)
            // Le « + » est une cible, pas un libellé : il prend de la place.
            .frame(minWidth: secteur == .nouvelle ? (agrandi ? Jetons.espace7 : Jetons.espace6) : 0)
            .frame(height: agrandi ? Jetons.hauteurCase : Jetons.diametreRond)
            .foregroundStyle(secteur == .nouvelle && etat == .repos ? Color.jeton(\.encre2) : etat.encre)
            .fondEtat(etat)
        }
        .buttonStyle(.plain)
        .curseurDeClic(secteur != .nouvelle)
        // Le « + » ne fait rien au clic : il attend qu'on y dépose un perso.
        .disabled(secteur == .nouvelle)
        .onHover { survole = $0 }
        .help(aide)
    }

    /// Plein : l'équipe active ; teinté : la cible du dépôt en cours.
    private var etat: EtatVisuel {
        actif ? .courant : cible ? .choisi : EtatVisuel(survole: survole)
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

/// Le point d'un perso : sa classe — emblème ou couleur —, un anneau vide s'il n'est pas connecté.
/// Même source de couleur et d'icône que le badge des pastilles ; la rangée des équipes et le
/// panneau des quêtes le montrent.
struct PointPerso: View {
    let classe: String?
    let connecte: Bool
    @ObservedObject private var icons = ClassesStore.shared

    var body: some View {
        Group {
            if !connecte {
                Circle().strokeBorder(Color.jeton(\.encre3), lineWidth: Jetons.epaisseurFocus)
            } else if let custom = icons.icon(for: classe) {
                Image(nsImage: custom)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle().fill(icons.catalogue.color(for: classe))
            }
        }
        .frame(width: Jetons.espace3, height: Jetons.espace3)
    }
}
