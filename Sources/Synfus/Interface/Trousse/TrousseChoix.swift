// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 0bdf7022746769dd · contenu 983c803c2635f8b2
import SwiftUI

// Les choix de la trousse : interrupteur, case ronde et radio, segmentés, onglets ronds, puces, barre
// des onglets de réglages. Un groupe est un seul arrêt de Tab ; les flèches déplacent le choix.

// MARK: - L'interrupteur

/// L'interrupteur de la trousse (`.tg`) : une pilule de `largeur-interrupteur` × `hauteur-case`, le
/// pouce de `diametre-rond` ; actif, plein `accent`. Le pouce s'allonge sous le doigt.
struct Interrupteur: ToggleStyle {
    /// Le libellé après l'interrupteur, sinon avant, comme le système.
    var libelleApres = false

    func makeBody(configuration: Configuration) -> some View {
        CorpsDeLInterrupteur(configuration: configuration, libelleApres: libelleApres)
    }
}

extension ToggleStyle where Self == Interrupteur {
    static var interrupteur: Interrupteur { Interrupteur() }
}

private struct CorpsDeLInterrupteur: View {
    let configuration: ToggleStyleConfiguration
    let libelleApres: Bool
    @Environment(\.isEnabled) private var actif
    @Environment(\.labelsVisibility) private var libelles

    var body: some View {
        HStack(spacing: Jetons.espace3) {
            if libelles != .hidden, !libelleApres { configuration.label }
            // Un bouton : Tab et espace comme l'interrupteur du système, l'anneau de la trousse ; un
            // clic relâché hors de la piste ne bascule rien.
            Button { configuration.isOn.toggle() } label: { EmptyView() }
                .buttonStyle(PisteDInterrupteur(allume: configuration.isOn))
                .focusEffectDisabled()
                .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
            if libelles != .hidden, libelleApres { configuration.label }
        }
        .font(Jetons.typoCorps.font)
        // Le grisé d'un tout, comme `opacity` en CSS : sans groupe, chaque couche pâlit sur l'autre.
        .compositingGroup()
        .opacity(actif ? 1 : Jetons.opaciteDesactive)
    }
}

private struct PisteDInterrupteur: ButtonStyle {
    let allume: Bool

    func makeBody(configuration: Configuration) -> some View { Corps(allume: allume, appuye: configuration.isPressed) }

    private struct Corps: View {
        let allume: Bool
        let appuye: Bool
        @Environment(\.isEnabled) private var actif
        @Environment(\.isFocused) private var focalise
        @Environment(\.etatImpose) private var impose
        @Environment(\.couleursSynseria) private var c
        @State private var survoleALaSouris = false

        /// Le jeu du pouce dans sa piste : la piste moins le pouce, de part et d'autre.
        private static let jeu = (Jetons.hauteurCase - Jetons.diametreRond) / 2

        // Grisé, rien ne réagit (`pointer-events:none`).
        private var presse: Bool { actif && (impose?.presse ?? appuye) }
        private var survole: Bool { actif && (impose?.survole ?? survoleALaSouris) }

        var body: some View {
            let allonge = presse ? Jetons.espace1 : 0
            Capsule()
                .fill(fond.couleur)
                .frame(width: Jetons.largeurInterrupteur, height: Jetons.hauteurCase)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill((allume ? c.texteSurAccent : c.encre).couleur)
                        .frame(width: Jetons.diametreRond + allonge, height: Jetons.diametreRond)
                        .padding(.leading, Self.jeu)
                        .offset(x: allume ? Jetons.hauteurCase - allonge : 0)
                }
                .anneauDeFocus(Capsule(), visible: actif && (impose?.focus ?? focalise))
                .contentShape(.capsule)
                .onHover { survoleALaSouris = $0 }
                .curseurDeClic(actif)
                .animation(Jetons.courbeSortie.animation(Jetons.dureeNormale), value: allume)
                .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: presse)
        }

        private var fond: Jetons.RVB {
            if allume { return survole ? c.accentSurvol : c.accent }
            return c.piste(survolee: survole)
        }
    }
}

