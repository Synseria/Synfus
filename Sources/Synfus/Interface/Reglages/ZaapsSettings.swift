import SwiftUI

/// Onglet Zaaps : chaque zaap en carte — activé ou non, étiqueté, favori —,
/// un ajout à la main, et la carte du jeu d'où ils viennent.
struct ZaapsSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var filtre = ""
    @State private var vue: Vue = .tous

    private enum Vue: CaseIterable {
        case tous, actifs, etiquetes

        var libelle: String {
            switch self {
            case .tous: return L("palette.reglages.tous")
            case .actifs: return L("palette.reglages.actifs")
            case .etiquetes: return L("palette.reglages.etiquetes")
            }
        }
    }

    var body: some View {
        let langue = L10n.courante.langue
        let connus = prefs.zaapsConnus
        PageListe(titre: L("reglages.zaaps"), sousTitre: L("zaaps.sousTitre", prefs.zaapsActifs.count, connus.count)) {
            SourceCarte().cadreDeListe(premiere: true, derniere: false)
            InterrupteurVuesCartes()
                .cadreDeListe(premiere: false, derniere: true)
            EnTeteListe(titre: L("zaaps.grille"), aide: L("zaap.liste.aide"))
            HStack(spacing: 10) {
                ChampFiltre(invite: L("palette.reglages.filtrer"), texte: $filtre)
                Picker(L("palette.reglages.vue"), selection: $vue) {
                    ForEach(Vue.allCases, id: \.self) { Text($0.libelle).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            .cadreDeListe(premiere: true, derniere: false)
            // Paresseuse dans la pile paresseuse : seules les cases à l'écran
            // se construisent, et avec elles leur vue de carte.
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(montres(connus, langue), id: \.cle) { zaap in
                    CarteZaapReglages(zaap: zaap, langue: langue)
                }
                AjoutZaap()
            }
            .padding(.vertical, 4)
            .cadreDeListe(premiere: false, derniere: true)
        }
    }

    private func montres(_ connus: [Zaap], _ langue: Langue) -> [Zaap] {
        let etiquettes = prefs.etiquettes
        return ListesReglages.zaaps
            .elements(source: [AnyHashable(connus), AnyHashable(etiquettes), AnyHashable(langue)], filtre: filtre,
                      trier: {
                          connus.sorted { a, b in
                              // Le Monde des Douze d'abord, puis les autres cartes ; par nom ensuite.
                              let (autreA, autreB) = (a.monde != Zaap.mondeDesDouze, b.monde != Zaap.mondeDesDouze)
                              if autreA != autreB { return !autreA }
                              return a.nom(en: langue).localizedStandardCompare(b.nom(en: langue)) == .orderedAscending
                          }
                      },
                      champs: { zaap in
                          RecherchePalette.Champs(titre: zaap.nom(en: langue), etiquette: etiquettes[zaap.cle],
                                                  lieu: zaap.zone(en: langue))
                      })
            .filter { zaap in
                switch vue {
                case .tous: return true
                case .actifs: return CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
                case .etiquetes: return etiquettes[zaap.cle] != nil
                }
            }
    }
}
