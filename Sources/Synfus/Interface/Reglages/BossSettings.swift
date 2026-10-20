import SwiftUI

/// Onglet Boss : le panneau d'aide, son raccourci, un boss par ligne, et ce
/// qu'il lit — les zones de la vie et du tchat se calibrent dans l'onglet
/// Lecture de l'écran.
struct BossSettings: View {
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        PageReglages(titre: L("boss.titre"), sousTitre: L("boss.sousTitre"), aide: L("boss.aide")) {
            Section {
                RaccourciReglable(label: L("boss.raccourci"), chemin: \.bossHotKey)
                ForEach(Boss.allCases, id: \.self) { boss in
                    Ligne(titre: BossVue.nom(boss), sousTexte: Self.resume(boss)) {
                        Button(L("boss.ouvrir")) { BossPanel.shared.ouvrir(boss) }
                    }
                }
            }
            Section {
                Ligne(titre: L("boss.lecture"), sousTexte: L("boss.lecture.sousTexte")) {
                    if !previews.authorized {
                        Button(L("boss.autoriser")) { previews.requestAuthorization() }
                    }
                }
            }
        }
    }

    private static func resume(_ boss: Boss) -> String {
        switch boss {
        case .harebourg: return L("boss.harebourg.sousTexte")
        case .kimbo: return L("boss.kimbo.sousTexte")
        case .toxoliath: return L("boss.toxoliath.sousTexte")
        case .ilyzaelle: return L("boss.ilyzaelle.sousTexte")
        case .talKasha: return L("boss.talKasha.sousTexte")
        }
    }
}
