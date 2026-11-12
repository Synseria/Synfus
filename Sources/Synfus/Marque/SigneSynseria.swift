import AppKit
import SwiftUI

/// L'emblème Synseria, d'après `Synseria-Design/marque/synseria-embleme-synfus.svg` : un rond nuit,
/// deux anneaux blancs à nœuds, une petite planète de trois disques. Moteur **pur** (la liste des
/// cercles, repère 64 × 64) ; le plus grand disque prend la `primaire` courante, donc rien n'est figé.
enum EmblemeSynseria {
    static let cote: CGFloat = 64

    enum Teinte: Equatable, Sendable { case nuit, blanc, primaire }

    struct Cercle: Equatable, Sendable {
        let cx, cy, r: CGFloat
        let remplissage: Teinte?
        let trait: Teinte?
        let epaisseur: CGFloat

        init(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, remplissage: Teinte? = nil, trait: Teinte? = nil, epaisseur: CGFloat = 0) {
            (self.cx, self.cy, self.r, self.remplissage, self.trait, self.epaisseur) = (cx, cy, r, remplissage, trait, epaisseur)
        }
    }

    /// De l'arrière vers l'avant.
    static let cercles: [Cercle] = [
        Cercle(32, 32, 32, remplissage: .nuit),
        Cercle(32, 32, 24, trait: .blanc, epaisseur: 2),
        Cercle(32, 32, 19.5, trait: .blanc, epaisseur: 2),
        Cercle(32, 10.25, 5, remplissage: .nuit, trait: .blanc, epaisseur: 2),
        Cercle(32, 53.75, 5, remplissage: .nuit, trait: .blanc, epaisseur: 2),
        Cercle(31, 31, 4.6, remplissage: .primaire),
        Cercle(40.5, 34.5, 3.8, remplissage: .blanc),
        Cercle(33.5, 41, 3.6, remplissage: .blanc),
    ]

    /// Le mot, en deux parties : la première en encre, la seconde en encre secondaire.
    static let mot = (syn: "syn", seria: "seria")
}

/// L'emblème dessiné à la hauteur demandée, aux couleurs du thème courant.
struct EmblemeSynseriaVue: View {
    var hauteur: CGFloat

    var body: some View {
        let nuit = Couleurs.nuit, blanc = Color.white, primaire = Couleurs.primaire
        Canvas { contexte, taille in
            let echelle = min(taille.width, taille.height) / EmblemeSynseria.cote
            func teinte(_ t: EmblemeSynseria.Teinte) -> Color {
                switch t {
                case .nuit: nuit
                case .blanc: blanc
                case .primaire: primaire
                }
            }
            for c in EmblemeSynseria.cercles {
                let chemin = Path(ellipseIn: CGRect(x: (c.cx - c.r) * echelle, y: (c.cy - c.r) * echelle,
                                                    width: 2 * c.r * echelle, height: 2 * c.r * echelle))
                if let remplissage = c.remplissage { contexte.fill(chemin, with: .color(teinte(remplissage))) }
                if let trait = c.trait { contexte.stroke(chemin, with: .color(teinte(trait)), lineWidth: c.epaisseur * echelle) }
            }
        }
        .frame(width: hauteur, height: hauteur)
        .accessibilityHidden(true)
    }
}

/// Le signe Synseria : l'emblème et le mot « synseria » à côté (jamais dans le rond). Outfit 600 si
/// elle est installée, sinon la police arrondie du système, de même graisse.
struct SigneSynseria: View {
    var hauteur: CGFloat = 40

    var body: some View {
        HStack(spacing: hauteur * 0.3) {
            EmblemeSynseriaVue(hauteur: hauteur)
            (Text(EmblemeSynseria.mot.syn).foregroundColor(Couleurs.encre)
                + Text(EmblemeSynseria.mot.seria).foregroundColor(Couleurs.encreSecondaire))
                .font(Self.policeDuMot(taille: hauteur * 0.56))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Synseria")
    }

    static func policeDuMot(taille: CGFloat) -> Font {
        outfitInstallee ? .custom("Outfit", fixedSize: taille).weight(.semibold)
            : .system(size: taille, weight: .semibold, design: .rounded)
    }

    private static let outfitInstallee = NSFont(name: "Outfit", size: 12) != nil
}
