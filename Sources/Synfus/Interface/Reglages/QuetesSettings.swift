import SwiftUI

/// Onglet Quêtes : le panneau, la liste des quêtes à ouvrir, et les PNJ que les quêtes situent.
struct QuetesSettings: View {
    @ObservedObject private var store = QuetesStore.shared
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.quetes")) {
            Bloc {
                SourceQuetes()
                RaccourciReglable(label: L("quetes.raccourci"), chemin: \.quetesHotKey)
                    .help(L("quetes.aide"))
            }
            Bloc(L("quetes.panneau")) {
                Interrupteur(titre: L("quetes.compact"), aide: L("quetes.compact.aide"), isOn: $prefs.quetesCompact)
                Interrupteur(titre: L("quetes.consigne"), aide: L("quetes.consigne.aide"), isOn: $prefs.quetesConsigne)
                Interrupteur(titre: L("quetes.masquerObjets"), aide: L("quetes.masquerObjets.aide"),
                             isOn: $prefs.quetesMasquerObjets)
                Interrupteur(titre: L("quetes.cocherSuivi"), aide: L("quetes.cocherSuivi.aide"),
                             isOn: $prefs.quetesCocherSuivi)
                // Les vignettes ne servent que si les vues des cartes sont là.
                InterrupteurVuesCartes()
                if prefs.vuesCartes {
                    Interrupteur(titre: L("quetes.vignettes"), aide: L("quetes.vignettes.aide"),
                                 isOn: $prefs.quetesVignettes)
                }
            }
            ListeQuetes()
            ListePNJ()
        }
    }
}

/// Ce qu'un bloc de données dit tant qu'il n'a rien à lister : l'attente, ou l'échec (« Nom indisponible »,
/// « Réessayer », sans la cause) ; `nil` quand la liste est là.
@MainActor
private func etatDesQuetes(_ store: QuetesStore, indisponibles: String) -> EtatDeBloc? {
    guard store.quetes == nil else { return nil }
    if store.echec != nil, !store.chargement {
        return EtatDeBloc(texte: indisponibles, geste: L("commun.reessayer")) { Task { try? await store.mettreAJour() } }
    }
    return EtatDeBloc(texte: L("commun.chargement"), attente: true)
}

private struct ListeQuetes: View {
    @ObservedObject private var store = QuetesStore.shared
    @State private var filtre = ""

    private static let limite = 200

    var body: some View {
        let langue = L10n.courante.langue
        let quetes = montrees(langue)
        Bloc(L("reglages.quetes"), paresseux: true) {
            if let etat = etatDesQuetes(store, indisponibles: L("quetes.indisponibles")) {
                etat
            } else {
                ChampFiltre(invite: L("quetes.filtrer"), texte: $filtre).rangee()
                if quetes.isEmpty { EtatDeBloc.aucun(L("quetes.aucune"), recherche: filtre) }
                ForEach(quetes.prefix(Self.limite), id: \.id) { quete in
                    Ligne(titre: Lieu.traduit(quete.noms, langue) ?? "?",
                          etat: L("quete.niveau", nombre: quete.etapes.count, quete.niveau, quete.etapes.count)) {
                        Button(L("quetes.ouvrir")) { QuetePanel.shared.ouvrir(quete.id) }
                    }
                }
                if quetes.count > Self.limite {
                    Text(L("lieux.affiner", quetes.count)).foregroundStyle(Color.jeton(\.encreSecondaire)).rangee()
                }
            }
        } entete: {
            if store.quetes != nil {
                Text(L("quetes.compte", quetes.count))
                    .font(Jetons.Typo.note.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
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

/// Les PNJ que les quêtes situent, et chaque case où elles les placent — la plus citée d'abord, avec sa
/// zone et la vue de sa carte ; un clic copie le trajet.
private struct ListePNJ: View {
    @ObservedObject private var store = QuetesStore.shared
    @State private var filtre = ""

    private static let limite = 150

    var body: some View {
        let langue = L10n.courante.langue
        let pnjs = montres(langue)
        Bloc(L("reglages.pnj"), aide: L("pnj.aide"), paresseux: true) {
            if let etat = etatDesQuetes(store, indisponibles: L("pnj.indisponibles")) {
                etat
            } else {
                ChampFiltre(invite: L("pnj.filtrer"), texte: $filtre).rangee()
                if pnjs.isEmpty { EtatDeBloc.aucun(L("pnj.aucun"), recherche: filtre) }
                ForEach(pnjs.prefix(Self.limite), id: \.id) { pnj in
                    fiche(pnj, langue)
                }
                if pnjs.count > Self.limite {
                    Text(L("lieux.affiner", pnjs.count)).foregroundStyle(Color.jeton(\.encreSecondaire)).rangee()
                }
            }
        } entete: {
            if store.quetes != nil {
                Text(L("pnj.compte", pnjs.count))
                    .font(Jetons.Typo.note.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
            }
        }
    }

    private func fiche(_ pnj: PNJ, _ langue: Langue) -> some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack(spacing: Jetons.Espace.deux) {
                Text(Lieu.traduit(pnj.noms, langue) ?? "?").font(Jetons.Typo.corpsFort.police)
                Spacer()
                BoutonEtiquette(cle: pnj.cle)
                BoutonFavori(cle: pnj.cle)
            }
            ForEach(Array(pnj.passages.enumerated()), id: \.offset) { rang, passage in
                HStack(spacing: Jetons.Espace.deux) {
                    Text(lieu(passage, langue)).foregroundStyle(rang == 0 ? Color.jeton(\.encre) : Color.jeton(\.encreSecondaire))
                    Text(L("pnj.quetes", nombre: passage.quetes, passage.quetes)).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    Spacer()
                    BoutonTrajet(x: passage.position.x, y: passage.position.y, sousZone: passage.sousZone)
                    if let carte = passage.carte { MiniatureCarte(carte: carte) }
                }
                .font(Jetons.Typo.note.police)
            }
        }
        .rangee()
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
