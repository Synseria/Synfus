import AppKit
import Combine
import SwiftUI
import SynseriaDesign

/// Le calque de visée contre le Comte Harebourg : posé exactement sur le
/// contenu de la fenêtre du perso devant, il dessine, sort préparé et case
/// visée à portée, où le sort retombera (`ViseeHarebourg.arrivees`) et le
/// pivot. Grille, pivot et portée sont relus sur l'écran pendant le tour. Il ne
/// fait que dessiner : `ignoresMouseEvents`, jamais clé — les clics vont au jeu.
///
/// Pas un `PanneauDeJeu` : il n'a ni place à garder ni hauteur de contenu, il
/// prend le cadre du contenu (`CalqueSurJeu`), caché dès que le pointeur passe
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

    private let calque = CalqueSurJeu(ViseeVue())
    /// Le relevé lent : cadre de la fenêtre, tour, pivot — tant que le réglage est allumé.
    private var veille: Timer?
    /// Le suivi du pointeur, seulement quand le calque peut dessiner.
    private var suivi: Timer?
    private var abonnements: Set<AnyCancellable> = []
    /// La fenêtre du perso devant, relue par la veille.
    private var cible: FenetreJeu?

    /// Le relevé du plateau en cours, et quand il a fini : deux captures par seconde au plus.
    private var releve: Task<Void, Never>?
    private var dernierReleve = Date.distantPast
    private static let intervalleReleve: TimeInterval = 0.5
    /// La grille du plateau, retrouvée sur l'écran : jamais réglée à la main.
    private var grille: GrilleIso?
    /// Le tour pour lequel la grille a été retrouvée : chaque tour la recale (la carte change d'un combat à l'autre).
    private var tourCale: (perso: String, tour: Int?)?
    /// La portée du sort préparé, sur la grille en place, chez ce perso.
    private var portee = PorteeSort()
    private var persoPortee: String?
    /// Une case active vue une fois : retenue comme pivot à la seconde lecture identique.
    private var pivotVu: (perso: String, position: GrilleIso.Case)?

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
        cible = FenetreJeu.devant()
        // La fenêtre a changé de proportions : la grille ne vaut plus, on la recherche.
        if let grille, let cible, !grille.valable(pour: cible.contenu.size) { tourCale = nil }
        let entrees = entrees()
        if entrees.reglage, entrees.harebourg, entrees.sonTour, let cible { relever(cible.perso) }
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

    /// Le pointeur est-il sur une fenêtre de Synfus qui prend les clics (panneau,
    /// barre, réglages) ? Pas celles qui les laissent passer au jeu (tableau de
    /// l'Huppermage, infobulle, vue de carte), ni une fenêtre d'un autre bureau.
    private func surSynfus() -> Bool {
        let souris = NSEvent.mouseLocation
        return NSApp.windows.contains {
            $0.isVisible && $0.isOnActiveSpace && !$0.ignoresMouseEvents && $0.frame.contains(souris)
        }
    }

    private func entrees() -> ViseeHarebourg.Entrees {
        let prefs = Preferences.shared
        let aide = AideBoss.shared
        var e = ViseeHarebourg.Entrees()
        e.reglage = prefs.harebourgVisee
        e.harebourg = aide.boss == .special(.harebourg)
        e.panneauMontre = BossPanel.shared.montre
        guard let cible else { return e }
        if case .monTour = LecteurEcran.shared.combats[cible.perso] { e.sonTour = true }
        let taille = cible.contenu.size
        e.contenu = taille
        e.grille = grille.flatMap { $0.valable(pour: taille) ? $0 : nil }
        e.lanceur = aide.visee.lanceur(cible.perso)
        e.confusion = aide.suivi.estimation(cible.perso) != nil
        e.sortPrepare = persoPortee == cible.perso && portee.sortPrepare
        let fraction = cible.pointeur()
        e.pointeurSurLeJeu = fraction != nil && !surSynfus()
        if let fraction, let grille = e.grille {
            e.survoleeVisable = ViseeHarebourg.visable(portee.teinte(grille.caseSous(fraction: fraction, contenu: taille)))
        }
        return e
    }

    /// Le perso au premier plan et la case sous le pointeur, sur la grille
    /// retrouvée et valable pour sa fenêtre ; `nil` sinon (raccourci « Marquer ma
    /// case »). Le même relevé que le calque : le pivot va au perso qu'il dessine.
    func caseSousLePointeur() -> (perso: String, position: GrilleIso.Case)? {
        guard let cible = FenetreJeu.devant(), let grille,
              let fraction = cible.pointeur(), !surSynfus() else { return nil }
        let taille = cible.contenu.size
        guard grille.valable(pour: taille) else { return nil }
        return (cible.perso, grille.caseSous(fraction: fraction, contenu: taille))
    }

    // MARK: - Relevé du plateau

    /// Ce qu'une capture donne, lu hors du fil principal.
    private struct Lecture: Sendable {
        /// La grille retrouvée, si elle était recherchée.
        var trouvee: GrilleIso?
        /// Le centre de la case cernée de blanc, en fractions du contenu.
        var pivot: CGPoint?
        /// Les cases mesurées, sur la grille employée (`trouvee` ou la connue).
        var signatures: [GrilleIso.Case: PorteeSort.Signature] = [:]
    }

    /// Pendant le tour, deux fois par seconde : la grille retrouvée sur le
    /// plateau (au premier passage du tour), la portée du sort préparé, et sans
    /// sort la case du perso, cernée de blanc par le jeu, qui devient le pivot
    /// si deux lectures de suite la donnent (un sort préparé cache le contour).
    /// Le raccourci « Marquer ma case » reste le recours.
    private func relever(_ perso: String) {
        guard releve == nil, Date().timeIntervalSince(dernierReleve) >= Self.intervalleReleve else { return }
        let tour = AideBoss.shared.tour
        let recaler = tourCale.map { $0.perso != perso || $0.tour != tour } ?? true
        let connue = grille
        releve = Task {
            defer { releve = nil; dernierReleve = Date() }
            guard let capture = await LecteurEcran.shared.imageDevant(region: .entiere) else { return }
            let lu = await Task.detached(priority: .utility) { Self.lirePlateau(capture, recaler: recaler, connue: connue) }.value
            let taille = CGSize(width: capture.width, height: capture.height)
            if let trouvee = lu.trouvee {
                tourCale = (perso, tour)
                // La même grille, retrouvée sur une autre case : on garde celle en place, et les pivots avec.
                if connue.map({ !$0.coincide(avec: trouvee, contenu: taille) }) ?? true {
                    grille = trouvee
                    AideBoss.shared.oublierPivots()
                    pivotVu = nil
                    portee = PorteeSort()
                }
            } else if recaler {
                // À recaler sans grille retrouvée : rien de lu sur l'ancienne.
                return
            }
            guard let grille, let cible, grille.valable(pour: cible.contenu.size) else { return }
            if persoPortee != perso {
                portee = PorteeSort()
                persoPortee = perso
            }
            portee.lire(lu.signatures)
            guard !portee.sortPrepare, let pivot = lu.pivot else { return }
            let position = grille.caseSous(fraction: pivot, contenu: cible.contenu.size)
            if let vu = pivotVu, vu.perso == perso, vu.position == position {
                AideBoss.shared.marquer(position, perso: perso)
            }
            pivotVu = (perso, position)
        }
    }

    /// Hors du fil principal : la grille retrouvée (si `recaler`), puis sur la
    /// grille employée — la connue si la retrouvée coïncide, celle des cases
    /// gardées — les cases mesurées et le centre de la case active.
    nonisolated private static func lirePlateau(_ capture: CGImage, recaler: Bool, connue: GrilleIso?) -> Lecture {
        guard let image = ImageRVB(cgImage: capture) else { return Lecture() }
        let w = CGFloat(image.width), h = CGFloat(image.height)
        var lu = Lecture()
        lu.trouvee = recaler ? PlateauCombat.grille(image)?.enFractions(image: CGSize(width: w, height: h)) : nil
        if recaler, lu.trouvee == nil { return lu }
        let grille: GrilleIso
        if let trouvee = lu.trouvee, let connue, connue.coincide(avec: trouvee, contenu: CGSize(width: w, height: h)) {
            grille = connue
        } else if let choisie = lu.trouvee ?? connue {
            grille = choisie
        } else {
            return lu
        }
        let enPixels = PlateauCombat.Grille(a: grille.demiLargeur * Double(h),
                                            centre: CGPoint(x: grille.origine.x * w, y: grille.origine.y * h))
        lu.signatures = PorteeSort.mesurer(image, grille: enPixels)
        if let (x, y) = PlateauCombat.caseActive(image, grille: enPixels) {
            let p = GrilleIso.projeter(x, y, a: CGFloat(enPixels.a), centre: enPixels.centre)
            lu.pivot = CGPoint(x: p.x / w, y: p.y / h)
        }
        return lu
    }

    // MARK: - Dessin

    private func suivre() {
        let entrees = entrees()
        let raison = ViseeHarebourg.inactive(entrees)
        let affichee = ViseeHarebourg.raisonAffichee(raison, avant: inactive, dofusDevant: cible != nil)
        if inactive != affichee { inactive = affichee }
        guard raison == nil, let cible, let grille = entrees.grille, let lanceur = entrees.lanceur,
              let fraction = cible.pointeur(),
              let estimation = AideBoss.shared.suivi.estimation(cible.perso)
        else { return montrer(nil, cible: nil) }
        let taille = cible.contenu.size
        let survolee = grille.caseSous(fraction: fraction, contenu: taille)
        let arrivees = ViseeHarebourg.arrivees(survolee: survolee, lanceur: lanceur, estimation: estimation, portee: portee)
        montrer(Dessin(grille: grille, lanceur: lanceur, survolee: survolee, arrivees: arrivees), cible: cible)
    }

    /// Publie au seul changement ; pose le calque sur le contenu, ou le retire.
    private func montrer(_ nouveau: Dessin?, cible: FenetreJeu?) {
        if dessin != nouveau { dessin = nouveau }
        calque.poser(sur: nouveau == nil ? nil : cible)
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
        case .sansLanceur: L("boss.visee.inactive.sansLanceur")
        case .sansConfusion: L("boss.visee.inactive.sansConfusion")
        case .sansSort: L("boss.visee.inactive.sansSort")
        case .horsDuJeu: L("boss.visee.inactive.horsDuJeu")
        case .horsPortee: L("boss.visee.inactive.horsPortee")
        }
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
/// nommée (rouge hors de la zone du sort), la voisine en pointillés, le pivot cerclé — en Nuit quel que soit le
/// thème de l'app : posé sur le jeu, il se lit sur n'importe quel décor.
struct CalqueVisee: View {
    let dessin: ViseePanel.Dessin