// MARK: - Le segmenté

/// Le segmenté à libellés (`.sg`) : une pilule sur la fenêtre et son filet, des crans de
/// `hauteur-case`, le choisi sur le fond du choix, l'accent en texte. Un seul arrêt de Tab, les
/// flèches déplacent le choix.
struct SegmenteTexte<Valeur: Hashable>: View {
    let titre: String
    let options: [(valeur: Valeur, libelle: String)]
    @Binding var selection: Valeur
    @Environment(\.couleursSynseria) private var c
    @FocusState private var focalise: Bool

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            ForEach(options, id: \.valeur) { option in
                let choisi = option.valeur == selection
                Button(option.libelle) { selection = option.valeur }
                    .buttonStyle(CranDeSegment(choisi: choisi, anneau: choisi && focalise))
                    .focusable(false)
                    .accessibilityAddTraits(option.valeur == selection ? .isSelected : [])
            }
        }
        // Le filet entoure l'air du segmenté, il ne le mange pas (`.sg` : bordure, puis padding).
        .padding(Jetons.espace1 + Jetons.epaisseurFilet)
        .background(c.fondFenetre.couleur, in: .capsule)
        .overlay { Capsule().strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
        // L'anneau entoure le cran choisi, que les flèches déplacent (`.sg button:focus-visible`).
        .focusable(interactions: .activate)
        .focused($focalise)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { deplacer(-1) }
        .onKeyPress(.rightArrow) { deplacer(1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(titre)
    }

    private func deplacer(_ pas: Int) -> KeyPress.Result {
        guard let index = options.firstIndex(where: { $0.valeur == selection }),
              options.indices.contains(index + pas) else { return .handled }
        selection = options[index + pas].valeur
        return .handled
    }
}

private struct CranDeSegment: ButtonStyle {
    let choisi: Bool
    /// Le segmenté a le focus : l'anneau sur le cran choisi.
    let anneau: Bool

    func makeBody(configuration: Configuration) -> some View { Corps(configuration: configuration, choisi: choisi, anneau: anneau) }

    private struct Corps: View {
        let configuration: ButtonStyleConfiguration
        let choisi: Bool
        let anneau: Bool
        @Environment(\.isEnabled) private var actif
        @Environment(\.etatImpose) private var impose
        @Environment(\.couleursSynseria) private var c
        @State private var survoleALaSouris = false

        // Grisé, rien ne réagit (`pointer-events:none`).
        private var survole: Bool { actif && (impose?.survole ?? survoleALaSouris) }
        private var presse: Bool { actif && (impose?.presse ?? configuration.isPressed) }

        var body: some View {
            configuration.label
                .font(Jetons.typoCorps.font)
                .fixedSize()
                .foregroundStyle((choisi ? c.accentTexte : survole || presse ? c.encre : c.encre2).couleur)
                .padding(.horizontal, Jetons.espace3)
                .frame(height: Jetons.hauteurCase)
                .background(fond, in: .capsule)
                .anneauDeFocus(Capsule(), visible: actif && choisi && (impose?.focus ?? anneau))
                .contentShape(.capsule)
                // Le grisé d'un tout, comme `opacity` en CSS : sans groupe, chaque couche pâlit sur l'autre.
                .compositingGroup()
                .opacity(actif ? 1 : Jetons.opaciteDesactive)
                .onHover { survoleALaSouris = $0 }
                .curseurDeClic(actif)
                .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: survole)
        }

        private var fond: Color {
            if choisi || presse { return c.selection.couleur }
            return survole ? c.survol.couleur : .clear
        }
    }
}

// MARK: - Les onglets ronds

/// Un choix parmi quelques icônes (`.tab`) : des ronds de `hauteur-controle`, le choisi plein
/// `accent`. Grisé, un onglet garde sa place et rien n'y paraît choisi. Un seul arrêt de Tab.
struct SegmentePlat<Valeur: Hashable>: View {
    struct Option {
        let valeur: Valeur
        let titre: String
        let symbole: String
        var aide: String?
        var disponible = true

