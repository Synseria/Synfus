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
    @ObservedObject private var icons = ClassIconStore.shared
    @State private var survole = false

    /// Ce qu'un point a besoin de savoir d'un membre.
    struct TeamMember: Hashable {
        let nom: String
        let classe: String?
        let connecte: Bool
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 2) {
                switch secteur {
                case .tous:
                    Image(systemName: "person.3")
                        .font(.system(size: 10, weight: .medium))
                case .equipe(let index):
                    Text("\(index + 1)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.trailing, 1)
                    ForEach(membres, id: \.self) { membre in
                        point(for: membre)
                    }
                case .nouvelle:
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .padding(.horizontal, agrandi ? 12 : 7)
            // Le « + » est une cible, pas un libellé : il prend de la place.
            .frame(minWidth: secteur == .nouvelle ? (agrandi ? 48 : 34) : 0)
            .frame(height: agrandi ? 24 : 19)
            .foregroundStyle(actif ? Color.white : (secteur == .nouvelle ? Color.secondary : Color.primary))
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fond)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(cible ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
        // Le « + » ne fait rien au clic : il attend qu'on y dépose un perso.
        .disabled(secteur == .nouvelle)
        .onHover { survole = $0 }
        .animation(.easeOut(duration: 0.15), value: cible)
        .help(aide)
    }

    private var fond: Color {
        if actif { return .accentColor }
        if cible { return Color.accentColor.opacity(0.18) }
        return survole ? Color.primary.opacity(0.08) : .clear
    }

    /// Le point d'un membre : sa classe, atténué s'il n'est pas connecté —
    /// même source de couleur et d'icône que le badge des pastilles.
    @ViewBuilder
    private func point(for membre: TeamMember) -> some View {
        Group {
            if let custom = icons.icon(for: membre.classe) {
                Image(nsImage: custom)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle().fill(DofusClass.color(for: membre.classe))
            }
        }
        .frame(width: 12, height: 12)
        .opacity(membre.connecte ? 1 : 0.35)
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
