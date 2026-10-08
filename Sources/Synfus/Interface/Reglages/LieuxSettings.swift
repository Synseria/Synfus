import SwiftUI

/// Onglet Lieux : les repères du jeu — banques, hôtels de vente, ateliers,
/// temples, donjons, transports —, à étiqueter, mettre en favori, rejoindre.
struct LieuxSettings: View {
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
        let affiches = Array(lieux.prefix(Self.limite).enumerated())
        PageListe(titre: L("reglages.lieux"), sousTitre: L("lieux.sousTitre")) {
            SourceCarte().cadreDeListe(premiere: true, derniere: false)
            InterrupteurVuesCartes().cadreDeListe(premiere: false, derniere: true)
            EnTeteListe(titre: L("lieux.compte", lieux.count), aide: L("palette.reglages.lieux.aide"))
            HStack(spacing: 10) {
                ChampFiltre(invite: L("lieux.filtrer"), texte: $filtre)
                Picker(L("lieux.categorie"), selection: $categorie) {
                    Text(L("palette.reglages.tous")).tag(Int?.none)
                    ForEach(CategorieLieu.allCases, id: \.self) { Text($0.titre).tag(Int?.some($0.rawValue)) }
                }
                .labelsHidden()
                .fixedSize()
                Toggle(L("lieux.marques"), isOn: $marquesSeulement)
                    .toggleStyle(.checkbox)
            }
            .cadreDeListe(premiere: true, derniere: affiches.isEmpty)
            ForEach(affiches, id: \.element.cle) { rang, lieu in
                Ligne(titre: lieu.nom(en: langue), sousTexte: Self.lieuDit(lieu, langue)) {
                    PictogrammeLieu(gfx: lieu.gfx) {
                        Image(systemName: "mappin.and.ellipse").foregroundStyle(.secondary)
                    }
                    .frame(width: 22, height: 22)
                } controle: {
                    HStack(spacing: 10) {
                        BoutonEtiquette(cle: lieu.cle)
                        BoutonFavori(cle: lieu.cle)
                        BoutonTrajet(x: lieu.x, y: lieu.y)
                        MiniatureCarte(carte: lieu.idCarte)
                    }
                }
                .cadreDeListe(premiere: false, derniere: rang == affiches.count - 1 && lieux.count <= Self.limite)
            }
            if lieux.count > Self.limite {
                Text(L("lieux.affiner", lieux.count)).foregroundStyle(.secondary)
                    .cadreDeListe(premiere: false, derniere: true)
            }
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
