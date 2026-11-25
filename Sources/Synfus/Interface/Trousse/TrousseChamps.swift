// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 0bdf7022746769dd · contenu 17aba7ad5030c6d1
import SwiftUI

// Les champs de la trousse : le cadre (`.f`), le champ à suggestions, le sélecteur en liste et leur
// hôte, l'enregistreur de raccourci.

// MARK: - Les suggestions

/// Une proposition d'un champ à suggestions ou d'un sélecteur : la valeur retenue, ce qui s'en lit,
/// son groupe — la liste range les propositions d'un même groupe ensemble, sous son titre — et son
/// symbole (SF Symbol), montré devant le libellé.
struct Proposition<Valeur: Hashable>: Hashable {
    var valeur: Valeur
    var libelle: String
    var groupe: String?
    var symbole: String?
}

extension Proposition: Sendable where Valeur: Sendable {}

/// Le filtrage, le parcours et la place de la liste : des fonctions pures, la seule source de ce
/// que font le champ à suggestions et le sélecteur.
enum Suggestions {
    /// Une proposition gardée par le filtre, et où la saisie s'y lit (nil : rien de tapé).
    struct Trouvee<Valeur: Hashable>: Hashable {
        let proposition: Proposition<Valeur>
        let plage: Range<String.Index>?
    }

    /// Sans casse ni accents : « eleve » trouve « Élevé ».
    static let pliage: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]

    /// Les propositions dont le libellé contient la saisie, groupe par groupe (dans l'ordre où ils
    /// paraissent, chacun d'un seul tenant ; un groupe que le filtre vide disparaît) ; dans un
    /// groupe, celles qui commencent par la saisie passent devant, chaque part dans son ordre.
    /// Rien de tapé : toutes, groupées.
    static func filtrer<Valeur>(_ propositions: [Proposition<Valeur>], par saisie: String) -> [Trouvee<Valeur>] {
        let cherche = saisie.trimmingCharacters(in: .whitespaces)
        var groupes: [String?] = []
        var parGroupe: [String?: [Proposition<Valeur>]] = [:]
        for proposition in propositions {
            if parGroupe[proposition.groupe] == nil { groupes.append(proposition.groupe) }
            parGroupe[proposition.groupe, default: []].append(proposition)
        }
        return groupes.flatMap { groupe -> [Trouvee<Valeur>] in
            let membres = parGroupe[groupe] ?? []
            guard !cherche.isEmpty else { return membres.map { Trouvee(proposition: $0, plage: nil) } }
            let trouvees = membres.compactMap { proposition in
                proposition.libelle.range(of: cherche, options: pliage).map { Trouvee(proposition: proposition, plage: $0) }
            }
            let enTete = { (trouvee: Trouvee<Valeur>) in trouvee.plage?.lowerBound == trouvee.proposition.libelle.startIndex }
            return trouvees.filter(enTete) + trouvees.filter { !enTete($0) }
        }
    }

    /// La première rangée dont le libellé commence par `frappe`, sans casse ni accents.
    static func premiere<Valeur>(commencantPar frappe: String, dans trouvees: [Trouvee<Valeur>]) -> Int? {
        guard !frappe.isEmpty else { return nil }
        return trouvees.firstIndex { $0.proposition.libelle.range(of: frappe, options: pliage.union(.anchored)) != nil }
    }

    /// Le titre à poser avant la rangée `index` : celui de son groupe quand il en change.
    static func titre<Valeur>(avant index: Int, dans trouvees: [Trouvee<Valeur>]) -> String? {
        guard let groupe = trouvees[index].proposition.groupe else { return nil }
        return index == 0 || trouvees[index - 1].proposition.groupe != groupe ? groupe : nil
    }

    /// La rangée surlignée après ↓ (`pas` 1) ou ↑ (-1) : depuis rien, la première ou la dernière ;
    /// arrêtée aux bords.
    static func voisine(de index: Int?, pas: Int, parmi compte: Int) -> Int? {
        guard compte > 0 else { return nil }
        guard let index else { return pas > 0 ? 0 : compte - 1 }
        return min(max(index + pas, 0), compte - 1)
    }

    /// Où se pose la liste : sous le champ, au-dessus seulement si elle manque de place dessous et en
    /// a dessus, jamais sur lui ; calée sur son bord gauche, à la largeur de son `contenu` — jamais
    /// moins que le champ, jamais plus que `largeur-feuille` ni que la racine (à `espace-2` du bord) :
    /// un libellé ne se coupe qu'au-delà.
    static func cadreDeLaListe(sous champ: CGRect, contenu: CGFloat, hauteur: CGFloat, dans racine: CGSize) -> CGRect {
        let dessous = champ.maxY + Jetons.espace1, dessus = champ.minY - Jetons.espace1 - hauteur
        let y = dessous + hauteur > racine.height && dessus >= 0 ? dessus : dessous
        let largeur = max(champ.width, min(contenu, Jetons.largeurFeuille, racine.width - Jetons.espace2 - champ.minX))
        return CGRect(x: champ.minX, y: y, width: largeur, height: hauteur)
    }

    /// Une saisie validée (⏎ sans rangée surlignée, champ quitté) : la valeur de la proposition qui
    /// porte ce libellé, sans casse ni accents ; sinon le texte lui-même.
    static func retenue(de saisie: String, parmi propositions: [Proposition<String>]) -> String {
        let texte = saisie.trimmingCharacters(in: .whitespaces)
        return propositions.first { $0.libelle.compare(texte, options: pliage) == .orderedSame }?.valeur ?? texte
    }
}

extension Suggestions.Trouvee: Sendable where Valeur: Sendable {}

// MARK: - Le champ à suggestions

/// Ce qu'un champ à suggestions garde entre deux gestes, hors de la valeur engagée (sa liaison) :
/// le texte du champ, la liste ouverte ou non, la rangée surlignée.
struct EtatDeSaisie: Hashable, Sendable {
    var texte = ""
    var ouverte = false
    var surlignee: Int?
}

/// La conduite d'un champ à suggestions, en fonctions pures sur `EtatDeSaisie` : celle d'une
/// combobox, où toute saisie vaut (un serveur n'annonce pas tout ce qu'il sert). Le filtre n'est
/// jamais retenu, il se déduit — le texte tapé quand il n'est pas celui de la valeur engagée, sinon
/// rien : ouvrir un champ qui montre sa valeur donne toute la liste. La saisie ne s'engage qu'à la
/// validation (⏎, le champ quitté).
struct ConduiteDesSuggestions {
    let propositions: [Proposition<String>]
    /// La valeur engagée.
    let engagee: String

    /// Ce que le champ montre de `valeur` : le libellé de sa proposition, sinon le texte lui-même.
    func libelle(de valeur: String) -> String {
        propositions.first { $0.valeur == valeur }?.libelle ?? valeur
    }

    var libelleEngage: String { libelle(de: engagee) }

    /// Ce qui filtre la liste : rien tant que le texte est celui de la valeur engagée, ou vide.
    func filtre(_ etat: EtatDeSaisie) -> String {
        let texte = etat.texte.trimmingCharacters(in: .whitespaces)
        return texte == libelleEngage.trimmingCharacters(in: .whitespaces) ? "" : texte
    }

    func trouvees(_ etat: EtatDeSaisie) -> [Suggestions.Trouvee<String>] {
        Suggestions.filtrer(propositions, par: filtre(etat))
    }

    /// Une saisie en cours — la liste ouverte, ou un texte qui n'est pas celui de la valeur engagée :
    /// ⏎ et ⎋ sont au champ, pas aux boutons de la feuille (« Enregistrer » prendrait l'ancienne valeur).
    func enCours(_ etat: EtatDeSaisie) -> Bool {
        etat.ouverte || etat.texte != libelleEngage
    }

    /// Le texte du champ suit la valeur engagée, sauf pendant une saisie.
    func suivre(_ etat: inout EtatDeSaisie, focalise: Bool) {
        if !focalise { etat.texte = libelleEngage }
    }

    /// Clic, chevron : la liste, la valeur engagée cochée et montrée, rien de surligné. Au clavier
    /// (↓ ↑), la valeur engagée surlignée, sinon la première ou la dernière rangée.
    func ouvrir(_ etat: inout EtatDeSaisie, auClavier pas: Int? = nil) {
        etat.ouverte = true
        let rang = trouvees(etat).firstIndex { $0.proposition.valeur == engagee }
        etat.surlignee = pas.flatMap { pas in rang ?? Suggestions.voisine(de: nil, pas: pas, parmi: trouvees(etat).count) }
    }

    func fermer(_ etat: inout EtatDeSaisie) {
        etat.ouverte = false
        etat.surlignee = nil
    }

