import SwiftUI

/// Onglet Quêtes : chercher une quête et l'ouvrir dans son panneau.
struct QuetesSettings: View {
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared
    @State private var filtre = ""

    private static let limite = 200

    var body: some View {
        let langue = L10n.courante.langue
        let quetes = montrees(langue)
        let affichees = Array(quetes.prefix(Self.limite).enumerated())
        PageListe(titre: L("reglages.quetes"), sousTitre: L("quetes.sousTitre")) {
            SourceQuetes().cadreDeListe(premiere: true, derniere: false)
            Interrupteur(titre: L("quetes.bouton"), isOn: $prefs.quetesBouton).cadreDeListe(premiere: false, derniere: true)
            EnTeteListe(titre: L("quetes.compte", quetes.count))
            ChampFiltre(invite: L("quetes.filtrer"), texte: $filtre)
                .cadreDeListe(premiere: true, derniere: affichees.isEmpty)
            ForEach(affichees, id: \.element.id) { rang, quete in
                Ligne(titre: Lieu.traduit(quete.noms, langue) ?? "?",
                      sousTexte: L("quete.niveau", quete.niveau, quete.etapes.count)) {
                    Button(L("quetes.ouvrir")) { QuetePanel.shared.ouvrir(quete.id) }
                }
                .cadreDeListe(premiere: false, derniere: rang == affichees.count - 1 && quetes.count <= Self.limite)
            }
            if quetes.count > Self.limite {
                Text(L("lieux.affiner", quetes.count)).foregroundStyle(.secondary)
                    .cadreDeListe(premiere: false, derniere: true)
            }
        }
    }

    private func montrees(_ langue: Langue) -> [Quete] {
        ListesReglages.quetes.elements(
            source: [AnyHashable(store.quetes?.date), AnyHashable(langue)], filtre: filtre,
            trier: { store.quetesTriees },
            champs: { RecherchePalette.Champs(titre: Lieu.traduit($0.noms, langue) ?? "") })
    }
}
