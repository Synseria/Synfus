import SwiftUI

/// Onglet Général : ce qui conditionne tout le reste — les deux autorisations
/// système —, puis la barre flottante, les aperçus, le système.
struct GeneralSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    /// `""` = suivre le système, sinon le code de la langue imposée.
    @State private var langue = LangueReglage.choisie?.rawValue ?? ""

    var body: some View {
        Form {
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

                if AppIntegrity.isQuarantined {
                    quarantineWarning
                }
            } header: {
                SectionTitle(L("general.autorisations"))
            }

            Section {
                Toggle(L("general.barre.afficher"), isOn: Binding(
                    get: { prefs.barVisible },
                    set: { prefs.barVisible = $0; FloatingBarController.shared.apply() }
                ))
                if prefs.barVisible {
                    Toggle(L("general.barre.seulementDofus"), isOn: Binding(
                        get: { prefs.barOnlyWithDofus },
                        set: { prefs.barOnlyWithDofus = $0; FloatingBarController.shared.updateVisibility() }
                    ))
                    Toggle(L("general.barre.numeros"), isOn: $prefs.showNumbers)
                    Toggle(L("general.barre.classes"), isOn: $prefs.showClasses)
                    HStack {
                        Text(L("general.barre.position"))
                        Spacer()
                        Button(L("general.barre.recentrer")) { FloatingBarController.shared.recenter() }
                            .font(.system(size: 11))
                    }
                }
            } header: {
                SectionTitle(L("general.barre"), help: L("general.barre.aide"))
            }

            Section {
                Toggle(L("general.apercus.survol"), isOn: Binding(
                    get: { prefs.showPreviewOnHover },
                    set: { value in
                        prefs.showPreviewOnHover = value
                        if value, !previews.authorized { previews.requestAuthorization() }
                    }
                ))
            } header: {
                SectionTitle(L("general.apercus"), help: L("general.apercus.aide"))
            }

            Section {
                Picker(L("general.icone"), selection: Binding(
                    get: { prefs.menuBarIcon },
                    set: { prefs.menuBarIcon = $0; MenuBarController.shared.refreshIcon() }
                )) {
                    ForEach(MenuBarIcon.allCases) { Text($0.label).tag($0) }
                }
                Toggle(L("general.demarrerAvecSession"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                languageRow
                HStack {
                    Text(L("general.version"))
                    Spacer()
                    Text(AppIntegrity.displayName).font(.system(size: 11)).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                SectionTitle(L("general.systeme"))
            }
        }
        .formStyle(.grouped)
    }

    /// La langue de l'interface. La table est chargée au lancement : le choix
    /// ne prend effet qu'en relançant, et le bouton n'apparaît que si le
    /// prochain lancement parlerait une autre langue que celui-ci.
    private var languageRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Picker(L("general.langue"), selection: $langue) {
                    Text(L("general.langue.systeme")).tag("")
                    ForEach(Langue.allCases) { Text($0.nom).tag($0.rawValue) }
                }
                .onChange(of: langue) { _, value in LangueReglage.choisie = Langue(rawValue: value) }
                HelpTip(L("general.langue.aide"))
            }
            if LangueReglage.auProchainLancement != L10n.courante.langue {
                HStack {
                    Spacer()
                    Button(L("general.langue.relancer")) { LangueReglage.relancer() }
                        .font(.system(size: 11))
                }
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
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text(L("general.quarantaine"))
                    .font(.system(size: 11, weight: .semibold))
                HelpTip(L("general.quarantaine.aide"))
            }
            CopiableCommand(command: AppIntegrity.quarantineFix)
            CopiableCommand(command: AppIntegrity.resetCommand)
        }
    }
}