    /// Une frappe : la liste s'ouvre, filtrée, rien de surligné (⏎ garde le texte tapé). Le même
    /// texte (le champ qui le renvoie en prenant le focus) ne change rien.
    func taper(_ texte: String, _ etat: inout EtatDeSaisie) {
        guard texte != etat.texte else { return }
        etat.texte = texte
        etat.ouverte = true
        etat.surlignee = nil
    }

    /// ↓ (`pas` 1) ou ↑ (-1) : ouvre la liste fermée, sinon déplace le surlignage.
    func parcourir(_ pas: Int, _ etat: inout EtatDeSaisie) {
        guard etat.ouverte else { return ouvrir(&etat, auClavier: pas) }
        etat.surlignee = Suggestions.voisine(de: etat.surlignee, pas: pas, parmi: trouvees(etat).count)
    }

    /// Une rangée choisie (clic, ⏎ sur la surlignée) : sa valeur, à engager.
    func choisir(_ proposition: Proposition<String>, _ etat: inout EtatDeSaisie) -> String {
        etat.texte = proposition.libelle
        fermer(&etat)
        return proposition.valeur
    }

    /// ⏎ : la rangée surlignée, sinon la saisie validée ; nil : rien à engager.
    func entrer(_ etat: inout EtatDeSaisie) -> String? {
        let trouvees = trouvees(etat)
        if etat.ouverte, let index = etat.surlignee, trouvees.indices.contains(index) {
            return choisir(trouvees[index].proposition, &etat)
        }
        return quitter(&etat)
    }

    /// Le champ quitté : la saisie validée ; nil si elle ne change rien.
    func quitter(_ etat: inout EtatDeSaisie) -> String? {
        fermer(&etat)
        // Le texte de la valeur engagée (un champ traversé) : rien à juger, ni à réécrire.
        guard etat.texte != libelleEngage else { return nil }
        let valeur = Suggestions.retenue(de: etat.texte, parmi: propositions)
        etat.texte = libelle(de: valeur)
        return valeur == engagee ? nil : valeur
    }

    /// ⎋ : ferme la liste ; fermée, rend la dernière valeur. Faux : rien à faire, la touche passe.
    func echapper(_ etat: inout EtatDeSaisie) -> Bool {
        if etat.ouverte {
            fermer(&etat)
            return true
        }
        guard etat.texte != libelleEngage else { return false }
        etat.texte = libelleEngage
        return true
    }
}

extension View {
    /// Le cadre du champ de la trousse (`.f`) : la fenêtre, son filet, `rayon-2` ; l'encre mêlée au
    /// filet au survol, l'accent et son anneau au focus, `danger` en erreur. `compact` : de
    /// `hauteur-controle`, pour une rangée serrée ; sinon de `hauteur-rangee`. Focalisé, un clic
    /// ailleurs rend le focus (`quitteAuClicAilleurs`).
    func cadreDeChamp(focalise: Bool, erreur: Bool = false, compact: Bool = false) -> some View {
        modifier(CadreDeChamp(focalise: focalise, erreur: erreur, compact: compact))
    }
}

private struct CadreDeChamp: ViewModifier {
    let focalise: Bool
    let erreur: Bool
    let compact: Bool
    @Environment(\.isEnabled) private var actif
    @Environment(\.etatImpose) private var impose
    @Environment(\.couleursSynseria) private var c
    @State private var survoleALaSouris = false

    func body(content: Content) -> some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        // Grisé, rien ne réagit (`pointer-events:none`).
        let focus = actif && (impose?.focus ?? focalise)
        let survole = actif && (impose?.survole ?? survoleALaSouris)
        let bord = erreur ? c.danger : focus ? c.accent
            : survole ? Jetons.Octets.melange(Jetons.Octets(c.filet.hex), Jetons.Octets(c.encre.hex), Jetons.filetSurvol).rvb : c.filet
        return content
            // Le filet compte dans la largeur (`.f` : bordure, puis padding).
            .padding(.horizontal, Jetons.espace3 + Jetons.epaisseurFilet)
            .frame(height: compact ? Jetons.hauteurControle : Jetons.hauteurRangee)
            .background(c.fondFenetre.couleur, in: forme)
            .overlay { forme.strokeBorder(bord.couleur, lineWidth: Jetons.epaisseurFilet) }
            // L'anneau colle au filet (`outline-offset:0`), celui du système est retiré.
            .overlay {
                if focus {
                    forme.inset(by: -Jetons.epaisseurFocus).strokeBorder(bord.couleur, lineWidth: Jetons.epaisseurFocus)
                }
            }
            .focusEffectDisabled()
            // Le grisé d'un tout, comme `opacity` en CSS : sans groupe, chaque couche pâlit sur l'autre.
            .compositingGroup()
            .opacity(actif ? 1 : Jetons.opaciteDesactive)
            .onHover { survoleALaSouris = $0 }
            .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: bord)
            .quitteAuClicAilleurs(focalise && actif)
    }
}

/// Le champ à suggestions de la trousse (`.cbx`), une combobox : le champ (`.f`) et, sous lui, en
/// carte (`.flot.mnu`), les propositions, aussi large que leurs libellés (`cadreDeLaListe`). Toute
/// saisie vaut : la liste ne fait que proposer. Un clic, le chevron ou ↓ ouvrent la liste entière,
/// la valeur engagée cochée ; la frappe la filtre, la saisie mise en valeur ; ↑↓ parcourent, ⏎
/// choisit, ⎋ ferme ; un clic ailleurs ferme, engage et rend le focus. La conduite est celle de
/// `ConduiteDesSuggestions`. La liste s'ouvre dans l'hôte de la racine (`hoteDesSuggestions`) : une
/// carte ou une section qui rogne son contenu ne la coupe pas, et le champ garde ses dimensions.
/// Une liste fermée, où seule une option vaut : `SelecteurEnListe`.
struct ChampASuggestions: View {
    let titre: String
    @Binding var texte: String
    let propositions: [Proposition<String>]
    var invite: String?
    /// La liste attendue : le serveur n'a pas encore répondu.
    var chargement = false
    /// Ce que dit la liste vide.
    let vide: String
    var compact = false

    @State private var etat = EtatDeSaisie()
    /// Le dernier clic dans le champ vient d'ouvrir la liste : le chevron qu'il touche ne la referme pas.
    @State private var ouverteAuClic = false
    @State private var selectionDuTexte: TextSelection?
    @FocusState private var focalise: Bool
    @Environment(\.isEnabled) private var actif
    @Environment(\.saisieImposee) private var saisieImposee
    @Environment(\.hoteDesSuggestions) private var hote
    @Environment(\.couleursSynseria) private var c

    /// Un nom à écrire ou à prendre dans la liste.
    init(_ titre: String, texte: Binding<String>, propositions: [String], invite: String? = nil, chargement: Bool = false,
         vide: String, compact: Bool = false) {
        self.init(titre, texte: texte, propositions: propositions.map { Proposition(valeur: $0, libelle: $0) }, invite: invite,
                  chargement: chargement, vide: vide, compact: compact)
    }

    /// Le même, des propositions dont le libellé n'est pas le nom (« Comme … » pour le nom vide).
    init(_ titre: String, texte: Binding<String>, propositions: [Proposition<String>], invite: String? = nil,
         chargement: Bool = false, vide: String, compact: Bool = false) {
        (self.titre, _texte, self.propositions, self.invite, self.chargement) = (titre, texte, propositions, invite, chargement)
        (self.vide, self.compact) = (vide, compact)
    }

    private var conduite: ConduiteDesSuggestions { ConduiteDesSuggestions(propositions: propositions, engagee: texte) }
    /// Ce qui se voit : une saisie imposée (une capture, la page de référence) ouvre la liste.
    private var vu: EtatDeSaisie { saisieImposee.map { EtatDeSaisie(texte: $0, ouverte: true) } ?? etat }
    private var estOuverte: Bool { actif && vu.ouverte }

