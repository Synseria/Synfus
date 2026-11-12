import SwiftUI

/// Onglet Carte : d'où vient la carte du jeu, comment un trajet se copie, et les repères qu'elle porte —
/// zaaps et lieux, à activer, étiqueter, mettre en favori.
struct CarteSettings: View {
    var body: some View {
        PageReglages(titre: L("reglages.carte")) {
            Bloc {
                SourceCarte()
                InterrupteurVuesCartes()
            }
            BlocTrajets()
            BlocZaaps()
            BlocLieux()
        }
    }
}

/// Un `/travel` copié passe par le zaap le plus proche.
private struct BlocTrajets: View {
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        Bloc(L("reglages.trajets")) {
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
                    .textFieldStyle(.roundedBorder)
                    .font(Jetons.Typo.codeInterface.police)
                    .frame(width: 180)
            }
            if prefs.lirePosition {
                Interrupteur(titre: L("zaap.auto"), aide: L("zaap.auto.aide"), isOn: $prefs.zaapAuto)
            } else {
                // La réécriture a besoin de la position : l'état se dit dans sa ligne, avec le geste qui le lève.
                Ligne(titre: L("zaap.auto"), etat: L("zaap.sansPosition"), aide: L("zaap.auto.aide")) {
                    Button(L("zaap.lirePosition")) {
                        prefs.lirePosition = true
                        if !WindowPreviewService.shared.authorized { WindowPreviewService.shared.requestAuthorization() }
                    }
                }
            }
        }
    }
}
