import SwiftUI

/// Les briques communes des réglages. La règle d'interface : **un réglage
/// par ligne, le libellé à gauche, le contrôle à droite** (`Ligne`), une
/// précision d'une ligne en gris sous le libellé, l'explication longue
/// derrière un ⓘ — jamais entre deux boutons. Libellés : sans deux-points ni
/// « / », un nom (« Gain minimal ») ou un infinitif (« Afficher la barre »).

/// Une page de réglages : son titre, une phrase, puis ses groupes.
struct PageReglages<Contenu: View>: View {
    let titre: String
    let sousTitre: String
    /// L'explication longue, derrière le ⓘ du titre.
    var aide: String?
    @ViewBuilder let contenu: Contenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EnTetePage(titre: titre, sousTitre: sousTitre, aide: aide)
            Form { contenu }
                .formStyle(.grouped)
        }
    }
}

/// Le titre d'une page, pour celles qui ne sont pas un formulaire.
struct EnTetePage: View {
    let titre: String
    let sousTitre: String
    var aide: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text(titre).font(.system(size: 20, weight: .bold))
                if let aide { HelpTip(aide) }
            }
            Text(sousTitre).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 28)
        .padding(.top, 22)
        .padding(.bottom, 4)
    }
}

/// Une ligne : libellé (ⓘ, précision) à gauche, contrôle à droite.
struct Ligne<Controle: View>: View {
    let titre: String
    var detail: String?
    var sousTexte: String?
    var aide: String?
    @ViewBuilder let controle: Controle

    var body: some View {
        LabeledContent {
            controle
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(titre)
                    if let detail { Text(detail).foregroundStyle(.secondary).lineLimit(1) }
                    if let aide { HelpTip(aide) }
                }
                if let sousTexte {
                    Text(sousTexte).font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Un interrupteur sur la grille des lignes.
struct Interrupteur: View {
    let titre: String
    var sousTexte: String?
    var aide: String?
    let isOn: Binding<Bool>

    var body: some View {
        Ligne(titre: titre, sousTexte: sousTexte, aide: aide) {
            Toggle(titre, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

/// Un avertissement d'une ligne, et le geste qui le lève.
struct Avertissement: View {
    let texte: String
    var bouton: String?
    var action: () -> Void = {}

    var body: some View {
        Ligne(titre: texte) {
            if let bouton { Button(bouton, action: action) }
        }
        .foregroundStyle(.orange)
    }
}

/// Le ⓘ : une bulle d'aide, au clic.
struct HelpTip: View {
    let text: String
    @State private var showing = false

    init(_ text: String) { self.text = text }

    var body: some View {
        Button { showing.toggle() } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(text)
                .font(.system(size: 12))
                .padding(12)
                .frame(width: 300, alignment: .leading)
        }
    }
}

/// En-tête de section avec son ⓘ.
struct SectionTitle: View {
    let title: String
    let help: String?

    init(_ title: String, help: String? = nil) {
        self.title = title
        self.help = help
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            if let help { HelpTip(help) }
        }
    }
}

/// Une ligne « libellé — enregistreur de raccourci ».
struct ShortcutRow: View {
    let label: String
    var detail: String? = nil
    var help: String? = nil
    var allowsBareKeys = false
    /// Cette combinaison est donnée à un autre geste : le système n'en
    /// enregistre qu'une, et rien ne le disait ligne par ligne.
    var conflit = false
    let hotKey: Binding<HotKey?>

    var body: some View {
        Ligne(titre: label, detail: detail, aide: help) {
            HStack(spacing: 6) {
                if conflit {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.orange)
                        .help(L("raccourcis.conflit"))
                }
                ShortcutRecorder(hotKey: hotKey, allowsBareKeys: allowsBareKeys)
            }
        }
    }
}

/// Un raccourci de `Preferences`, sur la grille : il signale lui-même un
/// doublon avec n'importe quel autre raccourci et réenregistre à chaque
/// changement — le seul chemin pour en régler un.
struct RaccourciReglable: View {
    let label: String
    var detail: String?
    var help: String?
    let chemin: ReferenceWritableKeyPath<Preferences, HotKey?>
    /// Après l'enregistrement (demander une autorisation…).
    var apres: (HotKey?) -> Void = { _ in }
    @ObservedObject private var prefs = Preferences.shared

    var body: some View {
        let valeur = prefs[keyPath: chemin]
        ShortcutRow(label: label, detail: detail, help: help,
                    conflit: valeur.map(HotKeyConflicts.doublons(prefs.raccourcisGlobaux).contains) ?? false,
                    hotKey: Binding(get: { prefs[keyPath: chemin] }, set: { nouvelle in
                        prefs[keyPath: chemin] = nouvelle
                        HotKeyManager.shared.rebind()
                        apres(nouvelle)
                    }))
    }
}

/// Le champ de recherche en tête d'un onglet de données.
struct ChampFiltre: View {
    let invite: String
    @Binding var texte: String

    var body: some View {
        TextField(invite, text: $texte, prompt: Text(invite))
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
    }
}

/// Une autorisation système : son état, et le bouton qui ouvre le bon panneau.
struct PermissionRow: View {
    let name: String
    let granted: Bool
    let help: String
    let open: () -> Void

    var body: some View {
        Ligne(titre: name, aide: help) {
            HStack(spacing: 8) {
                Circle().fill(granted ? Color.green : Color.orange).frame(width: 8, height: 8)
                Text(granted ? L("commun.accordee") : L("commun.manquante"))
                    .foregroundStyle(granted ? Color.secondary : Color.orange)
                if !granted { Button(L("commun.ouvrirReglagesSysteme"), action: open) }
            }
        }
    }
}

/// Commande sélectionnable et copiable d'un clic — la recopier à la main
/// depuis une capture d'écran est le meilleur moyen de se tromper.
struct CopiableCommand: View {
    let command: String

    var body: some View {
        HStack(spacing: 6) {
            Text(command)
                .font(.system(size: 10, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Button {
                PressePapiers.copier(command)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help(L("commun.copierCommande"))
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
    }
}
