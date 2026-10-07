import SwiftUI

/// Onglet Palette : la palette et son raccourci, la réécriture du `/travel`,
/// la chasse au trésor, puis ce que la palette propose — zaaps (activés,
/// étiquetés, favoris), lieux étiquetés, phrases — et la carte du jeu.
struct PaletteSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var carte = CarteStore.shared
    @State private var miseAJour = false
    @State private var echec: String?
    @State private var filtre = ""
    @State private var vue: VueZaaps = .tous

    private enum VueZaaps: CaseIterable {
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
        PageReglages(titre: L("reglages.palette"), sousTitre: L("palette.reglages.sousTitre")) {
            palette
            reecriture
            ChasseSection()
            zaaps
            lieux
            phrases
            carteDuJeu
        }
    }

    private func enConflit(_ hotKey: HotKey?) -> Bool {
        hotKey.map(HotKeyConflicts.doublons(prefs.raccourcisGlobaux).contains) ?? false
    }

    private func raccourci(_ chemin: ReferenceWritableKeyPath<Preferences, HotKey?>) -> Binding<HotKey?> {
        Binding(get: { prefs[keyPath: chemin] }, set: { prefs[keyPath: chemin] = $0; HotKeyManager.shared.rebind() })
    }

    // MARK: - Palette et réécriture

    private var palette: some View {
        Section {
            ShortcutRow(label: L("raccourcis.palette"), help: L("raccourcis.palette.aide"),
                        conflit: enConflit(prefs.paletteHotKey), hotKey: raccourci(\.paletteHotKey))
            Interrupteur(titre: L("zaap.bouton"), isOn: $prefs.zaapBouton)
        } header: {
            SectionTitle(L("raccourcis.palette.titre"))
        }
    }

    private var reecriture: some View {
        Section {
            ShortcutRow(label: L("zaap.raccourci"), help: L("zaap.raccourci.aide"),
                        conflit: enConflit(prefs.zaapHotKey), hotKey: raccourci(\.zaapHotKey))
            Ligne(titre: L("zaap.gain"), sousTexte: L("zaap.gain.sousTexte")) {
                Stepper(L("zaap.gain.valeur", prefs.zaapGainMinimal),
                        value: $prefs.zaapGainMinimal, in: ItineraireZaap.gainsPossibles)
            }
            if prefs.lirePosition {
                Interrupteur(titre: L("zaap.auto"), aide: L("zaap.auto.aide"), isOn: $prefs.zaapAuto)
            } else {
                Avertissement(texte: L("zaap.sansPosition"), bouton: L("zaap.lirePosition")) {
                    prefs.lirePosition = true
                    if !WindowPreviewService.shared.authorized { WindowPreviewService.shared.requestAuthorization() }
                }
            }
        } header: {
            SectionTitle(L("zaap.reecriture"), help: L("zaap.reecriture.aide"))
        }
    }

    // MARK: - Zaaps

    private var zaaps: some View {
        let connus = prefs.zaapsConnus
        let langue = L10n.courante.langue
        let montres = connus
            .filter { zaap in
                switch vue {
                case .tous: return true
                case .actifs: return CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
                case .etiquetes: return prefs.etiquettes[zaap.cle] != nil
                }
            }
            .filter { correspond($0, langue) }
            .sorted { ordre($0, $1, langue) }
        return Section {
            HStack(spacing: 10) {
                TextField(L("palette.reglages.filtrer"), text: $filtre)
                    .textFieldStyle(.roundedBorder)
                Picker(L("palette.reglages.vue"), selection: $vue) {
                    ForEach(VueZaaps.allCases, id: \.self) { Text($0.libelle).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .fixedSize()
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(montres, id: \.cle) { zaap in
                    CarteZaapReglages(zaap: zaap, langue: langue)
                }
                AjoutZaap()
            }
            .padding(.vertical, 4)
        } header: {
            SectionTitle(L("zaap.liste", prefs.zaapsActifs.count, connus.count), help: L("zaap.liste.aide"))
        }
    }

    private func correspond(_ zaap: Zaap, _ langue: Langue) -> Bool {
        let mots = RecherchePalette.mots(filtre)
        guard !mots.isEmpty else { return true }
        let texte = RecherchePalette.normaliser(
            [prefs.etiquettes[zaap.cle] ?? "", zaap.nom(en: langue), zaap.zone(en: langue) ?? "", "\(zaap.x),\(zaap.y)"]
                .joined(separator: " "))
        return mots.allSatisfy(texte.contains)
    }

    /// Le Monde des Douze d'abord, puis les autres cartes ; par nom ensuite.
    private func ordre(_ a: Zaap, _ b: Zaap, _ langue: Langue) -> Bool {
        let (autreA, autreB) = (a.monde != Zaap.mondeDesDouze, b.monde != Zaap.mondeDesDouze)
        if autreA != autreB { return !autreA }
        return a.nom(en: langue).localizedStandardCompare(b.nom(en: langue)) == .orderedAscending
    }

    // MARK: - Lieux

    @ViewBuilder
    private var lieux: some View {
        let langue = L10n.courante.langue
        let marques = carte.carte.lieux.filter { prefs.etiquettes[$0.cle] != nil || prefs.lieuxFavoris.contains($0.cle) }
        Section {
            if marques.isEmpty {
                Text(L("palette.reglages.lieux.aucun")).foregroundStyle(.secondary)
            }
            ForEach(marques, id: \.cle) { lieu in
                Ligne(titre: lieu.nom(en: langue),
                      sousTexte: [lieu.sousZone(en: langue), lieu.zone(en: langue), "\(lieu.x),\(lieu.y)"]
                        .compactMap { $0 }.joined(separator: " · ")) {
                    HStack(spacing: 8) {
                        if let etiquette = prefs.etiquettes[lieu.cle] { PastilleEtiquette(texte: etiquette) }
                        if prefs.lieuxFavoris.contains(lieu.cle) {
                            Image(systemName: "star.fill").foregroundStyle(Couleurs.ambre)
                        }
                        Button {
                            prefs.etiquettes[lieu.cle] = nil
                            prefs.lieuxFavoris.removeAll { $0 == lieu.cle }
                        } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.borderless)
                            .foregroundStyle(.secondary)
                            .help(L("palette.reglages.lieux.oublier"))
                    }
                }
            }
        } header: {
            SectionTitle(L("palette.reglages.lieux"), help: L("palette.reglages.lieux.aide"))
        }
    }

    // MARK: - Phrases

    private var phrases: some View {
        Section {
            ForEach(prefs.phrases.indices, id: \.self) { index in
                HStack(spacing: 8) {
                    TextField(L("palette.reglages.phrase.nom"), text: $prefs.phrases[index].nom)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                    TextField(L("palette.reglages.phrase.texte"), text: $prefs.phrases[index].texte)
                        .textFieldStyle(.roundedBorder)
                    Button { prefs.phrases.remove(at: index) } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                        .help(L("palette.reglages.phrase.supprimer"))
                }
            }
            Ligne(titre: L("palette.reglages.phrase.nouvelle")) {
                Button(L("palette.reglages.phrase.ajouter")) {
                    prefs.phrases.append(Phrase(nom: L("palette.reglages.phrase.nomParDefaut"), texte: ""))
                }
            }
        } header: {
            SectionTitle(L("palette.reglages.phrases"), help: L("palette.reglages.phrases.aide"))
        }
    }

    // MARK: - Carte

    private var carteDuJeu: some View {
        Section {
            Ligne(titre: source, sousTexte: L("palette.reglages.carte.contenu",
                                              carte.carte.lieux.count, carte.carte.zaaps.count),
                  aide: L("zaap.maj.aide")) {
                HStack(spacing: 8) {
                    if miseAJour { ProgressView().controlSize(.small) }
                    Button(L("zaap.maj"), action: mettreAJour).disabled(miseAJour)
                }
            }
        } header: {
            SectionTitle(L("palette.reglages.carte"))
        }
    }

    private var source: String {
        if let echec { return L("zaap.maj.echec", echec) }
        return L("zaap.maj.date", carte.carte.date.formatted(date: .abbreviated, time: .shortened))
    }

    private func mettreAJour() {
        miseAJour = true
        echec = nil
        Task {
            do {
                try await carte.mettreAJour()
            } catch {
                echec = error.localizedDescription
            }
            miseAJour = false
        }
    }
}

