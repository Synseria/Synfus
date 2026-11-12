import SwiftUI

/// Onglet Boss : le panneau d'aide, son raccourci, un boss par ligne, et ce
/// qu'il lit — les zones de la vie et du tchat se calibrent dans l'onglet
/// Lecture de l'écran.
struct BossSettings: View {
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        PageReglages(titre: L("boss.titre")) {
            Section {
                RaccourciReglable(label: L("boss.raccourci"), chemin: \.bossHotKey)
                    .help(L("boss.aide"))
                ForEach(Boss.allCases, id: \.self) { boss in
                    Ligne(titre: BossVue.nom(boss), aide: Self.resume(boss)) {
                        Button(L("boss.ouvrir")) { BossPanel.shared.ouvrir(.special(boss)) }
                    }
                }
            }
            if !previews.authorized {
                Section {
                    Ligne(titre: L("boss.lecture"), aide: L("boss.lecture.aide")) {
                        Button(L("boss.lecture.autoriser")) { previews.requestAuthorization() }
                    }
                }
            }
        }
    }

    private static func resume(_ boss: Boss) -> String {
        switch boss {
        case .harebourg: return L("boss.harebourg.aide")
        case .kimbo: return L("boss.kimbo.aide")
        case .toxoliath: return L("boss.toxoliath.aide")
        case .ilyzaelle: return L("boss.ilyzaelle.aide")
        case .talKasha: return L("boss.talKasha.aide")
        }
    }
}
