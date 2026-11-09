import SwiftUI

/// Onglet Général : ce qui conditionne tout le reste — les deux autorisations
/// système —, puis le système (icône, démarrage, langue, version).
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
                Ligne(titre: L("general.icone")) {
                    Picker(L("general.icone"), selection: Binding(
                        get: { prefs.menuBarIcon },
                        set: { prefs.menuBarIcon = $0; MenuBarController.shared.refreshIcon() }
                    )) {
                        ForEach(MenuBarIcon.allCases) { Text($0.label).tag($0) }
                    }
                    .labelsHidden()
                    .fixedSize()
                }
                Interrupteur(titre: L("general.demarrerAvecSession"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                languageRow
                Ligne(titre: L("general.version"), etat: etatMiseAJour) {
                    HStack(spacing: 8) {
                        Text(AppIntegrity.displayName).foregroundStyle(.secondary).textSelection(.enabled)
                        actionMiseAJour
                    }
                }
                Interrupteur(titre: L("maj.verifier"), aide: L("maj.verifier.aide"), isOn: $prefs.verifierMisesAJour)
            } header: {
                SectionTitle(L("general.systeme"))
            }
        }
    }

    private var etatMiseAJour: String? {
        switch miseAJour.etat {
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

    @ViewBuilder private var actionMiseAJour: some View {
        switch miseAJour.etat {
        case .verification, .installation:
            ProgressView().controlSize(.small)
        case .disponible:
            Button(L("maj.installer")) { miseAJour.proposer() }
        case .echec(.ecriture, let version):
            Button(L("maj.telecharger")) { NSWorkspace.shared.open(version.page) }
        case .echec:
            Button(L("maj.reessayer")) { miseAJour.proposer() }
        case .inconnu, .aJour:
            if prefs.verifierMisesAJour { Button(L("maj.rechercher")) { miseAJour.verifier() } }
        }
    }

    /// La langue de l'interface. La table est chargée au lancement : le choix
    /// ne prend effet qu'en relançant, et le bouton n'apparaît que si le
    /// prochain lancement parlerait une autre langue que celui-ci.
    private var languageRow: some View {
        Ligne(titre: L("general.langue"), aide: L("general.langue.aide")) {
            HStack(spacing: 8) {
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(Couleurs.alerte)
                Text(L("general.quarantaine"))
                    .font(.synfus(.petit, gras: true))
                HelpTip(L("general.quarantaine.aide"))
            }
            CopiableCommand(command: AppIntegrity.quarantineFix)
            CopiableCommand(command: AppIntegrity.resetCommand)
        }
    }
}
