import SwiftUI

/// Onglet Lecture de l'écran : lire la position et le combat par OCR, le calibrage de chaque zone, les
/// zones lues, ce que ça coûte, puis le diagnostic de ce que Synfus voit.
struct LectureSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var lecture = DiagnosticLecture.shared
    @State private var calibrage: GenreLecture?
    @State private var detection: Task<Void, Never>?
    @State private var decompte: Int?
    @State private var resultat: String?

    var body: some View {
        PageReglages(titre: L("reglages.lecture")) {
            // Chasse et suivi de quêtes se lisent à la demande, depuis leur panneau : leurs zones se
            // calibrent même lecture éteinte. La position et le combat se lisent en continu, d'où leur
            // interrupteur ; l'allumer demande l'autorisation, que la première ligne du bloc redonne tant qu'elle manque.
            Bloc(L("lecture.zones"), aide: L("lecture.zones.aide")) {
                if !previews.authorized {
                    PermissionRow(name: L("autorisation.lecture"), granted: false,
                                  help: L("general.enregistrementEcran.aide")) { previews.requestAuthorization() }
                }
                if let resultat {
                    Text(resultat).foregroundStyle(Color.jeton(\.encreSecondaire)).rangee()
                }
                ForEach(GenreLecture.allCases) { genre in
                    ligneZone(genre)
                    if genre == .combat, prefs.lireCombat {
                        Interrupteur(titre: L("lecture.combatDerriere"), aide: L("lecture.combatDerriere.aide"),
                                     isOn: $prefs.lireCombatDerriere)
                    }
                }
            } entete: {
                HStack(spacing: Jetons.Espace.deux) {
                    if detection != nil, decompte == nil { ProgressView().controlSize(.small) }
                    Button(decompte.map { L("calibration.decompte", $0) } ?? L("lecture.detecter.bouton")) {
                        detection == nil ? detecter() : annuler()
                    }
                    .disabled(manager.clients.isEmpty || (detection != nil && decompte == nil))
                    .help(L("lecture.detecter.aide"))
                }
            }
            if prefs.lirePosition || prefs.lireCombat {
                Bloc {
                    Ligne(titre: etatLecture,
                          etat: L("diagnostic.position.stats", lecture.lectures,
                                  Int(lecture.derniereDuree * 1000), lecture.sautes)) {
                        Button(L("diagnostic.position.toutLire")) { LecteurEcran.shared.toutLire() }
                            .help(L("diagnostic.position.toutLire.aide"))
                            .disabled(!previews.authorized || manager.clients.isEmpty)
                    }
                    .foregroundStyle(etatEnDefaut ? Color.jeton(\.alerte) : Color.jeton(\.encre))
                }
                if GenreLecture.allCases.contains(where: { lecture.captures[$0] != nil }) {
                    Bloc(L("lecture.zonesLues")) {
                        ForEach(GenreLecture.allCases) { genre in
                            if let image = lecture.captures[genre] {
                                zoneLue(genre, image)
                            }
                        }
                    }
                }
            }
            Text(L("reglages.diagnostic")).font(Jetons.Typo.titre.police)
                .padding(.horizontal, Jetons.Espace.trois)
            BlocsDiagnostic()
        }
        .sheet(item: $calibrage) { CalibrationZonesView(genre: $0) }
    }

    /// Une zone : son nom, son interrupteur s'il y en a un, « Calibrer ». Seul l'écart au normal s'écrit.
    private func ligneZone(_ genre: GenreLecture) -> some View {
        Ligne(titre: genre.libelle,
              etat: prefs[keyPath: genre.reglage] == nil ? nil : L("lecture.zone.calibree"),
              aide: genre == .position ? L("diagnostic.lecture.aide") : nil) {
            HStack(spacing: Jetons.Espace.deux) {
                if let chemin = genre.activation {
                    Toggle(genre.libelle, isOn: activation(chemin))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                Button(L("lecture.calibrer")) { calibrage = genre }
            }
        }
    }

    /// Après le décompte (le temps de revenir au jeu), une capture du perso
    /// devant, et chaque élément qu'elle montre trouve sa zone.
    private func detecter() {
        previews.refreshAuthorization()
        guard previews.authorized else { previews.requestAuthorization(); return }
        resultat = nil
        detection = Task {
            defer { detection = nil }
            guard await AutoCalibrage.decompter(tic: { decompte = $0 }) else { return }
            switch await AutoCalibrage.capturer() {
            case .failure(let echec):
                resultat = echec.message
            case .success(let image):
                let zones = await AutoCalibrage.detecter(sur: image)
                AutoCalibrage.appliquer(zones, capture: image)
                resultat = Self.resume(zones)
            }
            // Le joueur est dans le jeu : on lui rend le résultat.
            SettingsWindowController.shared.show()
        }
    }

    private func annuler() {
        detection?.cancel()
        detection = nil
        decompte = nil
    }

    /// Ce qui a été trouvé, ce qui n'était pas à l'écran.
    private static func resume(_ zones: [GenreLecture: ZoneEcran]) -> String {
        let trouvees = GenreLecture.allCases.filter { zones[$0] != nil }.map(\.libelle)
        let absentes = GenreLecture.allCases.filter { zones[$0] == nil }.map(\.libelle)
        guard !trouvees.isEmpty else { return L("lecture.detecter.rien") }
        guard !absentes.isEmpty else { return L("lecture.detecter.tout", trouvees.joined(separator: ", ")) }
        return L("lecture.detecter.resultat", trouvees.joined(separator: ", "), absentes.joined(separator: ", "))
    }

    private func activation(_ chemin: ReferenceWritableKeyPath<Preferences, Bool>) -> Binding<Bool> {
        Binding(get: { prefs[keyPath: chemin] }, set: { value in
            prefs[keyPath: chemin] = value
            if value, !previews.authorized { previews.requestAuthorization() }
        })
    }

    /// Ce que l'OCR a reçu : si le texte n'y est pas, c'est la zone qui est en
    /// cause — à recalibrer —, pas la reconnaissance.
    private func zoneLue(_ genre: GenreLecture, _ image: NSImage) -> some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            Text(L("diagnostic.lecture.zoneVue", genre.libelle, lecture.dernierPerso ?? "?"))
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.encreTertiaire))
            Image(nsImage: image)
                .resizable()
                .interpolation(.medium)
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 360, maxHeight: 80, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille))
            if let lignes = lecture.lignes[genre] {
                Text(L("diagnostic.position.brut", lignes.joined(separator: " ⏎ ")))
                    .font(Jetons.Typo.codeInterface.police)
                    .foregroundStyle(Color.jeton(\.encreTertiaire))
                    .textSelection(.enabled)
            }
            if genre == .combat, let couleur = lecture.couleur {
                Text(L("diagnostic.lecture.couleur", Int(couleur * 100)))
                    .font(Jetons.Typo.codeInterface.police)
                    .foregroundStyle(Color.jeton(\.encreTertiaire))
            }
        }
        .rangee()
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
}

private extension GenreLecture {
    /// L'interrupteur d'une lecture continue ; les autres genres se lisent à la demande.
    @MainActor var activation: ReferenceWritableKeyPath<Preferences, Bool>? {
        switch self {
        case .position: \.lirePosition
        case .combat: \.lireCombat
        case .chasse, .quetes, .vie, .tchat: nil
        }
    }
}
