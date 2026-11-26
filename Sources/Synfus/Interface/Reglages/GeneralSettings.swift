import MiseAJour
import SwiftUI
import SynseriaDesign

/// Réglages ▸ Général, commun (`ReglagesGeneraux`) : Ouvrir avec la session et Ma langue, puis ce qui
/// est propre à Synfus — les deux autorisations système, qui conditionnent tout le reste, et les
/// icônes —, puis Statistiques d'utilisation et Mise à jour.
struct GeneralSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var usage = UsageStore.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    private let miseAJour = MiseAJour.shared
    /// nil : la langue du système ; relue une fois, le réglage s'écrit dans le domaine de l'app.
    @State private var langue = LangueReglage.choisie?.rawValue

    var body: some View {
        ReglagesGeneraux(nomDeLApp: AppIntegrity.displayName, libelles: SettingsView.libelles,
                         langue: LangueDesReglages(langue: Binding(get: { langue }, set: choisirLangue),
                                                   langues: Langue.allCases.map { ($0.rawValue, $0.nom) },
                                                   aide: L("general.langue.aide")),
                         statistiques: StatistiquesDesReglages(partager: $prefs.partagerStatistiques,
                                                               dernierEnvoi: usage.registre.historique.dernierEnvoi,
                                                               aide: L("stats.partager.aide"),
                                                               dernierRapport: usage.registre.historique.dernierRapport,
                                                               prochainEnvoi: { usage.registre.apercuProchainEnvoi() }),
                         miseAJour: miseAJour.reglages) {
            Bloc(L("general.autorisations")) {
                PermissionRow(
                    name: L("general.accessibilite"),
                    granted: manager.accessibilityGranted,
                    help: aideAutorisation(L("general.accessibilite.aide")),
                    etat: aRedonner(manager.accessibilityGranted)
                ) { manager.requestAccessibility() }

                PermissionRow(
                    name: L("autorisation.lecture"),
                    granted: previews.authorized,
                    help: aideAutorisation(L("general.enregistrementEcran.aide")),
                    etat: aRedonner(previews.authorized)
                ) { previews.requestAuthorization() }

                if AppIntegrity.isQuarantined {
                    quarantineWarning
                }
            }

            Bloc(L("general.icones")) {
                IconesReglables()
            }
        }
    }

    private func choisirLangue(_ code: String?) {
        langue = code
        LangueReglage.choisie = code.flatMap(Langue.init(rawValue:))
    }

    /// Après une mise à jour (versions ad hoc), une autorisation manquante se redonne : la ligne le dit.
    private func aRedonner(_ accordee: Bool) -> String? {
        miseAJour.apresMiseAJour && !accordee ? L("maj.autorisations") : nil
    }

    private func aideAutorisation(_ aide: String) -> String {
        miseAJour.apresMiseAJour ? aide + "\n\n" + L("maj.autorisations.aide") : aide
    }

    /// Sans cet avertissement, l'utilisateur coche la case dans les Réglages, voit Synfus continuer à
    /// réclamer l'autorisation, et n'a aucun moyen de deviner pourquoi : l'app se lance normalement, rien
    /// n'indique qu'elle est en quarantaine.
    @ViewBuilder
    private var quarantineWarning: some View {
        Ligne(titre: L("general.quarantaine"), aide: L("general.quarantaine.aide")) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(Color.jeton(\.avertissement))
        }
        CopiableCommand(command: AppIntegrity.quarantineFix).rangee()
        CopiableCommand(command: AppIntegrity.resetCommand).rangee()
    }
}
