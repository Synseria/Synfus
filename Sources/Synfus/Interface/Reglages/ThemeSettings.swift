import SwiftUI

/// Onglet Thème : la nuance, la couleur et le fond de l'app, appliqués en direct dans les réglages comme dans
/// la barre et les panneaux (`ThemeCourant`).
struct ThemeSettings: View {
    var body: some View {
        PageReglages {
            Bloc {
                ChoixDeNuance()
                ChoixDuTheme()
                ChoixDuFond()
            }
            Bloc(L("theme.apercu")) {
                ApercuTheme().rangee()
            }
        }
    }
}

/// Système suit macOS (Jour en clair, Pénombre en sombre) ; une nuance s'impose à toutes les fenêtres.
private struct ChoixDeNuance: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Ligne(titre: L("theme.nuance")) {
            SegmenteTexte(titre: L("theme.nuance"),
                          options: [(nil, L("theme.nuance.systeme"))] + Jetons.Nuance.allCases.map { ($0, $0.libelle) },
                          selection: $prefs.nuanceDeLApp)
        }
    }
}

/// Les onze coloris en pastilles, puis Personnalisé : une teinte au curseur.
private struct ChoixDuTheme: View {
    @ObservedObject private var prefs = Preferences.shared
    @Environment(\.colorScheme) private var schema

    private enum Choix: Hashable { case coloris(Jetons.Coloris), personnalise }

    private var choix: Choix { prefs.themeDeLApp.coloris.map(Choix.coloris) ?? .personnalise }

    var body: some View {
        Ligne(titre: L("theme.couleur")) {
            HStack(spacing: Jetons.espace2) {
                ForEach(Jetons.Coloris.allCases) { pastille($0) }
                Button { choisir(.personnalise) } label: {
                    Text(L("theme.personnalise"))
                        .font(Jetons.typoCorps.font)
                        .padding(.horizontal, Jetons.espace3)
                        .frame(height: Jetons.hauteurControle)
                        .overlay {
                            if choix != .personnalise {
                                Capsule().strokeBorder(Color.jeton(\.filet), lineWidth: Jetons.epaisseurFilet)
                            }
                        }
                }
                .buttonStyle(.etat(choisi: choix == .personnalise, rayon: Jetons.rayonPilule))
                .elementDeGroupe()
                .accessibilityAddTraits(choix == .personnalise ? .isSelected : [])
            }
            .groupeSelection(L("theme.couleur"), selection: Binding(get: { choix }, set: choisir),
                             parmi: Jetons.Coloris.allCases.map(Choix.coloris) + [.personnalise])
        }
        if case .personnalise(let couleur) = prefs.themeDeLApp.primaire {
            CurseurDeTeinte(teinte: ConversionDuTheme.teinte(couleur)) {
                prefs.themeDeLApp = prefs.themeDeLApp.avecLaPrimaire(.personnalise(ConversionDuTheme.aLaTeinte(couleur, $0)))
            }
        }
    }

    private func choisir(_ nouveau: Choix) {
        switch nouveau {
        case .coloris(let coloris): prefs.themeDeLApp = prefs.themeDeLApp.avecLaPrimaire(.coloris(coloris))
        case .personnalise:
            guard case .coloris = prefs.themeDeLApp.primaire else { return }
            prefs.themeDeLApp = prefs.themeDeLApp.avecLaPrimaire(.personnalise(Jetons.personnaliseParDefaut))
        }
    }

    private func pastille(_ coloris: Jetons.Coloris) -> some View {
        let choisie = choix == .coloris(coloris)
        let nuance = ThemeCourant.reglage.nuance(sombre: schema == .dark)
        let plein = ThemeCourant.couleurs(prefs.themeDeLApp.avecLaPrimaire(.coloris(coloris)), nuance).accent.couleur
        return Button { choisir(.coloris(coloris)) } label: {
            Circle().fill(plein)
                .frame(width: Jetons.diametreRond, height: Jetons.diametreRond)
                .padding(Jetons.decalageFocus)
                // Un anneau d'`encre` : lisible sur toutes les pastilles, dans toutes les nuances.
                .overlay { if choisie { Circle().strokeBorder(Color.jeton(\.encre), lineWidth: Jetons.epaisseurFocus) } }
        }
        .buttonStyle(.plain)
        .curseurDeClic(true)
        .elementDeGroupe()
        .aide(coloris.libelle)
        .accessibilityAddTraits(choisie ? .isSelected : [])
    }
}

/// Les fonds nommés en pastilles, à leur couleur ; celui du thème porte un point d'accent. Le choisir
/// revient à suivre le thème : changer de couleur changera aussi le fond.
private struct ChoixDuFond: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let theme = prefs.themeDeLApp
        Ligne(titre: L("theme.fond")) {
            HStack(spacing: Jetons.espace2) {
                ForEach(Jetons.FondNomme.allCases) { pastille($0, theme: theme) }
            }
            .groupeSelection(L("theme.fond"), selection: Binding(get: { theme.fondApplique }, set: choisir),
                             parmi: Jetons.FondNomme.allCases.map { .nomme($0) })
        }
    }

    private func choisir(_ fond: Jetons.Fond) {
        prefs.themeDeLApp = prefs.themeDeLApp.avecLeFond(fond)
    }

    private func pastille(_ fond: Jetons.FondNomme, theme: Jetons.Theme) -> some View {
        let choisie = theme.fondApplique == .nomme(fond)
        let duTheme = fond == theme.fondParDefaut
        return Button { choisir(.nomme(fond)) } label: {
            Circle().fill(Jetons.RVB(fond.couleur).couleur)
                .frame(width: Jetons.diametreRond, height: Jetons.diametreRond)
                .overlay {
                    if duTheme {
                        Circle().fill(Color.jeton(\.accent))
                            .overlay { Circle().strokeBorder(Color.jeton(\.texteSurAccent), lineWidth: Jetons.epaisseurFilet) }
                            .frame(width: Jetons.diametreMini / 2, height: Jetons.diametreMini / 2)
                    }
                }
                .padding(Jetons.decalageFocus)
                .overlay { if choisie { Circle().strokeBorder(Color.jeton(\.encre), lineWidth: Jetons.epaisseurFocus) } }
        }
        .buttonStyle(.plain)
        .curseurDeClic(true)
        .elementDeGroupe()
        .aide(duTheme ? L("theme.fond.duTheme", fond.libelle) : fond.libelle)
        .accessibilityAddTraits(choisie ? .isSelected : [])
    }
}

