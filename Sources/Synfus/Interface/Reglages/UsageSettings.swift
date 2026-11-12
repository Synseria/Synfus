import SwiftUI

/// Les statistiques, dans la page Général : l'interrupteur du partage, puis ce que Synfus a compté et le
/// JSON exact de ce qui part. Compteurs montrés au seul partage : c'est ce qui donne envie de le laisser
/// allumé.
struct BlocsStatistiques: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var usage = UsageStore.shared
    @State private var periode = Periode.semaine
    @State private var donnees = false

    enum Periode: Hashable, CaseIterable {
        case semaine, mois, tout

        var jours: Int? {
            switch self {
            case .semaine: 7
            case .mois: 30
            case .tout: nil
            }
        }

        var libelle: String {
            switch self {
            case .semaine: L("stats.periode.semaine")
            case .mois: L("stats.periode.mois")
            case .tout: L("stats.periode.tout")
            }
        }
    }

    var body: some View {
        Bloc(L("stats.titre")) {
            Interrupteur(titre: L("stats.partager"), aide: L("stats.partager.aide"),
                         isOn: $prefs.partagerStatistiques)
            if prefs.partagerStatistiques {
                Ligne(titre: L("stats.dernierEnvoi")) {
                    HStack(spacing: Jetons.Espace.deux) {
                        Text(dernierEnvoi).foregroundStyle(Color.jeton(\.encreSecondaire))
                        Button(L("stats.voirDonnees")) { donnees = true }
                    }
                }
            }
        }
        .sheet(isPresented: $donnees) { DonneesEnvoyeesVue() }
        if prefs.partagerStatistiques { compteurs }
    }

    @ViewBuilder
    private var compteurs: some View {
        let aujourdhui = UsageStore.aujourdhui()
        let totaux = usage.historique.totaux(sur: periode.jours, aujourdhui: aujourdhui)
        Bloc {
            Ligne(titre: L("stats.periode")) {
                HStack(spacing: Jetons.Espace.deux) {
                    if let depuis { Text(depuis).foregroundStyle(Color.jeton(\.encreSecondaire)) }
                    Segments(L("stats.periode"), selection: $periode, choix: Periode.allCases.map { ($0, $0.libelle) })
                }
            }
            if let moyennes = usage.historique.moyennesPersos(sur: periode.jours, aujourdhui: aujourdhui) {
                valeur(L("stats.persosConnectes"), personnages(moyennes.connectes))
                valeur(L("stats.persosJoues"), personnages(moyennes.joues))
            }
        }
        ForEach(EvenementUsage.Famille.allCases, id: \.self) { famille in
            let evenements = EvenementUsage.allCases.filter { $0.famille == famille && totaux[$0, default: 0] > 0 }
            if !evenements.isEmpty {
                Bloc(titre(famille)) {
                    ForEach(evenements, id: \.self) { evenement in
                        valeur(evenement.libelle, totaux[evenement, default: 0].formatted())
                    }
                }
            }
        }
    }

    private func valeur(_ titre: String, _ texte: String) -> some View {
        Ligne(titre: titre) {
            Text(texte).monospacedDigit().foregroundStyle(Color.jeton(\.encreSecondaire))
        }
    }

    /// Une moyenne de personnages, son unité accordée : en français, singulier jusqu'à deux (« 1,9 personnage »).
    private func personnages(_ moyenne: Double) -> String {
        let accord = L10n.courante.langue == .fr ? Int(moyenne) : (moyenne == 1 ? 1 : 2)
        return L("stats.personnages", nombre: accord, moyenne.formatted(.number.precision(.fractionLength(1))))
    }

    private func titre(_ famille: EvenementUsage.Famille) -> String {
        switch famille {
        case .bascules: L("stats.bascules")
        case .palette: L("reglages.palette")
        case .outils: L("stats.outils")
        }
    }

    private var depuis: String? {
        guard periode == .tout, let premier = usage.historique.depuis.flatMap({ JourUsage.date($0) }) else { return nil }
        return L("stats.depuis", premier.formatted(date: .long, time: .omitted))
    }

    /// Une date à droite de la ligne, ou « Jamais » : la valeur, pas un sous-texte.
    private var dernierEnvoi: String {
        usage.historique.dernierEnvoi.map { $0.formatted(date: .abbreviated, time: .shortened) }
            ?? L("stats.jamais")
    }
}