    var body: some View {
        let liste = estOuverte ? AnyView(listeOuverte) : nil
        let hauteur = ListeDeSuggestions<String>.hauteur(pour: conduite.trouvees(vu))
        // Un clic ailleurs, la liste ouverte : la saisie s'engage et le champ rend le focus.
        let fermer: @MainActor () -> Void = {
            quitter()
            focalise = false
        }
        champ
            .anchorPreference(key: CleDeLaListeOuverte.self, value: .bounds) { ancre in
                hote ? liste.map { ListeOuverte(ancre: ancre, hauteur: hauteur, contenu: $0, fermer: fermer) } : nil
            }
            // Sans hôte, la liste s'ouvre sous le champ, rognée par ce qui le contient.
            .overlay(alignment: .topLeading) {
                if !hote, let liste { PoseDeLaListe(champ: nil, hauteur: hauteur) { liste } }
            }
            .zIndex(estOuverte ? 1 : 0)
            .onAppear { conduite.suivre(&etat, focalise: false) }
            .onChange(of: conduite.libelleEngage) { conduite.suivre(&etat, focalise: focalise) }
            // Au clavier, tout le texte se sélectionne : on tape par-dessus la valeur montrée.
            .onChange(of: focalise) { _, oui in
                if oui { selectionDuTexte = TextSelection(range: etat.texte.startIndex ..< etat.texte.endIndex) } else { quitter() }
            }
            // L'onglet ou la fenêtre quittés pendant une saisie : elle s'engage quand même.
            .onDisappear(perform: quitter)
            // ↑↓ laissent VoiceOver dans le champ : la rangée surlignée se dit.
            .onChange(of: etat.surlignee) { _, index in
                let trouvees = conduite.trouvees(etat)
                guard focalise, let index, trouvees.indices.contains(index) else { return }
                AccessibilityNotification.Announcement(trouvees[index].proposition.libelle).post()
            }
    }

    private var champ: some View {
        HStack(spacing: Jetons.espace2) {
            TextField(titre, text: Binding(get: { vu.texte }, set: { conduite.taper($0, &etat) }), selection: $selectionDuTexte,
                      prompt: invite.map { Text($0).foregroundStyle(c.encre3.couleur) })
                .textFieldStyle(.plain)
                // Le titre ne sert qu'à l'accessibilité : un `Form` le poserait dans le champ et
                // alignerait la saisie à droite.
                .labelsHidden()
                .multilineTextAlignment(.leading)
                .font(Jetons.typoCorps.font)
                .foregroundStyle(c.encre.couleur)
                .lineLimit(1)
                .focused($focalise)
                .onKeyPress(.downArrow) { conduite.parcourir(1, &etat); return .handled }
                .onKeyPress(.upArrow) { conduite.parcourir(-1, &etat); return .handled }
                .onKeyPress(.escape) { conduite.echapper(&etat) ? .handled : .ignored }
                .onKeyPress(.return) { entrer(); return .handled }
                .ouvreSonMenu(basculer)
            Button(action: basculer) {
                Image(systemName: "chevron.down")
                    .font(.system(size: Jetons.diametreMini))
                    .foregroundStyle(c.encre2.couleur)
                    .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .curseurDeClic(actif)
            // Le champ porte le titre et ouvre sa liste (`showMenu`) : le chevron ne se lit pas deux fois.
            .accessibilityHidden(true)
        }
        .cadreDeChamp(focalise: focalise || saisieImposee != nil, compact: compact)
        // Une valeur plus longue que le champ (un nom de modèle) se lit entière au survol.
        .help(conduite.libelleEngage)
        #if os(macOS)
        .background(PriseDeLaListe(touches: actif && focalise && conduite.enCours(etat), ouverte: estOuverte,
                                   clic: cliquer, ailleurs: quitter, replier: { conduite.fermer(&etat) },
                                   touche: PriseDeLaListe.rendreAuChamp))
        #else
        .simultaneousGesture(TapGesture().onEnded(cliquer))
        #endif
    }

    private var listeOuverte: some View {
        ListeDeSuggestions(trouvees: conduite.trouvees(vu), propositions: propositions, choisie: texte, surlignee: vu.surlignee,
                           chargement: chargement, vide: vide, surligner: { etat.surlignee = $0 }, choisir: choisir)
    }

    /// Un clic dans le champ (le texte ou le chevron) : la liste fermée s'ouvre.
    private func cliquer() {
        ouverteAuClic = actif && !etat.ouverte
        if ouverteAuClic { conduite.ouvrir(&etat) }
    }

    private func basculer() {
        defer { ouverteAuClic = false }
        focalise = true
        guard !ouverteAuClic else { return }
        if etat.ouverte { conduite.fermer(&etat) } else { conduite.ouvrir(&etat) }
    }

    private func choisir(_ proposition: Proposition<String>) {
        engager(conduite.choisir(proposition, &etat))
    }

    private func entrer() { engager(conduite.entrer(&etat)) }

    private func quitter() { engager(conduite.quitter(&etat)) }

    private func engager(_ retenue: String?) {
        if let retenue, retenue != texte { texte = retenue }
    }
}

private extension View {
    /// VoiceOver ouvre la liste par l'action « Afficher le menu » du champ (macOS seulement).
    func ouvreSonMenu(_ ouvrir: @escaping () -> Void) -> some View {
        #if os(macOS)
        accessibilityAction(.showMenu, ouvrir)
        #else
        self
        #endif
    }
}

// MARK: - Le sélecteur en liste

/// Ce qu'un sélecteur garde entre deux gestes : la liste ouverte ou non, la rangée surlignée, la
/// recherche (une liste de plus de huit options) et la frappe qui saute à une option (les autres),
/// avec l'instant de sa dernière touche.
struct EtatDuSelecteur: Hashable, Sendable {
    var ouverte = false
    var surlignee: Int?
    var recherche = ""
    var frappe = ""
    var derniereFrappe: TimeInterval = 0
}

/// Ce que devient une touche, le sélecteur au clavier ; nil : elle passe.
enum GesteDuSelecteur: Hashable, Sendable {
    case parcourir(Int)
    case entrer
    case espace
    case echapper
    case effacer
    /// ⇥ ou ⇧⇥, la liste ouverte : elle se ferme, le focus passe.
    case tabuler
    case taper(String)
}

/// La conduite d'un sélecteur, en fonctions pures sur `EtatDuSelecteur` : celle d'un menu
/// local du système. Seule une option se choisit — rien d'autre ne peut s'engager, il n'y a pas
/// d'état invalide. Clic, espace ou ↓ ouvrent ; ↑↓ parcourent ; ⏎ choisit, ⎋ ferme ; fermée, ⏎ et ⎋
/// passent (le bouton par défaut d'une feuille, son annulation), comme pour un menu local. La frappe
/// filtre une liste de plus de huit options, dans une recherche en tête de liste ; une liste plus
/// courte se voit entière, la frappe y saute à l'option qui commence par ses lettres.
struct ConduiteDuSelecteur<Valeur: Hashable> {
    let propositions: [Proposition<Valeur>]
    /// La valeur engagée.
    let engagee: Valeur
    /// Faux : jamais de recherche (des symboles seuls : leurs libellés ne se voient pas).
    var recherchable = true

    /// Les lettres tapées à moins d'une seconde l'une de l'autre se suivent, comme dans les menus
    /// du système ; au-delà, la frappe recommence.
    static var delaiDeFrappe: TimeInterval { 1 }

    /// La recherche, en tête de liste : au-delà des rangées visibles, sauter de lettre en lettre ne suffit plus.
    var avecRecherche: Bool { recherchable && propositions.count > ListeDeSuggestions<Valeur>.rangeesVisibles }

    var libelleEngage: String { propositions.first { $0.valeur == engagee }?.libelle ?? "" }

    func trouvees(_ etat: EtatDuSelecteur) -> [Suggestions.Trouvee<Valeur>] {
        Suggestions.filtrer(propositions, par: avecRecherche ? etat.recherche : "")
    }

    /// La liste, la valeur engagée cochée et montrée. Au clavier, la valeur engagée surlignée,
    /// sinon la première rangée ; à la souris, rien de surligné.
    func ouvrir(_ etat: inout EtatDuSelecteur, auClavier: Bool) {
        etat = EtatDuSelecteur(ouverte: true)
        let trouvees = trouvees(etat)
        etat.surlignee = auClavier ? trouvees.firstIndex { $0.proposition.valeur == engagee } ?? (trouvees.isEmpty ? nil : 0) : nil
    }

    func fermer(_ etat: inout EtatDuSelecteur) {
        etat = EtatDuSelecteur()
    }

    /// Un clic sur le sélecteur : la liste s'ouvre, ou se ferme.
    func basculer(_ etat: inout EtatDuSelecteur) {
        if etat.ouverte { fermer(&etat) } else { ouvrir(&etat, auClavier: false) }
    }

    /// ↓ (`pas` 1) ou ↑ (-1) : ouvre la liste fermée, sinon déplace le surlignage.
    func parcourir(_ pas: Int, _ etat: inout EtatDuSelecteur) {
        guard etat.ouverte else { return ouvrir(&etat, auClavier: true) }
        etat.surlignee = Suggestions.voisine(de: etat.surlignee, pas: pas, parmi: trouvees(etat).count)
    }

