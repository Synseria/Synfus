import SwiftUI

/// Onglet Usage : l'interrupteur du partage, puis le JSON exact de ce qui part
/// et ce que Synfus a compté. Compteurs montrés au seul partage : c'est ce qui
/// donne envie de le laisser allumé.
struct UsageSettings: View {
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
        PageReglages(titre: L("reglages.usage")) {
            Section {
                Interrupteur(titre: L("stats.partager"), aide: L("stats.partager.aide"),
                             isOn: $prefs.partagerStatistiques)
                if prefs.partagerStatistiques {
                    Ligne(titre: L("stats.dernierEnvoi"), etat: dernierEnvoi) {
                        Button(L("stats.voirDonnees")) { donnees = true }
                    }
                }
            }
            if prefs.partagerStatistiques { compteurs }
        }
        .sheet(isPresented: $donnees) { DonneesEnvoyeesVue() }
    }

    @ViewBuilder
    private var compteurs: some View {
        let aujourdhui = UsageStore.aujourdhui()
        let totaux = usage.historique.totaux(sur: periode.jours, aujourdhui: aujourdhui)
        Section {
            Ligne(titre: L("stats.periode"), etat: depuis) {
                Picker(L("stats.periode"), selection: $periode) {
                    ForEach(Periode.allCases, id: \.self) { Text($0.libelle).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            if let moyennes = usage.historique.moyennesPersos(sur: periode.jours, aujourdhui: aujourdhui) {
                valeur(L("stats.persosConnectes"), moyennes.connectes.formatted(.number.precision(.fractionLength(1))))
                valeur(L("stats.persosJoues"), moyennes.joues.formatted(.number.precision(.fractionLength(1))))
            }
        }
        ForEach(EvenementUsage.Famille.allCases, id: \.self) { famille in
            let evenements = EvenementUsage.allCases.filter { $0.famille == famille && totaux[$0, default: 0] > 0 }
            if !evenements.isEmpty {
                Section {
                    ForEach(evenements, id: \.self) { evenement in
                        valeur(evenement.libelle, totaux[evenement, default: 0].formatted())
                    }
                } header: {
                    SectionTitle(titre(famille))
                }
            }
        }
    }

    private func valeur(_ titre: String, _ texte: String) -> some View {
        Ligne(titre: titre) {
            Text(texte).monospacedDigit().foregroundStyle(Color.jeton(\.encreSecondaire))
        }
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
            Picker(L("stats.voirDonnees"), selection: $dernier) {
                Text(L("stats.prochainEnvoi")).tag(false)
                Text(L("stats.dernierEnvoi")).tag(true)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .fixedSize()
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
