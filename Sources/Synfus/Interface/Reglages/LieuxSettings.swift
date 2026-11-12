import SwiftUI

/// Les lieux : les repères du jeu — banques, hôtels de vente, ateliers, temples, donjons, transports —,
/// à étiqueter, mettre en favori, rejoindre.
struct BlocLieux: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var carte = CarteStore.shared
    @State private var filtre = ""
    @State private var categorie: Int?
    @State private var marquesSeulement = false

    /// Au-delà, la liste ne dit plus rien : on affine la recherche.
    private static let limite = 300

    var body: some View {
        let langue = L10n.courante.langue
        let lieux = montres(langue)
        Bloc(L("reglages.lieux"), aide: L("palette.reglages.lieux.aide"), paresseux: true) {
            HStack(spacing: Jetons.Espace.deux) {
                ChampFiltre(invite: L("lieux.filtrer"), texte: $filtre)
                Picker(L("lieux.categorie"), selection: $categorie) {
                    Text(L("palette.reglages.tous")).tag(Int?.none)
                    ForEach(CategorieLieu.allCases, id: \.self) { Text($0.titre).tag(Int?.some($0.rawValue)) }
                }
                .labelsHidden()
                .fixedSize()
                Button { marquesSeulement.toggle() } label: {
                    Text(L("lieux.marques"))
                        .font(Jetons.Typo.corps.police)
                        .padding(.horizontal, Jetons.Espace.trois)
                        .frame(height: Jetons.Taille.controle)
                }
                .buttonStyle(.etat(choisi: marquesSeulement, rayon: Jetons.Rayon.capsule))
                .accessibilityAddTraits(marquesSeulement ? .isSelected : [])
            }
            .rangee()
            if lieux.isEmpty {
                EtatDeBloc.aucun(L("lieux.aucun"), recherche: filtre)
            }
            ForEach(lieux.prefix(Self.limite), id: \.cle) { lieu in
                Ligne(titre: lieu.nom(en: langue), etat: Self.lieuDit(lieu, langue)) {
                    PictogrammeLieu(gfx: lieu.gfx) {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(Color.jeton(\.encreSecondaire))
                    }
                    .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
                } controle: {
                    HStack(spacing: Jetons.Espace.deux) {
                        BoutonEtiquette(cle: lieu.cle)
                        BoutonFavori(cle: lieu.cle)
                        BoutonTrajet(x: lieu.x, y: lieu.y, sousZone: lieu.idSousZone)
                        MiniatureCarte(carte: lieu.idCarte)
                    }
                }
            }
            if lieux.count > Self.limite {
                Text(L("lieux.affiner", lieux.count)).foregroundStyle(Color.jeton(\.encreSecondaire)).rangee()
            }
        } entete: {
            Text(L("lieux.compte", lieux.count))
                .font(Jetons.Typo.note.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
        }
    }

    private static func lieuDit(_ lieu: Lieu, _ langue: Langue) -> String {
        [lieu.sousZone(en: langue), lieu.zone(en: langue)].compactMap { $0 }.joined(separator: " · ")
    }

    private func montres(_ langue: Langue) -> [Lieu] {
        let etiquettes = prefs.etiquettes
        return ListesReglages.lieux
            .elements(source: [AnyHashable(carte.carte.date), AnyHashable(etiquettes), AnyHashable(langue)],
                      filtre: filtre,
                      trier: {
                          carte.carte.lieux.filter { !$0.estZaap }.sorted {
                              $0.nom(en: langue).localizedStandardCompare($1.nom(en: langue)) == .orderedAscending
                          }
                      },
                      champs: { lieu in
                          RecherchePalette.Champs(titre: lieu.nom(en: langue), etiquette: etiquettes[lieu.cle],
                                                  lieu: Self.lieuDit(lieu, langue), categorie: lieu.categorie)
                      })
            .filter { categorie == nil || $0.categorie == categorie }
            .filter { !marquesSeulement || etiquettes[$0.cle] != nil || prefs.estFavori($0.cle) }
    }
}
