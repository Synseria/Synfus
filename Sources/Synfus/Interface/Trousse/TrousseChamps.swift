// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 9109fc88022f5d8a · contenu 3ea0881a9b246411
import SwiftUI

// Les champs de la trousse : le cadre (`.f`), le champ à suggestions et son hôte, le menu en champ,
// l'enregistreur de raccourci.

// MARK: - Le champ à suggestions

/// Ce que retient un champ à suggestions (`.cbx`).
enum ModeDeSuggestions: Hashable, Sendable {
    /// Toute saisie : la liste ne fait que proposer (un serveur n'annonce pas tout ce qu'il sert).
    case libre
    /// Une valeur de la liste seulement : une saisie hors liste est signalée et revient à la
    /// dernière valeur retenue.
    case impose
}

/// Une proposition d'un champ à suggestions : la valeur retenue, ce qui s'en lit, et son groupe —
/// la liste range les propositions d'un même groupe ensemble, sous son titre.
struct Proposition<Valeur: Hashable>: Hashable {
    var valeur: Valeur
    var libelle: String
    var groupe: String?
}

extension Proposition: Sendable where Valeur: Sendable {}

/// Le filtrage, le parcours et ce que retient un champ à suggestions : des fonctions pures, la
/// seule source de ce que fait le champ.
enum Suggestions {
    /// Une proposition gardée par le filtre, et où la saisie s'y lit (nil : rien de tapé).
    struct Trouvee<Valeur: Hashable>: Hashable {
        let proposition: Proposition<Valeur>
        let plage: Range<String.Index>?
    }

    /// Ce que devient une saisie validée.
    enum Issue<Valeur: Hashable>: Hashable {
        case retenue(Valeur)
        /// Hors de la liste d'un champ `impose` : la dernière valeur reste.
        case refusee
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

    /// Où la liste entière montre `valeur` : l'ordre des groupes n'est pas celui des propositions.
    static func rang<Valeur>(de valeur: Valeur, parmi propositions: [Proposition<Valeur>]) -> Int? {
        filtrer(propositions, par: "").firstIndex { $0.proposition.valeur == valeur }
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

    /// Une saisie validée (⏎ sans rangée surlignée, champ quitté) : la proposition qui porte ce
    /// libellé, sans casse ni accents ; sinon le texte lui-même si le champ est libre (`nouvelle`) ;
    /// sinon refusée.
    static func issue<Valeur>(de saisie: String, parmi propositions: [Proposition<Valeur>],
                              nouvelle: ((String) -> Valeur)?) -> Issue<Valeur> {
        let texte = saisie.trimmingCharacters(in: .whitespaces)
        if let proposition = propositions.first(where: { $0.libelle.compare(texte, options: pliage) == .orderedSame }) {
            return .retenue(proposition.valeur)
        }
        return nouvelle.map { .retenue($0(texte)) } ?? .refusee
    }
}

extension Suggestions.Trouvee: Sendable where Valeur: Sendable {}
extension Suggestions.Issue: Sendable where Valeur: Sendable {}

extension View {
    /// Le cadre du champ de la trousse (`.f`) : la fenêtre, son filet, `rayon-2` ; l'encre mêlée au
    /// filet au survol, l'accent et son anneau au focus, `danger` en erreur. `compact` : de
    /// `hauteur-controle`, pour une rangée serrée ; sinon de `hauteur-rangee`.
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
    }
}

/// Le champ à suggestions de la trousse (`.cbx`) : le champ (`.f`) et, sous lui, en carte
/// (`.flot.mnu`), les propositions filtrées au fil de la frappe, la saisie mise en valeur. ↑↓
/// parcourent, ⏎ choisit, ⎋ ferme, un clic ailleurs aussi ; le chevron ouvre la liste entière. La
/// liste s'ouvre dans l'hôte de la racine (`hoteDesSuggestions`) : une carte ou une section qui
/// rogne son contenu ne la coupe pas. `libre` écrit la saisie à chaque frappe, `impose` ne retient
/// qu'une proposition.
struct ChampASuggestions<Valeur: Hashable>: View {
    let titre: String
    @Binding var valeur: Valeur
    let propositions: [Proposition<Valeur>]
    var invite: String?
    /// La liste attendue : le serveur n'a pas encore répondu.
    var chargement = false
    /// Ce que dit la liste vide.
    let vide: String
    /// Ce que dit une saisie refusée, en infobulle (`impose`).
    var horsListe: String?
    var compact = false
    /// Le texte d'une saisie libre devenu valeur ; nil : `impose`.
    private let nouvelle: ((String) -> Valeur)?

