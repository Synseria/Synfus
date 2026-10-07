import SwiftUI

/// Onglet Diagnostic : ce que Synfus voit, et les hypothèses qu'il fait.
struct DiagnosticSettings: View {
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var managerDiagnostics = WindowManagerDiagnostics.shared
    @ObservedObject private var probe = AttentionProbe.shared
    @ObservedObject private var attention = AttentionDiagnostics.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var arranger = WindowArranger.shared
    @ObservedObject private var freezes = FreezeWatcher.shared
    @ObservedObject private var lecteur = LecteurEcran.shared
    @ObservedObject private var lecture = DiagnosticLecture.shared
    @ObservedObject private var prefs = Preferences.shared
    @State private var calibrer = false

    var body: some View {
        VStack(spacing: 0) {
            EnTetePage(titre: L("reglages.diagnostic"), sousTitre: L("diagnostic.sousTitre"))
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button(L("commun.rafraichir")) { manager.refresh() }
                // La seconde qu'un client gelé coûte se paie ici, hors main :
                // si elle monte à ~1 s alors que la barre reste fluide, c'est
                // que le déport fait son travail.
                Text(L("diagnostic.dernierInventaire", Int(managerDiagnostics.lastInventoryDuration * 1000)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(managerDiagnostics.lastInventoryDuration > 0.5 ? .orange : .secondary)
                Spacer()
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var content: some View {
            HStack(spacing: 6) {
                Text(L("diagnostic.fenetres")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("diagnostic.fenetres.aide"))
            }

            if manager.clients.isEmpty {
                Text(manager.accessibilityGranted
                     ? L("diagnostic.aucuneFenetre")
                     : AppIntegrity.isQuarantined
                       ? L("diagnostic.accessibiliteManquanteQuarantaine")
                       : L("diagnostic.accessibiliteManquante"))
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.top, 6)
            } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(manager.clients) { client in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text(L("diagnostic.titre", client.rawTitle))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text("pid \(client.pid)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                if prefs.lirePosition {
                                    positionLine(for: client)
                                }
                                if prefs.lireCombat {
                                    Text(L("diagnostic.combat.ligne", libelleCombat(lecteur.combats[client.name])))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                if previews.authorized {
                                    Text(previews.unmatched.contains(client.slotKey)
                                         ? L("diagnostic.apercu.introuvable")
                                         : previews.previews[client.slotKey] != nil
                                           ? L("diagnostic.apercu.capture")
                                           : L("diagnostic.apercu.pasDemande"))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
                        }
                    }
            }

            Divider().padding(.vertical, 4)
            lectureSection

            Divider().padding(.vertical, 4)
            arrangementSection

            if !freezes.journal.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("diagnostic.gelesAcheves"))
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(freezes.journal.suffix(5)) { abattu in
                        Text(abattu.date.formatted(date: .omitted, time: .standard) + "  "
                             + L("diagnostic.gelesAcheves.ligne", abattu.nom, Int(abattu.pid)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider().padding(.vertical, 4)
            attentionProbeSection
    }

    /// La position lue par OCR, ou ce qui l'empêche. La ligne brute suit :
    /// si les coordonnées manquent, c'est elle qui dit ce que Vision a vu.
    @ViewBuilder
    private func positionLine(for client: DofusClient) -> some View {
        if let releve = lecteur.releves[client.name] {
            Text(L("diagnostic.position.ligne",
                   [releve.position?.coordonnees, releve.position?.zone].compactMap { $0 }.joined(separator: " — ")
                   .ifEmpty(L("diagnostic.position.illisible"))))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(releve.position == nil ? Color.orange : Color.secondary)
                .textSelection(.enabled)
            Text(L("diagnostic.position.brut", releve.lignes.joined(separator: " ⏎ ")))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)
        } else {
            Text(L("diagnostic.position.pasEncore"))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
    }

    /// Lecture de l'écran : les bascules, les zones, et ce que ça coûte. Les
    /// compteurs sont là pour le prouver — une lecture par changement de carte
    /// ou de tour, pas une par seconde.
    private var lectureSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L("diagnostic.lecture")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("diagnostic.lecture.aide"))
                Spacer()
                bascule(L("diagnostic.lecture.position"), \.lirePosition)
                bascule(L("diagnostic.lecture.combat"), \.lireCombat)
            }
            if prefs.lirePosition || prefs.lireCombat {
                HStack(spacing: 8) {
                    Text(etatLecture)
                        .font(.system(size: 11))
                        .foregroundStyle(etatEnDefaut ? Color.orange : Color.secondary)
                        .textSelection(.enabled)
                    Spacer()
                    Button(L("diagnostic.lecture.calibrer")) { calibrer = true }
                        .font(.system(size: 11))
                        .disabled(!previews.authorized || manager.clients.isEmpty)
                    Button(L("diagnostic.position.toutLire")) { LecteurEcran.shared.toutLire() }
                        .font(.system(size: 11))
                        .disabled(!previews.authorized || manager.clients.isEmpty)
                        .help(L("diagnostic.position.toutLire.aide"))
                }
                Text(L("diagnostic.position.stats", lecture.lectures,
                       Int(lecture.derniereDuree * 1000), lecture.sautes))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                ForEach(GenreLecture.allCases) { genre in
                    if let image = lecture.captures[genre] {
                        zoneLue(genre, image)
                    }
                }
            }
        }
        .sheet(isPresented: $calibrer) { CalibrationZonesView() }
    }

    /// Ce que l'OCR a reçu : si le texte n'y est pas, c'est la zone qui est en
    /// cause — à recalibrer —, pas la reconnaissance.
    private func zoneLue(_ genre: GenreLecture, _ image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(L("diagnostic.lecture.zoneVue", genre.libelle, lecture.dernierPerso ?? "?"))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 360, maxHeight: 80, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if let lignes = lecture.lignes[genre] {
                Text(L("diagnostic.position.brut", lignes.joined(separator: " ⏎ ")))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)
            }
            if genre == .combat, let couleur = lecture.couleur {
                Text(L("diagnostic.lecture.couleur", Int(couleur * 100)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// Une bascule de lecture. L'activer est la demande d'autorisation : c'est
    /// le seul endroit où la lecture de l'écran la fait.
    private func bascule(_ titre: String, _ chemin: ReferenceWritableKeyPath<Preferences, Bool>) -> some View {
        Toggle(titre, isOn: Binding(
            get: { prefs[keyPath: chemin] },
            set: { value in
                prefs[keyPath: chemin] = value
                if value, !previews.authorized { previews.requestAuthorization() }
            }))
            .toggleStyle(.switch)
            .controlSize(.mini)
            .font(.system(size: 11))
    }

    private func libelleCombat(_ etat: EtatCombat?) -> String {
        switch etat {
        case nil: return L("combat.pasEncore")
        case .horsCombat: return L("combat.horsCombat")
        case .placement: return L("combat.placement")
        case .pasMonTour: return L("combat.pasMonTour")
        case .monTour(let fin):
            guard let fin else { return L("combat.monTour") }
            return L("combat.monTourSecondes", max(0, Int(fin.timeIntervalSinceNow.rounded())))
        }
    }

    private var etatLecture: String {
        switch lecture.etat {
        case .eteint: return L("diagnostic.position.etat.eteint")
        case .nonAutorise: return L("diagnostic.position.etat.nonAutorise")
        case .preparation: return L("diagnostic.position.etat.preparation")
        case .attente: return L("diagnostic.position.etat.attente")
        case .actif: return L("diagnostic.position.etat.actif")
        case .sansCoordonnees: return L("diagnostic.position.etat.sansCoordonnees")
        case .echecCapture(let raison): return L("diagnostic.position.etat.echec", raison)
        }
    }

    private var etatEnDefaut: Bool {
        switch lecture.etat {
        case .nonAutorise, .sansCoordonnees, .echecCapture: return true
        default: return false
        }
    }

    /// Ce que le dernier rangement a réellement fait. Il repose sur des
    /// hypothèses — l'écran cible, la bonne volonté du client — et laisse des
    /// fenêtres de côté par principe : tout cela doit se lire quelque part.
    private var arrangementSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L("diagnostic.rangement")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("diagnostic.rangement.aide"))
            }

            if let rapport = arranger.dernierRapport {
                Text(L("diagnostic.rangement.entete", rapport.titre, rapport.ecran)
                     + " — " + rapport.date.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !rapport.rangees.isEmpty {
                    Text(L("diagnostic.rangement.ranges", rapport.rangees.joined(separator: ", ")))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ForEach(rapport.ecartees) { ecartee in
                    Text(L("diagnostic.rangement.ecarte", ecartee.nom, ecartee.raison))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            } else {
                Text(L("diagnostic.rangement.aucun"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var attentionProbeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L("diagnostic.attention")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("diagnostic.attention.aide"))
                Spacer()
                Button(probe.running ? L("diagnostic.attention.arreter") : L("diagnostic.attention.demarrer")) { probe.toggle() }
                    .font(.system(size: 11))
            }


            if !attention.pairing.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("diagnostic.attention.appariement"))
                        .font(.system(size: 11, weight: .medium))
                    ForEach(Array(attention.pairing.enumerated()), id: \.offset) { _, pair in
                        Text("\(pair.dock)  →  \(pair.character)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    // Une icône de plus (ou de moins) que de processus Dofus, et
                    // l'appariement rang ↔ processus ne vaut plus rien : mieux
                    // vaut le dire que laisser lire une correspondance fausse.
                    if !attention.pairingReliable {
                        Label(L("diagnostic.attention.appariementDouteux"),
                              systemImage: "exclamationmark.triangle")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.bottom, 4)
            }

            if let lecture = attention.dockReading {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("diagnostic.attention.releve"))
                        .font(.system(size: 11, weight: .medium))
                    Text(lecture)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }

            if !probe.watchedItems.isEmpty {
                Text(L("diagnostic.attention.iconesSurveillees", probe.watchedItems.joined(separator: ", ")))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button(L("diagnostic.attention.journal")) { probe.revealLog() }
                    .font(.system(size: 11))
                Text(AttentionProbe.logURL.path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .textSelection(.enabled)
            }

            if probe.events.isEmpty {
                if probe.running {
                    Text(L("diagnostic.attention.enEcoute"))
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(probe.events) { event in
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(event.time.formatted(date: .omitted, time: .standard))  \(event.label)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                Text(event.detail)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

private extension String {
    func ifEmpty(_ remplacement: String) -> String { isEmpty ? remplacement : self }
}
