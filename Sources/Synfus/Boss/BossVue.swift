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
    @State private var rappels = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            entete
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                if let fiche = aide.fiches[prefs.bossChoisi] { Self.ficheVue(fiche) }
                if previews.authorized {
                    ligneTour
                    switch prefs.bossChoisi {
                    case .harebourg: HarebourgVue()
                    case .kimbo: KimboVue()
                    case .toxoliath: ToxoliathVue()
                    case .ilyzaelle: IlyzaelleVue()
                    case .talKasha: TalKashaVue()
                    }
                } else {
                    autorisation
                }
                rappelsVue
            }
            .padding(12)
        }
        .frame(width: Self.largeur, alignment: .leading)
        .font(.synfus(.note))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.primary.opacity(0.12)))
        // L'autorisation donnée, la lecture démarre sans attendre un
        // changement d'app.
        .onChange(of: previews.authorized) { BossPanel.shared.revoirVisibilite(force: false) }
        .task(id: prefs.bossChoisi) { aide.chargerFiche(prefs.bossChoisi) }
    }

    /// Niveau, vie, PA et PM du plus haut grade, puis les résistances.
    private static func ficheVue(_ fiche: FicheBoss) -> some View {
        let res = fiche.resistances
        return VStack(alignment: .leading, spacing: 2) {
            Text(L("boss.fiche", fiche.niveau, fiche.vie.formatted(), fiche.pa, fiche.pm))
                .font(.synfus(.petit, gras: true))
            Text(L("boss.fiche.resistances", res[.neutre] ?? 0, res[.terre] ?? 0, res[.feu] ?? 0,
                   res[.eau] ?? 0, res[.air] ?? 0))
                .font(.synfus(.petit))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .help(L("boss.fiche.aide"))
    }

    private var entete: some View {
        EnTetePanneau(icone: "scope", teinte: Couleurs.ambre, menu: Self.menu) {
            Text(Self.nom(prefs.bossChoisi)).font(.synfus(.note, gras: true))
                .padding(.leading, 6)
            Image(systemName: "chevron.down").font(.synfus(.marque, gras: true)).foregroundStyle(.secondary)
                .padding(.leading, 3)
            if let perso = lecteur.persoDevant {
                Text(perso).font(.synfus(.petit)).foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.horizontal, 6)
            }
        } boutons: {
            BoutonEnTete(icone: "book", aide: L("boss.guide")) {
                let donjon = Preferences.shared.bossChoisi.donjon
                Task { await DofusPourLesNoobs.ouvrir(donjon) }
            }
            BoutonEnTete(icone: "minus", aide: L("quete.fermer.simple")) { BossPanel.shared.fermer() }
        }
    }

    /// Le menu du titre : les boss, le choisi coché.
    private static func menu() -> NSMenu {
        let menu = NSMenu()
        for boss in Boss.allCases {
            let item = CibleMenu.shared.element(nom(boss)) { AideBoss.shared.choisir(boss) }
            item.state = boss == Preferences.shared.bossChoisi ? .on : .off
            menu.addItem(item)
        }
        return menu
    }

    /// Le tour du combat compté chez le perso devant, à corriger d'un clic.
    private var ligneTour: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock").foregroundStyle(.secondary)
            Text(aide.tour.map { L("boss.tour", $0) } ?? L("boss.tour.attente"))
                .font(.synfus(.petit, gras: aide.tour != nil))
                .foregroundStyle(aide.tour == nil ? Color.secondary : Color.primary)
                .help(L("boss.tour.aide"))
            Spacer()
            PetitBouton(icone: "minus", aide: L("boss.tour.moins")) { aide.corrigerTour(-1) }
                .disabled((aide.tour ?? 1) <= 1)
            PetitBouton(icone: "plus", aide: L("boss.tour.plus")) { aide.corrigerTour(1) }
        }
        .disabled(lecteur.persoDevant == nil)
    }

    private var autorisation: some View {
        HStack(spacing: 8) {
            Text(L("boss.autoriser.aide"))
                .font(.synfus(.petit))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button { previews.requestAuthorization() } label: { Image(systemName: "lock") }
                .buttonStyle(.borderless)
                .aide(L("boss.autoriser"))
        }
    }

    private var rappelsVue: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button { rappels.toggle() } label: {
                Label(L("boss.rappels"), systemImage: rappels ? "chevron.down" : "chevron.right")
                    .font(.synfus(.petit, gras: true))
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if rappels {
                ForEach(Self.rappels(prefs.bossChoisi), id: \.self) {
                    Text("• " + $0)
                        .font(.synfus(.petit))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Libellés

    static func nom(_ boss: Boss) -> String {
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
                .font(.synfus(.petit, gras: true))
                .frame(width: 22, height: 20)
                .background(RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.primary.opacity(0.08)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        HStack(spacing: 6) {
            ForEach(choix, id: \.valeur) { option in
                let actif = option.valeur == actuel
                Button { choisir(actif ? nil : option.valeur) } label: {
                    Text(option.titre)
                        .font(.synfus(.petit, gras: true))
                        .frame(maxWidth: .infinity, minHeight: 24)
                        .foregroundStyle(actif ? Color.white : Color.primary)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(actif ? Couleurs.accentPlein : Color.primary.opacity(0.08)))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}