/// Le JSON d'un envoi, tel quel : le prochain (jours en attente, sinon la
/// journée en cours) et le dernier accepté.
struct DonneesEnvoyeesVue: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var usage = UsageStore.shared
    @State private var dernier = false

    var body: some View {
        let texte = dernier ? usage.historique.dernierRapport : usage.apercuProchainEnvoi()
        VStack(alignment: .leading, spacing: Jetons.Espace.trois) {
            Segments(L("stats.voirDonnees"), selection: $dernier,
                     choix: [(false, L("stats.prochainEnvoi")), (true, L("stats.dernierEnvoi"))])
            ScrollView {
                Text(texte ?? L("stats.rienAEnvoyer"))
                    .font(Jetons.Typo.codeInterface.police)
                    .textSelection(.enabled)
                    .foregroundStyle(texte == nil ? Color.jeton(\.encreSecondaire) : Color.jeton(\.encre))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Jetons.Espace.deux)
            }
            .background(RoundedRectangle(cornerRadius: Jetons.Rayon.controle).fill(Color.jeton(\.creux)))
            HStack {
                Button(L("menu.copier")) { if let texte { PressePapiers.copier(texte) } }
                    .buttonStyle(.bouton(.secondaire))
                    .disabled(texte == nil)
                Spacer()
                Button(L("menu.fermer")) { dismiss() }
                    .buttonStyle(.bouton(.principal))
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(Jetons.Espace.quatre)
        .frame(width: 620, height: 520)
        .background(Color.jeton(\.fenetre))
    }
}

extension EvenementUsage {
    var libelle: String {
        switch self {
        case .basculeRaccourci: L("stats.bascule_raccourci")
        case .basculeBarre: L("stats.bascule_barre")
        case .basculeMenu: L("stats.bascule_menu")
        case .basculeAttention: L("stats.bascule_attention")
        case .rotationRaccourci: L("stats.rotation_raccourci")
        case .rotationClic: L("stats.rotation_clic")
        case .session: L("stats.session")
        case .equipeSuivante: L("stats.equipe_suivante")
        case .rangement: L("stats.rangement")
        case .palette: L("stats.palette")
        case .paletteZaap: L("stats.palette_zaap")
        case .paletteLieu: L("stats.palette_lieu")
        case .paletteCommande: L("stats.palette_commande")
        case .paletteVariable: L("stats.palette_variable")
        case .palettePerso: L("stats.palette_perso")
        case .paletteAction: L("stats.palette_action")
        case .paletteRecent: L("stats.palette_recent")
        case .paletteQuete: L("stats.palette_quete")
        case .palettePNJ: L("stats.palette_pnj")
        case .paletteMonstre: L("stats.palette_monstre")
        case .paletteObjet: L("stats.palette_objet")
        case .trajetCopie: L("stats.trajet_copie")
        case .trajetReecrit: L("stats.trajet_reecrit")
        case .invitation: L("stats.invitation")
        case .chasse: L("stats.chasse")
        case .quetes: L("stats.quetes")
        case .bossHarebourg: L("stats.boss_harebourg")
        case .bossKimbo: L("stats.boss_kimbo")
        case .bossToxoliath: L("stats.boss_toxoliath")
        case .bossIlyzaelle: L("stats.boss_ilyzaelle")
        case .bossTalKasha: L("stats.boss_tal_kasha")
        case .apercu: L("stats.apercu")
        case .apercuGrille: L("stats.apercu_grille")
        case .reglages: L("stats.reglages")
        case .miseAJour: L("stats.mise_a_jour")
        }
    }
}