    /// Une frappe à l'instant `instant` (en secondes) : la liste s'ouvre au besoin ; la recherche
    /// filtre, la première trouvée surlignée ; sinon la première option qui commence par la frappe
    /// se surligne (rien ne bouge si aucune).
    func taper(_ texte: String, a instant: TimeInterval, _ etat: inout EtatDuSelecteur) {
        if !etat.ouverte { ouvrir(&etat, auClavier: true) }
        if avecRecherche {
            etat.recherche += texte
            etat.surlignee = trouvees(etat).isEmpty ? nil : 0
            return
        }
        if instant - etat.derniereFrappe > Self.delaiDeFrappe { etat.frappe = "" }
        etat.frappe += texte
        etat.derniereFrappe = instant
        if let index = Suggestions.premiere(commencantPar: etat.frappe, dans: trouvees(etat)) { etat.surlignee = index }
    }

    /// ⌫ : la recherche perd sa dernière lettre ; la frappe recommence.
    func effacer(_ etat: inout EtatDuSelecteur) {
        guard avecRecherche else { return etat.frappe = "" }
        guard !etat.recherche.isEmpty else { return }
        etat.recherche.removeLast()
        etat.surlignee = trouvees(etat).isEmpty ? nil : 0
    }

    /// Espace : ouvre la liste fermée ; au milieu d'une frappe (« Apple Intelligence »), une lettre
    /// comme une autre ; sinon choisit, comme ⏎.
    func espace(a instant: TimeInterval, _ etat: inout EtatDuSelecteur) -> Valeur? {
        guard etat.ouverte else {
            ouvrir(&etat, auClavier: true)
            return nil
        }
        let enFrappe = avecRecherche ? !etat.recherche.isEmpty : !etat.frappe.isEmpty && instant - etat.derniereFrappe <= Self.delaiDeFrappe
        guard !enFrappe else {
            taper(" ", a: instant, &etat)
            return nil
        }
        return entrer(&etat)
    }

    /// ⏎, la liste ouverte : choisit la rangée surlignée, sinon la ferme. nil : rien à engager.
    func entrer(_ etat: inout EtatDuSelecteur) -> Valeur? {
        guard etat.ouverte else { return nil }
        let trouvees = trouvees(etat)
        guard let index = etat.surlignee, trouvees.indices.contains(index) else {
            fermer(&etat)
            return nil
        }
        return choisir(trouvees[index].proposition, &etat)
    }

    /// Une rangée choisie (clic, ⏎) : sa valeur, à engager ; nil si c'est déjà elle.
    func choisir(_ proposition: Proposition<Valeur>, _ etat: inout EtatDuSelecteur) -> Valeur? {
        fermer(&etat)
        return proposition.valeur == engagee ? nil : proposition.valeur
    }

    /// ⎋ : ferme la liste. Faux : fermée, la touche passe (une feuille s'annule).
    func echapper(_ etat: inout EtatDuSelecteur) -> Bool {
        guard etat.ouverte else { return false }
        fermer(&etat)
        return true
    }

    /// Une touche, par le caractère qu'elle tape (`characters` : jamais par la position de la
    /// touche, et une touche morte — l'accent circonflexe d'un clavier AZERTY — compose sa lettre,
    /// « ê », avant d'arriver) : ↓↑, espace, une lettre ; la liste ouverte, ⏎ (du clavier ou du
    /// pavé), ⎋, ⌫ et ⇥. Les touches de fonction, une touche morte seule (rien de tapé) et celles
    /// qui portent ⌘ ⌃ ⌥ passent.
    static func geste(_ caracteres: String?, commande: Bool, ouverte: Bool) -> GesteDuSelecteur? {
        guard !commande, let caracteres, caracteres.count == 1, let scalaire = caracteres.unicodeScalars.first else { return nil }
        switch caracteres {
        case "\u{F701}": return .parcourir(1)
        case "\u{F700}": return .parcourir(-1)
        case "\r", "\u{3}": return ouverte ? .entrer : nil
        case " ": return .espace
        case "\u{1b}": return ouverte ? .echapper : nil
        case "\u{7f}": return ouverte ? .effacer : nil
        case "\t", "\u{19}": return ouverte ? .tabuler : nil
        default:
            // Les touches de fonction d'AppKit vivent dans la zone privée F700–F8FF.
            let fonction = (0xF700 ... 0xF8FF).contains(scalaire.value)
            return fonction || scalaire.properties.generalCategory == .control ? nil : .taper(caracteres)
        }
    }
}

/// Le sélecteur de la trousse : une option parmi une liste fermée, au dessin d'un champ compact
/// (`.f.cmp`, la valeur et le chevron), qui ouvre sous lui la liste du champ à suggestions (même
/// liste, même largeur, la valeur cochée). Pas de texte à saisir : rien d'invalide. Clic, espace ou
/// ↓ ouvrent ; la frappe filtre (plus de huit options, `rechercher` en invite) ou saute à une
/// option ; ⏎ choisit, ⎋ ferme, un clic dehors ou ⇥ ferment sans rien changer. La conduite est
/// celle de `ConduiteDuSelecteur`. Une option peut porter un symbole (`Proposition.symbole`), montré
/// devant son libellé ; `symbolesSeuls` : le symbole seul, le libellé ne reste qu'à VoiceOver et à
/// l'infobulle (un choix d'icône), sans recherche. Il prend la largeur qu'on lui donne
/// (`largeur-nav` × 0,9 au moins ; dans une `RangeeReglage`, celle de sa valeur) ; une valeur plus
/// longue se coupe, entière en infobulle.
struct SelecteurEnListe<Valeur: Hashable>: View {
    let titre: String
    @Binding var selection: Valeur
    let propositions: [Proposition<Valeur>]
    var chargement = false
    /// Ce que dit la liste vide.
    let vide: String
    /// L'invite de la recherche, en tête d'une liste de plus de huit options.
    var rechercher: String?
    var symbolesSeuls = false

    @State private var etat = EtatDuSelecteur()
    @FocusState private var focalise: Bool
    @Environment(\.isEnabled) private var actif
    @Environment(\.hoteDesSuggestions) private var hote
    @Environment(\.couleursSynseria) private var c

    init(_ titre: String, selection: Binding<Valeur>, propositions: [Proposition<Valeur>], chargement: Bool = false,
         vide: String, rechercher: String? = nil, symbolesSeuls: Bool = false) {
        (self.titre, _selection, self.propositions, self.chargement) = (titre, selection, propositions, chargement)
        (self.vide, self.rechercher, self.symbolesSeuls) = (vide, rechercher, symbolesSeuls)
    }

    /// Une liste d'options écrite d'avance, jamais vide : (valeur, libellé).
    init(_ titre: String, selection: Binding<Valeur>, options: [(valeur: Valeur, libelle: String)], rechercher: String? = nil) {
        self.init(titre, selection: selection, propositions: options.map { Proposition(valeur: $0.valeur, libelle: $0.libelle) },
                  vide: "", rechercher: rechercher)
    }

    private var conduite: ConduiteDuSelecteur<Valeur> {
        ConduiteDuSelecteur(propositions: propositions, engagee: selection, recherchable: !symbolesSeuls)
    }

    private var estOuverte: Bool { actif && etat.ouverte }
    private var choisie: Proposition<Valeur>? { propositions.first { $0.valeur == selection } }

    /// `.f.slc` : `largeur-nav` × 0,9 au moins, filet et air compris — `cadreDeChamp` les ajoute ; le
    /// symbole seul n'en demande pas tant.
    private var largeurMinimale: CGFloat {
        symbolesSeuls ? 0 : Jetons.largeurNav * 0.9 - 2 * (Jetons.espace3 + Jetons.epaisseurFilet)
    }

    var body: some View {
        let liste = estOuverte ? AnyView(listeOuverte) : nil
        let hauteur = ListeDeSuggestions<Valeur>.hauteur(pour: conduite.trouvees(etat), recherche: conduite.avecRecherche)
        // Un clic dehors ferme la liste sans rien changer, et rend le focus.
        let fermer: @MainActor () -> Void = {
            conduite.fermer(&etat)
            focalise = false
        }
        bouton
            .anchorPreference(key: CleDeLaListeOuverte.self, value: .bounds) { ancre in
                hote ? liste.map { ListeOuverte(ancre: ancre, hauteur: hauteur, contenu: $0, fermer: fermer) } : nil
            }
            .overlay(alignment: .topLeading) {
                if !hote, let liste { PoseDeLaListe(champ: nil, hauteur: hauteur) { liste } }
            }
            .zIndex(estOuverte ? 1 : 0)
            .onChange(of: actif) { _, oui in if !oui { conduite.fermer(&etat) } }
            // Le focus parti ailleurs (⇥, un autre contrôle) n'y laisse pas une liste ouverte.
            .onChange(of: focalise) { _, oui in if !oui { conduite.fermer(&etat) } }
            .onDisappear { conduite.fermer(&etat) }
    }

