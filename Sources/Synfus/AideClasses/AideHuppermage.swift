import AppKit
import Combine
import SwiftUI

/// Le tableau des combinaisons élémentaires, posé sur le jeu pendant le combat d'un Huppermage
/// (`CombinaisonsHuppermage.montree`) : presque transparent, il laisse passer les clics — il ne
/// gêne jamais. Devant un Huppermage, il fait lire le combat (`LecteurEcran.suivreAideClasse`),
/// réglage de lecture éteint ou non.
@MainActor
final class AideHuppermage {
    static let shared = AideHuppermage()

    private var panel: NSPanel?
    private var abonnements: Set<AnyCancellable> = []

    private init() {}

    func start() {
        let manager = WindowManager.shared
        let revoir: (Any) -> Void = { _ in MainActor.assumeIsolated { AideHuppermage.shared.revoir() } }
        // Après l'affectation : `@Published` publie avant d'écrire.
        manager.$frontmostPID.receive(on: DispatchQueue.main).sink(receiveValue: revoir).store(in: &abonnements)
        manager.$clients.receive(on: DispatchQueue.main).sink(receiveValue: revoir).store(in: &abonnements)
        LecteurEcran.shared.$combats.receive(on: DispatchQueue.main).sink(receiveValue: revoir).store(in: &abonnements)
        Preferences.shared.$aideHuppermage.receive(on: DispatchQueue.main).sink(receiveValue: revoir).store(in: &abonnements)
    }

    private func revoir() {
        let manager = WindowManager.shared
        let devant = manager.frontmostIsDofus ? manager.clients.first(where: manager.isFrontmost) : nil
        let classe = ClassesStore.shared.catalogue.key(for: devant?.characterClass)
        let reglage = Preferences.shared.aideHuppermage
        LecteurEcran.shared.suivreAideClasse(reglage && classe == CombinaisonsHuppermage.cleClasse)
        let enCombat = devant.flatMap { LecteurEcran.shared.combats[$0.name] }?.enCombat ?? false
        if CombinaisonsHuppermage.montree(reglage: reglage, classe: classe, enCombat: enCombat,
                                          dofusDevant: manager.frontmostIsDofus) {
            let affiche = panel ?? construire()
            panel = affiche
            if !affiche.isVisible {
                placer(affiche)
                affiche.orderFrontRegardless()
            }
        } else if let panel, panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func construire() -> NSPanel {
        let panel = PanneauDeJeu()
        let hosting = NSHostingController(rootView: TableauHuppermage().racineSynfus())
        hosting.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hosting
        panel.ignoresMouseEvents = true
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        return panel
    }

    /// En haut au centre de l'écran du jeu, sous la barre des menus : le haut de la fenêtre de
    /// Dofus ne porte rien qu'on vise en combat.
    private func placer(_ panel: NSPanel) {
        guard let zone = NSScreen.main?.visibleFrame else { return }
        panel.setFrameTopLeftPoint(NSPoint(x: zone.midX - panel.frame.width / 2, y: zone.maxY - Jetons.espace2))
    }
}

/// Le tableau : une ligne par combinaison, ses deux éléments, son nom et son effet.
struct TableauHuppermage: View {
    /// Assez pour lire, assez peu pour voir le jeu au travers.
    private static let opacite = 0.72

    var body: some View {
        VStack(alignment: .leading, spacing: Jetons.espace1) {
            ForEach(CombinaisonsHuppermage.Combinaison.allCases, id: \.self) { combinaison in
                HStack(alignment: .center, spacing: Jetons.espace1) {
                    HStack(spacing: Jetons.espace1) {
                        ForEach(CombinaisonsHuppermage.elements.filter(combinaison.paire.contains), id: \.self) {
                            // Mis à la même boîte : la montagne, plus large, débordait sur le nom.
                            Image(systemName: Self.symbole($0)).resizable().scaledToFit()
                                .foregroundStyle(Self.teinte($0))
                                .frame(width: Jetons.tailleIcone, height: Jetons.tailleIcone)
                        }
                    }
                    Text(Self.nom(combinaison)).font(Jetons.typoMicro.font)
                    Text(Self.effet(combinaison)).foregroundStyle(Color.jeton(\.encre2))
                }
            }
        }
        .font(Jetons.typoMeta.font)
        .fixedSize()
        .padding(Jetons.espace2)
        .surfaceFlottante()
        .opacity(Self.opacite)
        .accessibilityElement(children: .combine)
    }

    static func symbole(_ element: FicheCombat.Element) -> String {
        switch element {
        case .feu: "flame.fill"
        case .eau: "drop.fill"
        case .terre: "mountain.2.fill"
        case .air: "wind"
        case .neutre: "circle"
        }
    }

    /// Les éléments dans les teintes d'état du thème, au plus près de celles du jeu.
    static func teinte(_ element: FicheCombat.Element) -> Color {
        switch element {
        case .feu: Color.jeton(\.danger)
        case .eau: Color.jeton(\.info)
        case .terre: Color.jeton(\.avertissement)
        case .air: Color.jeton(\.succes)
        case .neutre: Color.jeton(\.encre2)
        }
    }

    static func nom(_ combinaison: CombinaisonsHuppermage.Combinaison) -> String {
        switch combinaison {
        case .eruption: L("huppermage.eruption")
        case .enlisement: L("huppermage.enlisement")
        case .carbonisation: L("huppermage.carbonisation")
        case .ebullition: L("huppermage.ebullition")
        case .cristallisation: L("huppermage.cristallisation")
        case .assechement: L("huppermage.assechement")
        }
    }

    static func effet(_ combinaison: CombinaisonsHuppermage.Combinaison) -> String {
        switch combinaison {
        case .eruption: L("huppermage.eruption.effet")
        case .enlisement: L("huppermage.enlisement.effet")
        case .carbonisation: L("huppermage.carbonisation.effet")
        case .ebullition: L("huppermage.ebullition.effet")
        case .cristallisation: L("huppermage.cristallisation.effet")
        case .assechement: L("huppermage.assechement.effet")
        }
    }
}
