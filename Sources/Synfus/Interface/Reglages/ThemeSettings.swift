import SwiftUI

/// Onglet Thème : la couleur de l'app et la teinte des fonds, appliquées en direct dans les réglages
/// comme dans la barre et les panneaux (`ThemeCourant`).
struct ThemeSettings: View {
    var body: some View {
        PageReglages(titre: L("reglages.theme")) {
            Section {
                ChoixDeCouleur()
                ChoixDesFonds()
            }
        }
    }
}

/// Les cinq préréglages en pastilles, puis « Autre… » : une teinte au curseur, que la primaire
/// refuse près du safran (`Jetons.teinteAcceptee`).
private struct ChoixDeCouleur: View {
    @ObservedObject private var prefs = Preferences.shared
    @Environment(\.colorScheme) private var schema

    private var courante: Jetons.Couleur { prefs.couleurDeLApp }
    private var estAutre: Bool {
        if case .teinte = courante { true } else { false }
    }

    var body: some View {
        Ligne(titre: L("theme.couleur")) {
            HStack(spacing: Jetons.Espace.deux) {
                ForEach(Jetons.Prereglage.allCases) { prereglage in
                    pastille(prereglage)
                }
                Button { choisirAutre() } label: {
                    Text(L("theme.autre"))
                        .font(Jetons.Typo.corps.police)
                        .padding(.horizontal, Jetons.Espace.trois)
                        .frame(height: Jetons.Taille.controle)
                        .overlay {
                            if !estAutre {
                                Capsule().strokeBorder(Color.jeton(\.contourControle), lineWidth: Jetons.Trait.filet)
                            }
                        }
                }
                .buttonStyle(.etat(choisi: estAutre, rayon: Jetons.Rayon.capsule))
                .accessibilityAddTraits(estAutre ? .isSelected : [])
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
                // Un anneau d'`encre` : lisible sur toutes les pastilles, en clair comme en sombre.
                .overlay { if choisie { Circle().strokeBorder(Color.jeton(\.encre), lineWidth: Jetons.Trait.focus) } }
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
        case .azur: L("theme.prereglage.azur")
        case .jade: L("theme.prereglage.jade")
        case .framboise: L("theme.prereglage.framboise")
        case .corail: L("theme.prereglage.corail")
        case .ardoise: L("theme.prereglage.ardoise")
        }
    }
}

/// Auto, Primaire, Nuit, Neutre ou Autre… : seule la teinte des neutres change, jamais leur clarté.
/// Auto est le choix non fait (`fondsDeLApp == nil`) : primaire en clair, nuit en sombre.
private struct ChoixDesFonds: View {
    @ObservedObject private var prefs = Preferences.shared

    private enum Choix: Hashable { case auto, primaire, nuit, neutre, autre }

    private var choix: Choix {
        switch prefs.fondsDeLApp {
        case nil: .auto
        case .primaire: .primaire
        case .nuit: .nuit
        case .neutre: .neutre
        case .teinte: .autre
        }
    }

    var body: some View {
        Ligne(titre: L("theme.fonds")) {
            Segments(L("theme.fonds"), selection: Binding(get: { choix }, set: choisir), choix: [
                (Choix.auto, L("commun.auto")), (.primaire, L("theme.fonds.primaire")), (.nuit, L("theme.fonds.nuit")),
                (.neutre, L("theme.fonds.neutre")), (.autre, L("theme.autre"))])
        }
        if case .teinte(let teinte) = prefs.fondsDeLApp {
            CurseurDeTeinte(teinte: teinte, accepte: { _ in true }) { prefs.fondsDeLApp = .teinte($0) }
        }
    }

    private func choisir(_ nouveau: Choix) {
        switch nouveau {
        case .auto: prefs.fondsDeLApp = nil
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
        Ligne(titre: L("theme.teinte")) {
            HStack(spacing: Jetons.Espace.deux) {
                Slider(value: $valeur, in: 0...359, step: 1)
                    .frame(width: 200)
                    .onChange(of: valeur) { _, nouvelle in
                        if accepte(Int(nouvelle)) { appliquer(Int(nouvelle)) }
                    }
                Text("\(Int(valeur))°")
                    .font(Jetons.Typo.chiffre.police)
                    .foregroundStyle(refusee ? Color.jeton(\.danger) : Color.jeton(\.encreSecondaire))
                    .frame(width: 40, alignment: .trailing)
                if refusee {
                    Image(systemName: "nosign")
                        .foregroundStyle(Color.jeton(\.danger))
                        .aide(L("theme.proche"))
                }
            }
        }
    }
}
