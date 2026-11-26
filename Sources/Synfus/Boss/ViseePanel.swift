import AppKit
import Combine
import SwiftUI
import SynseriaDesign

/// Le calque de visée contre le Comte Harebourg : posé exactement sur le
/// contenu de la fenêtre du perso devant, il dessine la case survolée, où le
/// sort retombera (`ViseeHarebourg.arrivees`) et le pivot marqué. Il ne fait
/// que dessiner : `ignoresMouseEvents`, jamais clé — les clics vont au jeu.
///
/// Pas un `PanneauDeJeu` : il n'a ni place à garder ni hauteur de contenu, il
/// prend le cadre du contenu. Au niveau `.statusBar` comme eux (`.floating`
/// disparaît sous un espace plein écran), et caché dès que le pointeur passe
/// sur une fenêtre de Synfus.
@MainActor
final class ViseePanel: ObservableObject {
    static let shared = ViseePanel()

    /// Ce que le calque dessine, en cases ; la vue le projette par la grille.
    struct Dessin: Equatable {
        let grille: GrilleIso
        let lanceur: GrilleIso.Case
        let survolee: GrilleIso.Case
        let arrivees: [ViseeHarebourg.Arrivee]
    }

    /// Pourquoi rien n'est dessiné (onglet Diagnostic) ; `nil` : le calque dessine.
    @Published private(set) var inactive: ViseeHarebourg.Inactive? = .reglage
    @Published private(set) var dessin: Dessin?

    private var panel: NSPanel?
    /// Le relevé lent : cadre de la fenêtre, tour, pivot — tant que le réglage est allumé.
    private var veille: Timer?
    /// Le suivi du pointeur, seulement quand le calque peut dessiner.
    private var suivi: Timer?
    private var abonnements: Set<AnyCancellable> = []
    /// Le contenu du perso devant : sa fenêtre, relue par la veille.
    private var cible: Cible?

    private struct Cible {
        let perso: String
        let fenetreAX: CGRect
        let pleinEcran: Bool
    }

    private static let intervalleVeille: TimeInterval = 0.5
    private static let intervalleSuivi: TimeInterval = 1.0 / 30

    private init() {}

    func start() {
        let prefs = Preferences.shared
        let revoir: (Any) -> Void = { _ in MainActor.assumeIsolated { ViseePanel.shared.revoir() } }
        // Après l'affectation : `@Published` publie avant d'écrire.
        prefs.$harebourgVisee.receive(on: DispatchQueue.main).sink { valeur in
            revoir(valeur)
            // Le raccourci « Marquer ma case » ne tient sa combinaison que visée allumée.
            MainActor.assumeIsolated { HotKeyManager.shared.rebind() }
        }.store(in: &abonnements)
        prefs.$bossChoisi.receive(on: DispatchQueue.main).sink(receiveValue: revoir).store(in: &abonnements)
    }

    /// Avec les panneaux du jeu (`PanneauxJeu.revoir`) : au changement d'app.
    func revoirVisibilite(force _: Bool) { revoir() }

    /// La veille ne tourne que réglage allumé, contre le Comte ; elle relit tout aussitôt.
    func revoir() {
        let prefs = Preferences.shared
        let veillee = prefs.harebourgVisee && AideBoss.shared.boss == .special(.harebourg)
        if veillee, veille == nil {
            veille = Timer.scheduledTimer(withTimeInterval: Self.intervalleVeille, repeats: true) { _ in
                MainActor.assumeIsolated { ViseePanel.shared.veiller() }
            }
        } else if !veillee {
            veille?.invalidate()
            veille = nil
        }
        veiller()
    }

    // MARK: - Relevés

    private func veiller() {
        cible = Self.cibleDevant()
        let entrees = entrees()
        // Tout est là sauf, peut-être, le pointeur : on le suit.
        let pointeurSuivi = [nil, .horsDuJeu].contains(ViseeHarebourg.inactive(entrees)) && entrees.contenu != nil
        if pointeurSuivi, suivi == nil {
            suivi = Timer.scheduledTimer(withTimeInterval: Self.intervalleSuivi, repeats: true) { _ in
                MainActor.assumeIsolated { ViseePanel.shared.suivre() }
            }
        } else if !pointeurSuivi {
            suivi?.invalidate()
            suivi = nil
        }
        suivre()
    }

    /// Le perso devant et le cadre de sa fenêtre, par le serveur de fenêtres :
    /// un client gelé ne fait pas attendre le calque.
    private static func cibleDevant() -> Cible? {
        let manager = WindowManager.shared
        guard manager.frontmostIsDofus, let client = manager.clients.first(where: manager.isFrontmost),
              let cadre = CrossSpaceTitles.cadreAffiche(pid: client.pid) else { return nil }
        return Cible(perso: client.name, fenetreAX: cadre, pleinEcran: client.pleinEcran)
    }