/// Un zaap dans les réglages : étiquette (au clic), favori, activation.
private struct CarteZaapReglages: View {
    let zaap: Zaap
    let langue: Langue
    @ObservedObject private var prefs = Preferences.shared
    @State private var edition = false
    @State private var texte = ""

    var body: some View {
        let actif = CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix)
        let favori = prefs.zaapsFavoris.contains(zaap.cle)
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button { texte = prefs.etiquettes[zaap.cle] ?? ""; edition = true } label: {
                    if let etiquette = prefs.etiquettes[zaap.cle] {
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
                .popover(isPresented: $edition, arrowEdge: .bottom) { editeur }
                Spacer(minLength: 0)
                Button {
                    if favori { prefs.zaapsFavoris.removeAll { $0 == zaap.cle } } else { prefs.zaapsFavoris.append(zaap.cle) }
                } label: {
                    Image(systemName: favori ? "star.fill" : "star")
                        .foregroundStyle(favori ? Couleurs.ambre : Color.secondary)
                }
                .buttonStyle(.borderless)
                .help(favori ? L("zaap.favori.retirer") : L("zaap.favori.ajouter"))
                Toggle(L("palette.reglages.actif"), isOn: Binding(
                    get: { actif }, set: { prefs.zaapsChoix[zaap.cle] = $0 }))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }
            Text(zaap.nom(en: langue))
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
            HStack(spacing: 4) {
                Text(zaap.zone(en: langue) ?? (prefs.zaapsAjoutes.contains(zaap) ? L("zaap.ajoute") : ""))
                    .lineLimit(1)
                if zaap.monde != Zaap.mondeDesDouze {
                    Text(L("zaap.autreCarte")).foregroundStyle(.orange)
                }
                Spacer(minLength: 0)
                Text("\(zaap.x),\(zaap.y)").font(.system(size: 11, design: .monospaced))
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.05)))
        .opacity(actif ? 1 : 0.55)
        .contextMenu {
            if prefs.zaapsAjoutes.contains(zaap) {
                Button(L("zaap.supprimer"), role: .destructive) {
                    prefs.zaapsAjoutes.removeAll { $0.cle == zaap.cle }
                    prefs.zaapsChoix[zaap.cle] = nil
                    prefs.zaapsFavoris.removeAll { $0 == zaap.cle }
                    prefs.etiquettes[zaap.cle] = nil
                }
            }
        }
    }

    private var editeur: some View {
        HStack(spacing: 8) {
            TextField(L("palette.etiquette.exemple"), text: $texte)
                .textFieldStyle(.roundedBorder)
                .frame(width: 160)
                .onSubmit(valider)
            Button(L("palette.reglages.ok"), action: valider)
        }
        .padding(10)
    }

    private func valider() {
        let propre = texte.trimmingCharacters(in: .whitespaces)
        prefs.etiquettes[zaap.cle] = propre.isEmpty ? nil : propre
        edition = false
    }
}

/// La dernière case de la grille : un zaap que la carte ne connaît pas encore.
private struct AjoutZaap: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var ouvert = false
    @State private var nom = ""
    @State private var x = ""
    @State private var y = ""

    var body: some View {
        Button { ouvert = true } label: {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                Text(L("zaap.ajout")).font(.system(size: 11))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 62)
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.secondary.opacity(0.4), style: StrokeStyle(dash: [4, 3])))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $ouvert, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L("zaap.ajout.aide")).font(.system(size: 11)).foregroundStyle(.secondary)
                    .frame(width: 260, alignment: .leading)
                HStack(spacing: 6) {
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
            .padding(12)
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