        init(valeur: Valeur, titre: String, symbole: String, aide: String? = nil, disponible: Bool = true) {
            (self.valeur, self.titre, self.symbole, self.aide, self.disponible) = (valeur, titre, symbole, aide, disponible)
        }
    }

    let titre: String
    let options: [Option]
    @Binding var selection: Valeur
    @FocusState private var focalise: Bool

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            ForEach(options, id: \.valeur) { option in
                let choisie = option.disponible && option.valeur == selection
                Button { selection = option.valeur } label: {
                    Label(option.titre, systemImage: option.symbole)
                }
                .buttonStyle(OngletRond(choisi: choisie, anneau: choisie && focalise))
                .focusable(false)
                .disabled(!option.disponible)
                .help(option.aide ?? option.titre)
                .accessibilityAddTraits(choisie ? .isSelected : [])
            }
        }
        // ←→ déplacent le cran choisi lui-même, qui porte l'anneau ; au clic, le champ en cours
        // garde le clavier.
        .focusable(interactions: .activate)
        .focused($focalise)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { deplacer(-1) }
        .onKeyPress(.rightArrow) { deplacer(1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(titre)
    }

    private func deplacer(_ pas: Int) -> KeyPress.Result {
        let disponibles = options.filter(\.disponible)
        guard let index = disponibles.firstIndex(where: { $0.valeur == selection }) else { return .ignored }
        let suivant = index + pas
        if disponibles.indices.contains(suivant) { selection = disponibles[suivant].valeur }
        return .handled
    }
}

/// Un onglet rond : plein `accent` choisi, l'encre secondaire sinon, le voile de l'encre au survol et
/// à la pression (`.tab`).
private struct OngletRond: ButtonStyle {
    let choisi: Bool
    /// Les onglets ont le focus : l'anneau sur l'onglet choisi.
    let anneau: Bool

    func makeBody(configuration: Configuration) -> some View { Corps(configuration: configuration, choisi: choisi, anneau: anneau) }

    private struct Corps: View {
        let configuration: ButtonStyleConfiguration
        let choisi: Bool
        let anneau: Bool
        @Environment(\.isEnabled) private var actif
        @Environment(\.etatImpose) private var impose
        @Environment(\.couleursSynseria) private var c
        @State private var survoleALaSouris = false

        // Grisé, rien ne réagit (`pointer-events:none`).
        private var survole: Bool { actif && (impose?.survole ?? survoleALaSouris) }
        private var presse: Bool { actif && (impose?.presse ?? configuration.isPressed) }

        var body: some View {
            configuration.label
                .labelStyle(.iconOnly)
                .font(.system(size: Jetons.tailleIcone))
                .foregroundStyle((choisi ? c.texteSurAccent : survole || presse ? c.encre : c.encre2).couleur)
                .frame(width: Jetons.hauteurControle, height: Jetons.hauteurControle)
                .background(fond.couleur, in: .circle)
                .anneauDeFocus(Circle(), visible: actif && choisi && (impose?.focus ?? anneau))
                .contentShape(.circle)
                .scaleEffect(presse ? Jetons.echellePressee : 1)
                // Le grisé d'un tout, comme `opacity` en CSS : sans groupe, chaque couche pâlit sur l'autre.
                .compositingGroup()
                .opacity(actif ? 1 : Jetons.opaciteDesactive)
                .onHover { survoleALaSouris = $0 }
                .curseurDeClic(actif)
                .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: survole)
        }

        private var fond: Jetons.RVB {
            if choisi { return presse ? c.accentPresse : c.accent }
            if presse { return c.rvb(.voileDePression) }
            return survole ? c.rvb(.voileDeSurvol) : c.encre.voile(0)
        }
    }
}

// MARK: - Case ronde et radio

