import SwiftUI

/// Onglet Diagnostic : ce que Synfus voit, et les hypothèses qu'il fait.
struct DiagnosticSettings: View {
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var probe = AttentionProbe.shared
    @ObservedObject private var attention = AttentionDiagnostics.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var arranger = WindowArranger.shared
    @ObservedObject private var freezes = FreezeWatcher.shared
    @ObservedObject private var spells = SpellRecognitionProbe.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Text("Fenêtres détectées").font(.system(size: 12, weight: .semibold))
                HelpTip("Les titres bruts des fenêtres Dofus. Si le nom affiché ne correspond pas à ton perso, "
                        + "c'est que le client n'expose pas le nom dans son titre ; la numérotation suit alors "
                        + "l'ordre de lancement, à réorganiser dans l'onglet Persos.")
            }

            if manager.clients.isEmpty {
                Text(manager.accessibilityGranted
                     ? "Aucune fenêtre Dofus détectée. Le jeu est-il lancé ?"
                     : AppIntegrity.isQuarantined
                       ? "Autorisation Accessibilité manquante — et cette copie est "
                         + "en quarantaine, ce qui l'empêchera de prendre effet. "
                         + "Voir l'onglet Général."
                       : "Autorisation Accessibilité manquante.")
                    .font(.system(size: 11))
                    .foregroundStyle(.orange)
                    .padding(.top, 6)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(manager.clients) { client in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(client.name)
                                    .font(.system(size: 12, weight: .medium))
                                Text("titre : \"\(client.rawTitle)\"")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                                Text("pid \(client.pid)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                if previews.authorized {
                                    Text(previews.unmatched.contains(client.slotKey)
                                         ? "aperçu : fenêtre introuvable à la capture"
                                         : previews.previews[client.slotKey] != nil
                                           ? "aperçu : capturé"
                                           : "aperçu : pas encore demandé")
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
            }

            Divider().padding(.vertical, 4)
            arrangementSection

            if !freezes.journal.isEmpty {
                Divider().padding(.vertical, 4)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clients gelés achevés")
                        .font(.system(size: 12, weight: .semibold))
                    ForEach(freezes.journal.suffix(5)) { abattu in
                        Text("\(abattu.date.formatted(date: .omitted, time: .standard))  "
                             + "\(abattu.nom) (pid \(abattu.pid)) — sans fenêtre et muet "
                             + "à trois sondes, forcé à quitter")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider().padding(.vertical, 4)
            spellRecognitionSection

            Divider().padding(.vertical, 4)
            attentionProbeSection

            Spacer()
            HStack {
                Button("Rafraîchir") { manager.refresh() }
                // La seconde qu'un client gelé coûte se paie ici, hors main :
                // si elle monte à ~1 s alors que la barre reste fluide, c'est
                // que le déport fait son travail.
                Text("dernier inventaire : \(Int(manager.lastInventoryDuration * 1000)) ms")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(manager.lastInventoryDuration > 0.5 ? .orange : .secondary)
                Spacer()
                Text("Synfus — barre et raccourcis de fenêtres")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
    }

    /// Ce que le dernier rangement a réellement fait. Il repose sur des
    /// hypothèses — l'écran cible, la bonne volonté du client — et laisse des
    /// fenêtres de côté par principe : tout cela doit se lire quelque part.
    private var arrangementSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Dernier rangement").font(.system(size: 12, weight: .semibold))
                HelpTip("Une fenêtre en plein écran n'est jamais déplacée, et un perso d'un autre bureau est "
                        + "hors de portée de l'Accessibilité — bascule dessus, puis relance le rangement.")
            }

            if let rapport = arranger.dernierRapport {
                Text("\(rapport.titre) — écran « \(rapport.ecran) » — "
                     + rapport.date.formatted(date: .omitted, time: .standard))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !rapport.rangees.isEmpty {
                    Text("Rangés : \(rapport.rangees.joined(separator: ", "))")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ForEach(rapport.ecartees) { ecartee in
                    Text("Écarté : \(ecartee.nom) — \(ecartee.raison)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            } else {
                Text("Aucun rangement pour l'instant.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// L'exploration de la reconnaissance des sorts : capturer, analyser,
    /// lire les scores. Rien n'est configuré ici — c'est le banc d'essai.
    private var spellRecognitionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Reconnaissance des sorts").font(.system(size: 12, weight: .semibold))
                HelpTip("Capture la fenêtre du perso actif en résolution native, cherche la barre de sorts et "
                        + "compare chaque case aux icônes de sa classe. Les captures restent dans "
                        + "~/Library/Logs/Synfus/captures. « Capturer » puis « Analyser » ; le rapport dit ce qui "
                        + "a été trouvé et avec quelle confiance.")
                Spacer()
                Button("Capturer") { spells.captureActive() }
                    .disabled(spells.busy || !previews.authorized)
                    .help(previews.authorized ? "Capture la fenêtre du perso actif" : "Autorise l'enregistrement de l'écran (onglet Général)")
                Button("Analyser") { spells.analyzeLast() }.disabled(spells.busy)
                Button("Fichier…") { spells.analyzeFile() }.help("Analyser un PNG existant")
                Button { spells.revealCaptures() } label: { Image(systemName: "folder") }
                    .help("Ouvrir le dossier des captures")
            }
            .font(.system(size: 11))
            if !spells.report.isEmpty {
                ScrollView {
                    Text(spells.report)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 160)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
            }
        }
    }

    private var attentionProbeSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Appels d'attention").font(.system(size: 12, weight: .semibold))
                HelpTip("Surveille les deux seuls signaux qu'une app émet vers l'extérieur : le titre de sa "
                        + "fenêtre et son icône du Dock. Démarre la sonde, joue un combat, et regarde si quelque "
                        + "chose bouge quand ton tour arrive. L'appariement icône → perso suppose que l'ordre des "
                        + "icônes suit l'ordre de lancement : vérifie que le bon perso est signalé. Un rebond "
                        + "éloigne une icône de son bandeau ; au repos, les écarts ne doivent pas bouger.")
                Spacer()
                Button(probe.running ? "Arrêter" : "Démarrer la sonde") { probe.toggle() }
                    .font(.system(size: 11))
            }


            if !attention.pairing.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Appariement icône du Dock → perso")
                        .font(.system(size: 11, weight: .medium))
                    ForEach(Array(attention.pairing.enumerated()), id: \.offset) { _, pair in
                        Text("\(pair.dock)  →  \(pair.character)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.bottom, 4)
            }

            if let lecture = attention.dockReading {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Relevé du Dock")
                        .font(.system(size: 11, weight: .medium))
                    Text(lecture)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 4)
            }

            if !probe.watchedItems.isEmpty {
                Text("Icônes surveillées : " + probe.watchedItems.joined(separator: ", "))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button("Ouvrir le journal") { probe.revealLog() }
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
                    Text("En écoute…")
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
                .frame(maxHeight: 130)
            }
        }
    }
}
