import SwiftUI

/// Le diagnostic, au bas de Lecture de l'écran : ce que Synfus voit, et les hypothèses qu'il fait.
struct BlocsDiagnostic: View {
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
        fenetres
        arrangementSection
        if !freezes.journal.isEmpty { gelesAcheves }
        attentionProbeSection
    }

    private func texteCode(_ texte: String, _ couleur: Color = Color.jeton(\.encreSecondaire)) -> some View {
        Text(texte)
            .font(Jetons.Typo.codeInterface.police)
            .foregroundStyle(couleur)
            .textSelection(.enabled)
    }

    private var fenetres: some View {
        Bloc(L("diagnostic.fenetres"), aide: L("diagnostic.fenetres.aide")) {
            if manager.clients.isEmpty {
                EtatDeBloc(texte: manager.accessibilityGranted
                           ? L("diagnostic.aucuneFenetre")
                           : AppIntegrity.isQuarantined
                             ? L("diagnostic.accessibiliteManquanteQuarantaine")
                             : L("diagnostic.accessibiliteManquante"))
            } else {
                ForEach(manager.clients) { client in
                    VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                        Text(client.name).font(Jetons.Typo.corpsFort.police)
                        texteCode(L("diagnostic.titre", client.rawTitle))
                        texteCode("pid " + String(client.pid), Color.jeton(\.encreTertiaire))
                        if prefs.lirePosition {
                            positionLine(for: client)
                        }
                        if prefs.lireCombat {
                            texteCode(L("diagnostic.combat.ligne", EtatCombat.libelle(lecteur.combats[client.name])))
                        }
                        if previews.authorized {
                            texteCode(previews.unmatched.contains(client.slotKey)
                                      ? L("diagnostic.apercu.introuvable")
                                      : previews.previews[client.slotKey] != nil
                                        ? L("diagnostic.apercu.capture")
                                        : L("diagnostic.apercu.pasDemande"), Color.jeton(\.encreTertiaire))
                        }
                    }
                    .rangee()
                }
            }
        } entete: {
            HStack(spacing: Jetons.Espace.deux) {
                // La seconde qu'un client gelé coûte se paie ici, hors main : si elle monte à ~1 s alors que
                // la barre reste fluide, c'est que le déport fait son travail.
                Text(L("diagnostic.dernierInventaire", Int(managerDiagnostics.lastInventoryDuration * 1000)))
                    .font(Jetons.Typo.codeInterface.police)
                    .foregroundStyle(managerDiagnostics.lastInventoryDuration > 0.5 ? Color.jeton(\.alerte) : Color.jeton(\.encreSecondaire))
                Button(L("commun.rafraichir")) { manager.refresh() }
            }
        }
    }

    /// La position lue par OCR, ou ce qui l'empêche. La ligne brute suit :
    /// si les coordonnées manquent, c'est elle qui dit ce que Vision a vu.
    @ViewBuilder
    private func positionLine(for client: DofusClient) -> some View {
        if let lignes = lecture.lignesPosition[client.name] {
            let position = lecteur.positions[client.name]
            texteCode(L("diagnostic.position.ligne", PositionCarte.libelle(position)),
                      position == nil ? Color.jeton(\.alerte) : Color.jeton(\.encreSecondaire))
            texteCode(L("diagnostic.position.brut", lignes.joined(separator: " ⏎ ")), Color.jeton(\.encreTertiaire))
        } else {
            texteCode(L("diagnostic.position.pasEncore"), Color.jeton(\.encreTertiaire))
        }
    }

    private var gelesAcheves: some View {
        Bloc(L("diagnostic.gelesAcheves")) {
            ForEach(freezes.journal.suffix(5)) { abattu in
                texteCode(abattu.date.formatted(date: .omitted, time: .standard) + "  "
                          + L("diagnostic.gelesAcheves.ligne", abattu.nom, Int(abattu.pid)))
                    .rangee()
            }
        }
    }

    /// Ce que le dernier rangement a réellement fait. Il repose sur des hypothèses — l'écran cible, la bonne
    /// volonté du client — et laisse des fenêtres de côté par principe : tout cela doit se lire quelque part.
    private var arrangementSection: some View {
        Bloc(L("diagnostic.rangement"), aide: L("diagnostic.rangement.aide")) {
            if let rapport = arranger.dernierRapport {
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    texteCode(L("diagnostic.rangement.entete", rapport.titre, rapport.ecran)
                              + " — " + rapport.date.formatted(date: .omitted, time: .standard))
                    if !rapport.rangees.isEmpty {
                        texteCode(L("diagnostic.rangement.ranges", rapport.rangees.joined(separator: ", ")))
                    }
                    ForEach(rapport.ecartees) { ecartee in
                        texteCode(L("diagnostic.rangement.ecarte", ecartee.nom, ecartee.raison), Color.jeton(\.alerte))
                    }
                }
                .rangee()
            } else {
                EtatDeBloc(texte: L("diagnostic.rangement.aucun"))
            }
        }
    }

    private var attentionProbeSection: some View {
        Bloc(L("diagnostic.attention"), aide: L("diagnostic.attention.aide")) {
            if !attention.pairing.isEmpty {
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    Text(L("diagnostic.attention.appariement")).font(Jetons.Typo.raccourci.police)
                    ForEach(Array(attention.pairing.enumerated()), id: \.offset) { _, pair in
                        texteCode("\(pair.dock)  →  \(pair.character)")
                    }
                    // Une icône de plus (ou de moins) que de processus Dofus, et l'appariement rang ↔
                    // processus ne vaut plus rien : mieux vaut le dire que laisser lire une correspondance fausse.
                    if !attention.pairingReliable {
                        Label(L("diagnostic.attention.appariementDouteux"), systemImage: "exclamationmark.triangle")
                            .font(Jetons.Typo.petit.police)
                            .foregroundStyle(Color.jeton(\.alerte))
                    }
                }
                .rangee()
            }
            if let lecture = attention.dockReading {
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    Text(L("diagnostic.attention.releve")).font(Jetons.Typo.raccourci.police)
                    texteCode(lecture)
                }
                .rangee()
            }
            if !probe.watchedItems.isEmpty {
                texteCode(L("diagnostic.attention.iconesSurveillees", probe.watchedItems.joined(separator: ", ")))
                    .rangee()
            }
            Ligne(titre: L("diagnostic.attention.journal"), etat: AttentionProbe.logURL.path) {
                Button(L("commun.ouvrir")) { probe.revealLog() }
            }
            if probe.events.isEmpty {
                if probe.running {
                    texteCode(L("diagnostic.attention.enEcoute"), Color.jeton(\.encreTertiaire)).rangee()
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                        ForEach(probe.events) { event in
                            VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                                Text("\(event.time.formatted(date: .omitted, time: .standard))  \(event.label)")
                                    .font(Jetons.Typo.codeInterface.police)
                                texteCode(event.detail)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
                .frame(maxHeight: 200)
                .rangee()
            }
        } entete: {
            Button(probe.running ? L("diagnostic.attention.arreter") : L("diagnostic.attention.demarrer")) { probe.toggle() }
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