    @State private var saisie = ""
    /// Ce qui filtre la liste : nil, la liste entière (le chevron, ↓ sur un champ fermé).
    @State private var filtre: String?
    @State private var ouverte = false
    @State private var surlignee: Int?
    @State private var refusee = false
    @State private var selectionDuTexte: TextSelection?
    @FocusState private var focalise: Bool
    @Environment(\.isEnabled) private var actif
    @Environment(\.saisieImposee) private var saisieImposee
    @Environment(\.hoteDesSuggestions) private var hote
    @Environment(\.couleursSynseria) private var c

    /// Une valeur de la liste seulement (`impose`).
    init(_ titre: String, selection: Binding<Valeur>, propositions: [Proposition<Valeur>], invite: String? = nil,
         chargement: Bool = false, vide: String, horsListe: String, compact: Bool = false) {
        (self.titre, _valeur, self.propositions, self.invite) = (titre, selection, propositions, invite)
        (self.chargement, self.vide, self.horsListe, self.compact, nouvelle) = (chargement, vide, horsListe, compact, nil)
    }

    private var mode: ModeDeSuggestions { nouvelle == nil ? .impose : .libre }
    private var libelleCourant: String {
        propositions.first { $0.valeur == valeur }?.libelle ?? (valeur as? String) ?? ""
    }
    private var estOuverte: Bool { actif && (saisieImposee != nil || ouverte) }
    private var trouvees: [Suggestions.Trouvee<Valeur>] { Suggestions.filtrer(propositions, par: saisieImposee ?? filtre ?? "") }

    var body: some View {
        let liste = estOuverte ? AnyView(listeOuverte) : nil
        let fermer: @MainActor () -> Void = { fermerLaListe() }
        champ
            .anchorPreference(key: CleDeLaListeOuverte.self, value: .bounds) { ancre in
                hote ? liste.map { ListeOuverte(ancre: ancre, contenu: $0, fermer: fermer) } : nil
            }
            // Sans hôte, la liste s'ouvre sous le champ, rognée par ce qui le contient.
            .overlay(alignment: .topLeading) {
                if !hote, let liste {
                    liste.offset(y: (compact ? Jetons.hauteurControle : Jetons.hauteurRangee) + Jetons.espace1)
                }
            }
            .zIndex(estOuverte ? 1 : 0)
            .onAppear { saisie = libelleCourant }
            .onChange(of: libelleCourant) { _, libelle in if !focalise { saisie = libelle } }
            // Au clavier, tout le texte se sélectionne : on tape par-dessus la valeur montrée.
            .onChange(of: focalise) { _, oui in
                if oui { selectionDuTexte = TextSelection(range: saisie.startIndex ..< saisie.endIndex) } else { valider() }
            }
    }

