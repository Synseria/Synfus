import SwiftUI

/// Les briques communes des réglages. La règle d'interface : **un réglage par ligne, le libellé à
/// gauche, le contrôle à droite** (`Ligne`), sous le libellé une valeur ou un état en gris (`etat`),
/// toute explication en infobulle de la ligne — jamais une phrase à l'écran. Les lignes se rangent
/// dans un `Bloc` : une carte, un seul dessin pour toutes les pages. Libellés : sans deux-points ni
/// « / », un nom (« Gain minimal ») ou un infinitif (« Afficher la barre »).

/// Le bord gauche du texte d'une page.
enum MargeReglages {
    static let texte: CGFloat = 32
}

/// Une page de réglages : son titre, puis ses blocs.
struct PageReglages<Contenu: View>: View {
    let titre: String
    var valeur: String?
    @ViewBuilder let contenu: Contenu

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            EnTetePage(titre: titre, valeur: valeur)
            ScrollView {
                VStack(alignment: .leading, spacing: Jetons.Espace.six) { contenu }
                    .padding(.horizontal, MargeReglages.texte)
                    .padding(.top, Jetons.Espace.quatre)
                    .padding(.bottom, Jetons.Espace.six)
            }
            .font(Jetons.Typo.corps.police)
            .buttonStyle(.bouton(.secondaire))
        }
    }
}

/// Le titre d'une page.
struct EnTetePage: View {
    let titre: String
    /// Un compte ou un état de la page, jamais une phrase.
    var valeur: String?

    var body: some View {
        HStack(spacing: Jetons.Espace.deux) {
            Text(titre).font(Jetons.Typo.titrePage.police)
            Spacer(minLength: Jetons.Espace.trois)
            if let valeur { Text(valeur).font(Jetons.Typo.note.police).foregroundStyle(Color.jeton(\.encreSecondaire)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, MargeReglages.texte)
        .padding(.top, Jetons.Espace.six)
        .padding(.bottom, Jetons.Espace.un)
    }
}

/// Un groupe de lignes sous son titre : une carte (`carte()`), un filet entre deux lignes. Le filet que
/// chaque ligne porte sous elle, le dernier compris, est rogné au bas du cadre. `paresseux` : une longue
/// liste ne construit que les lignes qui paraissent. `entete` : le geste qui concerne tout le bloc.
struct Bloc<Contenu: View, Entete: View>: View {
    var titre: String?
    /// Le ⓘ du titre, dernier recours ; `infobulle` : le même texte au seul survol du titre.
    var aide: String?
    var infobulle: String?
    var paresseux = false
    @ViewBuilder let contenu: Contenu
    @ViewBuilder let entete: Entete

    init(_ titre: String? = nil, aide: String? = nil, infobulle: String? = nil, paresseux: Bool = false,
         @ViewBuilder contenu: () -> Contenu, @ViewBuilder entete: () -> Entete) {
        self.titre = titre
        self.aide = aide
        self.infobulle = infobulle
        self.paresseux = paresseux
        self.contenu = contenu()
        self.entete = entete()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.Espace.deux) {
            if let titre {
                HStack(spacing: Jetons.Espace.deux) {
                    SectionTitle(titre, help: aide).infobulleSiPresente(infobulle)
                    Spacer(minLength: Jetons.Espace.trois)
                    entete
                }
                .font(Jetons.Typo.corpsFort.police)
                .padding(.horizontal, Jetons.Espace.trois)
            }
            lignes
                .padding(.bottom, -Jetons.Trait.filet)
                .clipShape(RoundedRectangle(cornerRadius: Jetons.Rayon.carte, style: .continuous))
                .carte()
        }
    }

    @ViewBuilder
    private var lignes: some View {
        if paresseux {
            LazyVStack(alignment: .leading, spacing: 0) { contenu }
        } else {
            VStack(alignment: .leading, spacing: 0) { contenu }
        }
    }
}

extension Bloc where Entete == EmptyView {
    init(_ titre: String? = nil, aide: String? = nil, infobulle: String? = nil, paresseux: Bool = false,
         @ViewBuilder contenu: () -> Contenu) {
        self.init(titre, aide: aide, infobulle: infobulle, paresseux: paresseux, contenu: contenu,
                  entete: { EmptyView() })
    }
}

extension View {
    /// Une ligne de bloc : retrait, hauteur d'un contrôle, filet dessous.
    func rangee() -> some View {
        VStack(spacing: 0) {
            frame(maxWidth: .infinity, minHeight: Jetons.Taille.controle, alignment: .leading)
                .padding(.horizontal, Jetons.Espace.trois)
                .padding(.vertical, Jetons.Espace.deux)
            Rectangle().fill(Color.jeton(\.filet)).frame(height: Jetons.Trait.filet)
        }
    }
}

/// Un état — vide, en attente, erreur — qui occupe le bloc entier : son mot, puis le geste qui le lève.
/// Une erreur dit « Nom indisponible » et « Réessayer », jamais sa cause.
struct EtatDeBloc: View {
    let texte: String
    var geste: String?
    var attente = false
    var action: () -> Void = {}