    private var bouton: some View {
        HStack(spacing: Jetons.espace2) {
            if let symbole = choisie?.symbole {
                Image(systemName: symbole)
                    .font(.system(size: Jetons.tailleIcone))
                    .foregroundStyle(c.encre.couleur)
                    .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
            }
            if !symbolesSeuls || choisie?.symbole == nil {
                Text(conduite.libelleEngage)
                    .font(Jetons.typoCorps.font)
                    .foregroundStyle(c.encre.couleur)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: Jetons.diametreMini))
                .foregroundStyle(c.encre2.couleur)
                .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
        }
        .frame(minWidth: largeurMinimale)
        .cadreDeChamp(focalise: focalise || estOuverte, compact: true)
        .contentShape(.rect)
        .focusable(interactions: .activate)
        .focused($focalise)
        .curseurDeClic(actif)
        .help(conduite.libelleEngage)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(titre)
        .accessibilityValue(conduite.libelleEngage)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { basculer() }
        .ouvreSonMenu(basculer)
        #if os(macOS)
        // La liste ouverte prend le clavier même sans focus (un clic ne le donne qu'avec la
        // navigation au clavier du système).
        .background(PriseDeLaListe(touches: actif && (focalise || estOuverte), ouverte: estOuverte,
                                   clic: basculer, ailleurs: { focalise = false }, replier: { conduite.fermer(&etat) },
                                   touche: touche))
        #else
        .onTapGesture(perform: basculer)
        #endif
    }

    private var listeOuverte: some View {
        ListeDeSuggestions(trouvees: conduite.trouvees(etat), propositions: propositions, choisie: selection,
                           surlignee: etat.surlignee, chargement: chargement, vide: vide,
                           recherche: conduite.avecRecherche ? etat.recherche : nil, rechercher: rechercher,
                           symbolesSeuls: symbolesSeuls, surligner: { etat.surlignee = $0 }, choisir: choisirALaSouris)
    }

    private func basculer() {
        guard actif else { return }
        conduite.basculer(&etat)
    }

    /// Choisie à la souris, la liste fermée ne garde pas le focus : rien ne reste allumé.
    private func choisirALaSouris(_ proposition: Proposition<Valeur>) {
        engager(conduite.choisir(proposition, &etat))
        focalise = false
    }

    private func engager(_ retenue: Valeur?) {
        if let retenue, retenue != selection { selection = retenue }
    }

    #if os(macOS)
    /// Vrai : la touche est au sélecteur, elle ne va pas plus loin. La rangée qu'elle surligne se
    /// dit (au clavier seulement : le survol de la souris ne parle pas).
    private func touche(_ evenement: NSEvent) -> Bool {
        let commande = !evenement.modifierFlags.intersection([.command, .control, .option]).isEmpty
        guard let geste = ConduiteDuSelecteur<Valeur>.geste(evenement.characters, commande: commande,
                                                             ouverte: etat.ouverte) else { return false }
        let instant = evenement.timestamp, avant = etat.surlignee
        defer { annoncer(si: avant) }
        switch geste {
        case .parcourir(let pas): conduite.parcourir(pas, &etat)
        case .entrer: engager(conduite.entrer(&etat))
        case .espace: engager(conduite.espace(a: instant, &etat))
        case .echapper: return conduite.echapper(&etat)
        case .effacer: conduite.effacer(&etat)
        case .tabuler:
            conduite.fermer(&etat)
            return false
        case .taper(let texte): conduite.taper(texte, a: instant, &etat)
        }
        return true
    }

    private func annoncer(si avant: Int?) {
        let trouvees = conduite.trouvees(etat)
        guard etat.ouverte, let index = etat.surlignee, index != avant, trouvees.indices.contains(index) else { return }
        AccessibilityNotification.Announcement(trouvees[index].proposition.libelle).post()
    }
    #endif
}

#if os(macOS)
/// Ce que le champ à suggestions ou le sélecteur prend avant sa fenêtre : les touches d'une saisie
/// en cours (`touches`) — sans cela, le bouton par défaut d'une feuille (« Enregistrer ») et celui
/// d'annulation les prennent : l'app passe ses équivalents avant le répondeur, `onKeyPress` ne vient
/// qu'après eux, et l'hôte SwiftUI traite les siens avant ses sous-vues. Un moniteur local, posé
/// tant que la saisie est en cours et pour la seule fenêtre du contrôle, donne la touche à `touche`
/// (vrai : prise). Et le clic sur le contrôle, que le texte focalisé garderait pour lui : un second
/// moniteur le voit passer sans le prendre (et, hors du contrôle, la liste fermée, appelle
/// `ailleurs`) — sauf quand la liste d'un autre contrôle de la fenêtre est ouverte : ce clic-là la
/// ferme (ou choisit une de ses rangées, posée sur ce contrôle). La fenêtre qui n'est plus la clé
/// (une autre app, une feuille, la fenêtre fermée) replie la liste. Rien n'est observé hors de l'app.
private struct PriseDeLaListe: NSViewRepresentable {
    let touches: Bool
    let ouverte: Bool
    let clic: () -> Void
    let ailleurs: () -> Void
    let replier: () -> Void
    let touche: (NSEvent) -> Bool

    /// Le champ texte : ⏎ et ⎋ (sans modificateur, par le caractère, jamais par la position de la
    /// touche) lui sont rendus, qui les traite comme une frappe.
    static func rendreAuChamp(_ evenement: NSEvent) -> Bool {
        let modificateurs = evenement.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function, .capsLock])
        guard modificateurs.isEmpty, let fenetre = evenement.window,
              ["\u{1b}", "\r", "\u{3}"].contains(evenement.charactersIgnoringModifiers) else { return false }
        fenetre.sendEvent(evenement)
        return true
    }

    /// Une liste de contrôle ouverte dans `fenetre` : un clic hors du contrôle est pour elle (la
    /// fermer, choisir une rangée), pas pour rendre le focus.
    @MainActor static func uneListeOuverte(dans fenetre: NSWindow) -> Bool {
        Vue.ouvertes.allObjects.contains { $0.window === fenetre }
    }

    func makeNSView(context _: Context) -> Vue { Vue() }

    func updateNSView(_ vue: Vue, context _: Context) {
        vue.regler(touches: touches, ouverte: ouverte, clic: clic, ailleurs: ailleurs, replier: replier, touche: touche)
    }

    static func dismantleNSView(_ vue: Vue, coordinator _: ()) { vue.retirer() }

    final class Vue: NSView {
        /// Les contrôles dont la liste est ouverte, toutes fenêtres confondues.
        static let ouvertes = NSHashTable<Vue>.weakObjects()

        private var prendLesTouches = false
        private var clic: () -> Void = {}
        private var ailleurs: () -> Void = {}
        private var replier: () -> Void = {}
        private var touche: (NSEvent) -> Bool = { _ in false }
        private var touches: Any?
        private var souris: Any?
        private weak var fenetreSuivie: NSWindow?

        override func hitTest(_: NSPoint) -> NSView? { nil }

        func regler(touches: Bool, ouverte: Bool, clic: @escaping () -> Void, ailleurs: @escaping () -> Void,
                    replier: @escaping () -> Void, touche: @escaping (NSEvent) -> Bool) {
            (prendLesTouches, self.clic, self.ailleurs, self.replier, self.touche) = (touches, clic, ailleurs, replier, touche)
            if ouverte { Self.ouvertes.add(self) } else { Self.ouvertes.remove(self) }
            poser()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window == nil ? retirer() : poser()
        }

        private func poser() {
            guard let fenetre = window else { return retirer() }
            if fenetreSuivie !== fenetre {
                NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
                NotificationCenter.default.addObserver(self, selector: #selector(fenetreQuittee),
                                                       name: NSWindow.didResignKeyNotification, object: fenetre)
                fenetreSuivie = fenetre
            }
            if souris == nil {
                souris = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] evenement in
                    MainActor.assumeIsolated { self?.voirLeClic(evenement) }
                    return evenement
                }
            }
            if prendLesTouches, touches == nil {
                touches = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] evenement in
                    MainActor.assumeIsolated { self?.prendre(evenement) ?? false } ? nil : evenement
                }
            } else if !prendLesTouches, let touches {
                NSEvent.removeMonitor(touches)
                self.touches = nil
            }
        }

        func retirer() {
            for moniteur in [touches, souris].compactMap(\.self) { NSEvent.removeMonitor(moniteur) }
            (touches, souris) = (nil, nil)
            NotificationCenter.default.removeObserver(self, name: NSWindow.didResignKeyNotification, object: nil)
            fenetreSuivie = nil
            Self.ouvertes.remove(self)
        }

        @objc private func fenetreQuittee(_: Notification) {
            if Self.ouvertes.contains(self) { replier() }
        }

        /// Un clic sur le contrôle l'ouvre. Un clic ailleurs, une saisie en cours et la liste fermée
        /// (la liste ouverte, l'hôte s'en charge) : `ailleurs` passe avant le bouton cliqué — un
        /// bouton ne prend pas le focus, « Enregistrer » aurait l'ancienne valeur.
        private func voirLeClic(_ evenement: NSEvent) {
            guard let fenetre = window, evenement.window === fenetre, estVue else { return }
            guard recoitLeClic(evenement) else {
                if prendLesTouches, !Self.ouvertes.contains(self) { ailleurs() }
                return
            }
            guard !Self.ouvertes.allObjects.contains(where: { $0 !== self && $0.window === fenetre }) else { return }
            clic()
        }

        private func prendre(_ evenement: NSEvent) -> Bool {
            guard let fenetre = window, evenement.window === fenetre else { return false }
            return touche(evenement)
        }
    }
}

