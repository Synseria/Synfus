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

    var body: some View {
        VStack(spacing: 0) {
            EnTetePage(titre: L("reglages.diagnostic"))
            ScrollView {
                VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                    content
                }
                .padding(.horizontal, MargeReglages.texte)
                .padding(.vertical, Jetons.Espace.trois)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button(L("commun.rafraichir")) { manager.refresh() }
                // La seconde qu'un client gelé coûte se paie ici, hors main :
                // si elle monte à ~1 s alors que la barre reste fluide, c'est
                // que le déport fait son travail.
                Text(L("diagnostic.dernierInventaire", Int(managerDiagnostics.lastInventoryDuration * 1000)))
                    .font(.synfus(.codeInterface))
                    .foregroundStyle(managerDiagnostics.lastInventoryDuration > 0.5 ? Couleurs.alerte : Couleurs.encreSecondaire)
                Spacer()
            }
            .padding(.horizontal, MargeReglages.texte)
            .padding(.vertical, Jetons.Espace.deux)
        }
    }

    @ViewBuilder
    private var content: some View {
            HStack(spacing: Jetons.Espace.un) {
                Text(L("diagnostic.fenetres")).font(.synfus(.corpsFort))
                HelpTip(L("diagnostic.fenetres.aide"))
            }

            if manager.clients.isEmpty {
                Text(manager.accessibilityGranted
                     ? L("diagnostic.aucuneFenetre")
                     : AppIntegrity.isQuarantined
                       ? L("diagnostic.accessibiliteManquanteQuarantaine")
                       : L("diagnostic.accessibiliteManquante"))
                    .font(.synfus(.petit))
                    .foregroundStyle(Couleurs.alerte)
                    .padding(.top, Jetons.Espace.un)
            } else {
                    VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
                        ForEach(manager.clients) { client in
                            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                                Text(client.name)
                                    .font(.synfus(.corpsFort))
                                Text(L("diagnostic.titre", client.rawTitle))
                                    .font(.synfus(.codeInterface))
                                    .foregroundStyle(Couleurs.encreSecondaire)
                                    .textSelection(.enabled)
                                Text("pid \(client.pid)")
                                    .font(.synfus(.codeInterface))
                                    .foregroundStyle(Couleurs.encreTertiaire)
                                if prefs.lirePosition {
                                    positionLine(for: client)
                                }
                                if prefs.lireCombat {
                                    Text(L("diagnostic.combat.ligne", EtatCombat.libelle(lecteur.combats[client.name])))
                                        .font(.synfus(.codeInterface))
                                        .foregroundStyle(Couleurs.encreSecondaire)
                                }
                                if previews.authorized {
                                    Text(previews.unmatched.contains(client.slotKey)
                                         ? L("diagnostic.apercu.introuvable")
                                         : previews.previews[client.slotKey] != nil
                                           ? L("diagnostic.apercu.capture")
                                           : L("diagnostic.apercu.pasDemande"))
                                        .font(.synfus(.codeInterface))
                                        .foregroundStyle(Couleurs.encreTertiaire)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(Jetons.Espace.deux)
                            .background(RoundedRectangle(cornerRadius: Jetons.Rayon.controle).fill(Couleurs.creux))
                        }
                    }
            }

            Divider().padding(.vertical, Jetons.Espace.un)
            arrangementSection

            if !freezes.journal.isEmpty {
                Divider().padding(.vertical, Jetons.Espace.un)
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    Text(L("diagnostic.gelesAcheves"))
                        .font(.synfus(.corpsFort))
                    ForEach(freezes.journal.suffix(5)) { abattu in
                        Text(abattu.date.formatted(date: .omitted, time: .standard) + "  "
                             + L("diagnostic.gelesAcheves.ligne", abattu.nom, Int(abattu.pid)))
                            .font(.synfus(.codeInterface))
                            .foregroundStyle(Couleurs.encreSecondaire)
                    }
                }
            }

            Divider().padding(.vertical, Jetons.Espace.un)
            attentionProbeSection
    }

    /// La position lue par OCR, ou ce qui l'empêche. La ligne brute suit :
    /// si les coordonnées manquent, c'est elle qui dit ce que Vision a vu.
    @ViewBuilder
    private func positionLine(for client: DofusClient) -> some View {
        if let lignes = lecture.lignesPosition[client.name] {
            let position = lecteur.positions[client.name]
            Text(L("diagnostic.position.ligne", PositionCarte.libelle(position)))
                .font(.synfus(.codeInterface))
                .foregroundStyle(position == nil ? Couleurs.alerte : Couleurs.encreSecondaire)
                .textSelection(.enabled)
            Text(L("diagnostic.position.brut", lignes.joined(separator: " ⏎ ")))
                .font(.synfus(.codeInterface))
                .foregroundStyle(Couleurs.encreTertiaire)
                .textSelection(.enabled)
        } else {
            Text(L("diagnostic.position.pasEncore"))
                .font(.synfus(.codeInterface))
                .foregroundStyle(Couleurs.encreTertiaire)
        }
    }

    /// Ce que le dernier rangement a réellement fait. Il repose sur des
    /// hypothèses — l'écran cible, la bonne volonté du client — et laisse des
    /// fenêtres de côté par principe : tout cela doit se lire quelque part.
    private var arrangementSection: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack(spacing: Jetons.Espace.un) {
                Text(L("diagnostic.rangement")).font(.synfus(.corpsFort))
                HelpTip(L("diagnostic.rangement.aide"))
            }

            if let rapport = arranger.dernierRapport {
                Text(L("diagnostic.rangement.entete", rapport.titre, rapport.ecran)
                     + " — " + rapport.date.formatted(date: .omitted, time: .standard))
                    .font(.synfus(.codeInterface))
                    .foregroundStyle(Couleurs.encreSecondaire)
                if !rapport.rangees.isEmpty {
                    Text(L("diagnostic.rangement.ranges", rapport.rangees.joined(separator: ", ")))
                        .font(.synfus(.codeInterface))
                        .foregroundStyle(Couleurs.encreSecondaire)
                }
                ForEach(rapport.ecartees) { ecartee in
                    Text(L("diagnostic.rangement.ecarte", ecartee.nom, ecartee.raison))
                        .font(.synfus(.codeInterface))
                        .foregroundStyle(Couleurs.alerte)
                }
            } else {
                Text(L("diagnostic.rangement.aucun"))
                    .font(.synfus(.petit))
                    .foregroundStyle(Couleurs.encreSecondaire)
            }
        }
    }

    private var attentionProbeSection: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack {
                Text(L("diagnostic.attention")).font(.synfus(.corpsFort))
                HelpTip(L("diagnostic.attention.aide"))
                Spacer()
                Button(probe.running ? L("diagnostic.attention.arreter") : L("diagnostic.attention.demarrer")) { probe.toggle() }
                    .font(.synfus(.petit))
            }


            if !attention.pairing.isEmpty {
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    Text(L("diagnostic.attention.appariement"))
                        .font(.synfus(.raccourci))
                    ForEach(Array(attention.pairing.enumerated()), id: \.offset) { _, pair in
                        Text("\(pair.dock)  →  \(pair.character)")
                            .font(.synfus(.codeInterface))
                            .foregroundStyle(Couleurs.encreSecondaire)
                    }
                    // Une icône de plus (ou de moins) que de processus Dofus, et
                    // l'appariement rang ↔ processus ne vaut plus rien : mieux
                    // vaut le dire que laisser lire une correspondance fausse.
                    if !attention.pairingReliable {
                        Label(L("diagnostic.attention.appariementDouteux"),
                              systemImage: "exclamationmark.triangle")
                            .font(.synfus(.petit))
                            .foregroundStyle(Couleurs.alerte)
                    }
                }
                .padding(.bottom, Jetons.Espace.un)
            }

            if let lecture = attention.dockReading {
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    Text(L("diagnostic.attention.releve"))
                        .font(.synfus(.raccourci))
                    Text(lecture)
                        .font(.synfus(.codeInterface))
                        .foregroundStyle(Couleurs.encreSecondaire)
                }
                .padding(.bottom, Jetons.Espace.un)
            }

            if !probe.watchedItems.isEmpty {
                Text(L("diagnostic.attention.iconesSurveillees", probe.watchedItems.joined(separator: ", ")))
                    .font(.synfus(.codeInterface))
                    .foregroundStyle(Couleurs.encreSecondaire)
            }

            HStack(spacing: Jetons.Espace.deux) {
                Button(L("diagnostic.attention.journal")) { probe.revealLog() }
                    .font(.synfus(.petit))
                Text(AttentionProbe.logURL.path)
                    .font(.synfus(.codeInterface))
                    .foregroundStyle(Couleurs.encreTertiaire)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .textSelection(.enabled)
            }

            if probe.events.isEmpty {
                if probe.running {
                    Text(L("diagnostic.attention.enEcoute"))
                        .font(.synfus(.petit))
                        .foregroundStyle(Couleurs.encreTertiaire)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                        ForEach(probe.events) { event in
                            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                                Text("\(event.time.formatted(date: .omitted, time: .standard))  \(event.label)")
                                    .font(.synfus(.codeInterface))
                                Text(event.detail)
                                    .font(.synfus(.codeInterface))
                                    .foregroundStyle(Couleurs.encreSecondaire)
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

// Les libellés d'une lecture, partagés par le Diagnostic et l'essai du calibrage.

extension EtatCombat {
    static func libelle(_ etat: EtatCombat?) -> String {
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
}

extension PositionCarte {
    static func libelle(_ position: PositionCarte?) -> String {
        [position?.coordonnees, position?.zone].compactMap { $0 }.joined(separator: " — ")
            .ifEmpty(L("diagnostic.position.illisible"))
    }
}
