import SwiftUI

/// Les zaaps : une ligne chacun — activé ou non, étiqueté, favori —, un ajout à la main, et la vue de
/// leur carte du jeu.
struct BlocZaaps: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var filtre = ""
    @State private var vue: Vue = .tous

    private enum Vue: CaseIterable {
        case tous, actifs, etiquetes

        var libelle: String {
            switch self {
            case .tous: return L("palette.reglages.tous")
            case .actifs: return L("palette.reglages.actifs")
            case .etiquetes: return L("palette.reglages.etiquetes")
            }
        }
    }

    var body: some View {
        let langue = L10n.courante.langue
        let connus = prefs.zaapsConnus
        let affiches = montres(connus, langue)
        Bloc(L("reglages.zaaps"), aide: L("zaap.liste.aide"), paresseux: true) {
            HStack(spacing: Jetons.espace2) {
                ChampFiltre(invite: L("palette.reglages.filtrer"), texte: $filtre)
                SegmenteTexte(titre: L("palette.reglages.vue"), options: Vue.allCases.map { ($0, $0.libelle) }, selection: $vue)
                AjoutZaap()
            }
            .rangee()
            if affiches.isEmpty {
                EtatDeBloc.aucun(L("zaap.aucun"), recherche: filtre)
            }
            ForEach(affiches, id: \.cle) { zaap in
                LigneZaap(zaap: zaap, langue: langue)
            }
        } entete: {
            Text(L("zaaps.compte", nombre: prefs.zaapsActifs.count, prefs.zaapsActifs.count, connus.count))
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.encre2))
        }
    }

    private func montres(_ connus: [Zaap], _ langue: Langue) -> [Zaap] {
        let etiquettes = prefs.etiquettes
        return ListesReglages.zaaps
            .elements(source: [AnyHashable(connus), AnyHashable(etiquettes), AnyHashable(langue)], filtre: filtre,
                      trier: {
                          connus.sorted { a, b in
                              // Le Monde des Douze d'abord, puis les autres cartes ; par nom ensuite.
                              let (autreA, autreB) = (a.monde != Zaap.mondeDesDouze, b.monde != Zaap.mondeDesDouze)
                              if autreA != autreB { return !autreA }
                              return a.nom(en: langue).localizedStandardCompare(b.nom(en: langue)) == .orderedAscending
                          }
                      },
                      champs: { zaap in
                          RecherchePalette.Champs(titre: zaap.nom(en: langue), etiquette: etiquettes[zaap.cle],
                                                  lieu: zaap.zone(en: langue))
                      })
            .filter { zaap in
                switch vue {
                case .tous: return true
                case .actifs: return CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
                case .etiquetes: return etiquettes[zaap.cle] != nil
                }
            }
    }
}

/// Un zaap sur une ligne : son nom et sa zone, puis son étiquette, son favori, ses coordonnées, son
/// interrupteur et la vue de sa carte. Un zaap désactivé passe en `encreTertiaire`, comme tout ce qui ne
/// répond plus.
private struct LigneZaap: View {
    let zaap: Zaap
    let langue: Langue
    @ObservedObject private var prefs = Preferences.shared
    @State private var confirmation: Confirmation?

    var body: some View {
        let actif = CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
        Ligne(titre: zaap.nom(en: langue),
              detail: zaap.monde == Zaap.mondeDesDouze ? nil : L("zaap.autreCarte"),
              etat: zaap.zone(en: langue) ?? (prefs.zaapsAjoutes.contains(zaap) ? L("zaap.ajoute") : nil)) {
            HStack(spacing: Jetons.espace2) {
                Text(Coordonnees.texte(zaap.x, zaap.y))
                    .font(Jetons.typoCode.font)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .frame(width: 80, alignment: .trailing)
                BoutonEtiquette(cle: zaap.cle)
                BoutonFavori(cle: zaap.cle)
                Toggle(L("palette.reglages.actif"), isOn: Binding(
                    get: { actif }, set: { prefs.zaapsChoix[zaap.cle] = $0 }))
                    .labelsHidden()
                    .toggleStyle(.interrupteur)
                if let carte = zaap.idCarte { MiniatureCarte(carte: carte) }
            }
        }
        .foregroundStyle(actif ? Color.jeton(\.encre) : Color.jeton(\.encre3))
        .contextMenu {
            if prefs.zaapsAjoutes.contains(zaap) {
                Button(L("zaap.supprimer"), role: .destructive) { confirmerSuppression() }
            }
        }
        .confirmation($confirmation, annuler: L("commun.annuler"))
    }

    /// Un zaap ajouté à la main ne se retrouve pas : un dernier mot avant de l'effacer.
    private func confirmerSuppression() {
        let zaap = zaap
        let langue = langue
        confirmation = Confirmation(titre: L("zaap.supprimer.confirmation", zaap.nom(en: langue)), verbe: L("commun.supprimer")) {
            let prefs = Preferences.shared
            prefs.zaapsAjoutes.removeAll { $0.cle == zaap.cle }
            prefs.zaapsChoix[zaap.cle] = nil
            prefs.zaapsFavoris.removeAll { $0 == zaap.cle }
            prefs.etiquettes[zaap.cle] = nil
        }
    }
}

/// Un zaap que la carte ne connaît pas encore.
private struct AjoutZaap: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var ouvert = false
    @State private var nom = ""
    @State private var x = ""
    @State private var y = ""

    var body: some View {
        Button(L("zaap.ajout")) { ouvert = true }
            .popover(isPresented: $ouvert, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: Jetons.espace2) {
                    HStack(spacing: Jetons.espace1) {
                        TextField(L("zaap.ajout.nom"), text: $nom)
                        TextField("x", text: $x).frame(width: 50)
                        TextField("y", text: $y).frame(width: 50)
                    }
                    .textFieldStyle(.roundedBorder)
                    .help(L("zaap.ajout.aide"))
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
                        .buttonStyle(BoutonPrincipal())
                        .disabled(nouveau == nil)
                    }
                }
                .padding(Jetons.espace3)
                .racineSynfus()
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
        // Déjà connu : il suffit de l'activer dans la liste.
        return prefs.zaapsConnus.contains { $0.cle == zaap.cle } ? nil : zaap
    }
}
