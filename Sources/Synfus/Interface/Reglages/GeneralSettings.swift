import SwiftUI

/// Onglet Général : ce qui conditionne tout le reste — les deux autorisations
/// système —, puis le système (démarrage, langue, version).
struct GeneralSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @ObservedObject private var miseAJour = MiseAJour.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    /// `""` = suivre le système, sinon le code de la langue imposée.
    @State private var langue = LangueReglage.choisie?.rawValue ?? ""

    var body: some View {
        PageReglages(titre: L("reglages.general")) {
            Section {
                PermissionRow(
                    name: L("general.accessibilite"),
                    granted: manager.accessibilityGranted,
                    help: L("general.accessibilite.aide")
                ) { manager.requestAccessibility() }

                PermissionRow(
                    name: L("general.enregistrementEcran"),
                    granted: previews.authorized,
                    help: L("general.enregistrementEcran.aide")
                ) { previews.requestAuthorization() }

                if miseAJour.apresMiseAJour, !manager.accessibilityGranted || !previews.authorized {
                    Avertissement(texte: L("maj.autorisations", AppIntegrity.version ?? ""),
                                  aide: L("maj.autorisations.aide"))
                }

                if AppIntegrity.isQuarantined {
                    quarantineWarning
                }
            } header: {
                SectionTitle(L("general.autorisations"))
            }

            Section {
                Interrupteur(titre: L("general.demarrerAvecSession"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                languageRow
                Ligne(titre: L("general.version"), etat: miseAJour.etat.libelle) {
                    HStack(spacing: Jetons.Espace.deux) {
                        Text(AppIntegrity.displayName).foregroundStyle(Couleurs.encreSecondaire).textSelection(.enabled)
                        ActionMiseAJour()
                    }
                }
                Interrupteur(titre: L("maj.verifier"), aide: L("maj.verifier.aide"), isOn: $prefs.verifierMisesAJour)
            } header: {
                SectionTitle(L("general.systeme"))
            }
        }
    }

    /// La langue de l'interface. La table est chargée au lancement : le choix
    /// ne prend effet qu'en relançant, et le bouton n'apparaît que si le
    /// prochain lancement parlerait une autre langue que celui-ci.
    private var languageRow: some View {
        Ligne(titre: L("general.langue"), aide: L("general.langue.aide")) {
            HStack(spacing: Jetons.Espace.deux) {
                if LangueReglage.auProchainLancement != L10n.courante.langue {
                    Button(L("general.langue.relancer")) { LangueReglage.relancer() }
                }
                Picker(L("general.langue"), selection: $langue) {
                    Text(L("general.langue.systeme")).tag("")
                    ForEach(Langue.allCases) { Text($0.nom).tag($0.rawValue) }
                }
                .labelsHidden()
                .fixedSize()
                .onChange(of: langue) { _, value in LangueReglage.choisie = Langue(rawValue: value) }
            }
        }
    }

    /// Sans cet avertissement, l'utilisateur coche la case dans les Réglages,
    /// voit Synfus continuer à réclamer l'autorisation, et n'a aucun moyen de
    /// deviner pourquoi : l'app se lance normalement, rien n'indique qu'elle est
    /// en quarantaine.
    private var quarantineWarning: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.un) {
            HStack(spacing: Jetons.Espace.un) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Couleurs.alerte)
                Text(L("general.quarantaine"))
                    .font(.synfus(.raccourci))
                HelpTip(L("general.quarantaine.aide"))
            }
            CopiableCommand(command: AppIntegrity.quarantineFix)
            CopiableCommand(command: AppIntegrity.resetCommand)
        }
    }
}
