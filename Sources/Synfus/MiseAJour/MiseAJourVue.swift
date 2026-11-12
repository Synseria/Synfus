import AppKit
import SwiftUI

extension MiseAJour.Etat {
    /// Ce que dit l'état à côté de la version ; rien tant qu'on n'a rien cherché.
    var libelle: String? {
        switch self {
        case .inconnu: nil
        case .verification: L("maj.verification")
        case .aJour: L("maj.aJour")
        case .disponible(let version): L("maj.disponible", version.numero)
        case .installation: L("maj.installation")
        case .echec(.reseau, _): L("maj.echec.reseau")
        case .echec(.empreinte, _): L("maj.echec.empreinte")
        case .echec(.image, _), .echec(.app, _): L("maj.echec.image")
        case .echec(.ecriture, _): L("maj.echec.ecriture")
        }
    }
}

/// Le geste que l'état appelle : Réglages ▸ Général et À propos.
struct ActionMiseAJour: View {
    @ObservedObject var miseAJour: MiseAJour = .shared
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        switch miseAJour.etat {
        case .verification, .installation:
            ProgressView().controlSize(.small)
        case .disponible:
            Button(L("maj.installer")) { miseAJour.proposer() }
                .buttonStyle(.bouton(.principal))
        case .echec(.ecriture, let version):
            Button(L("maj.telecharger")) { NSWorkspace.shared.open(version.page) }
                .buttonStyle(.bouton(.secondaire))
        case .echec:
            Button(L("maj.reessayer")) { miseAJour.proposer() }
                .buttonStyle(.bouton(.secondaire))
        case .inconnu, .aJour:
            if prefs.verifierMisesAJour {
                Button(L("maj.rechercher")) { miseAJour.verifier() }
                    .buttonStyle(.bouton(.secondaire))
            }
        }
    }
}
