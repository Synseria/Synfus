import SwiftUI

/// Onglet Données : d'où vient la carte du jeu, comment un trajet se copie, les repères qu'elle
/// porte (zaaps, lieux), puis le panneau des quêtes, la liste des quêtes et les PNJ situés — tout
/// ce que la palette et les panneaux lisent dans le jeu.
struct DonneesSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages {
            Bloc {
                SourceCarte()
                InterrupteurVuesCartes()
            }
            BlocTrajets()
            BlocZaaps()
            BlocLieux()
            Bloc {
                SourceQuetes()
            }
            Bloc(L("quetes.panneau")) {
                LigneInterrupteur(titre: L("quetes.compact"), aide: L("quetes.compact.aide"), isOn: $prefs.quetesCompact)
                LigneInterrupteur(titre: L("quetes.consigne"), aide: L("quetes.consigne.aide"), isOn: $prefs.quetesConsigne)
                LigneInterrupteur(titre: L("quetes.masquerObjets"), aide: L("quetes.masquerObjets.aide"),
                             isOn: $prefs.quetesMasquerObjets)
                LigneInterrupteur(titre: L("quetes.cocherSuivi"), aide: L("quetes.cocherSuivi.aide"),
                             isOn: $prefs.quetesCocherSuivi)
                // Les vignettes ne servent que si les vues des cartes sont là.
                InterrupteurVuesCartes()
                if prefs.vuesCartes {
                    LigneInterrupteur(titre: L("quetes.vignettes"), aide: L("quetes.vignettes.aide"),
                             isOn: $prefs.quetesVignettes)
                }
            }
            ListeQuetes()
            ListePNJ()
        }
    }
}

/// Un `/travel` copié passe par le zaap le plus proche.
private struct BlocTrajets: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Bloc(L("reglages.trajets")) {
            Ligne(titre: L("zaap.gain"), aide: L("zaap.gain.aide")) {
                Stepper(L("zaap.gain.valeur", nombre: prefs.zaapGainMinimal, prefs.zaapGainMinimal),
                        value: $prefs.zaapGainMinimal, in: ItineraireZaap.gainsPossibles)
            }
            LigneInterrupteur(titre: L("zaap.duJeu"), aide: L("zaap.duJeu.aide", ItineraireZaap.ecartZaapDuJeu), isOn: $prefs.zaapDuJeu)
            Ligne(titre: L("zaap.intercalees"), aide: L("zaap.intercalees.aide")) {
                TextField(L("zaap.intercalees"), text: $prefs.zaapIntercalees, prompt: Text(verbatim: "/a"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .font(Jetons.typoCode.font)
                    .frame(width: 180)
            }
            if prefs.lirePosition {
                LigneInterrupteur(titre: L("zaap.auto"), aide: L("zaap.auto.aide"), isOn: $prefs.zaapAuto)
            } else {
                // La réécriture a besoin de la position : l'état se dit dans sa ligne, avec le geste qui le lève.
                Ligne(titre: L("zaap.auto"), etat: L("zaap.sansPosition"), aide: L("zaap.auto.aide")) {
                    Button(WindowPreviewService.shared.authorized ? L("zaap.lirePosition") : L("autorisation.lectureEcran")) {
                        prefs.lirePosition = true
                        if !WindowPreviewService.shared.authorized { WindowPreviewService.shared.requestAuthorization() }
                    }
                }
            }
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
                    Text(L("lieux.affiner", quetes.count)).foregroundStyle(Color.jeton(\.encre2)).rangee()
                }
            }
        } entete: {
            if store.quetes != nil {
                Text(L("quetes.compte", quetes.count))
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre2))
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
                    Text(L("lieux.affiner", pnjs.count)).foregroundStyle(Color.jeton(\.encre2)).rangee()
                }
            }
        } entete: {
            if store.quetes != nil {
                Text(L("pnj.compte", pnjs.count))
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre2))
            }
        }
    }

    private func fiche(_ pnj: PNJ, _ langue: Langue) -> some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            HStack(spacing: Jetons.espace2) {
                Text(Lieu.traduit(pnj.noms, langue) ?? "?").font(Jetons.typoTitreCarte.font)
                Spacer()
                BoutonEtiquette(cle: pnj.cle)
                BoutonFavori(cle: pnj.cle)
            }
            ForEach(Array(pnj.passages.enumerated()), id: \.offset) { rang, passage in
                HStack(spacing: Jetons.espace2) {
                    Text(lieu(passage, langue)).foregroundStyle(rang == 0 ? Color.jeton(\.encre) : Color.jeton(\.encre2))
                    Text(L("pnj.quetes", nombre: passage.quetes.count, passage.quetes.count)).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
                    Spacer()
                    BoutonTrajet(x: passage.position.x, y: passage.position.y, sousZone: passage.sousZone)
                    if let carte = passage.carte { MiniatureCarte(carte: carte) }
                }
                .font(Jetons.typoMeta.font)
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
