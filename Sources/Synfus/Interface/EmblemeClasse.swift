import SwiftUI
import SynseriaDesign

/// Le repère de classe d'un perso : l'icône choisie dans les réglages, à défaut une pastille teintée
/// à l'abréviation. L'icône du Dock ne servirait à rien ici : tous les clients partagent le même bundle.
struct EmblemeClasse: View {
    let classe: String?
    /// L'anneau, selon que le fond le demande clair ou discret.
    let contour: Color
    @ObservedObject private var icons = ClassesStore.shared

    var body: some View {
        ZStack {
            if let custom = icons.icon(for: classe) {
                Image(nsImage: custom)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
                    .clipShape(Circle())
            } else {
                Circle().fill(icons.catalogue.color(for: classe))
                Text(icons.catalogue.abbreviation(for: classe))
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.texteSurClasse)
            }
        }
        .frame(width: Jetons.diametreRond + Jetons.epaisseurFocus, height: Jetons.diametreRond + Jetons.epaisseurFocus)
        .overlay(Circle().strokeBorder(contour, lineWidth: Jetons.epaisseurFilet))
    }
}