    var body: some View {
        GeometryReader { geo in
            Canvas { contexte, _ in Self.dessiner(dessin, taille: geo.size, dans: contexte) } symbols: {
                Self.etiquette(L("boss.visee.tombeIci")).tag(Symbole.tombeIci)
                Self.etiquette(L("boss.visee.tombeDehors")).tag(Symbole.tombeDehors)
            }
        }
        .accessibilityHidden(true)
    }

    private enum Symbole: Hashable { case tombeIci, tombeDehors }

    private static func etiquette(_ texte: String) -> some View {
        Text(texte)
            .font(Jetons.typoMicro.font)
            .foregroundStyle(Color.jeton(\.encre, en: .nuit))
            .padding(.horizontal, Jetons.espace1)
            .background(RoundedRectangle(cornerRadius: Jetons.rayon1)
                .fill(Color.jeton(\.plaque, en: .nuit).opacity(Jetons.opacitePlaque)))
    }

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
            // Hors de la zone du sort, la case est rouge : le sort partirait dans le vide.
            let couleur = arrivee.dansLaZone ? Color.jeton(\.succes, en: .nuit) : Color.jeton(\.danger, en: .nuit)
            if arrivee.principale {
                contexte.fill(losange, with: .color(couleur.opacity(Self.voileArrivee)))
                tracer(losange, couleur, largeur: trait, dans: contexte)
            } else {
                tracer(losange, arrivee.dansLaZone ? Color.jeton(\.avertissement, en: .nuit) : couleur,
                       largeur: trait, pointille: true, dans: contexte)
            }
        }
        if let principale = dessin.arrivees.first(where: \.principale),
           let etiquette = contexte.resolveSymbol(id: principale.dansLaZone ? Symbole.tombeIci : Symbole.tombeDehors) {
            let centre = grille.centre(principale.position, contenu: taille)
            contexte.draw(etiquette, at: CGPoint(x: centre.x, y: centre.y - a / 2 - Jetons.espace1), anchor: .bottom)
        }
    }
}