extension Jetons.FondNomme {
    var libelle: String {
        switch self {
        case .ardoise: L("theme.fond.ardoise")
        case .lagune: L("theme.fond.lagune")
        case .sable: L("theme.fond.sable")
        case .brique: L("theme.fond.brique")
        case .graphite: L("theme.fond.graphite")
        }
    }
}

extension Jetons.Coloris {
    var libelle: String {
        switch self {
        case .cerise: L("theme.coloris.cerise")
        case .terracotta: L("theme.coloris.terracotta")
        case .abricot: L("theme.coloris.abricot")
        case .ambre: L("theme.coloris.ambre")
        case .miel: L("theme.coloris.miel")
        case .sauge: L("theme.coloris.sauge")
        case .lagon: L("theme.coloris.lagon")
        case .bleuet: L("theme.coloris.bleuet")
        case .lilas: L("theme.coloris.lilas")
        case .prune: L("theme.coloris.prune")
        case .graphite: L("theme.coloris.graphite")
        }
    }
}

extension Jetons.Nuance {
    var libelle: String {
        switch self {
        case .jour: L("theme.nuance.jour")
        case .crepuscule: L("theme.nuance.crepuscule")
        case .penombre: L("theme.nuance.penombre")
        case .nuit: L("theme.nuance.nuit")
        }
    }
}

/// La teinte de Personnalisé au curseur, en degrés.
private struct CurseurDeTeinte: View {
    let appliquer: (Int) -> Void
    @State private var valeur: Double

    init(teinte: Int, appliquer: @escaping (Int) -> Void) {
        self.appliquer = appliquer
        _valeur = State(initialValue: Double(teinte))
    }

    var body: some View {
        Ligne(titre: L("theme.teinte")) {
            HStack(spacing: Jetons.espace2) {
                Slider(value: $valeur, in: 0...359, step: 1)
                    .frame(width: Jetons.largeurNav)
                    .onChange(of: valeur) { _, nouvelle in appliquer(Int(nouvelle)) }
                Text("\(Int(valeur))°")
                    .font(Jetons.typoTitreCarte.font.monospacedDigit())
                    .foregroundStyle(Color.jeton(\.encre2))
                    .frame(width: Jetons.espace7, alignment: .trailing)
            }
        }
    }
}

/// La barre et deux rangées de la palette par leurs vraies vues, sans interaction, sur le fond de la
/// Nuit, comme un jeu : la couleur se juge sur ce qu'on verra, pas sur la fenêtre des réglages.
private struct ApercuTheme: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var classesStore = ClassesStore.shared

    /// Deux zaaps de la carte, nommés dans la langue de l'interface, comme la palette les montre.
    private static var rangees: [EntreePalette] {
        let langue = L10n.courante.langue
        return CarteDuJeu.integree.zaaps.prefix(2).enumerated().map { rang, zaap in
            EntreePalette(id: "apercu.\(rang)", genre: .zaap, titre: zaap.nom(en: langue),
                          sousTitre: zaap.zone(en: langue), detail: Coordonnees.texte(zaap.x, zaap.y),
                          effet: .copier(""))
        }
    }

    /// Deux classes du catalogue, nommées dans la langue de l'interface.
    private var classes: [DofusClass.Breed] { Array(classesStore.catalogue.breeds.prefix(2)) }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace3) {
            barre
            VStack(spacing: 0) {
                ForEach(Array(Self.rangees.enumerated()), id: \.element.id) { rang, entree in
                    LigneResultat(entree: entree, choisie: rang == 0)
                }
            }
            .padding(Jetons.espace1)
            .frame(maxWidth: PalettePanel.largeur)
            .surfaceFlottante()
        }
        .padding(Jetons.espace4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Jetons.rayon2, style: .continuous).fill(Color.jeton(\.fondFenetre, en: .nuit)))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var barre: some View {
        HStack(spacing: Jetons.espace1) {
            ForEach(Array(zip(["Syn-App", "Brok"], classes).enumerated()), id: \.offset) { rang, perso in
                let devant = rang == 0
                PastillePerso(
                    nom: perso.0, classe: perso.1.label, libelleClasse: perso.1.nomLocalise, devant: devant,
                    touche: BarView.toucheDuPerso(index: rang, raccourcis: prefs.hotKeys),
                    affichage: AffichagePastille(devant: devant, reduireInactifs: prefs.reduirePersosInactifs,
                                                 embleme: prefs.showClasses, touche: prefs.showNumbers, aUneClasse: true))
            }
            ForEach(BoutonBarre.affiches(sauf: prefs.boutonsMasques), id: \.self) { bouton in
                ModeButton(icone: bouton.symbole, actif: bouton == .palette, aide: bouton.libelle) {}
            }
        }
        .padding(Jetons.espace1)
        .fixedSize()
        .surfaceFlottante()
    }
}
