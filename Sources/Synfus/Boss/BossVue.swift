import AppKit
import SwiftUI

/// Le panneau d'aide aux boss, au style des panneaux de quêtes et de chasse :
/// le boss choisi au titre (un clic en change), sa fiche, sa mécanique, puis
/// rappels et conseils, qui défilent chez eux (`SectionBoss`).
struct BossVue: View {
    static let largeur = Jetons.largeurPanneauBoss

    @ObservedObject private var aide = AideBoss.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var prefs = Preferences.shared
    /// La liste des donjons (nom d'un boss, guide) et leurs conseils arrivent après.
    @ObservedObject private var donjons = DonjonsStore.shared
    @State private var rappels = false
    /// `nil` : dépliés d'office pour un boss sans mécanique, dont ils sont tout le panneau.
    @State private var conseils: Bool?
    /// Le rappel tout juste copié (ou tous : `""`), coché le temps du signal.
    @StateObject private var copie = SignalCopie()

    var body: some View {
        // L'en-tête sur le verre, le contenu sur une plaque pleine.
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            entete
            VStack(alignment: .leading, spacing: Jetons.espace2) {
                if let fiche = aide.fiches[prefs.bossChoisi.monstre] { FicheCombatVue(fiche: fiche) }
                switch prefs.bossChoisi.special {
                case .harebourg: HarebourgVue()
                case .kimbo: KimboVue()
                case .toxoliath: ToxoliathVue()
                case .ilyzaelle: IlyzaelleVue()
                case .talKasha: TalKashaVue()
                case nil: EmptyView()
                }
                if !previews.authorized { LigneAutorisation() }
                if let special = prefs.bossChoisi.special { rappelsVue(special) }
                conseilsVue
            }
            .padding(.vertical, Jetons.espace2)
            .padding(.horizontal, Jetons.espace2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .plaquePleine()
        }
        .padding([.horizontal, .bottom], Jetons.espace2)
        .padding(.top, Jetons.espace1)
        .frame(width: Self.largeur, alignment: .leading)
        .font(Jetons.typoMeta.font)
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
        EnTetePanneau(icone: BoutonBarre.boss.symbole, teinte: Color.jeton(\.accentTexte), menu: Self.menu) {
            Text(Self.nom(prefs.bossChoisi, donjons: donjons.donjons, garde: prefs.nomsBossChoisi))
                .font(Jetons.typoTitreCarte.font)
                .padding(.leading, Jetons.espace1)
            if donjons.enCours, prefs.bossChoisi.special == nil, prefs.nomsBossChoisi == nil {
                ProgressView().controlSize(.mini).padding(.leading, Jetons.espace1)
            }
            Image(systemName: "chevron.down").font(Jetons.typoMicro.font).foregroundStyle(Color.jeton(\.encre2))
                .padding(.leading, Jetons.espace1)
            // Un boss sans mécanique ne fait rien lire : pas de perso suivi à nommer.
            if prefs.bossChoisi.special != nil, let perso = lecteur.persoDevant {
                Text(perso).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
                    .lineLimit(1)
                    .padding(.horizontal, Jetons.espace1)
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
        menu.autoenablesItems = false
        let choisi = Preferences.shared.bossChoisi
        var cibles = Boss.allCases.map(CibleBoss.special)
        if choisi.special == nil { cibles.append(choisi) }
        for cible in cibles {
            let item = CibleMenu.shared.element(nom(cible, donjons: DonjonsStore.shared.donjons, garde: Preferences.shared.nomsBossChoisi)) {
                AideBoss.shared.choisir(cible)
            }
            item.state = cible == choisi ? .on : .off
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let nouveau = CibleMenu.shared.element(L("boss.nouveauCombat")) { AideBoss.shared.nouveauCombat() }
        nouveau.image = NSImage(systemSymbolName: "arrow.counterclockwise", accessibilityDescription: nil)
        nouveau.isEnabled = AideBoss.shared.aDuNote
        menu.addItem(nouveau)
        menu.addItem(CibleMenu.shared.element(L("boss.autre")) { PalettePanel.shared.ouvrir(vue: .donjons) })
        menu.addItem(.separator())
        menu.addItem(CibleMenu.shared.element(L("panneau.fermer"), raccourci: Preferences.shared.bossHotKey) { BossPanel.shared.fermer() })
        return menu
    }

    /// Chaque rappel se copie d'un clic, pour le coller dans le tchat du
    /// groupe ; l'icône du titre les copie tous, à la suite.
    private func rappelsVue(_ boss: Boss) -> some View {
        let liste = Self.rappels(boss)
        return SectionBoss(titre: L("boss.rappels"), depliee: $rappels) {
            if rappels {
                Button { copier(liste.joined(separator: " "), signal: "") } label: {
                    IconeCopie(icone: "doc.on.doc", copie: copie.affiche(""))
                        .font(Jetons.typoMeta.font)
                        .foregroundStyle(Color.jeton(\.encre2))
                }
                .buttonStyle(BoutonTertiaire())
                .aide(L("boss.rappels.copier"))
            }
        } contenu: {
            ForEach(liste, id: \.self) { rappel in
                Button { copier(rappel, signal: rappel) } label: {
                    HStack(alignment: .firstTextBaseline, spacing: Jetons.espace1) {
                        Text("• " + rappel)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        IconeCopie(icone: nil, copie: copie.affiche(rappel))
                    }
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .aide(L("boss.rappel.copier"))
            }
        }
    }

    private func copier(_ texte: String, signal: String) {
        PressePapiers.copier(texte)
        copie.signaler(signal)
    }

    /// Les conseils de Dofus pour les noobs pour ce combat.
    @ViewBuilder
    private var conseilsVue: some View {
        if let liste = aide.donjon.flatMap({ donjons.conseils[$0.id] }), !liste.isEmpty {
            let depliee = Binding { conseils ?? (prefs.bossChoisi.special == nil) } set: { conseils = $0 }
            SectionBoss(titre: L("donjon.conseils", nombre: liste.count, liste.count), aide: L("donjon.conseils.aide"),
                        depliee: depliee) {} contenu: {
                ConseilsVue(conseils: liste).foregroundStyle(Color.jeton(\.encre2))
            }
        }
    }

    // MARK: - Libellés

    /// Le nom d'un boss de donjon vient de DofusDB : en attendant la liste, celui
    /// qu'on en gardait, à défaut un titre générique.
    static func nom(_ cible: CibleBoss, donjons: Donjons?, garde: [String: String]?) -> String {
        switch cible {
        case .special(let boss): return nom(boss)
        case .donjon:
            let langue = L10n.courante.langue
            return cible.nomDonjon(dans: donjons, langue) ?? garde.flatMap { Lieu.traduit($0, langue) } ?? L("boss.donjon")
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
                .font(Jetons.typoMicro.font)
                .frame(width: Jetons.hauteurCase, height: Jetons.hauteurCase)
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
        HStack(spacing: Jetons.espace1) {
            ForEach(choix, id: \.valeur) { option in
                let actif = option.valeur == actuel
                Button { choisir(actif ? nil : option.valeur) } label: {
                    Text(option.titre)
                        .font(Jetons.typoMicro.font)
                        .frame(maxWidth: .infinity, minHeight: Jetons.hauteurCase)
                }
                .buttonStyle(.etat(choisi: actif))
            }
        }
    }
}
