import SwiftUI

/// Onglet Trajets : un `/travel` copié passe par le zaap le plus proche.
struct TrajetsSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.trajets"), sousTitre: L("trajets.sousTitre"),
                     aide: L("zaap.reecriture.aide")) {
            Section {
                RaccourciReglable(label: L("zaap.raccourci"), help: L("zaap.raccourci.aide"), chemin: \.zaapHotKey)
                Ligne(titre: L("zaap.gain"), sousTexte: L("zaap.gain.sousTexte")) {
                    Stepper(L("zaap.gain.valeur", prefs.zaapGainMinimal),
                            value: $prefs.zaapGainMinimal, in: ItineraireZaap.gainsPossibles)
                }
                if prefs.lirePosition {
                    Interrupteur(titre: L("zaap.auto"), aide: L("zaap.auto.aide"), isOn: $prefs.zaapAuto)
                } else {
                    Avertissement(texte: L("zaap.sansPosition"), bouton: L("zaap.lirePosition")) {
                        prefs.lirePosition = true
                        if !WindowPreviewService.shared.authorized { WindowPreviewService.shared.requestAuthorization() }
                    }
                }
            }
        }
    }
}
