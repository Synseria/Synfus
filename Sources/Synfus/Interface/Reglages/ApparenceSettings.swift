import SwiftUI

/// Onglet Apparence : la couleur de l'app, la teinte des fonds et les icônes (app, barre de menus).
/// Couleurs et fonds s'appliquent en direct, dans les réglages comme dans la barre et les panneaux
/// (`Couleurs`).
struct ApparenceSettings: View {
    var body: some View {
        PageReglages(titre: L("reglages.apparence")) {
            Section {
                ChoixDeCouleur()
                ChoixDesFonds()
            }
            Section { IconesReglables() }
        }
    }
}

/// Les deux icônes : celle de l'app (Finder, alertes) et celle de la barre de menus.
private struct IconesReglables: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Ligne(titre: L("apparence.iconeApp"), aide: L("apparence.iconeApp.aide")) {
            ChoixIconeApp(choix: Binding(
                get: { prefs.iconeApp },
                set: { prefs.iconeApp = $0; IconeAppliquee.appliquer($0) }
            ))
        }
        Ligne(titre: L("apparence.icone")) {
            Picker(L("apparence.icone"), selection: Binding(
                get: { prefs.menuBarIcon },
                set: { prefs.menuBarIcon = $0; MenuBarController.shared.refreshIcon() }
            )) {
                ForEach(MenuBarIcon.allCases) { Text($0.label).tag($0) }
            }
            .labelsHidden()
            .fixedSize()
        }
    }
}

/// Les huit icônes de l'app, un motif par ligne, un fond par colonne : chacune
/// est son propre aperçu, la choisie teintée.
private struct ChoixIconeApp: View {
    @Binding var choix: IconeApp
    private let cote = Jetons.Espace.dix

    var body: some View {
        Grid(horizontalSpacing: Jetons.Espace.un, verticalSpacing: Jetons.Espace.un) {
            ForEach(IconeApp.Motif.allCases, id: \.self) { motif in
                GridRow {
                    ForEach(IconeApp.Fond.allCases, id: \.self) { fond in
                        vignette(IconeApp(motif: motif, fond: fond))
                    }
                }
            }
        }
    }

    private func vignette(_ icone: IconeApp) -> some View {
        Button { choix = icone } label: {
            Image(nsImage: IconeAppliquee.vignette(icone, cote: cote))
                .padding(Jetons.Espace.un)
        }
        .buttonStyle(.etat(choisi: icone == choix, nue: true))
        .aide(L("apparence.iconeApp.vignette", icone.motif.nom, icone.fond.nom))
        .accessibilityAddTraits(icone == choix ? .isSelected : [])
    }
}

private extension IconeApp.Motif {
    var nom: String {
        switch self {
        case .oeuf: L("apparence.iconeApp.oeuf")
        case .couvee: L("apparence.iconeApp.couvee")
        }
    }
}

private extension IconeApp.Fond {
    var nom: String {
        switch self {
        case .nuit: L("apparence.iconeApp.nuit")
        case .foret: L("apparence.iconeApp.foret")
        case .aube: L("apparence.iconeApp.aube")
        case .transparent: L("apparence.iconeApp.transparent")
        }
    }
}

/// Les six préréglages en pastilles, puis « Autre… » : une teinte au curseur, que la primaire
/// refuse près du safran (`Jetons.teinteAcceptee`).
private struct ChoixDeCouleur: View {
    @ObservedObject private var prefs = Preferences.shared
    @Environment(\.colorScheme) private var schema

    private var courante: Jetons.Couleur { prefs.couleurDeLApp }
    private var estAutre: Bool {
        if case .teinte = courante { true } else { false }
    }

    var body: some View {
        Ligne(titre: L("apparence.couleur")) {
            HStack(spacing: Jetons.Espace.deux) {
                ForEach(Jetons.Prereglage.allCases) { prereglage in
                    pastille(prereglage)
                }
                Button(L("apparence.autre")) { choisirAutre() }
                    .buttonStyle(.etat(choisi: estAutre, rayon: Jetons.Rayon.capsule))
            }
        }
        if case .teinte(let teinte) = courante {
            CurseurDeTeinte(teinte: teinte, accepte: Jetons.teinteAcceptee) { prefs.couleurDeLApp = .teinte($0) }
        }
    }

