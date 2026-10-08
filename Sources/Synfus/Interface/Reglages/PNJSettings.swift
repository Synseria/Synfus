import SwiftUI

/// Onglet PNJ : les PNJ que les quêtes situent, et chaque case où elles les
/// placent — la plus citée d'abord, avec sa zone et la vue de sa carte ; un
/// clic copie le trajet.
struct PNJSettings: View {
    @ObservedObject private var store = QuetesStore.shared
    @State private var filtre = ""

    private static let limite = 150

    var body: some View {
        let langue = L10n.courante.langue
        let pnjs = montres(langue)
        let affiches = Array(pnjs.prefix(Self.limite).enumerated())
        PageListe(titre: L("reglages.pnj"), sousTitre: L("pnj.sousTitre")) {
            SourceQuetes().cadreDeListe(premiere: true, derniere: false)
            InterrupteurVuesCartes().cadreDeListe(premiere: false, derniere: true)
            EnTeteListe(titre: L("pnj.compte", pnjs.count))
            ChampFiltre(invite: L("pnj.filtrer"), texte: $filtre)
                .cadreDeListe(premiere: true, derniere: affiches.isEmpty)
            ForEach(affiches, id: \.element.id) { rang, pnj in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Lieu.traduit(pnj.noms, langue) ?? "?").font(.system(size: 13, weight: .medium))
                    ForEach(Array(pnj.passages.enumerated()), id: \.offset) { rang, passage in
                        HStack(spacing: 8) {
                            Text(lieu(passage, langue)).foregroundStyle(rang == 0 ? Color.primary : Color.secondary)
                            Text(L("pnj.quetes", nombre: passage.quetes, passage.quetes)).font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            BoutonTrajet(x: passage.position.x, y: passage.position.y)
                            if let carte = passage.carte { MiniatureCarte(carte: carte) }
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding(.vertical, 2)
                .cadreDeListe(premiere: false, derniere: rang == affiches.count - 1 && pnjs.count <= Self.limite)
            }
            if pnjs.count > Self.limite {
                Text(L("lieux.affiner", pnjs.count)).foregroundStyle(.secondary)
                    .cadreDeListe(premiere: false, derniere: true)
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
        ListesReglages.pnjs.elements(
            source: [AnyHashable(store.quetes?.date), AnyHashable(langue)], filtre: filtre,
            trier: { store.pnjsTries },
            champs: { RecherchePalette.Champs(titre: Lieu.traduit($0.noms, langue) ?? "") })
    }
}
