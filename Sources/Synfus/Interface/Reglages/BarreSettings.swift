import SwiftUI

/// Onglet Barre : la barre flottante, ce qu'elle montre — ses boutons
/// compris —, et l'aperçu au survol.
struct BarreSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var previews = WindowPreviewService.shared

    var body: some View {
        PageReglages(titre: L("reglages.barre")) {
            Bloc {
                Interrupteur(titre: L("general.barre.afficher"), isOn: Binding(
                    get: { prefs.barVisible },
                    set: { prefs.barVisible = $0; FloatingBarController.shared.apply() }
                ))
                .help(L("general.barre.aide"))
                if prefs.barVisible {
                    Interrupteur(titre: L("general.barre.seulementDofus"), isOn: Binding(
                        get: { prefs.barOnlyWithDofus },
                        set: { prefs.barOnlyWithDofus = $0; FloatingBarController.shared.updateVisibility() }
                    ))
                    Interrupteur(titre: L("general.barre.numeros"), isOn: $prefs.showNumbers)
                    Interrupteur(titre: L("general.barre.classes"), isOn: $prefs.showClasses)
                    if prefs.showNumbers || prefs.showClasses {
                        Interrupteur(titre: L("general.barre.reduire"), aide: L("general.barre.reduire.aide"),
                                     isOn: $prefs.reduirePersosInactifs)
                    }
                    Ligne(titre: L("general.barre.position")) {
                        Button(L("general.barre.recentrer")) { FloatingBarController.shared.recenter() }
                    }
                }
                Interrupteur(titre: L("barre.panneauxSeulementDofus"), aide: L("barre.panneauxSeulementDofus.aide"),
                             isOn: Binding(get: { prefs.panneauxSeulementDofus }, set: { valeur in
                                 prefs.panneauxSeulementDofus = valeur
                                 PanneauxJeu.revoir(force: true)
                             }))
            }
            if prefs.barVisible {
                Bloc(L("barre.boutons")) {
                    ForEach(BoutonBarre.allCases, id: \.self) { bouton in
                        Interrupteur(titre: bouton.libelle, symbole: bouton.symbole, isOn: Binding(
                            get: { !prefs.boutonsMasques.contains(bouton) },
                            set: { prefs.montrer(bouton, $0) }
                        ))
                    }
                }
            }
            Bloc {
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
