import SwiftUI

extension GenreLecture: Identifiable {
    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .position: return L("diagnostic.lecture.position")
        case .combat: return L("diagnostic.lecture.combat")
        case .chasse: return L("diagnostic.lecture.chasse")
        case .quetes: return L("diagnostic.lecture.quetes")
        }
    }

    /// Ce qu'il faut avoir à l'écran quand la capture part.
    var consigne: String {
        switch self {
        case .position: return L("calibration.consigne.position")
        case .combat: return L("calibration.consigne.combat")
        case .chasse: return L("calibration.consigne.chasse")
        case .quetes: return L("calibration.consigne.quetes")
        }
    }

    /// Couleur du cadre de la zone sur la capture — le rose du bouton de fin
    /// de tour pour le combat, l'or d'un trésor pour la chasse.
    var teinte: Color {
        switch self {
        case .position: return .blue
        case .combat: return Color(red: 0.76, green: 0.44, blue: 0.73)
        case .chasse: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .quetes: return Color(red: 0.30, green: 0.68, blue: 0.45)
        }
    }
}

/// Calibrer la zone d'un genre de lecture : une capture du jeu prise quand
/// l'élément est à l'écran, la zone tracée dessus, et l'essai de la lecture.
///
/// Chaque genre a sa capture : le bouton de fin de tour n'existe qu'en
/// combat, le suivi de chasse pendant une chasse. Elle part après un compte à
/// rebours — le temps de revenir au jeu et d'ouvrir l'élément — et reste sur
/// le disque (`CapturesCalibrage`) pour recalibrer plus tard. Les zones sont
/// des fractions du contenu : tracées sur une fenêtre, elles valent pour
/// toutes les tailles de fenêtre.
struct CalibrationZonesView: View {
    let genre: GenreLecture

    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var capture: CapturesCalibrage.Capture?
    @State private var decompte: Int?
    @State private var attente: Task<Void, Never>?
    @State private var echec: String?
    /// Le rectangle en cours de tracé, en fractions de l'image.
    @State private var trace: CGRect?
    @State private var essai: Essai?
    @State private var essaiEnCours: Task<Void, Never>?

    private struct Essai {
        let lignes: [String]
        let compris: String
    }