    private var champ: some View {
        HStack(spacing: Jetons.espace2) {
            TextField(titre, text: Binding(get: { saisieImposee ?? saisie }, set: taper), selection: $selectionDuTexte,
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
                .onKeyPress(.downArrow) { parcourir(1) }
                .onKeyPress(.upArrow) { parcourir(-1) }
                .onKeyPress(.escape) { echapper() }
                // ⏎ sur une rangée surlignée la choisit ; sinon la saisie se valide (`onSubmit`).
                .onKeyPress(.return) { choisirLaSurlignee() }
                .onSubmit(valider)
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
            .accessibilityLabel(titre)
        }
        .cadreDeChamp(focalise: focalise || saisieImposee != nil, erreur: refusee, compact: compact)
        .help(refusee ? horsListe ?? "" : "")
        #if os(macOS)
        .background(PriseDesTouches(echap: estOuverte && focalise, entree: estOuverte && focalise && surlignee != nil))
        #endif
    }

    private var listeOuverte: some View {
        ListeDeSuggestions(trouvees: trouvees, choisie: valeur, surlignee: surlignee, chargement: chargement, vide: vide,
                           surligner: { surlignee = $0 }, choisir: choisir)
    }

    private func taper(_ texte: String) {
        saisie = texte
        refusee = false
        filtre = texte
        ouverte = true
        if let nouvelle {
            valeur = nouvelle(texte)
            surlignee = nil
        } else {
            // Imposé, la première proposition est celle que ⏎ prendra.
            surlignee = Suggestions.filtrer(propositions, par: texte).isEmpty ? nil : 0
        }
    }

    private func parcourir(_ pas: Int) -> KeyPress.Result {
        if !estOuverte {
            filtre = nil
            ouverte = true
            surlignee = Suggestions.rang(de: valeur, parmi: propositions) ?? Suggestions.voisine(de: nil, pas: pas, parmi: propositions.count)
        } else {
            surlignee = Suggestions.voisine(de: surlignee, pas: pas, parmi: trouvees.count)
        }
        return .handled
    }

    private func choisirLaSurlignee() -> KeyPress.Result {
        guard estOuverte, let surlignee, trouvees.indices.contains(surlignee) else { return .ignored }
        choisir(trouvees[surlignee].proposition)
        return .handled
    }

    private func echapper() -> KeyPress.Result {
        if estOuverte {
            fermerLaListe()
            return .handled
        }
        guard mode == .impose, saisie != libelleCourant else { return .ignored }
        saisie = libelleCourant
        refusee = false
        return .handled
    }

    private func basculer() {
        if estOuverte { return fermerLaListe() }
        filtre = nil
        ouverte = true
        surlignee = Suggestions.rang(de: valeur, parmi: propositions)
        focalise = true
    }

    private func choisir(_ proposition: Proposition<Valeur>) {
        valeur = proposition.valeur
        saisie = proposition.libelle
        refusee = false
        fermerLaListe()
    }

    /// ⏎ sans rangée surlignée, ou le champ quitté.
    private func valider() {
        fermerLaListe()
        // Imposé, rien de changé (un champ traversé au clavier, une liste pas encore venue) : rien à
        // juger. Libre, la frappe a déjà écrit la valeur telle quelle : la validation la rogne et
        // reprend l'écriture de la liste (« QWEN3 » → « qwen3 »).
        guard saisie != libelleCourant || nouvelle != nil else { return }
        switch Suggestions.issue(de: saisie, parmi: propositions, nouvelle: nouvelle) {
        case .retenue(let retenue):
            if retenue != valeur { valeur = retenue }
            saisie = libelleCourant
        case .refusee:
            // Un champ vidé revient sans reproche ; une saisie hors liste le dit.
            refusee = !saisie.trimmingCharacters(in: .whitespaces).isEmpty
            saisie = libelleCourant
        }
    }

    private func fermerLaListe() {
        ouverte = false
        filtre = nil
        surlignee = nil
    }
}

extension ChampASuggestions where Valeur == String {
    /// Un nom à écrire ou à prendre dans la liste ; `libre` par défaut.
    init(_ titre: String, texte: Binding<String>, propositions: [String], mode: ModeDeSuggestions = .libre,
         invite: String? = nil, chargement: Bool = false, vide: String, horsListe: String? = nil, compact: Bool = false) {
        self.init(titre, texte: texte, propositions: propositions.map { Proposition(valeur: $0, libelle: $0) }, mode: mode,
                  invite: invite, chargement: chargement, vide: vide, horsListe: horsListe, compact: compact)
    }

