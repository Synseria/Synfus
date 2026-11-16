import SwiftUI

/// Les positions d'un PNJ, dépliées sous sa ligne : une rangée de cartes comme celles des zaaps, la
/// mieux placée d'abord. Une carte prend toute la largeur, deux la moitié, trois le tiers ; au-delà
/// la rangée défile en suivant la sélection, la suivante entamée au bord droit. Sa hauteur est
/// bornée : les quêtes de la position défilent dans la carte.
struct PositionsPNJVue: View {
    @ObservedObject var modele: PaletteModele
    @Environment(\.accessibilityReduceMotion) private var sansMouvement

    private static let hauteur: CGFloat = 240
    private static let interstice = Jetons.Espace.deux

    private static func ancre(_ position: PNJ.Position) -> String { "position:\(position.x),\(position.y)" }

    var body: some View {
        let positions = modele.positionsDeplie
        GeometryReader { place in
            let largeur = DispositionPositions.largeur(nombre: positions.count, disponible: place.size.width,
                                                       interstice: Self.interstice)
            ScrollViewReader { defilement in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Self.interstice) {
                        ForEach(positions) { position in
                            let action = ActionFiche.position(position.position)
                            CarteZaap(entree: position.entree, choisie: modele.carte == action) {
                                QuetesDePosition(position: position)
                            }
                            .frame(width: largeur, height: Self.hauteur)
                            .id(Self.ancre(position.position))
                            .onTapGesture { modele.cliquer(action) }
                            .help(([position.entree.titre, position.entree.sousTitre, position.itineraire].compactMap(\.self)
                                   + position.quetes).joined(separator: "\n"))
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                }
                .scrollDisabled(!DispositionPositions.defile(positions.count))
                .onChange(of: modele.carte) { _, carte in
                    guard case .position(let position)? = carte else { return }
                    withAnimation(sansMouvement ? nil : Jetons.Duree.animation(Jetons.Duree.etat)) { defilement.scrollTo(Self.ancre(position), anchor: .center) }
                }
            }
        }
        .frame(height: Self.hauteur)
    }
}

/// Ce qu'il y a à faire à une position, et ce qu'il en coûte d'y aller : la liste des quêtes défile,
/// le trajet reste. Sur la vue de la carte, un fond la garde lisible.
private struct QuetesDePosition: View {
    let position: PositionPNJ

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            ScrollView {
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    ForEach(Array(position.quetes.enumerated()), id: \.offset) { _, nom in
                        Text(nom)
                            .font(Jetons.Typo.petit.police)
                            .foregroundStyle(Color.jeton(\.encre))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if let itineraire = position.itineraire {
                Text(itineraire)
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.primaireEncre))
                    .lineLimit(2)
            }
        }
        .padding(Jetons.Espace.un)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if FondCarte.surImage(position.entree.carte) {
                RoundedRectangle(cornerRadius: Jetons.Rayon.pastille, style: .continuous)
                    .fill(Color.jeton(\.surface).opacity(Self.voile))
            }
        }
    }

    private static let voile = 0.9
}
