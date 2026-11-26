import SwiftUI
import SynseriaDesign

/// Calibrer la grille du plateau de combat (`GrilleIso`) sur une capture du
/// jeu : un clic au centre d'une case, un autre au centre d'une case plus loin
/// sur la diagonale ↘, l'écart en cases — la grille se dessine par-dessus.
/// La capture reste dans les caches (`CapturesCalibrage`, `grille.png`).
struct CalibrationGrilleView: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var capture: CapturesCalibrage.Capture?
    @State private var decompte: Int?
    @State private var attente: Task<Void, Never>?
    @State private var echec: String?
    /// Les centres cliqués, en fractions de l'image : A, puis B.
    @State private var clics: [CGPoint] = []
    @State private var ecart = 6

    /// `capture` : celle des captures de la documentation ; sinon la capture gardée.
    init(capture: CapturesCalibrage.Capture? = nil) {
        _capture = State(initialValue: capture)
    }

    static let nomCapture = "grille"
    /// La case A teintée, la capture lisible dessous.
    private static let voileCaseA = 0.35
    private static let largeurImage: CGFloat = 800
    private static let hauteurImage: CGFloat = 500

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace2) {
            Text(L("calibration.titre", L("boss.visee.grille"))).font(Jetons.typoSection.font)
            Text(L("calibration.grille.consigne"))
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.encre2))
                .fixedSize(horizontal: false, vertical: true)

            image
                .frame(width: Self.largeurImage, height: Self.hauteurImage)
                .background(RoundedRectangle(cornerRadius: Jetons.rayon1).fill(Color.jeton(\.creux)))

            HStack(spacing: Jetons.espace2) {
                Stepper(L("calibration.grille.ecart", ecart), value: $ecart, in: 1...20)
                    .onChange(of: ecart) { calculer() }
                if let echec {
                    Text(echec).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.danger))
                }
            }

            HStack {
                Button(decompte.map { L("calibration.decompte", $0) } ?? L("calibration.capturer")) {
                    decompte == nil ? lancer() : annuler()
                }
                .disabled(decompte == nil && manager.clients.isEmpty)
                Button(L("calibration.grille.effacer")) {
                    prefs.grilleCombat = nil
                    clics = []
                }
                .disabled(prefs.grilleCombat == nil)
                Spacer()
                Button(L("calibration.terminer")) { dismiss() }
                    .buttonStyle(BoutonPrincipal())
                    .keyboardShortcut(.defaultAction)
            }
            .buttonStyle(BoutonBorde())
        }
        .padding(Jetons.espace4)
        .frame(width: Self.largeurImage + Jetons.espace6)
        .background(Color.jeton(\.fondFenetre))
        .task { if capture == nil { capture = CapturesCalibrage.gardee(nom: Self.nomCapture) } }
        .onDisappear { attente?.cancel() }
    }

    // MARK: - Capture et clics

    @ViewBuilder
    private var image: some View {
        if let capture {
            GeometryReader { geo in
                let taille = CGSize(width: capture.image.width, height: capture.image.height)
                let cadre = CalibrationZonesView.ajuste(taille, dans: geo.size)
                ZStack(alignment: .topLeading) {
                    Image(decorative: capture.image, scale: 1)
                        .resizable()
                        .frame(width: cadre.width, height: cadre.height)
                        .offset(x: cadre.minX, y: cadre.minY)
                    Canvas { contexte, _ in
                        if let grille = prefs.grilleCombat, grille.valable(pour: taille) {
                            Self.dessiner(grille, dans: cadre, contexte: contexte)
                        }
                        for (rang, clic) in clics.enumerated() {
                            let p = CGPoint(x: cadre.minX + clic.x * cadre.width, y: cadre.minY + clic.y * cadre.height)
                            let rond = Path(ellipseIn: CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8))
                            contexte.fill(rond, with: .color(rang == 0 ? Color.jeton(\.accent) : Color.jeton(\.avertissement)))
                        }
                    }
                    .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { point in
                    guard cadre.contains(point) else { return }
                    let f = CGPoint(x: (point.x - cadre.minX) / cadre.width, y: (point.y - cadre.minY) / cadre.height)
                    clics = clics.count == 1 ? clics + [f] : [f]
                    calculer()
                }
                .curseurDeClic(true)
            }
        } else {
            Text(decompte != nil ? L("calibration.enCours")
                 : echec ?? (manager.clients.isEmpty ? L("calibration.aucunPerso") : L("calibration.aucuneCapture")))
                .font(Jetons.typoMeta.font)
                .foregroundStyle(Color.jeton(\.encre2))
                .multilineTextAlignment(.center)
                .padding(Jetons.espace5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Deux clics : la grille, ou la raison de son refus.
    private func calculer() {
        echec = nil
        guard clics.count == 2, let capture else { return }
        let taille = CGSize(width: capture.image.width, height: capture.image.height)
        guard let grille = GrilleIso.depuis(centreA: clics[0], centreB: clics[1], ecart: GrilleIso.Case(ecart, 0),
                                            contenu: taille)
        else { echec = L("calibration.grille.refus"); return }
        prefs.grilleCombat = grille
    }

    private func lancer() {
        let service = WindowPreviewService.shared
        service.refreshAuthorization()
        guard service.authorized else { service.requestAuthorization(); return }
        echec = nil
        attente = Task {
            guard await AutoCalibrage.decompter(tic: { decompte = $0 }) else { return }
            switch await AutoCalibrage.capturer() {
            case .success(let image):
                do { try CapturesCalibrage.garder(image, nom: Self.nomCapture) } catch { echec = error.localizedDescription }
                capture = CapturesCalibrage.gardee(nom: Self.nomCapture)
                clics = []
            case .failure(let erreur):
                echec = erreur.message
            }
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

    // MARK: - Géométrie de l'affichage

    /// La grille sur l'image affichée : chaque case dont le centre y tombe.
    private static func dessiner(_ grille: GrilleIso, dans cadre: CGRect, contexte: GraphicsContext) {
        let a = grille.a(cadre.size)
        guard a > 2 else { return }
        let origine = CGPoint(x: cadre.minX + grille.origine.x * cadre.width,
                              y: cadre.minY + grille.origine.y * cadre.height)
        let portee = Int(cadre.width / a) + 2
        var trait = Path()
        for x in -portee...portee {
            for y in -portee...portee where cadre.contains(GrilleIso.projeter(x, y, a: a, centre: origine)) {
                trait.addLines(GrilleIso.losange(x, y, a: a, centre: origine))
                trait.closeSubpath()
            }
        }
        contexte.stroke(trait, with: .color(Color.jeton(\.accent)), lineWidth: Jetons.epaisseurFilet)
        // La case A, d'où partent les cases de la grille.
        contexte.fill(Path { $0.addLines(GrilleIso.losange(0, 0, a: a, centre: origine)); $0.closeSubpath() },
                      with: .color(Color.jeton(\.accent).opacity(Self.voileCaseA)))
    }
}
