import SwiftUI

/// Onglet Barre : la barre flottante, ce qu'elle montre, et l'aperçu au survol.
struct BarreSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        PageReglages(titre: L("reglages.barre"), sousTitre: L("barre.sousTitre"),
                     aide: L("general.barre.aide")) {
            Section {
                Interrupteur(titre: L("general.barre.afficher"), isOn: Binding(
                    get: { prefs.barVisible },
                    set: { prefs.barVisible = $0; FloatingBarController.shared.apply() }
                ))
                if prefs.barVisible {
                    Interrupteur(titre: L("general.barre.seulementDofus"), isOn: Binding(
                        get: { prefs.barOnlyWithDofus },
                        set: { prefs.barOnlyWithDofus = $0; FloatingBarController.shared.updateVisibility() }
                    ))
                    Interrupteur(titre: L("general.barre.numeros"), isOn: $prefs.showNumbers)
                    Interrupteur(titre: L("general.barre.classes"), isOn: $prefs.showClasses)
                    Ligne(titre: L("general.barre.position")) {
                        Button(L("general.barre.recentrer")) { FloatingBarController.shared.recenter() }
                    }
                }
                Interrupteur(titre: L("barre.panneauxSeulementDofus"), sousTexte: L("barre.panneauxSeulementDofus.sousTexte"),
                             isOn: Binding(get: { prefs.panneauxSeulementDofus }, set: { valeur in
                                 prefs.panneauxSeulementDofus = valeur
                                 QuetePanel.shared.revoirVisibilite(force: true)
                                 ChassePanel.shared.revoirVisibilite(force: true)
                             }))
            }


            Section {
                Interrupteur(titre: L("general.apercus.survol"), aide: L("general.apercus.aide"), isOn: Binding(
                    get: { prefs.showPreviewOnHover },
                    set: { value in
                        prefs.showPreviewOnHover = value
                        if value, !previews.authorized { previews.requestAuthorization() }
                    }
                ))
            }
        }
    }
}
