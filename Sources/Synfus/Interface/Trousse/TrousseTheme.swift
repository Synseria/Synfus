// Engendré par Synseria-Design — ne pas retoucher : changer jetons.json ou apps/Synfus.json, puis sh propager.sh.
// jetons.json 0bdf7022746769dd · contenu df7a239b7ba3f9ff
import SwiftUI

// Réglages ▸ Thème : l'affiche des douze thèmes, le bandeau des nuances et le verre (`K.fenetreTheme`
// de la page). L'app lie ses préférences et passe ses libellés ; tout s'applique en direct.

// MARK: - La teinte de Personnalisé

/// « Personnalisé » : une seule couleur enregistrée, que le curseur et le champ en degrés font
/// tourner. Le seul calcul de la teinte, pour l'affiche comme pour l'app qui relit un réglage.
enum TeinteDuPersonnalise {
    typealias P = Jetons.Parametres.Personnalise

    /// Sa teinte, en degrés entiers (0…359), celle que montrent le curseur et le champ.
    static func teinte(_ couleur: UInt32) -> Int { Int(Jetons.Octets(couleur).tsl.0.rounded()) % 360 }

    /// La même couleur à une autre teinte : une couleur terne prend la saturation du curseur, sinon
    /// il ne changerait rien ; la clarté est bornée comme dans le nuancier. Une teinte hors de
    /// 0…360 est ramenée au bord.
    static func aLaTeinte(_ couleur: UInt32, _ teinte: Int) -> UInt32 {
        let (saturation, clarte) = reglee(couleur)
        let voulue = min(360, max(0, teinte)) % 360
        // À l'octet, une couleur pâle ne tombe pas sur chaque degré : on cherche, à moins d'un degré
        // près, celle qui se relit à la teinte demandée, sinon le champ sauterait d'un cran.
        let ecarts = [0.0] + stride(from: 0.1, through: 1, by: 0.1).flatMap { [$0, -$0] }
        let couleurs = ecarts.lazy.map {
            Jetons.Octets.tsl((Double(voulue) + $0 + 360).truncatingRemainder(dividingBy: 360), saturation, clarte).hex
        }
        return couleurs.first { Self.teinte($0) == voulue } ?? Jetons.Octets.tsl(Double(voulue), saturation, clarte).hex
    }

    /// Le spectre du curseur, de 60° en 60°, à la saturation et la clarté que prendra la couleur.
    static func arc(_ couleur: UInt32) -> [Jetons.RVB] {
        let (saturation, clarte) = reglee(couleur)
        return stride(from: 0, through: 360, by: 60).map { Jetons.Octets.tsl(Double($0), saturation, clarte).rvb }
    }

    private static func reglee(_ couleur: UInt32) -> (saturation: Double, clarte: Double) {
        let (_, s, l) = Jetons.Octets(couleur).tsl
        return (max(s, P.saturationCurseurMin), min(P.clarte[1], max(P.clarte[0], l)))
    }
}

#if os(macOS)
// MARK: - L'affiche

/// Les mots de Réglages ▸ Thème, passés par l'app (sa langue, son tutoiement). Les noms des thèmes et
/// des nuances sont ceux du SDS, sauf traduction.
struct LibellesDuTheme {
    /// Le groupe des cartes et celui des nuances, pour VoiceOver.
    var theme: String
    var nuance: String
    var personnalise: String
    /// Les deux tâches et le bouton de l'aperçu d'une carte.
    var tache: String
    var tacheFaite: String
    var bouton: String
    /// Le curseur, le champ en degrés et la pastille du panneau de couleur de Personnalisé.
    var teinte: String
    var degres: String
    var couleur: String
    var suivreLeSysteme: String
    var suivreLeSystemeAide: String?
    var verre: String
    var verreAide: String?
    var nomDuColoris: (Jetons.Coloris) -> String = { $0.nom }
    var nomDeLaNuance: (Jetons.Nuance) -> String = { $0.nom }
}