    private func contenu(_ cible: Cible) -> CGRect {
        ZoneEcran.contenuAX(fenetreAX: cible.fenetreAX, barreTitre: GeometrieCapture.barreTitre,
                            pleinEcran: cible.pleinEcran)
    }

    /// Le pointeur en fraction du contenu du perso devant ; `nil` hors du contenu.
    private func pointeur(_ cible: Cible) -> CGPoint? {
        guard let hauteur = NSScreen.screens.first?.frame.height else { return nil }
        return ZoneEcran.fraction(pointEcran: NSEvent.mouseLocation, fenetreAX: cible.fenetreAX,
                                  hauteurPrincipale: hauteur, barreTitre: GeometrieCapture.barreTitre,
                                  pleinEcran: cible.pleinEcran)
    }

    /// Le pointeur est-il sur une fenêtre de Synfus (panneau, barre, réglages) ?
    private func surSynfus() -> Bool {
        let souris = NSEvent.mouseLocation
        return NSApp.windows.contains { $0 !== panel && $0.isVisible && $0.frame.contains(souris) }
    }

    private func entrees() -> ViseeHarebourg.Entrees {
        let prefs = Preferences.shared
        let aide = AideBoss.shared
        var e = ViseeHarebourg.Entrees()
        e.reglage = prefs.harebourgVisee
        e.harebourg = aide.boss == .special(.harebourg)
        e.panneauMontre = BossPanel.shared.montre
        e.grille = prefs.grilleCombat
        guard let cible else { return e }
        if case .monTour = LecteurEcran.shared.combats[cible.perso] { e.sonTour = true }
        e.contenu = contenu(cible).size
        e.lanceur = aide.visee.lanceur(cible.perso)
        e.confusion = aide.suivi.estimation(cible.perso) != nil
        e.pointeurSurLeJeu = pointeur(cible) != nil && !surSynfus()
        return e
    }

    /// Le perso au premier plan et la case sous le pointeur, sur la grille
    /// calibrée et valable pour sa fenêtre ; `nil` sinon (raccourci « Marquer ma
    /// case »). Le même relevé que le calque : le pivot va au perso qu'il dessine.
    func caseSousLePointeur() -> (perso: String, position: GrilleIso.Case)? {
        guard let cible = Self.cibleDevant(), let grille = Preferences.shared.grilleCombat,
              let fraction = pointeur(cible) else { return nil }
        let taille = contenu(cible).size
        guard grille.valable(pour: taille) else { return nil }
        return (cible.perso, grille.caseSous(fraction: fraction, contenu: taille))
    }

    // MARK: - Dessin

    private func suivre() {
        let entrees = entrees()
        let raison = ViseeHarebourg.inactive(entrees)
        let affichee = ViseeHarebourg.raisonAffichee(raison, avant: inactive, dofusDevant: cible != nil)
        if inactive != affichee { inactive = affichee }
        guard raison == nil, let cible, let grille = entrees.grille, let lanceur = entrees.lanceur,
              let fraction = pointeur(cible),
              let estimation = AideBoss.shared.suivi.estimation(cible.perso)
        else { return montrer(nil, cible: nil) }
        let taille = contenu(cible).size
        let survolee = grille.caseSous(fraction: fraction, contenu: taille)
        montrer(Dessin(grille: grille, lanceur: lanceur, survolee: survolee,
                       arrivees: ViseeHarebourg.arrivees(survolee: survolee, lanceur: lanceur, estimation: estimation)),
                cible: cible)
    }

    /// Publie au seul changement ; pose le calque sur le contenu, ou le retire.
    private func montrer(_ nouveau: Dessin?, cible: Cible?) {
        if dessin != nouveau { dessin = nouveau }
        guard nouveau != nil, let cible, let hauteur = NSScreen.screens.first?.frame.height else {
            if let panel, panel.isVisible { panel.orderOut(nil) }
            return
        }
        let affiche = panel ?? construire()
        panel = affiche
        let cadre = ZoneEcran.cadreAppKit(fenetreAX: cible.fenetreAX, hauteurPrincipale: hauteur,
                                          barreTitre: GeometrieCapture.barreTitre, pleinEcran: cible.pleinEcran)
        if affiche.frame != cadre { affiche.setFrame(cadre, display: true) }
        if !affiche.isVisible { affiche.orderFrontRegardless() }
    }