/// La coche de la trousse (`.ck svg`) : le trait de « M5.5 12.5l4.2 4.2L18.5 7.8 » sur 24, à 3,2.
private struct Coche: Shape {
    func path(in rect: CGRect) -> Path {
        let k = rect.width / 24
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + 5.5 * k, y: rect.minY + 12.5 * k))
        p.addLine(to: CGPoint(x: rect.minX + 9.7 * k, y: rect.minY + 16.7 * k))
        p.addLine(to: CGPoint(x: rect.minX + 18.5 * k, y: rect.minY + 7.8 * k))
        return p.strokedPath(StrokeStyle(lineWidth: 3.2 * k, lineCap: .round, lineJoin: .round))
    }
}

/// La case ronde (`.ck`) et la radio (`.rd`) : un rond de `diametre-rond` au trait d'`encre-3` ;
/// cochée, pleine `accent` (la coche ; la radio, un anneau de la plaque). Le libellé après.
struct CaseRonde: ToggleStyle {
    /// Une radio : le choix d'un groupe, pas une case qu'on coche.
    var radio = false

    func makeBody(configuration: Configuration) -> some View { CorpsDeLaCase(configuration: configuration, radio: radio) }
}

private struct CorpsDeLaCase: View {
    let configuration: ToggleStyleConfiguration
    let radio: Bool
    @Environment(\.labelsVisibility) private var libelles

    var body: some View {
        HStack(spacing: Jetons.espace2) {
            Button { configuration.isOn.toggle() } label: { EmptyView() }
                .buttonStyle(RondACocher(coche: configuration.isOn, radio: radio))
                .focusEffectDisabled()
                .accessibilityRepresentation { Toggle(isOn: configuration.$isOn) { configuration.label } }
            if libelles != .hidden { configuration.label.font(Jetons.typoCorps.font) }
        }
    }
}

extension ToggleStyle where Self == CaseRonde {
    static var caseRonde: CaseRonde { CaseRonde() }
    static var radio: CaseRonde { CaseRonde(radio: true) }
}

private struct RondACocher: ButtonStyle {
    let coche: Bool
    let radio: Bool

    func makeBody(configuration: Configuration) -> some View {
        ReactionDeCase(diametre: Jetons.diametreRond, cochee: coche, appuye: configuration.isPressed) { survole, presse in
            Dessin(coche: coche, radio: radio, survole: survole, presse: presse)
        }
    }

    private struct Dessin: View {
        let coche: Bool
        let radio: Bool
        let survole: Bool
        let presse: Bool
        @Environment(\.couleursSynseria) private var c
        /// Le trait du rond (`.ck` : 2 px).
        private static let trait: CGFloat = 2

        var body: some View {
            let plein = presse ? c.accentPresse : survole ? c.accentSurvol : c.accent
            let bord = coche ? plein : survole || presse ? c.encre2 : c.encre3
            ZStack {
                // Non cochée, rien dedans : le halo, dessous, en fait un seul disque.
                Circle().fill((coche ? plein : c.encre.voile(0)).couleur)
                if coche && radio {
                    Circle().inset(by: Self.trait).strokeBorder(c.plaque.couleur, lineWidth: Jetons.espace1)
                }
                Circle().strokeBorder(bord.couleur, lineWidth: Self.trait)
                if coche && !radio {
                    Coche().fill(c.texteSurAccent.couleur).frame(width: Jetons.diametreMini, height: Jetons.diametreMini)
                }
            }
            .frame(width: Jetons.diametreRond, height: Jetons.diametreRond)
        }
    }
}

/// Ce qui réagit dans toute case ronde qui se coche (`.ck`, `.rd`, `.rond`), une seule règle : comme
/// un bouton-icône, la main, au survol puis sous le doigt un halo de `hauteur-controle`, le voile de
/// l'encre (`survol` se perdrait dans une rangée survolée), qui ne pousse rien ; la pression la
/// rétrécit ; l'anneau du focus. Toute la case prend le clic, son centre compris.
private struct ReactionDeCase<Dessin: View>: View {
    let diametre: CGFloat
    let cochee: Bool
    let appuye: Bool
    @ViewBuilder let dessin: (_ survole: Bool, _ presse: Bool) -> Dessin
    @Environment(\.isEnabled) private var actif
    @Environment(\.isFocused) private var focalise
    @Environment(\.etatImpose) private var impose
    @Environment(\.couleursSynseria) private var c
    @State private var survoleALaSouris = false

