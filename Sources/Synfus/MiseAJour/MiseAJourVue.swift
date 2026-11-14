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

extension MiseAJour {
    /// L'état de la ligne « Version installée » : la version et, quand on sait de quand date la réponse
    /// de GitHub, « à jour, vérifiée aujourd'hui » ; une mise à jour disponible, un échec ou une recherche
    /// en cours se disent seuls.
    nonisolated static func resume(version: String?, etat: Etat, verifiee: Date?, maintenant: Date = Date(),
                                   calendrier: Calendar = .current) -> String? {
        let phrase: String?
        switch etat {
        case .aJour:
            phrase = verifiee.map { L("maj.etat.aJourVerifiee", quand($0, maintenant, calendrier)) } ?? L("maj.aJour")
        case .inconnu:
            phrase = verifiee.map { L("maj.etat.verifiee", quand($0, maintenant, calendrier)) }
        default:
            return etat.libelle
        }
        return [version.map { "v\($0)" }, phrase].compactMap(\.self).joined(separator: " · ").nilSiVide
    }

    nonisolated static func quand(_ date: Date, _ maintenant: Date, _ calendrier: Calendar) -> String {
        let jours = calendrier.dateComponents([.day], from: calendrier.startOfDay(for: date),
                                              to: calendrier.startOfDay(for: maintenant)).day ?? 0
        switch jours {
        case ...0: return L("maj.quand.aujourdhui")
        case 1: return L("maj.quand.hier")
        default: return L("maj.quand.le", date.formatted(.dateTime.day().month(.abbreviated)))
        }
    }
}

private extension String {
    var nilSiVide: String? { isEmpty ? nil : self }
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
            Button(L("commun.reessayer")) { miseAJour.proposer() }
                .buttonStyle(.bouton(.secondaire))
        case .inconnu, .aJour:
            if prefs.verifierMisesAJour {
                Button(L("maj.rechercher")) { miseAJour.verifier() }
                    .buttonStyle(.bouton(.secondaire))
            }
        }
    }
}