extension NSView {
    /// Vue de l'utilisateur : ni cachée, ni sous un ancêtre effacé (une page gardée montée à
    /// l'opacité nulle) — un clic à sa place est pour ce qui se voit.
    fileprivate var estVue: Bool {
        !isHiddenOrHasHiddenAncestor && !sequence(first: self, next: \.superview).contains { $0.alphaValue == 0 }
    }

    /// Le clic tombe sur la part visible de la vue : celle qu'une vue qui défile a rognée (sous une
    /// barre, hors du cadre) ne le reçoit pas.
    fileprivate func recoitLeClic(_ evenement: NSEvent) -> Bool {
        visibleRect.contains(convert(evenement.locationInWindow, from: nil))
    }
}

/// Le focus rendu au clic ailleurs : un champ qui édite (son éditeur de champ, le premier répondeur)
/// cesse d'éditer quand on clique hors de lui — le fond de la fenêtre, la plaque, un bouton —, comme
/// le veut l'utilisateur, alors qu'AppKit le garderait. Le clic n'est pas pris : il va ensuite à ce
/// qu'il touche (un autre champ prend le focus lui-même). Une liste ouverte dans la fenêtre garde le
/// clic pour elle (la fermer, choisir une rangée) ; c'est elle qui rend le focus. Rien n'est observé
/// hors de l'app ; le moniteur n'est posé que pour le champ focalisé.
private struct PriseDuClicAilleurs: NSViewRepresentable {
    let actif: Bool
    /// nil : rendre le focus de l'éditeur de champ ; sinon ce que fait le contrôle (un enregistreur se désarme).
    let quitter: (() -> Void)?

    func makeNSView(context _: Context) -> Vue { Vue() }

    func updateNSView(_ vue: Vue, context _: Context) { vue.regler(actif: actif, quitter: quitter) }

    static func dismantleNSView(_ vue: Vue, coordinator _: ()) { vue.regler(actif: false, quitter: nil) }

    final class Vue: NSView {
        private var moniteur: Any?
        private var quitter: (() -> Void)?

        override func hitTest(_: NSPoint) -> NSView? { nil }

        func regler(actif: Bool, quitter: (() -> Void)?) {
            self.quitter = quitter
            if actif, moniteur == nil {
                moniteur = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] evenement in
                    MainActor.assumeIsolated { self?.voirLeClic(evenement) }
                    return evenement
                }
            } else if !actif, let moniteur {
                NSEvent.removeMonitor(moniteur)
                self.moniteur = nil
            }
        }

        private func voirLeClic(_ evenement: NSEvent) {
            guard let fenetre = window, evenement.window === fenetre, estVue, !recoitLeClic(evenement),
                  !PriseDeLaListe.uneListeOuverte(dans: fenetre) else { return }
            if let quitter { return quitter() }
            let cadre = convert(bounds, to: nil)
            Self.rendreLeFocus(dans: fenetre, cadre: cadre)
            // Une fois le clic passé, encore : SwiftUI, qui prend le clic sur son fond, rend le
            // clavier au premier champ de la fenêtre — souvent le nôtre. Le cadre est gardé, pas la
            // vue : le focus rendu la démonte (`quitteAuClicAilleurs` ne la pose que focalisée).
            Task { @MainActor [weak fenetre] in
                guard let fenetre else { return }
                Self.rendreLeFocus(dans: fenetre, cadre: cadre)
            }
        }

        /// Le champ focalisé est le nôtre (son éditeur est dans `cadre`, en coordonnées de la
        /// fenêtre) : il cesse d'éditer. Un autre champ cliqué garde le focus qu'il vient de prendre.
        private static func rendreLeFocus(dans fenetre: NSWindow, cadre: CGRect) {
            guard let editeur = fenetre.firstResponder as? NSTextView, editeur.isFieldEditor, editeur.window === fenetre,
                  cadre.intersects(editeur.convert(editeur.bounds, to: nil)) else { return }
            fenetre.makeFirstResponder(nil)
        }
    }
}
#endif

extension View {
    /// Un clic hors du contrôle, `actif` (focalisé, armé), le lui fait quitter : `quitter`, sinon
    /// l'éditeur du champ rend le focus (`PriseDuClicAilleurs`). Le cadre des champs (`cadreDeChamp`)
    /// le pose ; un champ qui dessine le sien aussi.
    @ViewBuilder func quitteAuClicAilleurs(_ actif: Bool, quitter: (() -> Void)? = nil) -> some View {
        #if os(macOS)
        // Posée seulement quand elle sert : une vue AppKit ne se dessine pas dans un `ImageRenderer`.
        background { if actif { PriseDuClicAilleurs(actif: true, quitter: quitter) } }
        #else
        self
        #endif
    }
}

/// Pose la liste dans ce qui la contient (la racine de l'hôte, sinon le champ même) : mesurée à la
/// largeur de son contenu, puis placée par `cadreDeLaListe` — la seule règle de sa place.
private struct PoseDeLaListe: Layout {
    /// Le champ dans la racine ; nil : la liste se pose dans le champ, rien ne la borne que `largeur-feuille`.
    let champ: CGRect?
    let hauteur: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard let liste = subviews.first else { return }
        let contenu = liste.sizeThatFits(ProposedViewSize(width: nil, height: hauteur)).width
        let cadre = Suggestions.cadreDeLaListe(sous: champ ?? CGRect(origin: .zero, size: bounds.size), contenu: contenu,
                                               hauteur: hauteur,
                                               dans: champ == nil ? CGSize(width: CGFloat.infinity, height: .infinity) : bounds.size)
        liste.place(at: CGPoint(x: bounds.minX + cadre.minX, y: bounds.minY + cadre.minY), proposal: ProposedViewSize(cadre.size))
    }
}

/// La liste d'un champ à suggestions ou d'un sélecteur (`.cbx .mnu`) : une carte sur la fenêtre,
/// son filet, `rayon-2` ; des rangées de menu (`.mi`) — la choisie cochée, la surlignée pleine
/// `accent`, la saisie sur le fond du choix (`mark`) ; huit rangées, puis elle défile. Vide, elle le
/// dit ; en attente du serveur, l'activité. `recherche` : ce qui filtre, en tête (`.cbx .rch`).
struct ListeDeSuggestions<Valeur: Hashable>: View {
    let trouvees: [Suggestions.Trouvee<Valeur>]
    /// Toutes les propositions : la liste prend la largeur de la plus longue, filtrée ou non — elle
    /// ne saute pas à la frappe.
    var propositions: [Proposition<Valeur>] = []
    let choisie: Valeur?
    let surlignee: Int?
    var chargement = false
    let vide: String
    /// La recherche tapée, en tête de liste ; nil : pas de recherche.
    var recherche: String?
    /// Son invite, tant que rien n'est tapé.
    var rechercher: String?
    /// Le symbole seul de chaque rangée, son libellé à VoiceOver et à l'infobulle.
    var symbolesSeuls = false
    var surligner: (Int) -> Void = { _ in }
    var choisir: (Proposition<Valeur>) -> Void = { _ in }
    @Environment(\.couleursSynseria) private var c

    /// `.cbx .mnu` : huit rangées visibles, puis elle défile.
    nonisolated static var rangeesVisibles: Int { 8 }

    /// Les rangées de la liste, un titre de groupe compté pour une.
    static func rangees(_ trouvees: [Suggestions.Trouvee<Valeur>]) -> Int {
        trouvees.count + trouvees.indices.filter { Suggestions.titre(avant: $0, dans: trouvees) != nil }.count
    }

