import SwiftUI

/// Onglet Aides : les panneaux posés sur le jeu — la chasse au trésor et les boss.
struct AidesSettings: View {
    @ObservedObject private var modele = ChasseModele.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        PageReglages(titre: L("reglages.aides")) {
            Bloc(L("chasse.titre")) {
                RaccourciReglable(label: L("chasse.raccourci"), chemin: \.chasseHotKey)
                    .help(L("chasse.aide"))
                indices
            }
            Bloc(L("boss.titre")) {
                RaccourciReglable(label: L("boss.raccourci"), chemin: \.bossHotKey)
                    .help(L("boss.aide"))
                ForEach(Boss.allCases, id: \.self) { boss in
                    Ligne(titre: BossVue.nom(boss), aide: Self.resume(boss)) {
                        Button(L("boss.ouvrir")) { BossPanel.shared.ouvrir(.special(boss)) }
                    }
                }
                if !previews.authorized {
                    Ligne(titre: L("boss.lecture"), aide: L("boss.lecture.aide")) {
                        Button(L("boss.lecture.autoriser")) { previews.requestAuthorization() }
                    }
                }
            }
        }
    }

    /// La liste des indices de DofusDB : sa date, ou son échec — le nom et le geste, sans la cause.
    @ViewBuilder
    private var indices: some View {
        if modele.echecIndices != nil, !modele.chargementIndices {
            Ligne(titre: L("chasse.indices.indisponibles")) {
                Button(L("commun.reessayer")) { Task { await modele.chargerIndices(forcer: true) } }
            }
        } else {
            Ligne(titre: L("chasse.indices"), etat: source) {
                HStack(spacing: Jetons.Espace.deux) {
                    if modele.chargementIndices { ProgressView().controlSize(.small) }
                    Button(L("chasse.indices.maj")) { Task { await modele.chargerIndices(forcer: true) } }
                        .disabled(modele.chargementIndices)
                    Button(L("chasse.ouvrir")) { ChassePanel.shared.ouvrir() }
                }
            }
        }
    }

    private var source: String {
        guard let date = modele.dateIndices else { return L("chasse.indices.aucune") }
        return L("chasse.indices.date", modele.indices.count,
                 date.formatted(date: .abbreviated, time: .omitted))
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