    private func pastille(_ prereglage: Jetons.Prereglage) -> some View {
        let choisie = courante == .prereglage(prereglage)
        let nom = prereglage.libelle
        let plein = Jetons.theme(.prereglage(prereglage), schema == .dark ? .sombre : .clair).primaire.couleur
        return Button { prefs.couleurDeLApp = .prereglage(prereglage) } label: {
            Circle().fill(plein)
                .frame(width: Jetons.Taille.controle - Jetons.Espace.deux, height: Jetons.Taille.controle - Jetons.Espace.deux)
                .padding(Jetons.Trait.focusEcart)
                .overlay { if choisie { Circle().strokeBorder(Couleurs.primaireEncre, lineWidth: Jetons.Trait.focus) } }
        }
        .buttonStyle(.plain)
        .aide(nom)
        .accessibilityAddTraits(choisie ? .isSelected : [])
    }

    /// Part de la teinte du préréglage courant, sinon d'un bleu que le safran n'approche pas.
    private func choisirAutre() {
        guard case .prereglage(let p) = courante else { return }
        prefs.couleurDeLApp = .teinte(Jetons.teinteAcceptee(p.teinte) ? p.teinte : 200)
    }
}

private extension Jetons.Prereglage {
    var libelle: String {
        switch self {
        case .azur: L("apparence.prereglage.azur")
        case .jade: L("apparence.prereglage.jade")
        case .violet: L("apparence.prereglage.violet")
        case .framboise: L("apparence.prereglage.framboise")
        case .corail: L("apparence.prereglage.corail")
        case .ardoise: L("apparence.prereglage.ardoise")
        }
    }
}

/// Primaire, Nuit, Neutre ou Autre… : seule la teinte des neutres change, jamais leur clarté.
private struct ChoixDesFonds: View {
    @ObservedObject private var prefs = Preferences.shared

    private enum Choix: Hashable { case primaire, nuit, neutre, autre }

    private var choix: Choix {
        switch prefs.fondsDeLApp {
        case .primaire: .primaire
        case .nuit: .nuit
        case .neutre: .neutre
        case .teinte: .autre
        }
    }

    var body: some View {
        Ligne(titre: L("apparence.fonds")) {
            Picker(L("apparence.fonds"), selection: Binding(get: { choix }, set: choisir)) {
                Text(L("apparence.fonds.primaire")).tag(Choix.primaire)
                Text(L("apparence.fonds.nuit")).tag(Choix.nuit)
                Text(L("apparence.fonds.neutre")).tag(Choix.neutre)
                Text(L("apparence.autre")).tag(Choix.autre)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
        if case .teinte(let teinte) = prefs.fondsDeLApp {
            CurseurDeTeinte(teinte: teinte, accepte: { _ in true }) { prefs.fondsDeLApp = .teinte($0) }
        }
    }

    private func choisir(_ nouveau: Choix) {
        switch nouveau {
        case .primaire: prefs.fondsDeLApp = .primaire
        case .nuit: prefs.fondsDeLApp = .nuit
        case .neutre: prefs.fondsDeLApp = .neutre
        case .autre:
            if case .teinte = prefs.fondsDeLApp { return }
            prefs.fondsDeLApp = .teinte(268)
        }
    }
}

/// La teinte au curseur, en degrés. Une valeur refusée ne s'applique pas : le curseur la montre
/// barrée et la couleur reste celle d'avant.
private struct CurseurDeTeinte: View {
    let accepte: (Int) -> Bool
    let appliquer: (Int) -> Void
    @State private var valeur: Double

    init(teinte: Int, accepte: @escaping (Int) -> Bool, appliquer: @escaping (Int) -> Void) {
        self.accepte = accepte
        self.appliquer = appliquer
        _valeur = State(initialValue: Double(teinte))
    }

    var body: some View {
        let refusee = !accepte(Int(valeur))
        Ligne(titre: L("apparence.teinte")) {
            HStack(spacing: Jetons.Espace.deux) {
                Slider(value: $valeur, in: 0...359, step: 1)
                    .frame(width: 200)
                    .onChange(of: valeur) { _, nouvelle in
                        if accepte(Int(nouvelle)) { appliquer(Int(nouvelle)) }
                    }
                Text("\(Int(valeur))°")
                    .font(.synfus(.chiffre))
                    .foregroundStyle(refusee ? Couleurs.danger : Couleurs.encreSecondaire)
                    .frame(width: 40, alignment: .trailing)
                if refusee {
                    Image(systemName: "nosign")
                        .foregroundStyle(Couleurs.danger)
                        .aide(L("apparence.proche"))
                }
            }
        }
    }
}
