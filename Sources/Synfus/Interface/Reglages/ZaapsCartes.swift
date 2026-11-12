import SwiftUI

/// Un zaap dans les réglages : étiquette (au clic), favori, activation ; en
/// fond, la vue de sa carte du jeu (`vuesCartes`).
struct CarteZaapReglages: View {
    let zaap: Zaap
    let langue: Langue
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let actif = CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
        // Un zaap désactivé : `encreTertiaire` sur `creux`, comme tout ce qui ne répond plus.
        let encre = actif ? Color.jeton(\.encre) : Color.jeton(\.encreTertiaire)
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack(spacing: Jetons.Espace.un) {
                BoutonEtiquette(cle: zaap.cle)
                Spacer(minLength: 0)
                BoutonFavori(cle: zaap.cle)
                Toggle(L("palette.reglages.actif"), isOn: Binding(
                    get: { actif }, set: { prefs.zaapsChoix[zaap.cle] = $0 }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            Text(zaap.nom(en: langue))
                .font(Jetons.Typo.corpsFort.police)
                .foregroundStyle(encre)
                .lineLimit(1)
            HStack(spacing: Jetons.Espace.un) {
                Text(zaap.zone(en: langue) ?? (prefs.zaapsAjoutes.contains(zaap) ? L("zaap.ajoute") : ""))
                    .lineLimit(1)
                if zaap.monde != Zaap.mondeDesDouze {
                    Text(L("zaap.autreCarte")).foregroundStyle(Color.jeton(\.alerte))
                }
                Spacer(minLength: 0)
                Text(Coordonnees.texte(zaap.x, zaap.y)).font(Jetons.Typo.codeInterface.police)
            }
            .font(Jetons.Typo.petit.police)
            .foregroundStyle(actif ? Color.jeton(\.encreSecondaire) : Color.jeton(\.encreTertiaire))
        }
        .padding(Jetons.Espace.deux)
        .background { if actif { FondCarte(carte: zaap.idCarte) } else {
            RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous).fill(Color.jeton(\.creux))
        } }
        .contextMenu {
            if prefs.zaapsAjoutes.contains(zaap) {
                Button(L("zaap.supprimer"), role: .destructive) { confirmerSuppression() }
            }
        }
    }
}

extension CarteZaapReglages {
    /// Un zaap ajouté à la main ne se retrouve pas : un dernier mot avant de l'effacer.
    fileprivate func confirmerSuppression() {
        let zaap = zaap
        let langue = langue
        Task {
            let demande = DemandeConfirmation(titre: L("zaap.supprimer.confirmation", zaap.nom(en: langue)), verbe: L("commun.supprimer"))
            guard await Confirmation.demander(demande) else { return }
            let prefs = Preferences.shared
            prefs.zaapsAjoutes.removeAll { $0.cle == zaap.cle }
            prefs.zaapsChoix[zaap.cle] = nil
            prefs.zaapsFavoris.removeAll { $0 == zaap.cle }
            prefs.etiquettes[zaap.cle] = nil
        }
    }
}

/// La dernière case de la grille : un zaap que la carte ne connaît pas encore.
struct AjoutZaap: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var ouvert = false
    @State private var nom = ""
    @State private var x = ""
    @State private var y = ""

    var body: some View {
        Button { ouvert = true } label: {
            VStack(spacing: Jetons.Espace.un) {
                Image(systemName: "plus")
                Text(L("zaap.ajout")).font(Jetons.Typo.petit.police)
            }
            .foregroundStyle(Color.jeton(\.encreSecondaire))
            .frame(maxWidth: .infinity, minHeight: Jetons.Taille.rangeePalette + Jetons.Taille.controle - Jetons.Espace.deux)
            .overlay(RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous)
                .strokeBorder(Color.jeton(\.contourControle), style: StrokeStyle(lineWidth: Jetons.Trait.filet, dash: [Jetons.Espace.un, Jetons.Espace.un])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $ouvert, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                Text(L("zaap.ajout.aide")).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    .frame(width: 260, alignment: .leading)
                HStack(spacing: Jetons.Espace.un) {
                    TextField(L("zaap.ajout.nom"), text: $nom)
                    TextField("x", text: $x).frame(width: 50)
                    TextField("y", text: $y).frame(width: 50)
                }
                .textFieldStyle(.roundedBorder)
                HStack {
                    Spacer()
                    Button(L("zaap.ajout.bouton")) {
                        guard let zaap = nouveau else { return }
                        prefs.zaapsAjoutes.append(zaap)
                        nom = ""
                        x = ""
                        y = ""
                        ouvert = false
                    }
                    .disabled(nouveau == nil)
                }
            }
            .padding(Jetons.Espace.trois)
        }
    }

    private var nouveau: Zaap? {
        let nom = nom.trimmingCharacters(in: .whitespaces)
        guard !nom.isEmpty,
              let x = Int(x.trimmingCharacters(in: .whitespaces)),
              let y = Int(y.trimmingCharacters(in: .whitespaces)),
              abs(x) <= PositionCarte.borne, abs(y) <= PositionCarte.borne
        else { return nil }
        let zaap = Zaap(x, y, noms: [L10n.courante.langue.rawValue: nom])
        // Déjà connu : il suffit de l'activer dans la grille.
        return prefs.zaapsConnus.contains { $0.cle == zaap.cle } ? nil : zaap
    }
}