/// Réglages ▸ Thème (`.affiche`, `.bnd`) : douze cartes-aperçus, quatre de front — les onze coloris
/// dans l'ordre du spectre, puis Personnalisé —, chacune peinte par le nuancier dans la nuance
/// affichée, la choisie cerclée de son accent ; puis le bandeau des nuances, « Suivre le système » et
/// « Verre ». Un seul arrêt de Tab par groupe ; les flèches déplacent le choix lui-même.
///
/// `coloris` nil : Personnalisé, à la couleur `personnalise`, gardée quand un coloris est choisi.
/// `nuance` nil : la nuance suit le système. `fond` : celui que l'app a choisi, nil celui de chaque
/// thème. Sans `verre`, pas d'interrupteur du verre.
struct AfficheDuTheme: View {
    @Binding var coloris: Jetons.Coloris?
    @Binding var personnalise: UInt32
    @Binding var nuance: Jetons.Nuance?
    let fond: Jetons.Fond?
    var verre: Binding<Bool>?
    let libelles: LibellesDuTheme
    @Environment(\.colorScheme) private var schema

    init(coloris: Binding<Jetons.Coloris?>, personnalise: Binding<UInt32>, nuance: Binding<Jetons.Nuance?>,
         fond: Jetons.Fond? = nil, verre: Binding<Bool>? = nil, libelles: LibellesDuTheme) {
        (_coloris, _personnalise, _nuance, self.fond, self.verre, self.libelles) = (coloris, personnalise, nuance, fond, verre, libelles)
    }

    static let colonnes = 4

    /// Le thème choisi : un coloris, ou Personnalisé à sa couleur, sur le fond de l'app.
    var theme: Jetons.Theme { theme(de: coloris) }

    private func theme(de carte: Jetons.Coloris?) -> Jetons.Theme {
        carte.map { .coloris($0, fond: fond) } ?? .personnalise(personnalise, fond: fond)
    }

    /// La nuance que l'app dessine en ce moment : la choisie, sinon celle du système.
    private var affichee: Jetons.Nuance { nuance ?? .duSysteme(sombre: schema == .dark) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            affiche
            bandeau.padding(.top, Jetons.espace4)
        }
    }

    // MARK: Les cartes

    /// L'ordre des cartes, celui des flèches : les coloris, puis Personnalisé (nil).
    static var ordre: [Jetons.Coloris?] { Jetons.Coloris.allCases.map(Optional.some) + [nil] }

    /// La carte où mène une flèche depuis `depuis` : `pas` de ±1 sur la rangée, ±`colonnes` d'une
    /// rangée à l'autre ; au bord, le choix ne bouge pas.
    static func voisin(de depuis: Jetons.Coloris?, pas: Int) -> Jetons.Coloris?? {
        guard let index = ordre.firstIndex(of: depuis), ordre.indices.contains(index + pas) else { return nil }
        return .some(ordre[index + pas])
    }

    private var affiche: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Jetons.espace4, alignment: .top), count: Self.colonnes),
                  spacing: Jetons.espace4) {
            // L'identité d'une carte est son coloris, pas sa valeur : la couleur de Personnalisé change
            // sous le curseur, et une carte refaite à chaque pas lâchait le curseur en plein geste.
            ForEach(Self.ordre, id: \.self) { carte in
                CarteDApercu(theme: theme(de: carte), nuance: affichee,
                             choisie: carte == coloris, libelles: libelles,
                             choisir: { if coloris != carte { coloris = carte } },
                             poser: poser)
            }
        }
        .padding(Jetons.espace1 / 2)
        .focusable(interactions: .activate)
        .focusEffectDisabled()
        .onKeyPress(.leftArrow) { deplacer(-1) }
        .onKeyPress(.rightArrow) { deplacer(1) }
        .onKeyPress(.upArrow) { deplacer(-Self.colonnes) }
        .onKeyPress(.downArrow) { deplacer(Self.colonnes) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(libelles.theme)
    }

    /// N'écrire que ce qui change : chaque affectation enregistre chez l'app, et le curseur de
    /// teinte en envoie une à chaque pas.
    private func poser(_ couleur: UInt32) {
        if personnalise != couleur { personnalise = couleur }
        if coloris != nil { coloris = nil }
    }

    private func deplacer(_ pas: Int) -> KeyPress.Result {
        if let voisin = Self.voisin(de: coloris, pas: pas) { coloris = voisin }
        return .handled
    }

    // MARK: Le bandeau

    @Environment(\.couleursSynseria) private var c

    private var bandeau: some View {
        let forme = RoundedRectangle(cornerRadius: Jetons.rayon3, style: .circular)
        return HStack(spacing: Jetons.espace4) {
            HStack(spacing: Jetons.espace2) {
                ForEach(Jetons.Nuance.allCases) { cran in
                    CranDeLaNuance(nuance: cran, theme: theme, nom: libelles.nomDeLaNuance(cran), choisi: cran == affichee) {
                        if nuance != cran { nuance = cran }
                    }
                }
            }
            .focusable(interactions: .activate)
            .focusEffectDisabled()
            .onKeyPress(.leftArrow) { deplacerLaNuance(-1) }
            .onKeyPress(.rightArrow) { deplacerLaNuance(1) }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(libelles.nuance)
            Toggle(libelles.suivreLeSysteme, isOn: Binding(get: { nuance == nil }, set: { nuance = $0 ? nil : affichee }))
                .toggleStyle(Interrupteur(libelleApres: true))
                .fixedSize()
                .help(libelles.suivreLeSystemeAide ?? "")
            // Le verre à côté de la nuance : les deux font le fond.
            if let verre {
                Toggle(libelles.verre, isOn: verre)
                    .toggleStyle(Interrupteur(libelleApres: true))
                    .fixedSize()
                    .help(libelles.verreAide ?? "")
            }
        }
        .foregroundStyle(c.encre.couleur)
        .padding(Jetons.espace2)
        .background(c.fondFenetre.couleur, in: forme)
        .overlay { forme.strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
    }

    private func deplacerLaNuance(_ pas: Int) -> KeyPress.Result {
        let toutes = Jetons.Nuance.allCases
        if let index = toutes.firstIndex(of: affichee), toutes.indices.contains(index + pas) { nuance = toutes[index + pas] }
        return .handled
    }
}