    /// Le halo déborde de la case d'autant tout autour : `hauteur-controle` autour de `diametre-rond`.
    private static var debord: CGFloat { (Jetons.hauteurControle - Jetons.diametreRond) / 2 }

    private var presse: Bool { actif && (impose?.presse ?? appuye) }
    private var survole: Bool { actif && (impose?.survole ?? survoleALaSouris) }

    var body: some View {
        let halo = diametre + 2 * Self.debord
        dessin(survole, presse)
            .background {
                if survole || presse {
                    Circle().fill(c.rvb(presse ? .voileDePression : .voileDeSurvol).couleur).frame(width: halo, height: halo)
                }
            }
            .anneauDeFocus(Circle(), visible: actif && (impose?.focus ?? focalise))
            .contentShape(.circle)
            .scaleEffect(presse ? Jetons.echellePressee : 1)
            .compositingGroup()
            .opacity(actif ? 1 : Jetons.opaciteDesactive)
            .onHover { survoleALaSouris = $0 }
            .curseurDeClic(actif)
            .animation(Jetons.courbeStandard.animation(Jetons.dureeRapide), value: [cochee, survole, presse])
    }
}

// MARK: - La case d'une tâche

/// La case ronde d'une tâche (`.rond`), le dessin seul : un rond de `diametre-rond` (`diametre-mini`
/// en mini) au trait d'`encre-3`, pointillé pour ce qui ne se compte pas ; cochée, pleine `accent` et
/// la coche. Inerte (un pas fait, un calage) : ce qui se coche passe par `.caseDeTache`.
struct CaseDeTache: View {
    let cochee: Bool
    var pointillee = false
    var mini = false
    fileprivate var survolee = false
    fileprivate var pressee = false
    @Environment(\.couleursSynseria) private var c

    init(cochee: Bool, pointillee: Bool = false, mini: Bool = false) {
        self.cochee = cochee
        self.pointillee = pointillee
        self.mini = mini
    }

    /// Le trait du rond (`.rond` : 2 px) ; le pointillé, son pas (le masque de `.rond.pt`).
    static let trait: CGFloat = 2
    static let pas: [CGFloat] = [2, 4]
    var diametre: CGFloat { mini ? Jetons.diametreMini : Jetons.diametreRond }

    var body: some View {
        let reagit = survolee || pressee
        let plein = pressee ? c.accentPresse : survolee ? c.accentSurvol : c.accent
        let bord = cochee ? plein : reagit ? c.encre2 : c.encre3
        ZStack {
            // Non cochée, rien dedans : le halo du bouton, dessous, en fait un seul disque.
            Circle().fill((cochee ? plein : c.encre.voile(0)).couleur)
            if cochee {
                // La coche de `.rond.ok svg` : `diametre-mini`, le tiers de moins en mini (8 sur 12).
                let coche = mini ? Jetons.diametreMini * 2 / 3 : Jetons.diametreMini
                Coche().fill(c.texteSurAccent.couleur).frame(width: coche, height: coche)
            } else {
                Circle().strokeBorder(bord.couleur, style: StrokeStyle(lineWidth: Self.trait, dash: pointillee ? Self.pas : []))
            }
        }
        .frame(width: diametre, height: diametre)
    }
}

/// La case d'une tâche qui se coche : elle réagit comme toute case ronde (`ReactionDeCase`).
/// L'étiquette du bouton n'est pas dessinée : `Button(action:) { EmptyView() }`.
struct BoutonDeCase: ButtonStyle {
    let cochee: Bool
    var pointillee = false
    var mini = false

