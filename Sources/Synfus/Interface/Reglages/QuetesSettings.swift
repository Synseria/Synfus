import SwiftUI

/// Onglet Quêtes : chercher une quête et l'ouvrir dans son panneau.
struct QuetesSettings: View {
    @ObservedObject private var store = QuetesStore.shared
    @State private var filtre = ""

    private static let limite = 200

    var body: some View {
        let langue = L10n.courante.langue
        let quetes = montrees(langue)
        PageReglages(titre: L("reglages.quetes"), sousTitre: L("quetes.sousTitre")) {
            Section {
                SourceQuetes()
            }
            Section {
                ChampFiltre(invite: L("quetes.filtrer"), texte: $filtre)
                ForEach(quetes.prefix(Self.limite), id: \.id) { quete in
                    Ligne(titre: Lieu.traduit(quete.noms, langue) ?? "?",
                          sousTexte: L("quete.niveau", quete.niveau, quete.etapes.count)) {
                        Button(L("quetes.ouvrir")) { QuetePanel.shared.ouvrir(quete.id) }
                    }
                }
                if quetes.count > Self.limite {
                    Text(L("lieux.affiner", quetes.count)).foregroundStyle(.secondary)
                }
            } header: {
                SectionTitle(L("quetes.compte", quetes.count))
            }
        }
    }

    private func montrees(_ langue: Langue) -> [Quete] {
        let mots = RecherchePalette.mots(filtre)
        return (store.quetes?.quetes ?? [])
            .filter { quete in
                mots.isEmpty || mots.allSatisfy(RecherchePalette.normaliser(Lieu.traduit(quete.noms, langue) ?? "").contains)
            }
            .sorted { ($0.niveau, Lieu.traduit($0.noms, langue) ?? "") < ($1.niveau, Lieu.traduit($1.noms, langue) ?? "") }
    }
}