    /// Le temps de revenir au jeu et d'y ouvrir l'élément.
    private static let delai = 5
    private static let largeurImage: CGFloat = 640
    private static let hauteurImage: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("calibration.titre", genre.libelle)).font(.system(size: 14, weight: .semibold))
            Text(genre.consigne)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            image
                .frame(width: Self.largeurImage, height: Self.hauteurImage)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
            if let capture {
                Text(L("calibration.capturee", capture.date.formatted(date: .abbreviated, time: .shortened)))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            essaiVue

            HStack {
                Button(decompte.map { L("calibration.decompte", $0) } ?? L("calibration.capturer")) {
                    decompte == nil ? lancer() : annuler()
                }
                .disabled(decompte == nil && manager.clients.isEmpty)
                Button(L("calibration.defaut")) { poser(nil) }
                    .disabled(prefs[keyPath: genre.reglage] == nil)
                Spacer()
                Button(L("calibration.terminer")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: Self.largeurImage + 32)
        .task {
            capture = CapturesCalibrage.gardee(genre)
            essayer()
        }
        .onDisappear {
            attente?.cancel()
            essaiEnCours?.cancel()
        }
    }

    // MARK: - Capture et tracé

    @ViewBuilder
    private var image: some View {
        if let capture {
            GeometryReader { geo in
                let taille = CGSize(width: capture.image.width, height: capture.image.height)
                let cadre = ajuste(taille, dans: geo.size)
                let zone = versEcran(trace ?? genre.zone.rect, dans: cadre)
                ZStack(alignment: .topLeading) {
                    Image(decorative: capture.image, scale: 1)
                        .resizable()
                        .frame(width: cadre.width, height: cadre.height)
                        .offset(x: cadre.minX, y: cadre.minY)
                    Rectangle()
                        .strokeBorder(genre.teinte, lineWidth: 2)
                        .background(genre.teinte.opacity(0.15))
                        .frame(width: max(zone.width, 1), height: max(zone.height, 1))
                        .offset(x: zone.minX, y: zone.minY)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { valeur in
                            trace = fraction(de: valeur.startLocation, a: valeur.location, dans: cadre)
                        }
                        .onEnded { valeur in
                            let r = fraction(de: valeur.startLocation, a: valeur.location, dans: cadre)
                            trace = nil
                            guard r.width >= ZoneEcran.tailleMinimale, r.height >= ZoneEcran.tailleMinimale
                            else { return }
                            poser(ZoneEcran(r).bornee())
                        }
                )
            }
        } else {
            Text(decompte != nil ? L("calibration.enCours")
                 : echec ?? (manager.clients.isEmpty ? L("calibration.aucunPerso") : L("calibration.aucuneCapture")))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Ce que la zone donne, agrandi — ce que l'OCR reçoit —, ce qu'il y lit
    /// et ce que Synfus en comprend.
    @ViewBuilder
    private var essaiVue: some View {
        if let capture, let recadree = capture.image.cropping(
            to: genre.zone.pixels(dans: CGSize(width: capture.image.width, height: capture.image.height))) {
            HStack(alignment: .top, spacing: 10) {
                Image(decorative: recadree, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 200, maxHeight: 120, alignment: .topLeading)
                    .overlay(Rectangle().strokeBorder(genre.teinte.opacity(0.6), lineWidth: 1))
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(L("calibration.essai")).font(.system(size: 11, weight: .semibold))
                        if essaiEnCours != nil { ProgressView().controlSize(.mini) }
                    }
                    if let essai {
                        Text(L("calibration.essai.compris", essai.compris))
                            .font(.system(size: 11))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(L("diagnostic.position.brut",
                               essai.lignes.isEmpty ? "—" : essai.lignes.joined(separator: " ⏎ ")))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(6)
                            .textSelection(.enabled)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func lancer() {
        let service = WindowPreviewService.shared
        service.refreshAuthorization()
        guard service.authorized else { service.requestAuthorization(); return }
        echec = nil
        attente = Task {
            for reste in stride(from: Self.delai, to: 0, by: -1) {
                decompte = reste
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { decompte = nil; return }
            }
            await capturer()
            decompte = nil
            attente = nil
            // Le joueur est dans le jeu : on lui rend la capture.
            SettingsWindowController.shared.show()
        }
    }

    private func annuler() {
        attente?.cancel()
        attente = nil
        decompte = nil
    }

    /// Le perso devant à la fin du décompte — celui où l'on vient d'ouvrir
    /// l'élément —, sinon celui qui a une fenêtre à l'écran.
    private func capturer() async {
        guard let client = manager.clients.first(where: { manager.isFrontmost($0) })
                ?? manager.clients.first(where: { !$0.dormant }) ?? manager.clients.first
        else { echec = L("calibration.aucunPerso"); return }
        // Le contenu entier, sans barre de titre et à l'échelle de la
        // lecture : c'est le repère des zones et ce que l'OCR recevra.
        guard let png = await WindowPreviewService.shared.captureData(
            client, region: CGRect(x: 0, y: 0, width: 1, height: 1), maxWidth: nil, inventaireGarde: false,
            contenu: CaptureContenu(pleinEcran: client.pleinEcran, normaliser: true))
        else { echec = WindowPreviewService.shared.lastCaptureError ?? L("calibration.echec"); return }
        do {
            try CapturesCalibrage.garder(png, pour: genre)
        } catch {
            echec = error.localizedDescription
        }
        capture = CapturesCalibrage.gardee(genre)
        essayer()
    }

    // MARK: - Zone et essai

    private func poser(_ zone: ZoneEcran?) {
        prefs[keyPath: genre.reglage] = zone
        essayer()
    }

    /// L'OCR de la zone sur la capture gardée, puis son interprétation —
    /// relancé à chaque tracé : on voit tout de suite si la zone convient.
    private func essayer() {
        essaiEnCours?.cancel()
        guard let capture, let png = CapturesCalibrage.decouper(genre.zone, dans: capture.image) else {
            essai = nil
            essaiEnCours = nil
            return
        }
        let genre = genre
        essaiEnCours = Task {
            let lu = await LecteurEcran.shared.lire(png: png, genre: genre)
            let compris = await comprendre(lu?.lignes ?? [], couleur: lu?.couleur ?? 0)
            guard !Task.isCancelled else { return }
            essai = Essai(lignes: lu?.lignes ?? [], compris: compris)
            essaiEnCours = nil
        }
    }

    private func comprendre(_ lignes: [String], couleur: Double) async -> String {
        switch genre {
        case .position:
            return PositionCarte.libelle(PositionCarte.lire(lignes))
        case .combat:
            let constat = LectureCombat.classer(lignes: lignes, couleur: couleur)
            return L("calibration.essai.combat", EtatCombat.libelle(EtatCombat.depuis(constat, avant: nil, maintenant: Date())),
                     Int(couleur * 100))
        case .chasse:
            let chasse = ChasseModele.shared
            if chasse.indices.isEmpty { await chasse.chargerIndices() }
            let lues = EtapeChasse.ciblesLues(dans: lignes, parmi: chasse.indices)
            return lues.isEmpty ? L("chasse.rienLu") : lues.map { $0.nom(en: chasse.langue) }.joined(separator: ", ")
        case .quetes:
            guard let quetes = await QuetesStore.shared.chargees() else { return L("palette.quetes.chargement") }
            let reconnues = await Task.detached { SuiviQuetes.reconnaitre(lignes, dans: quetes) }.value
            guard !reconnues.isEmpty else { return L("quete.suivi.rien") }
            return reconnues.map { reconnue in
                let nom = QuetesStore.shared.nom(reconnue.id) ?? "#\(reconnue.id)"
                return reconnue.etape.map { L("calibration.essai.quete", nom, $0 + 1) } ?? nom
            }.joined(separator: ", ")
        }
    }

    // MARK: - Géométrie de l'affichage

    /// L'image ajustée dans la vue, centrée, proportions gardées.
    private func ajuste(_ taille: CGSize, dans vue: CGSize) -> CGRect {
        guard taille.width > 0, taille.height > 0 else { return .zero }
        let echelle = min(vue.width / taille.width, vue.height / taille.height)
        let l = taille.width * echelle, h = taille.height * echelle
        return CGRect(x: (vue.width - l) / 2, y: (vue.height - h) / 2, width: l, height: h)
    }

    private func versEcran(_ zone: CGRect, dans cadre: CGRect) -> CGRect {
        CGRect(x: cadre.minX + zone.minX * cadre.width, y: cadre.minY + zone.minY * cadre.height,
               width: zone.width * cadre.width, height: zone.height * cadre.height)
    }

    private func fraction(de a: CGPoint, a b: CGPoint, dans cadre: CGRect) -> CGRect {
        func f(_ p: CGPoint) -> CGPoint {
            CGPoint(x: min(max((p.x - cadre.minX) / max(cadre.width, 1), 0), 1),
                    y: min(max((p.y - cadre.minY) / max(cadre.height, 1), 0), 1))
        }
        let p = f(a), q = f(b)
        return CGRect(x: min(p.x, q.x), y: min(p.y, q.y), width: abs(q.x - p.x), height: abs(q.y - p.y))
    }
}
