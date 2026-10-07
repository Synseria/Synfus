import SwiftUI

/// Onglet Zaap : la réécriture du `/travel` copié, et les zaaps qu'elle peut
/// proposer — activables un à un, mis à jour depuis DofusDB, ajoutés à la main.
struct ZaapSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var miseAJour = false
    @State private var echec: String?
    @State private var nouveauNom = ""
    @State private var nouveauX = ""
    @State private var nouveauY = ""

    var body: some View {
        Form {
            reecriture
            liste
            ajout
        }
        .formStyle(.grouped)
    }

    // MARK: - Réécriture

    private var reecriture: some View {
        Section {
            ShortcutRow(label: L("zaap.raccourci"), help: L("zaap.raccourci.aide"),
                        conflit: prefs.zaapHotKey.map(HotKeyConflicts.doublons(prefs.raccourcisGlobaux).contains) ?? false,
                        hotKey: Binding(get: { prefs.zaapHotKey },
                                        set: { prefs.zaapHotKey = $0; HotKeyManager.shared.rebind() }))
            Stepper(L("zaap.gain", prefs.zaapGainMinimal),
                    value: $prefs.zaapGainMinimal, in: ItineraireZaap.gainsPossibles)
            if prefs.lirePosition {
                Toggle(L("zaap.bouton"), isOn: $prefs.zaapBouton)
                HStack {
                    Toggle(L("zaap.auto"), isOn: $prefs.zaapAuto)
                    HelpTip(L("zaap.auto.aide"))
                }
            } else {
                HStack {
                    Label(L("zaap.sansPosition"), systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11)).foregroundStyle(.orange)
                    Spacer()
                    Button(L("zaap.lirePosition")) {
                        prefs.lirePosition = true
                        if !WindowPreviewService.shared.authorized {
                            WindowPreviewService.shared.requestAuthorization()
                        }
                    }
                    .font(.system(size: 11))
                }
            }
        } header: {
            SectionTitle(L("zaap.reecriture"), help: L("zaap.reecriture.aide"))
        }
    }

    // MARK: - Liste

    private var liste: some View {
        let connus = prefs.zaapsConnus
        let ajoutes = Set(prefs.zaapsAjoutes.map(\.cle))
        let langue = L10n.courante.langue
        return Section {
            HStack(spacing: 8) {
                Text(source)
                    .font(.system(size: 11))
                    .foregroundStyle(echec == nil ? Color.secondary : Color.orange)
                    .textSelection(.enabled)
                Spacer()
                if miseAJour { ProgressView().controlSize(.small) }
                Button(L("zaap.maj"), action: mettreAJour)
                    .font(.system(size: 11))
                    .disabled(miseAJour)
                HelpTip(L("zaap.maj.aide"))
            }
            ForEach(connus.sorted { ordre($0, $1, langue) }, id: \.cle) { zaap in
                HStack(spacing: 6) {
                    Toggle(isOn: actif(zaap)) {
                        Text(zaap.nom(en: langue))
                    }
                    if zaap.monde != Zaap.mondeDesDouze { etiquette(L("zaap.autreCarte")) }
                    if ajoutes.contains(zaap.cle) { etiquette(L("zaap.ajoute")) }
                    Spacer()
                    Text("\(zaap.x),\(zaap.y)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    if ajoutes.contains(zaap.cle) {
                        Button { supprimer(zaap) } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                            .help(L("zaap.supprimer"))
                    }
                }
            }
        } header: {
            SectionTitle(L("zaap.liste", prefs.zaapsActifs.count, connus.count), help: L("zaap.liste.aide"))
        }
    }

    /// Le Monde des Douze d'abord, puis les autres cartes ; par nom ensuite.
    private func ordre(_ a: Zaap, _ b: Zaap, _ langue: Langue) -> Bool {
        let (autreA, autreB) = (a.monde != Zaap.mondeDesDouze, b.monde != Zaap.mondeDesDouze)
        if autreA != autreB { return !autreA }
        return a.nom(en: langue).localizedStandardCompare(b.nom(en: langue)) == .orderedAscending
    }

    private func etiquette(_ texte: String) -> some View {
        Text(texte)
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            .background(Capsule().fill(Color.primary.opacity(0.08)))
    }

    private var source: String {
        if let echec { return L("zaap.maj.echec", echec) }
        guard let releve = prefs.zaapsDofusDB else { return L("zaap.maj.integree") }
        return L("zaap.maj.date", releve.date.formatted(date: .abbreviated, time: .shortened))
    }

    private func actif(_ zaap: Zaap) -> Binding<Bool> {
        Binding(
            get: { CatalogueZaaps.estActif(zaap, choix: prefs.zaapsChoix) },
            set: { prefs.zaapsChoix[zaap.cle] = $0 })
    }

    private func supprimer(_ zaap: Zaap) {
        prefs.zaapsAjoutes.removeAll { $0.cle == zaap.cle }
        prefs.zaapsChoix[zaap.cle] = nil
    }

    private func mettreAJour() {
        miseAJour = true
        echec = nil
        Task {
            do {
                let zaaps = try await ZaapsDofusDB.telecharger()
                prefs.zaapsDofusDB = ReleveZaaps(date: Date(), zaaps: zaaps)
            } catch {
                echec = error.localizedDescription
            }
            miseAJour = false
        }
    }

    // MARK: - Ajout

    private var nouveau: Zaap? {
        let nom = nouveauNom.trimmingCharacters(in: .whitespaces)
        guard !nom.isEmpty,
              let x = Int(nouveauX.trimmingCharacters(in: .whitespaces)),
              let y = Int(nouveauY.trimmingCharacters(in: .whitespaces)),
              abs(x) <= PositionCarte.borne, abs(y) <= PositionCarte.borne
        else { return nil }
        let zaap = Zaap(x, y, noms: [L10n.courante.langue.rawValue: nom])
        // Déjà connu : il suffit de le cocher dans la liste.
        return prefs.zaapsConnus.contains { $0.cle == zaap.cle } ? nil : zaap
    }

    private var ajout: some View {
        Section {
            HStack {
                TextField(L("zaap.ajout.nom"), text: $nouveauNom)
                TextField("x", text: $nouveauX).frame(width: 50)
                TextField("y", text: $nouveauY).frame(width: 50)
                Button(L("zaap.ajout.bouton")) {
                    guard let zaap = nouveau else { return }
                    prefs.zaapsAjoutes.append(zaap)
                    nouveauNom = ""
                    nouveauX = ""
                    nouveauY = ""
                }
                .disabled(nouveau == nil)
            }
            .font(.system(size: 11))
        } header: {
            SectionTitle(L("zaap.ajout"), help: L("zaap.ajout.aide"))
        }
    }
}
