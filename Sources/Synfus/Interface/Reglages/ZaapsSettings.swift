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
        PageReglages(titre: L("reglages.zaaps"),
                     sousTitre: L("zaaps.sousTitre", prefs.zaapsActifs.count, connus.count)) {
            Section {
                SourceCarte()
                Interrupteur(titre: L("zaaps.vueCarte"), sousTexte: L("zaaps.vueCarte.sousTexte"), isOn: $prefs.zaapsVueCarte)
            }
            Section {
                HStack(spacing: 10) {
                    ChampFiltre(invite: L("palette.reglages.filtrer"), texte: $filtre)
                    Picker(L("palette.reglages.vue"), selection: $vue) {
                        ForEach(Vue.allCases, id: \.self) { Text($0.libelle).tag($0) }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .fixedSize()
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(montres(connus, langue), id: \.cle) { zaap in
                        CarteZaapReglages(zaap: zaap, langue: langue)
                    }
                    AjoutZaap()
                }
                .padding(.vertical, 4)
            } header: {
                SectionTitle(L("zaaps.grille"), help: L("zaap.liste.aide"))
            }
        }
    }

    private func montres(_ connus: [Zaap], _ langue: Langue) -> [Zaap] {
        let mots = RecherchePalette.mots(filtre)
        return connus
            .filter { zaap in
                switch vue {
                case .tous: return true
                case .actifs: return CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
                case .etiquetes: return prefs.etiquettes[zaap.cle] != nil
                }
            }
            .filter { zaap in
                let texte = RecherchePalette.normaliser(
                    [prefs.etiquettes[zaap.cle] ?? "", zaap.nom(en: langue), zaap.zone(en: langue) ?? ""]
                        .joined(separator: " "))
                return mots.allSatisfy(texte.contains)
            }
            .sorted { a, b in
                // Le Monde des Douze d'abord, puis les autres cartes ; par nom ensuite.
                let (autreA, autreB) = (a.monde != Zaap.mondeDesDouze, b.monde != Zaap.mondeDesDouze)
                if autreA != autreB { return !autreA }
                return a.nom(en: langue).localizedStandardCompare(b.nom(en: langue)) == .orderedAscending
            }
    }
}
