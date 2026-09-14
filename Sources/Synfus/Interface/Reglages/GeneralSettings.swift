import SwiftUI

/// Onglet Général : ce qui conditionne tout le reste — les deux autorisations
/// système —, puis la barre flottante, les aperçus, le système.
struct GeneralSettings: View {
    @ObservedObject private var prefs = Preferences.shared
    @ObservedObject private var manager = WindowManager.shared
    @ObservedObject private var previews = WindowPreviewService.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        Form {
            Section {
                PermissionRow(
                    name: "Accessibilité",
                    granted: manager.accessibilityGranted,
                    help: "Indispensable : c'est ce qui permet de lister les fenêtres de Dofus, "
                        + "de lire le nom du perso et d'activer un client. Sans elle, aucun perso "
                        + "n'apparaît. Réglages Système → Confidentialité et sécurité → Accessibilité."
                ) { manager.requestAccessibility() }

                PermissionRow(
                    name: "Enregistrement de l'écran",
                    granted: previews.authorized,
                    help: "Sert aux aperçus des fenêtres, à la reconnaissance des sorts et à la "
                        + "détection de combat. Autorisation distincte de l'Accessibilité ; macOS "
                        + "demande souvent de relancer Synfus après l'avoir accordée. Réglages Système "
                        + "→ Confidentialité et sécurité → Enregistrement de l'écran."
                ) { previews.requestAuthorization() }

                if AppIntegrity.isQuarantined {
                    quarantineWarning
                }
            } header: {
                SectionTitle("Autorisations")
            }

            Section {
                Toggle("Afficher la barre", isOn: Binding(
                    get: { prefs.barVisible },
                    set: { prefs.barVisible = $0; FloatingBarController.shared.apply() }
                ))
                if prefs.barVisible {
                    Toggle("Seulement quand Dofus est devant", isOn: Binding(
                        get: { prefs.barOnlyWithDofus },
                        set: { prefs.barOnlyWithDofus = $0; FloatingBarController.shared.updateVisibility() }
                    ))
                    Toggle("Numéros des emplacements", isOn: $prefs.showNumbers)
                    Toggle("Classe sous le nom", isOn: $prefs.showClasses)
                    HStack {
                        Text("Position")
                        Spacer()
                        Button("Recentrer en haut de l'écran") { FloatingBarController.shared.recenter() }
                            .font(.system(size: 11))
                    }
                }
            } header: {
                SectionTitle("Barre flottante", help: "La barre se déplace en saisissant les points à sa gauche. "
                             + "Elle ne prend jamais le clavier : c'est un overlay de jeu.")
            }

            Section {
                Toggle("Aperçu au survol d'un perso", isOn: Binding(
                    get: { prefs.showPreviewOnHover },
                    set: { value in
                        prefs.showPreviewOnHover = value
                        if value, !previews.authorized { previews.requestAuthorization() }
                    }
                ))
            } header: {
                SectionTitle("Aperçus", help: "Une vignette de la fenêtre du perso au survol de sa pastille. "
                             + "Un perso sur un autre bureau ou en plein écran ailleurs est capturable, "
                             + "mais son image peut dater : macOS ne redessine pas une fenêtre qu'il ne montre pas.")
            }

            Section {
                Picker("Icône dans la barre de menus", selection: Binding(
                    get: { prefs.menuBarIcon },
                    set: { prefs.menuBarIcon = $0; MenuBarController.shared.refreshIcon() }
                )) {
                    ForEach(MenuBarIcon.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Démarrer Synfus avec la session", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, value in LaunchAtLogin.set(value) }
                HStack {
                    Text("Version")
                    Spacer()
                    Text(AppIntegrity.displayName).font(.system(size: 11)).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                SectionTitle("Système")
            }
        }
        .formStyle(.grouped)
    }

    /// Sans cet avertissement, l'utilisateur coche la case dans les Réglages,
    /// voit Synfus continuer à réclamer l'autorisation, et n'a aucun moyen de
    /// deviner pourquoi : l'app se lance normalement, rien n'indique qu'elle est
    /// en quarantaine.
    private var quarantineWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                Text("Cette copie est en quarantaine : l'autorisation Accessibilité restera sans effet")
                    .font(.system(size: 11, weight: .semibold))
                HelpTip("Elle a été téléchargée, et macOS la marque comme non vérifiée. Tant que cette "
                        + "marque est là, cocher Synfus dans les Réglages reste sans effet. Exécute la "
                        + "première commande dans le Terminal puis relance Synfus ; la seconde réinitialise "
                        + "l'entrée si Synfus avait déjà été autorisé avant.")
            }
            CopiableCommand(command: AppIntegrity.quarantineFix)
            CopiableCommand(command: AppIntegrity.resetCommand)
        }
    }
}
