import AppKit
import MiseAJour
import SwiftUI
import SynseriaDesign

extension SuiviDeMiseAJour.Etat {
    /// L'état tel que la ligne commune le montre (`LigneDeMiseAJour`) : une version trouvée est prête à
    /// installer (le geste la télécharge d'abord) ; une version que ce Mac ne peut pas prendre et un
    /// échec se disent en texte, « Rechercher » relance.
    var pourLaLigne: EtatDeLaMiseAJour {
        switch self {
        case .repos: .repos
        case .recherche: .recherche
        case .aJour: .aJour
        case .disponible(let version), .prete(let version): .prete(version: version.numero.texte, notes: version.notes)
        case .telechargement(let version): .telechargement(version: version.numero.texte)
        case .incompatible(let version): .echec(L("maj.incompatible", version.numero.texte, version.macOSMinimum ?? ""))
        case .echec(.reseau, _), .echec(.autre, _): .echec(L("maj.echec.reseau"))
        case .echec(.empreinte, _): .echec(L("maj.echec.empreinte"))
        case .echec(.image, _), .echec(.app, _), .echec(.signature, _), .echec(.version, _), .echec(.systeme, _):
            .echec(L("maj.echec.image"))
        case .echec(.ecriture, _): .echec(L("maj.echec.ecriture"))
        }
    }
}

extension MiseAJour {
    /// La mise à jour telle que Réglages ▸ Général et À propos la montrent : la seule traduction de
    /// l'état et des gestes de Synfus vers la ligne commune.
    var reglages: MiseAJourDesReglages {
        let prefs = Preferences.shared
        return MiseAJourDesReglages(
            version: AppIntegrity.version ?? "?",
            beta: Binding(get: { prefs.canalDeMiseAJour == .beta },
                          set: { prefs.canalDeMiseAJour = $0 ? .beta : .stable; self.canalChange() }),
            etat: etat.pourLaLigne,
            rechercher: { self.verifier() },
            installer: { self.installer() })
    }
}
