import SwiftUI

extension GenreLecture: Identifiable {
    var id: String { rawValue }

    var libelle: String {
        switch self {
        case .position: return L("diagnostic.lecture.position")
        case .combat: return L("diagnostic.lecture.combat")
        }
    }

    /// Couleur du cadre de la zone sur la capture — le rose du bouton de fin
    /// de tour pour le combat.
    var teinte: Color {
        switch self {
        case .position: return .blue
        case .combat: return Color(red: 0.76, green: 0.44, blue: 0.73)
        }
    }
}

/// Calibrer les zones de lecture d'un tracé : une capture du contenu d'un
/// client, les zones posées dessus, et un rectangle tiré à la souris pour
/// remplacer celle qu'on a choisie.
///
/// L'interface du jeu se déplace — le bouton de fin de tour en premier —,
/// mais on la règle une fois : chercher le bouton partout à chaque lecture
/// coûterait pour rien. Les zones sont des fractions du contenu : tracées sur
/// une fenêtre, elles valent pour toutes les tailles de fenêtre.
struct CalibrationZonesView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var image: NSImage?
    @State private var enCours = false
    @State private var genre: GenreLecture = .position
    /// Le rectangle en cours de tracé, en fractions de l'image.
    @State private var trace: CGRect?
    @State private var cible: String?

    private static let largeurImage: CGFloat = 640
    private static let hauteurImage: CGFloat = 400

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L("calibration.titre")).font(.system(size: 14, weight: .semibold))
                Spacer()
                Picker("", selection: $cible) {
                    ForEach(manager.clients) { client in
                        Text(client.name).tag(Optional(client.slotKey))
                    }
                }
                .labelsHidden()
                .frame(width: 180)
                .onChange(of: cible) { _, _ in Task { await capturer() } }
            }
            Text(L("calibration.aide"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Picker("", selection: $genre) {
                ForEach(GenreLecture.allCases) { Text($0.libelle).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            capture
                .frame(width: Self.largeurImage, height: Self.hauteurImage)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))

            apercu

            HStack {
                Button(L("calibration.recapturer")) { Task { await capturer() } }
                    .disabled(enCours || manager.clients.isEmpty)
                Button(L("calibration.defaut", genre.libelle)) { poser(nil, pour: genre) }
                    .disabled(zone(genre) == nil)
                Spacer()
                Button(L("calibration.terminer")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: Self.largeurImage + 32)
        .task {
            cible = cible ?? defaut()?.slotKey
            await capturer()
        }
    }

    // MARK: - Capture et tracé

    @ViewBuilder
    private var capture: some View {
        if let image {
            GeometryReader { geo in
                let cadre = ajuste(image.size, dans: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: cadre.width, height: cadre.height)
                        .offset(x: cadre.minX, y: cadre.minY)
                    ForEach(GenreLecture.allCases) { g in
                        let r = versEcran(trace.flatMap { g == genre ? $0 : nil } ?? effective(g).rect, dans: cadre)
                        Rectangle()
                            .strokeBorder(g.teinte, lineWidth: g == genre ? 2 : 1)
                            .background(g.teinte.opacity(g == genre ? 0.15 : 0.05))
                            .frame(width: max(r.width, 1), height: max(r.height, 1))
                            .offset(x: r.minX, y: r.minY)
                            .allowsHitTesting(false)
                    }
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
                            poser(ZoneEcran(r).bornee(), pour: genre)
                        }
                )
            }
        } else {
            Text(enCours ? L("calibration.enCours")
                 : manager.clients.isEmpty ? L("calibration.aucunPerso")
                 : (WindowPreviewService.shared.lastCaptureError ?? L("calibration.enCours")))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Ce que la zone choisie donne, agrandi : c'est à peu près ce que l'OCR
    /// recevra.
    @ViewBuilder
    private var apercu: some View {
        if let image, let recadree = recadrer(image, effective(genre).rect) {
            HStack(alignment: .top, spacing: 8) {
                Text(L("calibration.apercu"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Image(nsImage: recadree)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 420, maxHeight: 90, alignment: .leading)
                    .overlay(Rectangle().strokeBorder(genre.teinte.opacity(0.6), lineWidth: 1))
            }
        }
    }

    private func capturer() async {
        guard let client = manager.clients.first(where: { $0.slotKey == cible }) ?? defaut() else { return }
        let service = WindowPreviewService.shared
        service.refreshAuthorization()
        guard service.authorized else { image = nil; return }
        enCours = true
        defer { enCours = false }
        // Le contenu entier, sans barre de titre : c'est le repère des zones.
        let data = await service.captureData(
            client, region: CGRect(x: 0, y: 0, width: 1, height: 1), maxWidth: 1400,
            inventaireGarde: false, contenu: CaptureContenu(pleinEcran: client.pleinEcran, normaliser: false))
        image = data.flatMap(NSImage.init(data:))
    }

    /// Le perso devant s'il y en a un, sinon le premier qui a une fenêtre à
    /// l'écran — un dormant se capture, mais son image peut dater.
    private func defaut() -> DofusClient? {
        manager.clients.first(where: { manager.isFrontmost($0) })
            ?? manager.clients.first(where: { !$0.dormant })
            ?? manager.clients.first
    }

    // MARK: - Zones

    private func zone(_ genre: GenreLecture) -> ZoneEcran? {
        switch genre {
        case .position: return prefs.zonePosition
        case .combat: return prefs.zoneCombat
        }
    }

    private func effective(_ genre: GenreLecture) -> ZoneEcran { genre.zone }

    private func poser(_ zone: ZoneEcran?, pour genre: GenreLecture) {
        switch genre {
        case .position: prefs.zonePosition = zone
        case .combat: prefs.zoneCombat = zone
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

    private func recadrer(_ image: NSImage, _ zone: CGRect) -> NSImage? {
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let r = CGRect(x: zone.minX * CGFloat(cg.width), y: zone.minY * CGFloat(cg.height),
                       width: zone.width * CGFloat(cg.width), height: zone.height * CGFloat(cg.height)).integral
        guard let coupe = cg.cropping(to: r) else { return nil }
        return NSImage(cgImage: coupe, size: NSSize(width: coupe.width, height: coupe.height))
    }
}
