import SwiftUI

/// Onglet PNJ : les PNJ que les quêtes situent, et chaque case où elles les
/// placent — la plus citée d'abord, avec sa zone ; un clic copie le trajet.
struct PNJSettings: View {
    @ObservedObject private var store = QuetesStore.shared
    @State private var filtre = ""

    private static let limite = 150

    var body: some View {
        let langue = L10n.courante.langue
        let pnjs = montres(langue)
        PageReglages(titre: L("reglages.pnj"), sousTitre: L("pnj.sousTitre")) {
            Section {
                SourceQuetes()
            }
            Section {
                ChampFiltre(invite: L("pnj.filtrer"), texte: $filtre)
                ForEach(pnjs.prefix(Self.limite), id: \.id) { pnj in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Lieu.traduit(pnj.noms, langue) ?? "?").font(.system(size: 13, weight: .medium))
                        ForEach(Array(pnj.passages.enumerated()), id: \.offset) { rang, passage in
                            HStack(spacing: 8) {
                                Text(lieu(passage, langue)).foregroundStyle(rang == 0 ? Color.primary : Color.secondary)
                                Text(L("pnj.quetes", passage.quetes)).font(.system(size: 11)).foregroundStyle(.secondary)
                                Spacer()
                                BoutonTrajet(x: passage.position.x, y: passage.position.y)
                            }
                            .font(.system(size: 12))
                        }
                    }
                    .padding(.vertical, 2)
                }
                if pnjs.count > Self.limite {
                    Text(L("lieux.affiner", pnjs.count)).foregroundStyle(.secondary)
                }
            } header: {
                SectionTitle(L("pnj.compte", pnjs.count))
            }
        }
    }

    private func lieu(_ passage: PNJ.Passage, _ langue: Langue) -> String {
        guard let sousZone = passage.sousZone.flatMap({ store.quetes?.sousZones[String($0)] }) else {
            return L("pnj.zoneInconnue")
        }
        return [Lieu.traduit(sousZone.noms, langue), Lieu.traduit(sousZone.zone, langue)]
            .compactMap { $0 }.joined(separator: " · ")
    }

    private func montres(_ langue: Langue) -> [PNJ] {
        let mots = RecherchePalette.mots(filtre)
        guard !mots.isEmpty else { return store.pnjsTries }
        return store.pnjsTries.filter { pnj in
            mots.allSatisfy(RecherchePalette.normaliser(Lieu.traduit(pnj.noms, langue) ?? "").contains)
        }
    }
}
