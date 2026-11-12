import SwiftUI

/// Les briques des onglets de données (Zaaps, Lieux, Quêtes, PNJ, Classes) : d'où
/// vient la liste et le bouton qui la met à jour, l'étiquette, le favori.

/// La carte du jeu (zaaps et lieux) : sa date, son contenu, sa mise à jour.
struct SourceCarte: View {
    @ObservedObject private var carte = CarteStore.shared
    @State private var miseAJour = false
    @State private var echec: String?

    var body: some View {
        Ligne(titre: echec.map { _ in L("zaap.maj.echec") }
                ?? L("zaap.maj.date", carte.carte.date.formatted(date: .abbreviated, time: .shortened)),
              etat: L("palette.reglages.carte.contenu", carte.carte.lieux.count, carte.carte.zaaps.count),
              aide: L("zaap.maj.aide")) {
            HStack(spacing: Jetons.Espace.deux) {
                if miseAJour { ProgressView().controlSize(.small) }
                Button(L("zaap.maj")) {
                    miseAJour = true
                    echec = nil
                    Task {
                        do { try await carte.mettreAJour() } catch { echec = error.localizedDescription }
                        miseAJour = false
                    }
                }
                .disabled(miseAJour)
            }
        }
    }
}

/// Les quêtes (et les PNJ qu'elles situent) : date, contenu, mise à jour.
struct SourceQuetes: View {
    @ObservedObject private var quetes = QuetesStore.shared

    var body: some View {
        Ligne(titre: titre,
              etat: quetes.quetes.map { L("palette.reglages.quetes.contenu", $0.quetes.count, $0.pnjs.count) },
              aide: L("palette.reglages.quetes.aide")) {
            HStack(spacing: Jetons.Espace.deux) {
                if quetes.chargement { ProgressView().controlSize(.small) }
                Button(L("palette.reglages.quetes.maj")) { Task { try? await quetes.mettreAJour() } }
                    .disabled(quetes.chargement)
            }
        }
        .onAppear { quetes.preparer() }
    }

    private var titre: String {
        if quetes.echec != nil { return L("zaap.maj.echec") }
        guard let date = quetes.quetes?.date else { return L("palette.reglages.quetes.aucune") }
        return L("palette.reglages.quetes.date", date.formatted(date: .abbreviated, time: .shortened))
    }
}

/// Les classes (noms et emblèmes) : date, contenu, mise à jour.
struct SourceClasses: View {
    @ObservedObject private var classes = ClassesStore.shared

    var body: some View {
        Ligne(titre: titre, etat: L("classes.maj.contenu", classes.catalogue.breeds.count),
              aide: L("classes.maj.aide")) {
            HStack(spacing: Jetons.Espace.deux) {
                if classes.chargement { ProgressView().controlSize(.small) }
                Button(L("classes.maj")) { Task { try? await classes.mettreAJour() } }
                    .disabled(classes.chargement)
            }
        }
    }

    private var titre: String {
        if classes.echec != nil { return L("zaap.maj.echec") }
        guard let date = classes.date else { return L("classes.maj.aucune") }
        return L("classes.maj.date", date.formatted(date: .abbreviated, time: .shortened))
    }
}

/// L'étiquette libre d'un zaap ou d'un lieu : la pastille, ou « + Étiquette »,
/// qui s'écrit au clic.
struct BoutonEtiquette: View {
    let cle: String
    @ObservedObject private var prefs = Preferences.shared
    @State private var edition = false
    @State private var texte = ""

    var body: some View {
        Button { texte = prefs.etiquettes[cle] ?? ""; edition = true } label: {
            if let etiquette = prefs.etiquettes[cle] {
                PastilleEtiquette(texte: etiquette)
            } else {
                Text(L("palette.reglages.etiquette"))
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .padding(.horizontal, Jetons.Espace.un)
                    .padding(.vertical, Jetons.Espace.un)
                    .overlay(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille)
                        .strokeBorder(Color.jeton(\.encreSecondaire).opacity(0.5), style: StrokeStyle(dash: [3, 2])))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $edition, arrowEdge: .bottom) {
            HStack(spacing: Jetons.Espace.deux) {
                TextField(L("palette.etiquette.exemple"), text: $texte)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit(valider)
                Button(L("palette.reglages.ok"), action: valider)
            }
            .padding(Jetons.Espace.deux)
        }
    }

    private func valider() {
        let propre = texte.trimmingCharacters(in: .whitespaces)
        prefs.etiquettes[cle] = propre.isEmpty ? nil : propre
        edition = false
    }
}

/// L'étoile d'un zaap ou d'un lieu.
struct BoutonFavori: View {
    let cle: String
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let favori = prefs.estFavori(cle)
        Button { prefs.basculerFavori(cle) } label: {
            Image(systemName: favori ? "star.fill" : "star")
                .foregroundStyle(favori ? Color.jeton(\.safranTexte) : Color.jeton(\.encreSecondaire))
        }
        .buttonStyle(.borderless)
        .aide(favori ? L("zaap.favori.retirer") : L("zaap.favori.ajouter"))
    }
}

/// Copier le trajet vers une case, zaap compris dans le Monde des Douze — le
/// geste des listes. La sous-zone dit si la case en est (`ReseauSousZones.horsDesDouze`).
struct BoutonTrajet: View {
    let x: Int
    let y: Int
    let sousZone: Int?
    @State private var copie = false

    private var dansLesDouze: Bool { !CarteStore.shared.reseau.horsDesDouze(sousZone) }

    var body: some View {
        Button {
            ZaapClipboard.shared.copierTrajet(vers: (x, y), sousZone: sousZone, dansLesDouze: dansLesDouze)
            copie = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                copie = false
            }
        } label: {
            HStack(spacing: Jetons.Espace.un) {
                Text(Coordonnees.texte(x, y)).font(Jetons.Typo.codeInterface.police)
                Image(systemName: copie ? "checkmark" : "doc.on.clipboard")
            }
            .foregroundStyle(copie ? Color.jeton(\.primaireEncre) : Color.jeton(\.encreSecondaire))
        }
        .buttonStyle(.borderless)
        .help(dansLesDouze ? L("ouTrouver.copierTrajet") : L("trajet.copier.horsDesDouze"))
    }
}

/// Les vues des cartes, partout à la fois : vignettes de la palette, des
/// listes et du panneau des quêtes, fonds des zaaps. Sur chaque page qui en
/// montre, un seul réglage derrière.
struct InterrupteurVuesCartes: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Interrupteur(titre: L("vuesCartes"), aide: L("vuesCartes.aide"), isOn: $prefs.vuesCartes)
    }
}