    /// Sa hauteur, connue avant d'être posée : l'hôte place la liste sans la mesurer d'abord.
    /// La recherche ajoute sa rangée et l'air qui la sépare.
    static func hauteur(pour trouvees: [Suggestions.Trouvee<Valeur>], recherche: Bool = false) -> CGFloat {
        CGFloat(min(max(rangees(trouvees), 1), rangeesVisibles)) * Jetons.hauteurControle + 2 * Jetons.espace1
            + (recherche ? Jetons.hauteurControle + Jetons.espace1 : 0)
    }

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        return VStack(spacing: 0) {
            if let recherche {
                RangeeDeRecherche(texte: recherche, invite: rechercher)
                    .padding([.horizontal, .top], Jetons.espace1)
            }
            rangees
        }
        .background(c.fondFenetre.couleur, in: forme)
        .overlay { forme.strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
        .clipShape(forme)
    }

    private var rangees: some View {
        let rangees = Self.rangees(trouvees)
        return ScrollViewReader { lecteur in
            ScrollView {
                VStack(spacing: 0) {
                    // La largeur de la liste : chaque libellé et chaque titre, dans sa rangée, sans hauteur.
                    ZStack {
                        ForEach(Array(propositions.enumerated()), id: \.offset) { _, proposition in
                            RangeeDeSuggestion(trouvee: Suggestions.Trouvee(proposition: proposition, plage: nil), choisie: false,
                                               surlignee: false, symboleSeul: symbolesSeuls, surligner: {}, choisir: {})
                        }
                        ForEach(Array(Set(propositions.compactMap(\.groupe))), id: \.self) { TitreDeGroupe(titre: $0) }
                    }
                    .frame(height: 0)
                    .hidden()
                    .accessibilityHidden(true)
                    if trouvees.isEmpty {
                        HStack(spacing: Jetons.espace2) {
                            if chargement { RoueDActivite() } else { Text(vide).foregroundStyle(c.encre2.couleur) }
                        }
                        .font(Jetons.typoCorps.font)
                        .padding(.horizontal, Jetons.espace2)
                        .frame(maxWidth: .infinity, minHeight: Jetons.hauteurControle, alignment: .leading)
                    }
                    ForEach(Array(trouvees.enumerated()), id: \.offset) { index, trouvee in
                        if let titre = Suggestions.titre(avant: index, dans: trouvees) { TitreDeGroupe(titre: titre) }
                        RangeeDeSuggestion(trouvee: trouvee, choisie: trouvee.proposition.valeur == choisie,
                                           surlignee: index == surlignee, symboleSeul: symbolesSeuls, surligner: { surligner(index) },
                                           choisir: { choisir(trouvee.proposition) })
                            .id(index)
                    }
                }
                .padding(Jetons.espace1)
            }
            .scrollIndicators(rangees > Self.rangeesVisibles ? .automatic : .never)
            .frame(height: Self.hauteur(pour: trouvees))
            // Ouverte, la valeur engagée se montre, même au-delà de la huitième rangée.
            .onAppear {
                if let index = surlignee ?? trouvees.firstIndex(where: { $0.proposition.valeur == choisie }) {
                    lecteur.scrollTo(index, anchor: .center)
                }
            }
            .onChange(of: surlignee) { _, index in if let index { lecteur.scrollTo(index) } }
        }
    }
}

/// La recherche d'un sélecteur, en tête de sa liste (`.cbx .rch`) : la loupe, ce qui est tapé, sur
/// la plaque, `rayon-1`. La frappe va au sélecteur, qui la lui passe : rien à focaliser.
private struct RangeeDeRecherche: View {
    let texte: String
    let invite: String?
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        HStack(spacing: Jetons.espace2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Jetons.diametreMini))
                .foregroundStyle(c.encre2.couleur)
                .frame(width: Jetons.tailleIcone)
            Text(texte.isEmpty ? invite ?? "" : texte)
                .foregroundStyle((texte.isEmpty ? c.encre3 : c.encre).couleur)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(Jetons.typoCorps.font)
        .padding(.horizontal, Jetons.espace2)
        .frame(height: Jetons.hauteurControle)
        .background(c.plaque.couleur, in: .rect(cornerRadius: Jetons.rayon1, style: .circular))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(invite ?? "")
        .accessibilityValue(texte)
    }
}

/// Le titre d'un groupe de la liste (`.cbx .mg`) : en micro, à l'encre secondaire, aligné sur les
/// libellés ; ni survolé, ni choisi, ni parcouru par ↑↓.
private struct TitreDeGroupe: View {
    let titre: String
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        Text(titre)
            .font(Jetons.typoMicro.font)
            .foregroundStyle(c.encre2.couleur)
            .lineLimit(1)
            .padding(.leading, Jetons.espace2 + Jetons.tailleIcone + Jetons.espace2)
            .padding(.trailing, Jetons.espace2)
            .frame(maxWidth: .infinity, minHeight: Jetons.hauteurControle, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct RangeeDeSuggestion<Valeur: Hashable>: View {
    let trouvee: Suggestions.Trouvee<Valeur>
    let choisie: Bool
    let surlignee: Bool
    var symboleSeul = false
    let surligner: () -> Void
    let choisir: () -> Void
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        let encre = surlignee ? c.texteSurAccent : c.encre
        let symbole = trouvee.proposition.symbole
        HStack(spacing: Jetons.espace2) {
            Image(systemName: "checkmark")
                .font(.system(size: Jetons.diametreMini))
                .foregroundStyle((surlignee ? c.texteSurAccent : c.encre2).couleur)
                .frame(width: Jetons.tailleIcone)
                .opacity(choisie ? 1 : 0)
            if let symbole {
                Image(systemName: symbole)
                    .font(.system(size: Jetons.tailleIcone))
                    .foregroundStyle(encre.couleur)
                    .frame(width: Jetons.tailleIcone)
            }
            // Coupé en fin, au-delà de la borne de la liste seulement.
            if !symboleSeul || symbole == nil {
                Text(libelle)
                    .foregroundStyle(encre.couleur)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .font(Jetons.typoCorps.font)
        .padding(.horizontal, Jetons.espace2)
        .frame(height: Jetons.hauteurControle)
        .background((surlignee ? c.accent : c.accent.voile(0)).couleur, in: .rect(cornerRadius: Jetons.rayon1, style: .circular))
        .contentShape(.rect)
        .onHover { if $0 { surligner() } }
        .onTapGesture(perform: choisir)
        .curseurDeClic(true)
        .help(trouvee.proposition.libelle)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(trouvee.proposition.libelle)
        .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { choisir() }
    }

    /// La saisie sur le fond du choix (`mark`) ; sur la rangée pleine `accent`, un voile de son texte.
    private var libelle: AttributedString {
        let libelle = trouvee.proposition.libelle
        var texte = AttributedString(libelle)
        if let plage = trouvee.plage, let marque = Range(plage, in: texte) {
            texte[marque].backgroundColor = surlignee ? c.texteSurAccent.voile(Jetons.voileTouche).couleur : c.selection.couleur
        }
        return texte
    }
}

/// L'activité (`.spin`) : un anneau de l'encre en voile, un quart d'`accent` qui en fait le tour en
/// `duree-tour`, calculé depuis la date (aucune animation en boucle).

extension View {
    /// La place où s'ouvrent les listes des champs à suggestions, posée à la racine d'une fenêtre,
    /// d'une feuille ou d'un panneau, sous ses couleurs (`couleursSynseria`) : la liste passe
    /// au-dessus de tout, sous son champ, au-dessus s'il manque de place ; un clic hors du champ et
    /// d'elle la ferme. Une feuille reçoit la sienne : l'environnement la traverse, pas la liste.
    func hoteDesSuggestions() -> some View { modifier(HoteDesSuggestions()) }
}

private struct ListeOuverte {
    let ancre: Anchor<CGRect>
    let hauteur: CGFloat
    let contenu: AnyView
    let fermer: @MainActor () -> Void
}

/// Une seule liste ouverte à la fois : le clavier n'est qu'à un champ.
private struct CleDeLaListeOuverte: PreferenceKey {
    static var defaultValue: ListeOuverte? { nil }
    static func reduce(value: inout ListeOuverte?, nextValue: () -> ListeOuverte?) {
        if value == nil { value = nextValue() }
    }
}

private struct HoteDesSuggestions: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(\.hoteDesSuggestions, true)
            .overlayPreferenceValue(CleDeLaListeOuverte.self) { liste in
                if let liste {
                    GeometryReader { racine in
                        let champ = racine[liste.ancre]
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(.clear)
                                .contentShape(SaufLeChamp(champ: champ), eoFill: true)
                                .onTapGesture { liste.fermer() }
                            PoseDeLaListe(champ: champ, hauteur: liste.hauteur) { liste.contenu }
                        }
                    }
                }
            }
            // Une racine dans une autre (une rangée hébergée, une bulle) : la liste n'est montrée qu'une fois.
            .transformPreference(CleDeLaListeOuverte.self) { $0 = nil }
    }
}

/// Toute la racine sauf le champ : un clic sur le champ lui reste.
private struct SaufLeChamp: Shape {
    let champ: CGRect

