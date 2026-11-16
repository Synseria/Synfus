import SwiftUI

/// Les positions d'un PNJ, dépliées sous sa ligne : une rangée de cartes au format de celles des
/// zaaps, la mieux placée d'abord. Une carte prend toute la largeur, deux la moitié, trois le tiers ;
/// au-delà la rangée défile en suivant la sélection, la suivante entamée au bord droit.
struct PositionsPNJVue: View {
    @ObservedObject var modele: PaletteModele
    @Environment(\.accessibilityReduceMotion) private var sansMouvement
    @State private var disponible: CGFloat = 0

    private static let interstice = Jetons.Espace.deux

    private static func ancre(_ position: PNJ.Position) -> String { "position:\(position.x),\(position.y)" }

    var body: some View {
        let positions = modele.positionsDeplie
        let largeur = DispositionPositions.largeur(nombre: positions.count, disponible: disponible,
                                                   interstice: Self.interstice)
        ScrollViewReader { defilement in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Self.interstice) {
                    ForEach(positions) { position in
                        CarteZaap(entree: position.entree, choisie: modele.position == position.position) { encres in
                            QuetesDePosition(quetes: position.quetes, encres: encres)
                        }
                        .frame(width: largeur)
                        .id(Self.ancre(position.position))
                        .onTapGesture { modele.cliquer(position.position) }
                        .help(([position.entree.titre, position.entree.sousTitre, position.entree.itineraire].compactMap(\.self)
                               + position.quetes).joined(separator: "\n"))
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .scrollDisabled(!DispositionPositions.defile(positions.count))
            .onChange(of: modele.position) { _, position in
                guard let position else { return }
                withAnimation(sansMouvement ? nil : Jetons.Duree.animation(Jetons.Duree.etat)) { defilement.scrollTo(Self.ancre(position), anchor: .center) }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { disponible = $0 }
    }
}

/// Ce qu'il y a à faire à une position, sur une ligne : les noms des quêtes quand ils y entrent, sinon
/// leur nombre, jamais coupé ; la liste entière est dans l'infobulle. Sur la vue de la carte, un voile la
/// garde lisible.
private struct QuetesDePosition: View {
    let quetes: [String]
    let encres: EncresCarte

    var body: some View {
        ViewThatFits(in: .horizontal) {
            Text(quetes.joined(separator: " · "))
                .foregroundStyle(encres.encre)
                .lineLimit(1)
            Text(L("pnj.quetes", nombre: quetes.count, quetes.count))
                .foregroundStyle(encres.accent)
                .lineLimit(1)
        }
        .font(Jetons.Typo.petit.police)
        .background {
            if encres.surImage, !quetes.isEmpty {
                RoundedRectangle(cornerRadius: Jetons.Rayon.pastille, style: .continuous)
                    .fill(Color.jeton(\.nuitProfond).opacity(FondCarte.voileTexte))
                    .padding(-Jetons.Espace.un)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Jetons.Espace.quatre, alignment: .leading)
    }
}