/// Un thème en miniature (`.tc`) : la barre de la fenêtre (`.mbar`), deux tâches, une choisie et une
/// faite, le bouton principal (`.mpl`), son nom ; la choisie cerclée de son accent. Personnalisé
/// porte à la place de la barre ce qui règle sa couleur, hors du bouton de la carte.
private struct CarteDApercu: View {
    let theme: Jetons.Theme
    let nuance: Jetons.Nuance
    let choisie: Bool
    let libelles: LibellesDuTheme
    let choisir: () -> Void
    let poser: (UInt32) -> Void

    private static let rayon = Jetons.rayon3

    var body: some View {
        // Les couleurs du thème de la carte, jamais celles de l'app : chacune montre le sien.
        let c = Jetons.Nuancier.couleurs(theme, nuance)
        VStack(alignment: .leading, spacing: 0) {
            if case .personnalise(let couleur) = theme.primaire {
                LigneDuPersonnalise(couleur: couleur, c: c, libelles: libelles, poser: poser)
            } else {
                Button(action: choisir) { BarreDApercu(c: c).contentShape(.rect) }
                    .buttonStyle(.plain)
                    .focusable(false)
                    .curseurDeClic(true)
            }
            Button(action: choisir) {
                VStack(alignment: .leading, spacing: 0) {
                    PlaqueDApercu(c: c, libelles: libelles)
                    Text(nom)
                        .font(Jetons.typoTitreCarte.font)
                        .foregroundStyle(c.encre.couleur)
                        .lineLimit(1)
                        .frame(minHeight: Jetons.hauteurCase)
                        .padding(.top, Jetons.espace3)
                        .padding(.horizontal, Jetons.espace1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .curseurDeClic(true)
        }
        .padding(Jetons.espace2)
        .background(c.fondFenetre.couleur, in: .rect(cornerRadius: Self.rayon))
        .overlay { RoundedRectangle(cornerRadius: Self.rayon).strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
        .overlay {
            if choisie {
                RoundedRectangle(cornerRadius: Self.rayon + Jetons.decalageFocus)
                    .strokeBorder(c.accent.couleur, lineWidth: Jetons.epaisseurFocus)
                    .padding(-Jetons.decalageFocus - Jetons.epaisseurFocus)
            }
        }
        // Ce qu'elle contient (l'anneau de focus du curseur, du champ) prend l'accent de son thème.
        .couleursSynseria(c)
        // Personnalisé garde ses réglages visibles de VoiceOver ; une autre carte n'est qu'un bouton.
        .accessibilityElement(children: estPersonnalise ? .contain : .combine)
        .accessibilityLabel(nom)
        .accessibilityAddTraits(choisie ? [.isButton, .isSelected] : .isButton)
    }

    private var estPersonnalise: Bool {
        if case .personnalise = theme.primaire { true } else { false }
    }

    private var nom: String {
        if case .coloris(let coloris) = theme.primaire { libelles.nomDuColoris(coloris) } else { libelles.personnalise }
    }
}

/// `.mbar` : l'onglet choisi plein d'accent, deux autres, la recherche.
struct BarreDApercu: View {
    let c: Jetons.Couleurs

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            rond(c.accent.couleur)
            rond(c.encre.couleur.opacity(0.14))
            rond(c.encre.couleur.opacity(0.14))
            RoundedRectangle(cornerRadius: Jetons.rayon1).fill(c.plaque.couleur)
                .overlay { RoundedRectangle(cornerRadius: Jetons.rayon1).strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
                .frame(height: Jetons.diametreRond)
                .padding(.leading, Jetons.espace1)
        }
        .padding(.horizontal, Jetons.espace1)
        .padding(.bottom, Jetons.espace2)
    }

    private func rond(_ couleur: Color) -> some View {
        Circle().fill(couleur).frame(width: Jetons.diametreRond, height: Jetons.diametreRond)
    }
}

/// `.mpl` : la tâche choisie (`.mr.sel`), la faite (`.mr.done`), le bouton principal (`.mb`).
private struct PlaqueDApercu: View {
    let c: Jetons.Couleurs
    let libelles: LibellesDuTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            rangee(libelles.tache, faite: false)
                .background(c.selection.couleur, in: .rect(cornerRadius: Jetons.rayon0))
            rangee(libelles.tacheFaite, faite: true)
            Text(libelles.bouton)
                .font(Jetons.typoMicro.font)
                .foregroundStyle(c.texteSurAccent.couleur)
                .padding(.horizontal, Jetons.espace3)
                .frame(height: Jetons.hauteurCase)
                .background(c.accent.couleur, in: .capsule)
                .padding(.top, Jetons.espace2)
                .padding(.leading, Jetons.espace2)
        }
        .padding(Jetons.espace2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(c.plaque.couleur, in: .rect(cornerRadius: Jetons.rayon1))
        .overlay { RoundedRectangle(cornerRadius: Jetons.rayon1).strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
    }

    private func rangee(_ titre: String, faite: Bool) -> some View {
        HStack(spacing: Jetons.espace2) {
            ZStack {
                if faite {
                    Circle().fill(c.accent.couleur)
                    Image(systemName: "checkmark")
                        .font(.system(size: Jetons.diametreMini - Jetons.espace1, weight: .heavy))
                        .foregroundStyle(c.texteSurAccent.couleur)
                } else {
                    Circle().strokeBorder(c.encre3.couleur, lineWidth: Jetons.epaisseurFocus)
                }
            }
            .frame(width: Jetons.diametreMini, height: Jetons.diametreMini)
            Text(titre)
                .font(Jetons.typoMicro.font)
                .strikethrough(faite)
                .foregroundStyle((faite ? c.encre2 : c.encre).couleur)
                .lineLimit(1)
        }
        .padding(.horizontal, Jetons.espace2)
        .frame(maxWidth: .infinity, minHeight: Jetons.hauteurControle, alignment: .leading)
    }
}

// MARK: - Personnalisé

/// La ligne de Personnalisé (`.mp2`), à la hauteur de la barre des autres cartes : le curseur de
/// teinte, son champ en degrés et la pastille du panneau de couleur, synchronisés par la seule
/// couleur enregistrée. Toucher l'un choisit Personnalisé.
private struct LigneDuPersonnalise: View {
    let couleur: UInt32
    let c: Jetons.Couleurs
    let libelles: LibellesDuTheme
    let poser: (UInt32) -> Void

    /// La hauteur de la barre des autres cartes : la carte ne grandit pas.
    static let hauteur = Jetons.diametreRond

    @FocusState private var pastilleFocalisee: Bool

    var body: some View {
        let teinte = TeinteDuPersonnalise.teinte(couleur)
        HStack(spacing: Jetons.espace2) {
            CurseurDeLaTeinte(teinte: teinte, arc: TeinteDuPersonnalise.arc(couleur).map(\.couleur), c: c, libelle: libelles.teinte) {
                poser(TeinteDuPersonnalise.aLaTeinte(couleur, $0))
            }
            ChampDesDegres(teinte: teinte, c: c, libelle: libelles.degres) { poser(TeinteDuPersonnalise.aLaTeinte(couleur, $0)) }
            Button { PanneauDuPersonnalise.shared.ouvrir(couleur, poser: poser) } label: {
                Circle().fill(Jetons.RVB(couleur).couleur)
                    .padding(Jetons.epaisseurFocus)
                    .background(c.plaque.couleur, in: .circle)
                    .overlay { Circle().strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
                    .frame(width: Self.hauteur, height: Self.hauteur)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .focused($pastilleFocalisee)
            .anneauDeFocus(Circle(), visible: pastilleFocalisee)
            .curseurDeClic(true)
            .help(libelles.couleur)
            .accessibilityLabel(libelles.couleur)
        }
        .frame(height: Self.hauteur)
        .padding(.horizontal, Jetons.espace1)
        .padding(.bottom, Jetons.espace2)
    }
}

/// Le curseur de teinte, 0…359°, sur le spectre ; un seul arrêt de Tab, les flèches le déplacent
/// d'un degré (⇧ : de dix) sans rendre la main à l'affiche.
private struct CurseurDeLaTeinte: View {
    let teinte: Int
    let arc: [Color]
    let c: Jetons.Couleurs
    let libelle: String
    let poser: (Int) -> Void

    /// `.hue` de la page : le pouce et la piste.
    private static let diametre = Jetons.diametrePouce
    @FocusState private var focalise: Bool

    var body: some View {
        GeometryReader { cadre in
            let course = max(1, cadre.size.width - Self.diametre)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: Jetons.rayon0)
                    .fill(LinearGradient(colors: arc, startPoint: .leading, endPoint: .trailing))
                    .frame(height: Jetons.hauteurPiste)
                Circle()
                    .fill(c.accent.couleur)
                    .overlay { Circle().strokeBorder(c.fondFenetre.couleur, lineWidth: Jetons.epaisseurFocus) }
                    .frame(width: Self.diametre, height: Self.diametre)
                    .anneauDeFocus(Circle(), visible: focalise)
                    .offset(x: CGFloat(teinte) / 359 * course)
            }
            .frame(maxHeight: .infinity)
            .contentShape(.rect)
            .gesture(DragGesture(minimumDistance: 0).onChanged { geste in
                poser(min(359, max(0, Int(((geste.location.x - Self.diametre / 2) / course * 359).rounded()))))
            })
        }
        .frame(minWidth: Jetons.espace6)
        .focusable(interactions: .activate)
        .focused($focalise)
        .focusEffectDisabled()
        .curseurDeClic(true)
        .onKeyPress(keys: [.leftArrow, .rightArrow]) { touche in
            let pas = touche.modifiers.contains(.shift) ? 10 : 1
            poser(min(359, max(0, teinte + (touche.key == .leftArrow ? -pas : pas))))
            return .handled
        }
        .accessibilityElement()
        .accessibilityLabel(libelle)
        .accessibilityValue("\(teinte)°")
        .accessibilityAdjustableAction { sens in
            poser(min(359, max(0, teinte + (sens == .increment ? 1 : -1))))
        }
    }
}

/// La teinte en degrés, saisie au clavier : chaque chiffre tapé repeint ; à la sortie du champ, il
/// reprend la teinte retenue (une saisie hors de 0…360 est ramenée au bord).
private struct ChampDesDegres: View {
    let teinte: Int
    let c: Jetons.Couleurs
    let libelle: String
    let poser: (Int) -> Void

    @State private var brouillon = ""
    @FocusState private var saisi: Bool

    var body: some View {
        HStack(spacing: 0) {
            TextField(libelle, text: Binding(get: { brouillon }, set: { texte in
                brouillon = texte
                if let valeur = Int(texte.trimmingCharacters(in: .whitespaces)) { poser(valeur) }
            }))
            .textFieldStyle(.plain)
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .font(Jetons.typoMeta.font.monospacedDigit())
            .foregroundStyle(c.encre.couleur)
            .focused($saisi)
            .focusEffectDisabled()
            Text(verbatim: "°")
                .font(Jetons.typoMeta.font)
                .foregroundStyle(c.encre2.couleur)
        }
        // `.deg` : `espace-7` + `espace-2` de large, filet compris ; au focus, filet d'accent et
        // anneau collé au bord (`outline-offset: 0`).
        .padding(.horizontal, Jetons.espace2)
        .frame(width: Jetons.espace7 + Jetons.espace2, height: LigneDuPersonnalise.hauteur)
        .background(c.plaque.couleur, in: .rect(cornerRadius: Jetons.rayon1))
        .overlay {
            RoundedRectangle(cornerRadius: Jetons.rayon1)
                .strokeBorder((saisi ? c.accent : c.filet).couleur, lineWidth: Jetons.epaisseurFilet)
        }
        .overlay {
            if saisi {
                RoundedRectangle(cornerRadius: Jetons.rayon1 + Jetons.epaisseurFocus)
                    .strokeBorder(c.accent.couleur, lineWidth: Jetons.epaisseurFocus)
                    .padding(-Jetons.epaisseurFocus)
            }
        }
        .onAppear { brouillon = String(teinte) }
        .onChange(of: teinte) { if !saisi { brouillon = String(teinte) } }
        .onChange(of: saisi) { if !saisi { brouillon = String(teinte) } }
        .quitteAuClicAilleurs(saisi)
        .help(libelle)
    }
}

/// Le panneau de couleur du système pour Personnalisé : continu, sans opacité.
@MainActor
private final class PanneauDuPersonnalise: NSObject {
    static let shared = PanneauDuPersonnalise()
    private var poser: ((UInt32) -> Void)?

    func ouvrir(_ couleur: UInt32, poser: @escaping (UInt32) -> Void) {
        let panneau = NSColorPanel.shared
        panneau.showsAlpha = false
        panneau.isContinuous = true
        // La couleur d'abord : posée après la cible, elle renverrait l'action.
        panneau.setTarget(nil)
        panneau.color = NSColor(Jetons.RVB(couleur).couleur)
        self.poser = poser
        panneau.setTarget(self)
        panneau.setAction(#selector(changer(_:)))
        panneau.orderFront(nil)
    }

    @objc private func changer(_ panneau: NSColorPanel) {
        guard let srgb = panneau.color.usingColorSpace(.sRGB) else { return }
        func octet(_ c: CGFloat) -> UInt32 { UInt32((max(0, min(1, c)) * 255).rounded()) }
        poser?(octet(srgb.redComponent) << 16 | octet(srgb.greenComponent) << 8 | octet(srgb.blueComponent))
    }
}

// MARK: - Le bandeau des nuances

/// Un cran du bandeau (`.cran`) : la vignette du thème choisi dans cette nuance (`.trio` : la
/// fenêtre, la plaque, l'accent), son nom ; le choisi cerclé de l'accent. Choisir une nuance cesse
/// de suivre le système.
struct CranDeLaNuance: View {
    let nuance: Jetons.Nuance
    let theme: Jetons.Theme
    let nom: String
    let choisi: Bool
    let choisir: () -> Void
    @Environment(\.couleursSynseria) private var c

    var body: some View {
        let vignette = Jetons.Nuancier.couleurs(theme, nuance)
        Button(action: choisir) {
            HStack(spacing: Jetons.espace3) {
                HStack(spacing: 0) {
                    vignette.fondFenetre.couleur
                    vignette.plaque.couleur
                    vignette.accent.couleur
                }
                .frame(width: Jetons.diametreMini * 3, height: Jetons.hauteurCase)
                .clipShape(.rect(cornerRadius: Jetons.rayon0))
                // Le filet hors de la vignette (`outline` de la page), qui garde sa taille.
                .overlay {
                    RoundedRectangle(cornerRadius: Jetons.rayon0 + Jetons.epaisseurFilet)
                        .strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet)
                        .padding(-Jetons.epaisseurFilet)
                }
                // Rien de tronqué : le nom garde sa taille, le cran s'élargit.
                Text(nom)
                    .font(Jetons.typoTitreCarte.font)
                    .foregroundStyle(c.encre.couleur)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 0)
            }
            // Le filet du cran s'ajoute à son air, comme la bordure de la page.
            .padding(Jetons.espace2 + Jetons.epaisseurFilet)
            .frame(maxWidth: .infinity)
            .background(c.fondFenetre.couleur, in: .rect(cornerRadius: Jetons.rayon1))
            .overlay { RoundedRectangle(cornerRadius: Jetons.rayon1).strokeBorder(c.filet.couleur, lineWidth: Jetons.epaisseurFilet) }
            .overlay {
                // Le contour choisi à un point du bord (`outline-offset: 1px` de la page).
                if choisi {
                    RoundedRectangle(cornerRadius: Jetons.rayon1 + Jetons.epaisseurFilet)
                        .strokeBorder(c.accent.couleur, lineWidth: Jetons.epaisseurFocus)
                        .padding(-Jetons.epaisseurFilet - Jetons.epaisseurFocus)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .focusable(false)
        .curseurDeClic(true)
        .accessibilityLabel(nom)
        .accessibilityAddTraits(choisi ? .isSelected : [])
    }
}
#endif
