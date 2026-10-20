import SwiftUI

/// Onglet Boss : le panneau d'aide contre le Comte Harebourg, son raccourci,
/// et ce qu'il lit — les zones de la vie et du tchat se calibrent dans
/// l'onglet Lecture de l'écran.
struct BossSettings: View {
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        PageReglages(titre: L("boss.titre"), sousTitre: L("boss.sousTitre"), aide: L("boss.aide")) {
            Section {
                RaccourciReglable(label: L("boss.raccourci"), chemin: \.bossHotKey)
                Ligne(titre: L("boss.harebourg"), sousTexte: L("boss.harebourg.sousTexte")) {
                    Button(L("boss.ouvrir")) { BossPanel.shared.ouvrir() }
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
}