    func makeBody(configuration: Configuration) -> some View {
        let dessin = CaseDeTache(cochee: cochee, pointillee: pointillee, mini: mini)
        return ReactionDeCase(diametre: dessin.diametre, cochee: cochee, appuye: configuration.isPressed) { survole, presse in
            var reagit = dessin
            reagit.survolee = survole
            reagit.pressee = presse
            return reagit
        }
    }
}

extension ButtonStyle where Self == BoutonDeCase {
    static func caseDeTache(cochee: Bool, pointillee: Bool = false, mini: Bool = false) -> BoutonDeCase {
        BoutonDeCase(cochee: cochee, pointillee: pointillee, mini: mini)
    }
}

// MARK: - Les puces

/// Des puces qui passent à la ligne quand la rangée est pleine (les filtres d'une palette, un
/// tiroir). Le calcul des places est pur (`placer`) : la mise en page n'en est que l'application.
struct RangeeDePuces: Layout {
    var espacement: CGFloat = Jetons.espace2
    var interligne: CGFloat = Jetons.espace2

    struct Placement: Equatable {
        var origines: [CGPoint]
        var taille: CGSize
    }

    /// Chaque puce à la suite de la précédente ; celle qui dépasserait `largeur` ouvre une ligne (une
    /// puce plus large que la ligne y tient seule). Les puces d'une ligne sont centrées sur sa hauteur.
    static func placer(_ tailles: [CGSize], largeur: CGFloat, espacement: CGFloat, interligne: CGFloat) -> Placement {
        var lignes: [[Int]] = []
        var x: CGFloat = 0
        for (i, taille) in tailles.enumerated() {
            if lignes.isEmpty || (x > 0 && x + taille.width > largeur + 0.5) {
                lignes.append([])
                x = 0
            }
            lignes[lignes.count - 1].append(i)
            x += taille.width + espacement
        }
        var origines = Array(repeating: CGPoint.zero, count: tailles.count)
        var y: CGFloat = 0
        var largeurUtile: CGFloat = 0
        for ligne in lignes {
            let hauteur = ligne.map { tailles[$0].height }.max() ?? 0
            var x: CGFloat = 0
            for i in ligne {
                origines[i] = CGPoint(x: x, y: y + (hauteur - tailles[i].height) / 2)
                x += tailles[i].width + espacement
            }
            largeurUtile = max(largeurUtile, x - espacement)
            y += hauteur + interligne
        }
        return Placement(origines: origines, taille: CGSize(width: largeurUtile, height: lignes.isEmpty ? 0 : y - interligne))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let tailles = subviews.map { $0.sizeThatFits(.unspecified) }
        return Self.placer(tailles, largeur: proposal.width ?? .infinity, espacement: espacement, interligne: interligne).taille
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let tailles = subviews.map { $0.sizeThatFits(.unspecified) }
        let placement = Self.placer(tailles, largeur: bounds.width, espacement: espacement, interligne: interligne)
        for (vue, (origine, taille)) in zip(subviews, zip(placement.origines, tailles)) {
            vue.place(at: CGPoint(x: bounds.minX + origine.x, y: bounds.minY + origine.y), proposal: ProposedViewSize(taille))
        }
    }
}

/// Une puce (`.puce`) : un filtre, une capsule discrète en méta. Choisie, le fond du choix et une
/// coche, sans liseré ; désignée au clavier, le seul liseré de la rangée — dans la capsule, pas
/// autour, la rangée garde son air.
struct Puce: View {
    let libelle: String
    var symbole: String?
    var choisie = false
    /// Celle que les flèches désignent : Espace la prend.
    var auClavier = false
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            if choisie { Image(systemName: "checkmark").imageScale(.small) }
            if let symbole { Image(systemName: symbole).imageScale(.small) }
            Text(libelle).lineLimit(1)
        }
        .font(Jetons.typoMeta.font)
        .foregroundStyle((choisie ? c.encre : c.encre2).couleur)
        .padding(.horizontal, Jetons.espace2)
        .padding(.vertical, Jetons.espace1)
        .background((choisie ? c.selection : c.survol).couleur, in: .capsule)
        .overlay { if auClavier { Capsule().strokeBorder(c.accent.couleur, lineWidth: Jetons.epaisseurFocus) } }
        .contentShape(.capsule)
        .curseurDeClic(true)
    }
}

