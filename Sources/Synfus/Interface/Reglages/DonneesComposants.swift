import SwiftUI

/// Les briques des onglets de données (Zaaps, Lieux, Quêtes, PNJ) : d'où
/// vient la liste et le bouton qui la met à jour, l'étiquette, le favori.

/// La carte du jeu (zaaps et lieux) : sa date, son contenu, sa mise à jour.
struct SourceCarte: View {
    @ObservedObject private var carte = CarteStore.shared
    @State private var miseAJour = false
    @State private var echec: String?

    var body: some View {
        Ligne(titre: echec.map { L("zaap.maj.echec", $0) }
                ?? L("zaap.maj.date", carte.carte.date.formatted(date: .abbreviated, time: .shortened)),
              sousTexte: L("palette.reglages.carte.contenu", carte.carte.lieux.count, carte.carte.zaaps.count),
              aide: L("zaap.maj.aide")) {
            HStack(spacing: 8) {
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
              sousTexte: quetes.quetes.map { L("palette.reglages.quetes.contenu", $0.quetes.count, $0.pnjs.count) },
              aide: L("palette.reglages.quetes.aide")) {
            HStack(spacing: 8) {
                if quetes.chargement { ProgressView().controlSize(.small) }
                Button(L("palette.reglages.quetes.maj")) { Task { try? await quetes.mettreAJour() } }
                    .disabled(quetes.chargement)
            }
        }
        .onAppear { quetes.preparer() }
    }

    private var titre: String {
        if let echec = quetes.echec { return L("zaap.maj.echec", echec) }
        guard let date = quetes.quetes?.date else { return L("palette.reglages.quetes.aucune") }
        return L("palette.reglages.quetes.date", date.formatted(date: .abbreviated, time: .shortened))
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
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(Color.secondary.opacity(0.5), style: StrokeStyle(dash: [3, 2])))
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $edition, arrowEdge: .bottom) {
            HStack(spacing: 8) {
                TextField(L("palette.etiquette.exemple"), text: $texte)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 160)
                    .onSubmit(valider)
                Button(L("palette.reglages.ok"), action: valider)
            }
            .padding(10)
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
                .foregroundStyle(favori ? Couleurs.ambre : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help(favori ? L("zaap.favori.retirer") : L("zaap.favori.ajouter"))
    }
}

/// Copier le trajet vers une case, zaap compris — le geste des listes.
struct BoutonTrajet: View {
    let x: Int
    let y: Int
    @State private var copie = false

    var body: some View {
        Button {
            ZaapClipboard.shared.copierTrajet(vers: (x, y))
            copie = true
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                copie = false
            }
        } label: {
            HStack(spacing: 4) {
                Text(Coordonnees.texte(x, y)).font(.system(size: 11, design: .monospaced))
                Image(systemName: copie ? "checkmark" : "doc.on.clipboard")
            }
            .foregroundStyle(copie ? Couleurs.accent : Color.secondary)
        }
        .buttonStyle(.borderless)
        .help(L("quete.copierTrajet"))
    }
}