    func path(in rect: CGRect) -> Path {
        var chemin = Path(rect)
        chemin.addRect(champ)
        return chemin
    }
}

#if os(macOS)
// MARK: - L'enregistreur de raccourci

/// Un champ qui enregistre une combinaison de touches (`.enr`). Un clic l'arme ; la frappe suivante
/// que `lire` accepte devient le raccourci ; ⌫ l'efface, ⎋ ou un clic ailleurs renoncent. Au repos, ses touches comme
/// partout (`ToucheDeClavier`) ; sans raccourci, un tiret. Un seul champ de l'app écoute à la fois :
/// en armer un désarme l'autre (`ParoleDuClavier`). L'app garde son type de raccourci :
/// `lire` le tire d'une frappe (nil : refusée, l'écoute continue), `touches` le dessine.
struct EnregistreurDeRaccourci<Valeur: Equatable>: View {
    @Binding var valeur: Valeur?
    let touches: (Valeur) -> [String]
    let lire: (NSEvent) -> Valeur?
    /// Ce que dit le champ armé (« Tape le raccourci »), et sans raccourci, pour VoiceOver (« Aucun »).
    let invite: String
    let aucun: String
    @State private var arme: Bool
    @Environment(\.couleursSynseria) private var c

    /// `armeAuDepart` : le champ naît à l'écoute (on arrive pour changer ce raccourci).
    init(valeur: Binding<Valeur?>, touches: @escaping (Valeur) -> [String], lire: @escaping (NSEvent) -> Valeur?,
         invite: String, aucun: String, armeAuDepart: Bool = false) {
        (_valeur, self.touches, self.lire, self.invite, self.aucun) = (valeur, touches, lire, invite, aucun)
        _arme = State(initialValue: armeAuDepart)
    }

    var body: some View {
        Button { arme.toggle() } label: {
            if !arme, let valeur {
                HStack(spacing: Jetons.espace1) {
                    ForEach(Array(touches(valeur).enumerated()), id: \.offset) { _, touche in ToucheDeClavier(touche: touche) }
                }
                .fixedSize()
                .accessibilityLabel(touches(valeur).joined())
            } else {
                let forme = RoundedRectangle(cornerRadius: Jetons.rayon1, style: .circular)
                Text(arme ? invite : "—")
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(c.encre2.couleur)
                    .padding(.horizontal, Jetons.espace2)
                    .frame(minWidth: Jetons.largeurNav * 0.4, minHeight: Jetons.diametreRond)
                    .background(c.plaque.couleur, in: forme)
                    .overlay { forme.strokeBorder((arme ? c.accent : c.filet).couleur, lineWidth: Jetons.epaisseurFilet) }
                    .accessibilityLabel(arme ? invite : aucun)
            }
        }
        .buttonStyle(.plain)
        .contentShape(.rect)
        .curseurDeClic(true)
        .background(EcouteDuClavier(arme: $arme, lire: lire) { valeur = $0 })
        // Un clic ailleurs renonce, comme ⎋.
        .quitteAuClicAilleurs(arme) { arme = false }
    }
}

/// Le moniteur local de frappe, vivant tant que le champ est armé : il ne voit que les touches de
/// l'app, et ne mord que pour son champ vu (sa fenêtre clé, ni caché ni effacé) — sinon il se
/// désarme et laisse passer la touche. Démonté armé, il se retire : il avalait toutes les frappes.
struct EcouteDuClavier<Valeur>: NSViewRepresentable {
    @Binding var arme: Bool
    let lire: (NSEvent) -> Valeur?
    let capturer: (Valeur?) -> Void

    func makeNSView(context _: Context) -> NSView { NSView() }

    func updateNSView(_ vue: NSView, context: Context) {
        context.coordinator.regler(arme: arme, vue: vue, lire: lire, capturer: { capturer($0); arme = false }) { arme = false }
    }

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    static func dismantleNSView(_: NSView, coordinator: Coordinateur) { coordinator.arreter() }

    /// Ce que devient une frappe reçue armé.
    enum Issue: Equatable {
        /// Le champ n'est pas vu : il se désarme, la touche suit son chemin.
        case ailleurs
        /// ⎋ : le champ renonce, la touche s'arrête là.
        case renoncer
        /// ⌫ ou ⌦ : le raccourci s'efface.
        case effacer
        /// Le reste : `lire` dit si c'est un raccourci.
        case lire
    }

    /// Par le caractère, jamais par la position de la touche : ⎋ et ⌫ se lisent sur toute disposition.
    static func issue(vu: Bool, modificateurs: NSEvent.ModifierFlags, caracteres: String?) -> Issue {
        guard vu else { return .ailleurs }
        let nus = modificateurs.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function, .capsLock]).isEmpty
        switch (nus, caracteres) {
        case (true, "\u{1b}"): return .renoncer
        case (true, "\u{7f}"), (true, "\u{f728}"): return .effacer
        default: return .lire
        }
    }

    @MainActor
    final class Coordinateur {
        private var moniteur: Any?
        private weak var vue: NSView?
        private var lire: (NSEvent) -> Valeur? = { _ in nil }
        private var capturer: (Valeur?) -> Void = { _ in }
        private var renoncer: () -> Void = {}
        /// Un autre champ a pris le clavier pendant que celui-ci restait armé : il ne le reprend
        /// pas avant d'avoir été désarmé, même si sa liaison n'a pas encore suivi.
        private var paroleRendue = false

        /// Vrai tant que le moniteur est posé.
        var ecoute: Bool { moniteur != nil }

        func regler(arme: Bool, vue: NSView, lire: @escaping (NSEvent) -> Valeur?,
                    capturer: @escaping (Valeur?) -> Void, renoncer: @escaping () -> Void) {
            (self.vue, self.lire, self.capturer, self.renoncer) = (vue, lire, capturer, renoncer)
            guard arme else {
                paroleRendue = false
                return arreter()
            }
            guard moniteur == nil, !paroleRendue else { return }
            ParoleDuClavier.partagee.prendre(self) { [weak self] in self?.rendreLaParole() }
            moniteur = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] evenement in
                MainActor.assumeIsolated { self?.avaler(evenement) ?? false } ? nil : evenement
            }
        }

        /// Vrai : la frappe est pour le champ, elle ne va pas plus loin.
        func avaler(_ evenement: NSEvent) -> Bool {
            // Une page gardée montée mais effacée (un ancêtre à l'opacité nulle) ne se voit pas non plus.
            let vu = vue.map { vue in
                guard let fenetre = vue.window else { return false }
                return evenement.window === fenetre && fenetre.isKeyWindow && !vue.isHiddenOrHasHiddenAncestor
                    && !sequence(first: vue, next: \.superview).contains { $0.alphaValue == 0 }
            } ?? false
            switch Self.issueDe(evenement, vu: vu) {
            case .ailleurs:
                renoncer()
                return false
            case .renoncer: renoncer()
            case .effacer: capturer(nil)
            case .lire: if let valeur = lire(evenement) { capturer(valeur) }
            }
            return true
        }

        private static func issueDe(_ evenement: NSEvent, vu: Bool) -> Issue {
            EcouteDuClavier.issue(vu: vu, modificateurs: evenement.modifierFlags,
                                  caracteres: vu ? evenement.charactersIgnoringModifiers : nil)
        }

        func arreter() {
            ParoleDuClavier.partagee.lacher(self)
            guard let moniteur else { return }
            NSEvent.removeMonitor(moniteur)
            self.moniteur = nil
        }

        /// Un autre champ s'arme : le moniteur part tout de suite, la liaison suit après la mise à
        /// jour en cours (l'écrire pendant celle de l'autre champ est interdit).
        private func rendreLaParole() {
            paroleRendue = true
            arreter()
            let renoncer = renoncer
            Task { @MainActor in renoncer() }
        }
    }
}

/// Qui écoute le clavier pour un raccourci : un seul champ de l'app à la fois. S'armer retire la
/// parole à celui qui l'avait, sinon la frappe suivante irait aux deux et le premier resterait
/// armé pour toujours.
@MainActor
final class ParoleDuClavier {
    static let partagee = ParoleDuClavier()
    private(set) weak var titulaire: AnyObject?
    private var rendre: (() -> Void)?

    func prendre(_ qui: AnyObject, rendre: @escaping () -> Void) {
        if titulaire !== qui, let ancien = self.rendre {
            self.rendre = nil
            ancien()
        }
        (titulaire, self.rendre) = (qui, rendre)
    }

    /// Ne rend la parole que si `qui` l'a : un champ qui disparaît ne coupe pas l'écoute d'un autre.
    func lacher(_ qui: AnyObject) {
        guard titulaire === qui else { return }
        (titulaire, rendre) = (nil, nil)
    }
}
#endif
