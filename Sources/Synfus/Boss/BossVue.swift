import AppKit
import SwiftUI

/// Le panneau d'aide aux boss, au style des panneaux de quêtes et de chasse :
/// le boss choisi au titre (un clic en change), le tour du combat, sa
/// mécanique, ses rappels.
struct BossVue: View {
    static let largeur: CGFloat = 252

    @ObservedObject private var aide = AideBoss.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var prefs = Preferences.shared
    /// La liste des donjons (nom d'un boss, guide) et leurs conseils arrivent après.
    @ObservedObject private var donjons = DonjonsStore.shared
    @State private var rappels = false
    @State private var conseils = false
    /// Le rappel tout juste copié (ou tous : `""`), coché le temps du signal.
    @State private var copie: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                if let fiche = aide.fiches[prefs.bossChoisi.monstre] { FicheCombatVue(fiche: fiche) }
                if previews.authorized {
                    ligneTour
                    switch prefs.bossChoisi.special {
                    case .harebourg: HarebourgVue()
                    case .kimbo: KimboVue()
                    case .toxoliath: ToxoliathVue()
                    case .ilyzaelle: IlyzaelleVue()
                    case .talKasha: TalKashaVue()
                    case nil: EmptyView()
                    }
                } else {
                    autorisation
                }
                if let special = prefs.bossChoisi.special { rappelsVue(special) }
                conseilsVue
            }
            .padding(Jetons.Espace.trois)
        }
        .frame(width: Self.largeur, alignment: .leading)
        .font(Jetons.Typo.note.police)
        .surfaceFlottante()
        // L'autorisation donnée, la lecture démarre sans attendre un
        // changement d'app.
        .onChange(of: previews.authorized) { BossPanel.shared.revoirVisibilite(force: false) }
        .task(id: prefs.bossChoisi) {
            aide.chargerFiche(prefs.bossChoisi)
            donjons.charger()
        }
        .task(id: aide.donjon?.id) { if let donjon = aide.donjon { donjons.demander(donjon) } }
    }


    private var entete: some View {
        EnTetePanneau(icone: "scope", teinte: Color.jeton(\.safran), menu: Self.menu) {
            Text(Self.nom(prefs.bossChoisi, donjons: donjons.donjons)).font(Jetons.Typo.corpsFort.police)
                .padding(.leading, Jetons.Espace.un)
            Image(systemName: "chevron.down").font(Jetons.Typo.micro.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                .padding(.leading, Jetons.Espace.un)
            if let perso = lecteur.persoDevant {
                Text(perso).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    .lineLimit(1)
                    .padding(.horizontal, Jetons.Espace.un)
            }
        } boutons: {
            if let nom = aide.donjon?.nomFrancais {
                BoutonEnTete(icone: "book", aide: L("boss.guide")) { Task { await DofusPourLesNoobs.ouvrir(nom) } }
            }
            BoutonEnTete(icone: "xmark", aide: L("quete.fermer.simple")) { BossPanel.shared.fermer() }
        }
    }

    /// Le menu du titre : les boss à mécanique, le boss de donjon suivi s'il
    /// en est un, coché, puis la palette pour en chercher un autre.
    private static func menu() -> NSMenu {
        let menu = NSMenu()
        let choisi = Preferences.shared.bossChoisi
        var cibles = Boss.allCases.map(CibleBoss.special)
        if choisi.special == nil { cibles.append(choisi) }
        for cible in cibles {
            let item = CibleMenu.shared.element(nom(cible, donjons: DonjonsStore.shared.donjons)) {
                AideBoss.shared.choisir(cible)
            }
            item.state = cible == choisi ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(CibleMenu.shared.element(L("boss.autre")) { PalettePanel.shared.ouvrir(requete: L("boss.autre.recherche")) })
        menu.addItem(.separator())
        menu.addItem(CibleMenu.shared.element(L("panneau.fermer")) { BossPanel.shared.fermer() })
        return menu
    }

    /// Le tour du combat compté chez le perso devant, à corriger d'un clic.
    private var ligneTour: some View {
        HStack(spacing: Jetons.Espace.un) {
            Image(systemName: "clock").foregroundStyle(Color.jeton(\.encreSecondaire))
            Text(aide.tour.map { L("boss.tour", $0) } ?? L("boss.tour.attente"))
                .font((aide.tour != nil ? Jetons.Typo.raccourci : Jetons.Typo.petit).police)
                .foregroundStyle(aide.tour == nil ? Color.jeton(\.encreSecondaire) : Color.jeton(\.encre))
                .help(L("boss.tour.aide"))
            Spacer()
            PetitBouton(icone: "minus", aide: L("boss.tour.moins")) { aide.corrigerTour(-1) }
                .disabled((aide.tour ?? 1) <= 1)
            PetitBouton(icone: "plus", aide: L("boss.tour.plus")) { aide.corrigerTour(1) }
        }
        .disabled(lecteur.persoDevant == nil)
    }

    private var autorisation: some View {
        HStack(spacing: Jetons.Espace.deux) {
            Text(L("boss.autoriser.aide"))
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { previews.requestAuthorization() } label: { Image(systemName: "lock") }
                .buttonStyle(.bouton(.tertiaire, dense: true))
                .aide(L("boss.autoriser"))
        }
    }

    /// Chaque rappel se copie d'un clic, pour le coller dans le tchat du
    /// groupe ; l'icône du titre les copie tous, à la suite.
    private func rappelsVue(_ boss: Boss) -> some View {
        let liste = Self.rappels(boss)
        return VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack(spacing: Jetons.Espace.un) {
                Button { rappels.toggle() } label: {
                    Label(L("boss.rappels"), systemImage: rappels ? "chevron.down" : "chevron.right")
                        .font(Jetons.Typo.raccourci.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Spacer(minLength: 0)
                if rappels {
                    Button { copier(liste.joined(separator: " "), signal: "") } label: {
                        Image(systemName: copie == "" ? "checkmark" : "doc.on.doc")
                            .font(Jetons.Typo.petit.police)
                            .foregroundStyle(Color.jeton(\.encreSecondaire))
                    }
                    .buttonStyle(.bouton(.tertiaire, dense: true))
                    .aide(L("boss.rappels.copier"))
                }
            }
            if rappels {
                ForEach(liste, id: \.self) { rappel in
                    Button { copier(rappel, signal: rappel) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: Jetons.Espace.un) {
                            Text("• " + rappel)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                            if copie == rappel { Image(systemName: "checkmark") }
                        }
                        .font(Jetons.Typo.petit.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .aide(L("boss.rappel.copier"))
                }
            }
        }
    }

    private func copier(_ texte: String, signal: String) {
        PressePapiers.copier(texte)
        copie = signal
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            if copie == signal { copie = nil }
        }
    }

    /// Les conseils de Dofus pour les noobs pour ce combat, dépliés d'un
    /// clic ; l'explication de chacun en infobulle.
    @ViewBuilder
    private var conseilsVue: some View {
        if let liste = aide.donjon.flatMap({ donjons.conseils[$0.id] }), !liste.isEmpty {
            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                Button { conseils.toggle() } label: {
                    Label(L("donjon.conseils", nombre: liste.count, liste.count),
                          systemImage: conseils ? "chevron.down" : "chevron.right")
                        .font(Jetons.Typo.raccourci.police)
                        .foregroundStyle(Color.jeton(\.encreSecondaire))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .aide(L("donjon.conseils.aide"))
                if conseils {
                    ForEach(Array(liste.enumerated()), id: \.offset) { _, conseil in
                        Text("• " + conseil.titre)
                            .font(Jetons.Typo.petit.police)
                            .foregroundStyle(Color.jeton(\.encreSecondaire))
                            .fixedSize(horizontal: false, vertical: true)
                            .help(conseil.detail)
                    }
                    Text(L("donjon.conseils.source")).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreTertiaire))
                }
            }
        }
    }

    // MARK: - Libellés

    /// Le nom d'un boss de donjon vient de DofusDB ; « ? » tant que la liste
    /// n'est pas là.
    static func nom(_ cible: CibleBoss, donjons: Donjons?) -> String {
        switch cible {
        case .special(let boss): return nom(boss)
        case .donjon(let monstre, _):
            return donjons?.nomsBoss[monstre].flatMap { Lieu.traduit($0, L10n.courante.langue) } ?? "?"
        }
    }

    nonisolated static func nom(_ boss: Boss) -> String {
        switch boss {
        case .harebourg: return L("boss.harebourg")
        case .kimbo: return L("boss.kimbo")
        case .toxoliath: return L("boss.toxoliath")
        case .ilyzaelle: return L("boss.ilyzaelle")
        case .talKasha: return L("boss.talKasha")
        }
    }

    private static func rappels(_ boss: Boss) -> [String] {
        switch boss {
        case .harebourg: return [L("boss.rappel.carillon"), L("boss.rappel.echec")]
        case .kimbo: return [L("boss.kimbo.rappel.disciple"), L("boss.kimbo.rappel.parite"), L("boss.kimbo.rappel.neutre")]
        case .toxoliath:
            return [L("boss.toxoliath.rappel.toxmose"), L("boss.toxoliath.rappel.mort"), L("boss.toxoliath.rappel.venin")]
        case .ilyzaelle:
            return [L("boss.ilyzaelle.rappel.erosion"), L("boss.ilyzaelle.rappel.portail"), L("boss.ilyzaelle.rappel.critiques")]
        case .talKasha:
            return [L("boss.talKasha.rappel.ligne"), L("boss.talKasha.rappel.glyphes"), L("boss.talKasha.rappel.pm")]
        }
    }
}

/// Un petit bouton à icône des panneaux d'aide : + et −, une cible de 22 pt.
struct PetitBouton: View {
    let icone: String
    let aide: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icone)
                .font(Jetons.Typo.raccourci.police)
                .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)
        }
        .buttonStyle(.etat())
        .aide(aide)
    }
}

/// Un choix parmi quelques-uns, en boutons côte à côte : celui en cours en
/// couleur ; un second clic sur lui l'efface (`nil`).
struct ChoixBoss<Valeur: Hashable>: View {
    let choix: [(valeur: Valeur, titre: String)]
    let actuel: Valeur?
    let choisir: (Valeur?) -> Void

    var body: some View {
        HStack(spacing: Jetons.Espace.un) {
            ForEach(choix, id: \.valeur) { option in
                let actif = option.valeur == actuel
                Button { choisir(actif ? nil : option.valeur) } label: {
                    Text(option.titre)
                        .font(Jetons.Typo.raccourci.police)
                        .frame(maxWidth: .infinity, minHeight: Jetons.Taille.cibleMin)
                }
                .buttonStyle(.etat(choisi: actif))
            }
        }
    }
}