    /// Ce que fait le calque, ou pourquoi il ne dessine pas.
    static func libelle(_ inactive: ViseeHarebourg.Inactive?) -> String {
        switch inactive {
        case nil: L("boss.visee.active")
        case .reglage: L("boss.visee.inactive.reglage")
        case .pasHarebourg: L("boss.visee.inactive.pasHarebourg")
        case .panneauCache: L("boss.visee.inactive.panneauCache")
        case .pasSonTour: L("boss.visee.inactive.pasSonTour")
        case .grilleAbsente: L("boss.visee.inactive.grilleAbsente")
        case .grilleInvalide: L("boss.visee.inactive.grilleInvalide")
        case .sansLanceur: L("boss.visee.inactive.sansLanceur")
        case .sansConfusion: L("boss.visee.inactive.sansConfusion")
        case .horsDuJeu: L("boss.visee.inactive.horsDuJeu")
        }
    }

    private func construire() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.contentView = NSHostingView(rootView: ViseeVue().racineSynfus())
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        return panel
    }
}

/// Le calque tel que `ViseePanel` le publie.
struct ViseeVue: View {
    @ObservedObject private var visee = ViseePanel.shared

    var body: some View {
        if let dessin = visee.dessin { CalqueVisee(dessin: dessin) }
    }
}

/// Le dessin du calque : la case survolée d'un filet, l'arrivée pleine et
/// nommée, la voisine en pointillés, le pivot cerclé — en Nuit quel que soit le
/// thème de l'app : posé sur le jeu, il se lit sur n'importe quel décor.
struct CalqueVisee: View {
    let dessin: ViseePanel.Dessin

    var body: some View {
        GeometryReader { geo in
            Canvas { contexte, _ in Self.dessiner(dessin, taille: geo.size, dans: contexte) } symbols: {
                Text(L("boss.visee.tombeIci"))
                    .font(Jetons.typoMicro.font)
                    .foregroundStyle(Color.jeton(\.encre, en: .nuit))
                    .padding(.horizontal, Jetons.espace1)
                    .background(RoundedRectangle(cornerRadius: Jetons.rayon1)
                        .fill(Color.jeton(\.plaque, en: .nuit).opacity(Jetons.opacitePlaque)))
                    .tag(Symbole.tombeIci)
            }
        }
        .accessibilityHidden(true)
    }

    private enum Symbole: Hashable { case tombeIci }

    /// Assez pour voir l'arrivée d'un coup d'œil, assez peu pour voir la case du jeu dessous.
    private static let voileArrivee = 0.55

    private static func chemin(_ sommets: [CGPoint]) -> Path {
        Path { $0.addLines(sommets); $0.closeSubpath() }
    }

    /// Un trait sur un halo de la plaque : il se lit sur le damier bleu comme sur le sol clair.
    private static func tracer(_ chemin: Path, _ couleur: Color, largeur: CGFloat, pointille: Bool = false,
                               dans contexte: GraphicsContext) {
        let tirets: [CGFloat] = pointille ? [largeur * 2, largeur * 2] : []
        contexte.stroke(chemin, with: .color(Color.jeton(\.plaque, en: .nuit).opacity(Jetons.opacitePlaque)),
                        style: StrokeStyle(lineWidth: largeur * 2.5, lineJoin: .round))
        contexte.stroke(chemin, with: .color(couleur), style: StrokeStyle(lineWidth: largeur, lineJoin: .round, dash: tirets))
    }

    private static func dessiner(_ dessin: ViseePanel.Dessin, taille: CGSize, dans contexte: GraphicsContext) {
        let grille = dessin.grille
        let a = grille.a(taille)
        let trait = Jetons.epaisseurFocus
        // Le pivot : un anneau dans sa case.
        let pivot = grille.centre(dessin.lanceur, contenu: taille)
        tracer(Path(ellipseIn: CGRect(x: pivot.x - a * 0.6, y: pivot.y - a * 0.3, width: a * 1.2, height: a * 0.6)),
               Color.jeton(\.encre, en: .nuit), largeur: trait, dans: contexte)
        // La case visée.
        tracer(chemin(grille.losange(dessin.survolee, contenu: taille)), Color.jeton(\.encre, en: .nuit),
               largeur: Jetons.epaisseurFilet, dans: contexte)
        for arrivee in dessin.arrivees.reversed() {
            let losange = chemin(grille.losange(arrivee.position, contenu: taille))
            if arrivee.principale {
                contexte.fill(losange, with: .color(Color.jeton(\.succes, en: .nuit).opacity(Self.voileArrivee)))
                tracer(losange, Color.jeton(\.succes, en: .nuit), largeur: trait, dans: contexte)
            } else {
                tracer(losange, Color.jeton(\.avertissement, en: .nuit), largeur: trait, pointille: true, dans: contexte)
            }
        }
        if let principale = dessin.arrivees.first(where: \.principale),
           let etiquette = contexte.resolveSymbol(id: Symbole.tombeIci) {
            let centre = grille.centre(principale.position, contenu: taille)
            contexte.draw(etiquette, at: CGPoint(x: centre.x, y: centre.y - a / 2 - Jetons.espace1), anchor: .bottom)
        }
    }
}