    /// Le même, des propositions dont le libellé n'est pas le nom (« Comme … » pour le nom vide).
    init(_ titre: String, texte: Binding<String>, propositions: [Proposition<String>], mode: ModeDeSuggestions = .libre,
         invite: String? = nil, chargement: Bool = false, vide: String, horsListe: String? = nil, compact: Bool = false) {
        (self.titre, _valeur, self.propositions, self.invite, self.chargement) = (titre, texte, propositions, invite, chargement)
        (self.vide, self.horsListe, self.compact) = (vide, horsListe, compact)
        nouvelle = mode == .libre ? { $0 } : nil
    }
}

#if os(macOS)
/// ⏎ et ⎋ d'une liste ouverte vont au champ avant les équivalents clavier de sa fenêtre : sans
/// elle, le bouton par défaut d'une feuille (« Enregistrer ») et celui d'annulation les prennent —
/// l'app passe ses équivalents avant le répondeur, `onKeyPress` ne vient qu'après eux, et l'hôte
/// SwiftUI traite les siens avant ses sous-vues. Un moniteur local, posé tant que la liste est
/// ouverte et pour la seule fenêtre du champ, rend la touche au champ, qui la traite comme une
/// frappe ; rien n'est observé hors de l'app ni hors de ce moment.
private struct PriseDesTouches: NSViewRepresentable {
    let echap: Bool
    let entree: Bool

    func makeNSView(context: Context) -> Vue { Vue() }

    func updateNSView(_ vue: Vue, context: Context) {
        vue.regler(echap: echap, entree: entree)
    }

    static func dismantleNSView(_ vue: Vue, coordinator: ()) { vue.retirer() }

    final class Vue: NSView {
        private var echap = false
        private var entree = false
        private var moniteur: Any?

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        func regler(echap: Bool, entree: Bool) {
            (self.echap, self.entree) = (echap, entree)
            echap ? poser() : retirer()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if window == nil { retirer() } else if echap { poser() }
        }

        private func poser() {
            guard moniteur == nil, window != nil else { return }
            moniteur = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] evenement in
                MainActor.assumeIsolated { self?.prendre(evenement) ?? false } ? nil : evenement
            }
        }

        func retirer() {
            if let moniteur { NSEvent.removeMonitor(moniteur) }
            moniteur = nil
        }

        private func prendre(_ evenement: NSEvent) -> Bool {
            let modificateurs = evenement.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function, .capsLock])
            guard modificateurs.isEmpty, let fenetre = window, evenement.window === fenetre else { return false }
            // Par le caractère, jamais par la position de la touche : ⏎ du clavier ou du pavé, ⎋.
            let touche = evenement.charactersIgnoringModifiers
            guard (echap && touche == "\u{1b}") || (entree && (touche == "\r" || touche == "\u{3}")) else { return false }
            fenetre.sendEvent(evenement)
            return true
        }
    }
}
#endif

/// La liste d'un champ à suggestions (`.cbx .mnu`) : une carte sur la fenêtre, son filet,
/// `rayon-2` ; des rangées de menu (`.mi`) — la choisie cochée, la surlignée pleine `accent`, la
/// saisie sur le fond du choix (`mark`) ; huit rangées, puis elle défile. Vide, elle le dit ; en
/// attente du serveur, l'activité.
struct ListeDeSuggestions<Valeur: Hashable>: View {
    let trouvees: [Suggestions.Trouvee<Valeur>]
    let choisie: Valeur?
    let surlignee: Int?
    var chargement = false
    let vide: String
    var surligner: (Int) -> Void = { _ in }
    var choisir: (Proposition<Valeur>) -> Void = { _ in }
    @Environment(\.couleursSynseria) private var c

    /// `.cbx .mnu` : la largeur d'un menu au moins (`largeur-nav` × 1,2), huit rangées visibles.
    static var largeurMinimale: CGFloat { Jetons.largeurNav * 1.2 }
    static var rangeesVisibles: Int { 8 }

