import SwiftUI

/// Onglet Trajets : un `/travel` copié passe par le zaap le plus proche.
struct TrajetsSettings: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        PageReglages(titre: L("reglages.trajets")) {
            Section {
                RaccourciReglable(label: L("zaap.raccourci"), help: L("zaap.raccourci.aide"), chemin: \.zaapHotKey)
                    .help(L("zaap.reecriture.aide", ItineraireZaap.ecartZaapDuJeu))
                Ligne(titre: L("zaap.gain"), aide: L("zaap.gain.aide")) {
                    Stepper(L("zaap.gain.valeur", nombre: prefs.zaapGainMinimal, prefs.zaapGainMinimal),
                            value: $prefs.zaapGainMinimal, in: ItineraireZaap.gainsPossibles)
                }
                Interrupteur(titre: L("zaap.duJeu"), aide: L("zaap.duJeu.aide", ItineraireZaap.ecartZaapDuJeu), isOn: $prefs.zaapDuJeu)
                Ligne(titre: L("zaap.intercalees"), aide: L("zaap.intercalees.aide")) {
                    TextField(L("zaap.intercalees"), text: $prefs.zaapIntercalees, prompt: Text(verbatim: "/a"))
                        .labelsHidden()
                        .font(.synfus(.codeInterface))
                        .frame(width: 180)
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
