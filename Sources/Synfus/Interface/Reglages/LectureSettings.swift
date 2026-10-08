import SwiftUI

/// Onglet Lecture de l'écran : lire la position et le combat par OCR, le
/// calibrage de chaque zone, les zones lues, ce que ça coûte. L'activer est
/// la demande d'autorisation — le seul endroit où la lecture la fait.
struct LectureSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var lecture = DiagnosticLecture.shared
    @State private var calibrage: GenreLecture?

    var body: some View {
        PageReglages(titre: L("reglages.lecture"), sousTitre: L("lecture.sousTitre"),
                     aide: L("diagnostic.lecture.aide")) {
            Section {
                Interrupteur(titre: L("diagnostic.lecture.position"), isOn: activation(\.lirePosition))
                Interrupteur(titre: L("diagnostic.lecture.combat"), isOn: activation(\.lireCombat))
                if prefs.lirePosition || prefs.lireCombat {
                    Ligne(titre: etatLecture,
                          sousTexte: L("diagnostic.position.stats", lecture.lectures,
                                       Int(lecture.derniereDuree * 1000), lecture.sautes)) {
                        Button(L("diagnostic.position.toutLire")) { LecteurEcran.shared.toutLire() }
                            .help(L("diagnostic.position.toutLire.aide"))
                            .disabled(!previews.authorized || manager.clients.isEmpty)
                    }
                    .foregroundStyle(etatEnDefaut ? Color.orange : Color.primary)
                }
            }
            // Chasse et suivi de quêtes se lisent à la demande, depuis leur
            // panneau : leurs zones se calibrent même lecture éteinte.
            Section {
                ForEach(GenreLecture.allCases) { genre in
                    Ligne(titre: genre.libelle,
                          sousTexte: prefs[keyPath: genre.reglage] == nil
                              ? L("lecture.zone.defaut") : L("lecture.zone.calibree")) {
                        Button(L("lecture.calibrer")) { calibrage = genre }
                    }
                }
            } header: {
                SectionTitle(L("lecture.zones"), help: L("lecture.zones.aide"))
            }
            if prefs.lirePosition || prefs.lireCombat {
                Section {
                    ForEach(GenreLecture.allCases) { genre in
                        if let image = lecture.captures[genre] {
                            zoneLue(genre, image)
                        }
                    }
                } header: {
                    SectionTitle(L("lecture.zonesLues"))
                }
            }
        }
        .sheet(item: $calibrage) { CalibrationZonesView(genre: $0) }
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