    var body: some View {
        VStack(spacing: Jetons.Espace.deux) {
            if attente { ProgressView().controlSize(.small) }
            Text(texte).foregroundStyle(Color.jeton(\.encreSecondaire))
            if let geste { Button(geste, action: action) }
        }
        .frame(maxWidth: .infinity, minHeight: Jetons.Taille.rangeePalette * 3)
        .padding(Jetons.Espace.quatre)
    }
}

extension EtatDeBloc {
    /// « Aucun + nom », suivi de la recherche quand il y en a une.
    static func aucun(_ nom: String, recherche: String) -> EtatDeBloc {
        EtatDeBloc(texte: recherche.isEmpty ? nom : L("commun.pourRecherche", nom, recherche))
    }
}

/// Une ligne : libellé (état) à gauche, précédé d'une icône s'il y en a une, contrôle à droite.
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
        // Le contrôle se centre sur le bloc entier du libellé (titre et état), jamais accroché à sa
        // dernière ligne : c'est ce qui tient l'alignement des lignes à état.
        HStack(alignment: .center, spacing: Jetons.Espace.trois) {
            HStack(spacing: Jetons.Espace.deux) {
                icone
                VStack(alignment: .leading, spacing: Jetons.Espace.un) {
                    HStack(spacing: Jetons.Espace.un) {
                        Text(titre)
                        if let detail { Text(detail).foregroundStyle(Color.jeton(\.encreSecondaire)).lineLimit(1) }
                    }
                    if let etat {
                        Text(etat).font(Jetons.Typo.petit.police).foregroundStyle(Color.jeton(\.encreSecondaire))
                    }
                }
            }
            Spacer(minLength: Jetons.Espace.trois)
            controle
        }
        // L'explication d'une ligne est une infobulle sur toute la ligne : jamais une phrase à l'écran.
        .infobulleSiPresente(aide, indice: true)
        .rangee()
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
    /// Le dessin de la chose réglée, dans une colonne fixe devant le libellé.
    var symbole: String?
    let isOn: Binding<Bool>

    var body: some View {
        Ligne(titre: titre, aide: aide, icone: {
            if let symbole {
                Image(systemName: symbole)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
                    .frame(width: Jetons.Taille.cibleMin)
                    .accessibilityHidden(true)
            }
        }, controle: {
            Toggle(titre, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        })
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
                .font(Jetons.Typo.note.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
        }
        .buttonStyle(.plain)
        .help(text)
        .accessibilityLabel(text)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            Text(text)
                .font(Jetons.Typo.note.police)
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
                        .font(Jetons.Typo.petit.police)
                        .foregroundStyle(Color.jeton(\.alerte))
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
    var etat: String?
    let open: () -> Void

    var body: some View {
        Ligne(titre: name, etat: etat, aide: help) {
            HStack(spacing: Jetons.Espace.deux) {
                Circle().fill(granted ? Color.jeton(\.succes) : Color.jeton(\.alerte)).frame(width: Jetons.Espace.deux, height: Jetons.Espace.deux)
                Text(granted ? L("commun.accordee") : L("commun.manquante"))
                    .foregroundStyle(granted ? Color.jeton(\.encreSecondaire) : Color.jeton(\.alerte))
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
                .font(Jetons.Typo.codeInterface.police)
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
        .background(RoundedRectangle(cornerRadius: Jetons.Rayon.pastille).fill(Color.jeton(\.creux)))
    }
}

extension View {
    /// Une infobulle vide masquerait celle qu'un appelant pose autour : sans texte, rien n'est posé.
    @ViewBuilder
    func infobulleSiPresente(_ texte: String?, indice: Bool = false) -> some View {
        if let texte {
            if indice { help(texte).accessibilityHint(texte) } else { help(texte) }
        } else {
            self
        }
    }
}
