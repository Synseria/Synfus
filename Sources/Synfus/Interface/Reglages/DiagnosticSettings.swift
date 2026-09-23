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
    @State private var zoomCapture = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    content
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider()
            HStack {
                Button(L("commun.rafraichir")) { manager.refresh() }
                // La seconde qu'un client gelé coûte se paie ici, hors main :
                // si elle monte à ~1 s alors que la barre reste fluide, c'est
                // que le déport fait son travail.
                Text(L("diagnostic.dernierInventaire", Int(manager.lastInventoryDuration * 1000)))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(manager.lastInventoryDuration > 0.5 ? .orange : .secondary)
                Spacer()
            }
            .padding(10)
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
            spellRecognitionSection

            Divider().padding(.vertical, 4)
            attentionProbeSection
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

    /// L'exploration de la reconnaissance des sorts : capturer, analyser,
    /// lire les scores. Rien n'est configuré ici — c'est le banc d'essai.
    private var spellRecognitionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(L("diagnostic.sorts")).font(.system(size: 12, weight: .semibold))
                HelpTip(L("diagnostic.sorts.aide"))
                Spacer()
                Button(L("diagnostic.sorts.capturer")) { spells.captureActive() }
                    .disabled(spells.busy || !previews.authorized)
                    .help(previews.authorized ? L("diagnostic.sorts.capturer.aide") : L("diagnostic.sorts.capturer.nonAutorise"))
                Button(L("diagnostic.sorts.analyser")) { spells.analyzeLast() }.disabled(spells.busy)
                Button(L("diagnostic.sorts.fichier")) { spells.analyzeFile() }.help(L("diagnostic.sorts.fichier.aide"))
                Button { spells.revealCaptures() } label: { Image(systemName: "folder") }
                    .help(L("diagnostic.sorts.dossier"))
            }
            .font(.system(size: 11))
            if let picture = spells.lastPicture {
                CaptureOverlay(picture: picture, bar: spells.lastBar, analysis: spells.lastAnalysis, zoomed: zoomCapture)
                    .frame(maxWidth: .infinity)
                    .frame(height: zoomCapture ? 220 : 300)
                HStack {
                    Toggle(L("diagnostic.sorts.zoomer"), isOn: $zoomCapture).font(.system(size: 11))
                        .disabled(spells.lastBar == nil)
                    Button(L("diagnostic.sorts.ouvrirEnGrand")) { spells.revealLastCapture() }.font(.system(size: 11))
                }
            }
            if !spells.report.isEmpty {
                Text(spells.report)
                    .font(.system(size: 10, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.04)))
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

/// La capture avec, par-dessus, les cases trouvées : vertes quand le sort est
/// reconnu avec certitude, orange sinon. C'est ce qui permet de voir d'un
/// coup d'œil si le localisateur a visé la barre — ou le décor.
private struct CaptureOverlay: View {
    let picture: NSImage
    let bar: SpellBarLocator.Bar?
    let analysis: SpellRecognition.Analysis?
    var zoomed = false

    /// La partie de l'image montrée : tout, ou la barre avec une marge.
    private var window: CGRect {
        let full = CGRect(origin: .zero, size: picture.size)
        guard zoomed, let bar else { return full }
        let region = bar.region(in: picture.size, margin: 0.6)
        return CGRect(x: region.minX * picture.size.width, y: region.minY * picture.size.height,
                      width: region.width * picture.size.width, height: region.height * picture.size.height)
    }

    var body: some View {
        GeometryReader { geometry in
            let window = window
            let scale = min(geometry.size.width / window.width, geometry.size.height / window.height)
            let drawn = CGSize(width: window.width * scale, height: window.height * scale)
            ZStack(alignment: .topLeading) {
                Image(nsImage: picture)
                    .resizable()
                    .frame(width: picture.size.width * scale, height: picture.size.height * scale)
                    .offset(x: -window.minX * scale, y: -window.minY * scale)
                if let bar {
                    Canvas { context, _ in
                        for (row, rects) in bar.rows.enumerated() {
                            for (position, rect) in rects.enumerated() {
                                let cell = analysis?.cells.first { $0.row == row && $0.position == position }
                                let color: Color = cell?.match == nil ? .gray : (cell?.match?.isConfident == true ? .green : .orange)
                                let scaled = CGRect(x: (rect.minX - window.minX) * scale, y: (rect.minY - window.minY) * scale,
                                                    width: rect.width * scale, height: rect.height * scale)
                                context.stroke(Path(scaled), with: .color(color), lineWidth: zoomed ? 2 : 1.5)
                                if zoomed, let nom = cell?.match?.nom {
                                    context.draw(Text(nom).font(.system(size: 8)).foregroundStyle(color),
                                                 at: CGPoint(x: scaled.midX, y: scaled.maxY + 6))
                                }
                            }
                        }
                    }
                    .frame(width: drawn.width, height: drawn.height)
                }
            }
            .frame(width: drawn.width, height: drawn.height)
            .clipped()
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .center)
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.black.opacity(0.06)))
    }
}
