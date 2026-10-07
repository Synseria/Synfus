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
        PageReglages(titre: L("reglages.lieux"), sousTitre: L("lieux.sousTitre")) {
            Section {
                SourceCarte()
            }
            Section {
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
                ForEach(lieux.prefix(Self.limite), id: \.cle) { lieu in
                    Ligne(titre: lieu.nom(en: langue),
                          sousTexte: [lieu.sousZone(en: langue), lieu.zone(en: langue)].compactMap { $0 }
                            .joined(separator: " · ")) {
                        HStack(spacing: 10) {
                            BoutonEtiquette(cle: lieu.cle)
                            BoutonFavori(cle: lieu.cle)
                            BoutonTrajet(x: lieu.x, y: lieu.y)
                        }
                    }
                }
                if lieux.count > Self.limite {
                    Text(L("lieux.affiner", lieux.count)).foregroundStyle(.secondary)
                }
            } header: {
                SectionTitle(L("lieux.compte", lieux.count), help: L("palette.reglages.lieux.aide"))
            }
        }
    }

    private func montres(_ langue: Langue) -> [Lieu] {
        let mots = RecherchePalette.mots(filtre)
        return carte.carte.lieux
            .filter { !$0.estZaap }
            .filter { categorie == nil || $0.categorie == categorie }
            .filter { !marquesSeulement || prefs.etiquettes[$0.cle] != nil || prefs.estFavori($0.cle) }
            .filter { lieu in
                guard !mots.isEmpty else { return true }
                let texte = RecherchePalette.normaliser(
                    [prefs.etiquettes[lieu.cle] ?? "", lieu.nom(en: langue), lieu.sousZone(en: langue) ?? "",
                     lieu.zone(en: langue) ?? ""].joined(separator: " "))
                return mots.allSatisfy(texte.contains)
            }
            .sorted { $0.nom(en: langue).localizedStandardCompare($1.nom(en: langue)) == .orderedAscending }
    }
}
