import SwiftUI

/// Onglet Général : ce qui conditionne tout le reste — les deux autorisations système —, puis le
/// système (démarrage, langue), les mises à jour, les icônes et les statistiques.
struct GeneralSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var miseAJour = MiseAJour.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    /// `""` = suivre le système, sinon le code de la langue imposée.
    @State private var langue = LangueReglage.choisie?.rawValue ?? ""

    var body: some View {
        PageReglages {
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

            Bloc(L("general.systeme")) {
                LigneInterrupteur(titre: L("general.demarrerAvecSession"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                languageRow
            }

            Bloc(L("maj.titre")) {
                Ligne(titre: L("maj.versionInstallee"),
                      etat: MiseAJour.resume(version: AppIntegrity.version, etat: miseAJour.etat,
                                             verifiee: prefs.derniereVerificationMaj)) {
                    ActionMiseAJour()
                }
                LigneInterrupteur(titre: L("maj.verifier"), aide: L("maj.verifier.aide"), isOn: $prefs.verifierMisesAJour)
            }

            Bloc(L("general.icones")) {
                IconesReglables()
            }

            BlocsStatistiques()
        }
    }

    /// Après une mise à jour (versions ad hoc), une autorisation manquante se redonne : la ligne le dit.
    private func aRedonner(_ accordee: Bool) -> String? {
        miseAJour.apresMiseAJour && !accordee ? L("maj.autorisations") : nil
    }

    private func aideAutorisation(_ aide: String) -> String {
        miseAJour.apresMiseAJour ? aide + "\n\n" + L("maj.autorisations.aide") : aide
    }

    /// La langue de l'interface. La table est chargée au lancement : le choix
    /// ne prend effet qu'en relançant, et le bouton n'apparaît que si le
    /// prochain lancement parlerait une autre langue que celui-ci.
    private var languageRow: some View {
        Ligne(titre: L("general.langue"), aide: L("general.langue.aide")) {
            HStack(spacing: Jetons.espace2) {
                if LangueReglage.auProchainLancement != L10n.courante.langue {
                    Button(L("general.langue.relancer")) { LangueReglage.relancer() }
                }
                SelecteurEnListe(L("general.langue"), selection: $langue,
                                 options: [("", L("general.langue.systeme"))] + Langue.allCases.map { ($0.rawValue, $0.nom) })
                    .fixedSize()
                .onChange(of: langue) { _, value in LangueReglage.choisie = Langue(rawValue: value) }
            }
        }
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
