import SwiftUI

/// Les briques communes des réglages. La règle d'interface : **un réglage par ligne, le libellé à
/// gauche, le contrôle à droite** (`Ligne`), une valeur ou un état en méta juste avant le contrôle
/// (`etat`), toute explication en infobulle — jamais une phrase à l'écran, jamais un ⓘ. Les lignes se
/// rangent dans un `Bloc`, au dessin de `SectionCompacte` de la trousse. Libellés : sans deux-points
/// ni « / », un nom (« Gain minimal ») ou un infinitif (« Afficher la barre »).

/// Une page de réglages : le formulaire de la trousse (`FormulaireCompact`), en colonne centrée de
/// `largeur-colonne`. Pas de titre : les onglets disent où l'on est.
struct PageReglages<Contenu: View>: View {
    @ViewBuilder let contenu: Contenu

    var body: some View {
        FormulaireCompact {
            contenu
                .frame(maxWidth: Jetons.largeurColonne)
                .frame(maxWidth: .infinity)
        }
        .font(Jetons.typoCorps.font)
        .buttonStyle(BoutonBorde())
    }
}

/// Une section : son titre (l'explication en infobulle), puis une carte dont chaque ligne porte son
/// filet, le dernier rogné au bas du cadre — le dessin de `SectionCompacte`, avec ce qu'elle n'a pas :
/// `paresseux` (une longue liste ne construit que les lignes qui paraissent) et `entete` (le geste qui
/// concerne tout le bloc, au bout du titre).
struct Bloc<Contenu: View, Entete: View>: View {
    var titre: String?
    /// L'explication du bloc, en infobulle sur son titre.
    var aide: String?
    var paresseux = false
    @ViewBuilder let contenu: Contenu
    @ViewBuilder let entete: Entete

    init(_ titre: String? = nil, aide: String? = nil, paresseux: Bool = false,
         @ViewBuilder contenu: () -> Contenu, @ViewBuilder entete: () -> Entete) {
        self.titre = titre
        self.aide = aide
        self.paresseux = paresseux
        self.contenu = contenu()
        self.entete = entete()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            if let titre {
                HStack(spacing: Jetons.espace2) {
                    Text(titre)
                        .font(Jetons.typoTitreCarte.font)
                        .foregroundStyle(Color.jeton(\.encre2))
                        .infobulleSiPresente(aide)
                    Spacer(minLength: Jetons.espace3)
                    entete
                }
                .padding(.leading, Jetons.espace1)
            }
            lignes
                .padding(.bottom, -Jetons.epaisseurFilet)
                .clipShape(RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular))
                .carte(marge: 0)
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
    init(_ titre: String? = nil, aide: String? = nil, paresseux: Bool = false, @ViewBuilder contenu: () -> Contenu) {
        self.init(titre, aide: aide, paresseux: paresseux, contenu: contenu, entete: { EmptyView() })
    }
}

extension View {
    /// Une ligne de bloc, aux mesures des rangées de `SectionCompacte` : `hauteur-rangee` − `espace-2`
    /// au moins, `espace-3` de côté, filet dessous.
    func rangee() -> some View {
        VStack(spacing: 0) {
            frame(maxWidth: .infinity, minHeight: Jetons.hauteurRangee - Jetons.espace2, alignment: .leading)
                .padding(.horizontal, Jetons.espace3)
                .padding(.vertical, Jetons.espace1)
            Rectangle().fill(Color.traitSurVerre).frame(height: Jetons.epaisseurFilet)
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
        VStack(spacing: Jetons.espace2) {
            if attente { ProgressView().controlSize(.small) }
            Text(texte).foregroundStyle(Color.jeton(\.encre2))
            if let geste { Button(geste, action: action) }
        }
        .frame(maxWidth: .infinity, minHeight: Jetons.hauteurRangee * 3)
        .padding(Jetons.espace4)
    }
}

extension EtatDeBloc {
    /// « Aucun + nom », suivi de la recherche quand il y en a une.
    static func aucun(_ nom: String, recherche: String) -> EtatDeBloc {
        EtatDeBloc(texte: recherche.isEmpty ? nom : L("commun.pourRecherche", nom, recherche))
    }
}

/// Une ligne : libellé à gauche, précédé d'une icône s'il y en a une ; l'état puis le contrôle à droite.
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
        HStack(alignment: .center, spacing: Jetons.espace3) {
            HStack(spacing: Jetons.espace2) {
                icone
                HStack(spacing: Jetons.espace1) {
                    Text(titre)
                    if let detail { Text(detail).foregroundStyle(Color.jeton(\.encre2)).lineLimit(1) }
                }
            }
            Spacer(minLength: Jetons.espace3)
            // La valeur ou l'état, en méta juste avant le contrôle : jamais une ligne sous le libellé.
            if let etat {
                Text(etat).font(Jetons.typoMeta.font).foregroundStyle(Color.jeton(\.encre2))
                    .multilineTextAlignment(.trailing)
            }
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
struct LigneInterrupteur: View {
    let titre: String
    var aide: String?
    /// Le dessin de la chose réglée, dans une colonne fixe devant le libellé.
    var symbole: String?
    let isOn: Binding<Bool>

    var body: some View {
        Ligne(titre: titre, aide: aide, icone: {
            if let symbole {
                Image(systemName: symbole)
                    .foregroundStyle(Color.jeton(\.encre2))
                    .frame(width: Jetons.hauteurCase)
                    .accessibilityHidden(true)
            }
        }, controle: {
            Toggle(titre, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.interrupteur)
        })
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
            HStack(spacing: Jetons.espace1) {
                if conflit || refuse {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(Jetons.typoMeta.font)
                        .foregroundStyle(Color.jeton(\.avertissement))
                        .help(conflit ? L("raccourcis.conflit") : L("raccourcis.refuse"))
                }
                EnregistreurDeRaccourci(valeur: hotKey, touches: \.touches, lire: { HotKey.lu($0, nues: allowsBareKeys) },
                                        invite: L("raccourci.pressez"), aucun: L("raccourci.aucun"))
                    .help(L("raccourci.enregistrer.aide"))
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
            HStack(spacing: Jetons.espace2) {
                Badge(texte: granted ? L("commun.accordee") : L("commun.manquante"), ton: granted ? .succes : .avertissement, point: true)
                if !granted { Button(L("autorisation.autoriser"), action: open) }
            }
        }
    }
}

/// Commande sélectionnable et copiable d'un clic — la recopier à la main
/// depuis une capture d'écran est le meilleur moyen de se tromper.
struct CopiableCommand: View {
    let command: String

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            Text(command)
                .font(Jetons.typoCode.font)
                .textSelection(.enabled)
                .lineLimit(2)
                .truncationMode(.middle)
            Button {
                PressePapiers.copier(command)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(BoutonTertiaire())
            .aide(L("commun.copierCommande"))
        }
        .padding(Jetons.espace1)
        .background(RoundedRectangle(cornerRadius: Jetons.rayon0).fill(Color.jeton(\.creux)))
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
