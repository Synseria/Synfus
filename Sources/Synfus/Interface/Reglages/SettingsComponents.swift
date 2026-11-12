import SwiftUI

/// Les briques communes des réglages. La règle d'interface : **un réglage
/// par ligne, le libellé à gauche, le contrôle à droite** (`Ligne`), sous le
/// libellé une valeur ou un état en gris (`etat`), toute explication derrière
/// un ⓘ — jamais une phrase à l'écran. Libellés : sans deux-points ni « / »,
/// un nom (« Gain minimal ») ou un infinitif (« Afficher la barre »).

/// Le bord gauche du texte d'une page, celui des lignes d'un `Form` groupé.
enum MargeReglages {
    static let texte: CGFloat = 32
    /// Le retrait d'une ligne dans le cadre d'une `PageListe`.
    static let ligne: CGFloat = 10
}

/// Une page de réglages : son titre, puis ses groupes.
struct PageReglages<Contenu: View>: View {
    let titre: String
    /// L'explication, derrière le ⓘ du titre.
    var aide: String?
    @ViewBuilder let contenu: Contenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EnTetePage(titre: titre, aide: aide)
            Form { contenu }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .buttonStyle(.bouton(.secondaire))
        }
    }
}

/// Le titre d'une page, pour celles qui ne sont pas un formulaire.
struct EnTetePage: View {
    let titre: String
    /// Un compte ou un état de la page, jamais une phrase.
    var valeur: String?
    var aide: String?

    var body: some View {
        HStack(spacing: Jetons.Espace.deux) {
            Text(titre).font(.synfus(.titrePage))
            if let aide { HelpTip(aide) }
            Spacer(minLength: Jetons.Espace.trois)
            if let valeur { Text(valeur).font(.synfus(.note)).foregroundStyle(Couleurs.encreSecondaire) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MargeReglages.texte)
        .padding(.top, Jetons.Espace.six)
        .padding(.bottom, Jetons.Espace.un)
    }
}

/// Une ligne : libellé (ⓘ, état) à gauche, précédé d'une icône s'il y en a
/// une, contrôle à droite.
struct Ligne<Controle: View, Icone: View>: View {
    let titre: String
    var detail: String?
    var etat: String?
    var aide: String?
    let icone: Icone
    let controle: Controle

    init(titre: String, detail: String? = nil, etat: String? = nil, aide: String? = nil,
         @ViewBuilder icone: () -> Icone, @ViewBuilder controle: () -> Controle) {
        self.titre = titre
        self.detail = detail
        self.etat = etat
        self.aide = aide
        self.icone = icone()
        self.controle = controle()
    }

    var body: some View {
        LabeledContent {
            controle
        } label: {
            HStack(spacing: Jetons.Espace.deux) {
                icone
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    HStack(spacing: Jetons.Espace.un) {
                        Text(titre)
                        if let detail { Text(detail).foregroundStyle(Couleurs.encreSecondaire).lineLimit(1) }
                        if let aide { HelpTip(aide) }
                    }
                    if let etat {
                        Text(etat).font(.synfus(.petit)).foregroundStyle(Couleurs.encreSecondaire)
                    }
                }
            }
        }
    }
}

extension Ligne where Icone == EmptyView {
    init(titre: String, detail: String? = nil, etat: String? = nil, aide: String? = nil,
         @ViewBuilder controle: () -> Controle) {
        self.init(titre: titre, detail: detail, etat: etat, aide: aide, icone: { EmptyView() }, controle: controle)
    }
}

/// Un interrupteur sur la grille des lignes.
struct Interrupteur: View {
    let titre: String
    var aide: String?
    let isOn: Binding<Bool>

    var body: some View {
        Ligne(titre: titre, aide: aide) {
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
    var aide: String?
    var bouton: String?
    var action: () -> Void = {}

    var body: some View {
        Ligne(titre: texte, aide: aide) {
            if let bouton { Button(bouton, action: action) }
        }
        .foregroundStyle(Couleurs.alerte)
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
                .font(.synfus(.note))
                .foregroundStyle(Couleurs.encreSecondaire)
        }
        .buttonStyle(.plain)
        .help(text)
        .accessibilityLabel(text)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(text)
                .font(.synfus(.note))
                .padding(Jetons.Espace.trois)
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
        HStack(spacing: Jetons.Espace.un) {
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
    /// Le système l'a refusée : une autre app la tient déjà.
    var refuse = false
    let hotKey: Binding<HotKey?>

    var body: some View {
        Ligne(titre: label, detail: detail, aide: help) {
            HStack(spacing: Jetons.Espace.un) {
                if conflit || refuse {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.synfus(.petit))
                        .foregroundStyle(Couleurs.alerte)
                        .help(conflit ? L("raccourcis.conflit") : L("raccourcis.refuse"))
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
    @ObservedObject private var hotKeys = HotKeyManager.shared

    var body: some View {
        let valeur = prefs[keyPath: chemin]
        ShortcutRow(label: label, detail: detail, help: help,
                    conflit: valeur.map(HotKeyConflicts.doublons(prefs.raccourcisGlobaux).contains) ?? false,
                    refuse: valeur.map(hotKeys.rejected.contains) ?? false,
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
            HStack(spacing: Jetons.Espace.deux) {
                Circle().fill(granted ? Couleurs.succes : Couleurs.alerte).frame(width: Jetons.Espace.deux, height: Jetons.Espace.deux)
                Text(granted ? L("commun.accordee") : L("commun.manquante"))
                    .foregroundStyle(granted ? Couleurs.encreSecondaire : Couleurs.alerte)
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
        HStack(spacing: Jetons.Espace.un) {
            Text(command)
                .font(.synfus(.codeInterface))
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Button {
                PressePapiers.copier(command)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bouton(.tertiaire, dense: true))
            .aide(L("commun.copierCommande"))
        }
        .padding(Jetons.Espace.un)
        .background(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille).fill(Couleurs.creux))
    }
}