// MARK: - La barre des onglets de réglages

/// Les onglets d'une fenêtre de réglages (`.stab`) : l'icône et le nom en micro dessous, sans cadre,
/// le choisi sur le fond du choix et l'accent en texte. Pas de titre de page : les onglets disent où
/// l'on est. Un seul arrêt de Tab, ←→ changent d'onglet.
///
/// Dans la fenêtre, cette barre est le bandeau du haut (`.sw .bar`) : la fenêtre hôte est en
/// `fullSizeContentView` + `titlebarAppearsTransparent`, titre caché, et cette barre est ancrée au
/// sommet du contenu, d'un bord à l'autre, en ignorant la safe-area du titre (`safeAreaRegions = []`) —
/// jamais poussée sous la rangée des feux. Son propre fond couvre la bande de la barre de titre
/// comprise ; rien n'est posé dans la barre de titre au-dessus du contenu. Le volet commence au bas
/// du bandeau, à `espace-2` comme autour de la plaque, et le déplacement de la fenêtre se fait par le
/// bandeau, hors onglets. Règle complète : « La fenêtre Réglages (.sw) monte sous la barre de titre »,
/// section 7 de la référence.
struct BarreDesOnglets<Valeur: Hashable>: View {
    struct Onglet {
        let valeur: Valeur
        let libelle: String
        let symbole: String
    }

    let onglets: [Onglet]
    @Binding var selection: Valeur

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            ForEach(onglets, id: \.valeur) { onglet in
                OngletDeReglages(onglet: onglet, choisi: onglet.valeur == selection) { selection = onglet.valeur }
            }
        }
        // `.sw .bar` : le haut à hauteur des boutons de la fenêtre.
        .padding(.top, Jetons.espace3)
        .padding(.bottom, Jetons.espace2)
        .frame(maxWidth: .infinity)
        .focusable(interactions: .activate)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { deplacer(-1) }
        .onKeyPress(.rightArrow) { deplacer(1) }
    }

    private func deplacer(_ pas: Int) -> KeyPress.Result {
        guard let rang = onglets.firstIndex(where: { $0.valeur == selection }), onglets.indices.contains(rang + pas) else { return .handled }
        selection = onglets[rang + pas].valeur
        return .handled
    }

    private struct OngletDeReglages: View {
        let onglet: Onglet
        let choisi: Bool
        let choisir: () -> Void
        @State private var survole = false
        @Environment(\.couleursSynseria) private var c

        var body: some View {
            Button(action: choisir) {
                // La moitié de `largeur-nav`, l'icône sur `espace-5`, le nom en micro.
                VStack(spacing: Jetons.espace1) {
                    Image(systemName: onglet.symbole)
                        .font(.system(size: Jetons.espace5 * 3 / 4))
                        .frame(height: Jetons.espace5)
                    Text(onglet.libelle).font(Jetons.typoMicro.font).lineLimit(1).fixedSize()
                }
                .foregroundStyle((choisi ? c.accentTexte : c.encre2).couleur)
                .padding([.horizontal, .top], Jetons.espace1)
                .padding(.bottom, Jetons.espace2)
                .frame(width: Jetons.largeurNav / 2)
                .background((choisi ? c.selection : survole ? c.survol : c.survol.voile(0)).couleur,
                            in: .rect(cornerRadius: Jetons.rayon2, style: .circular))
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .onHover { survole = $0 }
            .curseurDeClic(true)
            .accessibilityLabel(onglet.libelle)
            .accessibilityAddTraits(choisi ? [.isButton, .isSelected] : .isButton)
        }
    }
}