    var body: some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon2, style: .circular)
        // Un titre de groupe compte pour une rangée.
        let rangees = trouvees.count + trouvees.indices.filter { Suggestions.titre(avant: $0, dans: trouvees) != nil }.count
        let hauteur = CGFloat(min(max(rangees, 1), Self.rangeesVisibles)) * Jetons.hauteurControle
        return ScrollViewReader { lecteur in
            ScrollView {
                VStack(spacing: 0) {
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
                                           surlignee: index == surlignee, surligner: { surligner(index) },
                                           choisir: { choisir(trouvee.proposition) })
                            .id(index)
                    }
                }
                .padding(Jetons.espace1)
            }
            .scrollIndicators(rangees > Self.rangeesVisibles ? .automatic : .never)
            .frame(height: hauteur + 2 * Jetons.espace1)
            .onChange(of: surlignee) { _, index in if let index { lecteur.scrollTo(index) } }
        }
        .background(c.fondFenetre.couleur, in: forme)
        .overlay { forme.strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
        .clipShape(forme)
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
    let surligner: () -> Void
    let choisir: () -> Void
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        let encre = surlignee ? c.texteSurAccent : c.encre
        HStack(spacing: Jetons.espace2) {
            Image(systemName: "checkmark")
                .font(.system(size: Jetons.diametreMini))
                .foregroundStyle((surlignee ? c.texteSurAccent : c.encre2).couleur)
                .frame(width: Jetons.tailleIcone)
                .opacity(choisie ? 1 : 0)
            Text(libelle)
                .foregroundStyle(encre.couleur)
                .lineLimit(1)
                .truncationMode(.middle)
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
    @State private var tailleDeLaListe = CGSize.zero

    func body(content: Content) -> some View {
        content
            .environment(\.hoteDesSuggestions, true)
            .overlayPreferenceValue(CleDeLaListeOuverte.self) { liste in
                if let liste {
                    GeometryReader { racine in
                        let champ = racine[liste.ancre]
                        let dessous = champ.maxY + Jetons.espace1, dessus = champ.minY - Jetons.espace1 - tailleDeLaListe.height
                        ZStack(alignment: .topLeading) {
                            Rectangle().fill(.clear)
                                .contentShape(SaufLeChamp(champ: champ), eoFill: true)
                                .onTapGesture { liste.fermer() }
                            // La largeur du champ au moins, celle de la plus longue proposition sinon :
                            // rien ne s'y coupe tant que la racine la tient.
                            liste.contenu
                                .frame(minWidth: max(champ.width, ListeDeSuggestions<Int>.largeurMinimale), alignment: .leading)
                                .fixedSize(horizontal: true, vertical: false)
                                .onGeometryChange(for: CGSize.self) { $0.size } action: { tailleDeLaListe = $0 }
                                .offset(x: max(0, min(champ.minX, racine.size.width - tailleDeLaListe.width)),
                                        y: dessous + tailleDeLaListe.height > racine.size.height && dessus >= 0 ? dessus : dessous)
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
/// que `lire` accepte devient le raccourci ; ⌫ l'efface, ⎋ renonce. Au repos, ses touches comme
/// partout (`ToucheDeClavier`) ; sans raccourci, un tiret. L'app garde son type de raccourci :
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
    }
}

/// Le moniteur local de frappe, vivant tant que le champ est armé : il ne voit que les touches de
/// l'app, et ne mord que pour son champ vu (sa fenêtre clé, ni caché ni effacé) — sinon il se
/// désarme et laisse passer la touche. Démonté armé, il se retire : il avalait toutes les frappes.
private struct EcouteDuClavier<Valeur>: NSViewRepresentable {
    @Binding var arme: Bool
    let lire: (NSEvent) -> Valeur?
    let capturer: (Valeur?) -> Void

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ vue: NSView, context: Context) {
        context.coordinator.regler(arme: arme, vue: vue, lire: lire, capturer: { capturer($0); arme = false }) { arme = false }
    }

    func makeCoordinator() -> Coordinateur { Coordinateur() }

    static func dismantleNSView(_: NSView, coordinator: Coordinateur) { coordinator.arreter() }

    @MainActor
    final class Coordinateur {
        private var moniteur: Any?
        private weak var vue: NSView?
        private var lire: (NSEvent) -> Valeur? = { _ in nil }
        private var capturer: (Valeur?) -> Void = { _ in }
        private var renoncer: () -> Void = {}

        func regler(arme: Bool, vue: NSView, lire: @escaping (NSEvent) -> Valeur?,
                    capturer: @escaping (Valeur?) -> Void, renoncer: @escaping () -> Void) {
            (self.vue, self.lire, self.capturer, self.renoncer) = (vue, lire, capturer, renoncer)
            guard arme else { return arreter() }
            guard moniteur == nil else { return }
            moniteur = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] evenement in
                MainActor.assumeIsolated { self?.avaler(evenement) ?? false } ? nil : evenement
            }
        }

        /// Vrai : la frappe est pour le champ, elle ne va pas plus loin.
        private func avaler(_ evenement: NSEvent) -> Bool {
            // Une page gardée montée mais effacée (un ancêtre à l'opacité nulle) ne se voit pas non plus.
            guard let vue, let fenetre = vue.window, evenement.window === fenetre, fenetre.isKeyWindow,
                  !vue.isHiddenOrHasHiddenAncestor,
                  !sequence(first: vue, next: \.superview).contains(where: { $0.alphaValue == 0 }) else {
                renoncer()
                return false
            }
            let modificateurs = evenement.modifierFlags.intersection(.deviceIndependentFlagsMask)
                .subtracting([.numericPad, .function, .capsLock])
            // Par le caractère, jamais par la position de la touche : ⎋ renonce, ⌫ efface.
            switch (modificateurs.isEmpty, evenement.charactersIgnoringModifiers) {
            case (true, "\u{1b}"): renoncer()
            case (true, "\u{7f}"), (true, "\u{f728}"): capturer(nil)
            default: if let valeur = lire(evenement) { capturer(valeur) }
            }
            return true
        }

        func arreter() {
            guard let moniteur else { return }
            NSEvent.removeMonitor(moniteur)
            self.moniteur = nil
        }
    }
}
#endif

#if os(macOS)
// MARK: - Le menu en champ

/// Un choix parmi une liste fermée, au dessin d'un champ compact (`.fmen`) : la valeur, le chevron,
/// un menu du système à l'ouverture. Pour une liste qu'on ne filtre pas en tapant ; sinon,
/// `ChampASuggestions` imposé.
struct MenuEnChamp<Valeur: Hashable>: View {
    let titre: String
    let options: [(valeur: Valeur, libelle: String)]
    @Binding var selection: Valeur
    @Environment(\.couleursSynseria) private var c
    @FocusState private var focalise: Bool

    /// `.fmen` : `largeur-nav` × 0,9 au moins, filet et air compris — `cadreDeChamp` les ajoute.
    private static var largeurMinimale: CGFloat { Jetons.largeurNav * 0.9 - 2 * (Jetons.espace3 + Jetons.epaisseurFilet) }

    private var libelle: String { options.first { $0.valeur == selection }?.libelle ?? "" }

    var body: some View {
        Menu {
            ForEach(options, id: \.valeur) { option in
                Toggle(option.libelle, isOn: Binding(get: { option.valeur == selection }, set: { if $0 { selection = option.valeur } }))
            }
        } label: {
            HStack(spacing: Jetons.espace2) {
                Text(libelle)
                    .font(Jetons.typoCorps.font)
                    .foregroundStyle(c.encre.couleur)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: Jetons.diametreMini))
                    .foregroundStyle(c.encre2.couleur)
            }
            .frame(minWidth: Self.largeurMinimale)
            // Le cadre retire l'anneau du système : le sien dit seul le focus clavier.
            .cadreDeChamp(focalise: focalise, compact: true)
            .contentShape(.rect)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .focused($focalise)
        .fixedSize()
        .curseurDeClic(true)
        .accessibilityLabel(titre)
        .accessibilityValue(libelle)
    }
}
#endif
