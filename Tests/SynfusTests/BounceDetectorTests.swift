import Testing
import CoreGraphics
@testable import Synfus

/// Le détecteur est une machine à états pure : on peut lui rejouer un Dock
/// entier — masquage automatique compris — sans écran ni Accessibilité.
struct BounceDetectorTests {

    private static let tailleIcone = CGSize(width: 52, height: 52)

    /// Fabrique un relevé à partir des ordonnées de chaque icône. `bandeau` est
    /// l'ordonnée du Dock lui-même ; l'omettre revient à ne pas l'avoir lue.
    private func releve(
        _ ordonnees: [CGFloat],
        bandeau: CGFloat? = nil,
        hauteurs: [CGFloat]? = nil,
        sourisSurLeDock: Bool = false
    ) -> BounceDetector.Snapshot {
        let cles = ordonnees.indices.map { "dofus#\($0)" }
        return BounceDetector.Snapshot(
            keys: cles,
            y: Dictionary(uniqueKeysWithValues: zip(cles, ordonnees)),
            size: Dictionary(uniqueKeysWithValues: cles.enumerated().map { index, cle in
                (cle, CGSize(width: Self.tailleIcone.width,
                             height: hauteurs?[index] ?? Self.tailleIcone.height))
            }),
            dockTop: bandeau,
            mouseInDock: sourisSurLeDock
        )
    }

    /// Rejoue une suite de relevés et rend tous les rangs déclenchés.
    private func rejouer(
        _ detecteur: inout BounceDetector,
        _ releves: [BounceDetector.Snapshot]
    ) -> [Int] {
        releves.flatMap { detecteur.ingest($0) }
    }

    /// Indice du relevé qui a déclenché — c'est-à-dire le délai, en tours de
    /// 0,1 s. Ce que le résultat seul ne dit pas.
    private func tourDeDeclenchement(
        _ detecteur: inout BounceDetector,
        _ releves: [BounceDetector.Snapshot]
    ) -> Int? {
        for (index, releve) in releves.enumerated() where !detecteur.ingest(releve).isEmpty {
            return index
        }
        return nil
    }

    // MARK: - Le cas nominal

    @Test("Une montée suivie du retour au repos est un rebond")
    func rebondComplet() {
        var detecteur = BounceDetector()
        // Deux tours d'amorçage : le premier enregistre l'effectif, le second
        // prend la position de repos.
        let declenches = rejouer(&detecteur, [
            releve([900]), releve([900]),
            releve([850]), releve([840]), releve([870]),   // le saut
            releve([900]),                                  // le retour
        ])
        #expect(declenches == [0])
    }

    @Test("Une montée qui ne redescend jamais n'est pas un rebond")
    func monteeSansRetour() {
        var detecteur = BounceDetector()
        // Une icône déplacée pour de bon : le vol expire au bout de 15 tours.
        let releves = [releve([900]), releve([900])] + Array(repeating: releve([850]), count: 20)
        #expect(rejouer(&detecteur, releves).isEmpty)
    }

    // MARK: - Le masquage automatique du Dock

    @Test("Un Dock en masquage automatique ne déclenche rien en se dévoilant")
    func dockMasquePuisSurvole() {
        var detecteur = BounceDetector()
        // Repos, Dock masqué : bandeau et icône reposent ensemble sous l'écran.
        var releves = [releve([970], bandeau: 970), releve([970], bandeau: 970)]
        // Survol : le bandeau *et* l'icône remontent de 70, restent déployés,
        // puis se masquent de nouveau. C'est un aller-retour parfait, que la
        // seule géométrie de l'icône ne distingue pas d'un saut — mais l'icône
        // n'a pas bougé d'un point par rapport à son bandeau.
        releves += Array(repeating: releve([900], bandeau: 900), count: 8)
        releves += Array(repeating: releve([970], bandeau: 970), count: 5)
        #expect(rejouer(&detecteur, releves).isEmpty)
    }

    /// Relevé réel du 03/08, écran 1728 × 1117 et Dock en masquage automatique :
    /// les icônes reposent à y = 1117, donc entièrement sous le bord de l'écran.
    /// L'ancienne règle « un rebond a lieu Dock visible » refusait toute position
    /// de repos, et ce rebond-là — 61 points de montée — ne déclenchait rien.
    @Test("Un rebond se voit alors même que le Dock est masqué")
    func rebondDockMasque() {
        var detecteur = BounceDetector()
        let declenches = rejouer(&detecteur, Self.relevéDu3Aout.map(releveReel))
        #expect(declenches == [1])
    }

    /// La même suite, mesurée en délai. Le rebond s'étale sur deux secondes de
    /// relevé ; conclure au retour coûtait tout l'arc, soit la latence dont
    /// l'usage se plaignait. La montée est décisive dès son premier tour : 32
    /// points pour une icône de 56 de haut.
    @Test("Un rebond franc se conclut sur la montée, sans attendre le retour")
    func declenchementSurLaMontee() {
        var detecteur = BounceDetector()
        let tour = tourDeDeclenchement(&detecteur, Self.relevéDu3Aout.map(releveReel))
        // Indices 0 et 1 amorcent (effectif puis position de repos), l'indice 2
        // est le premier tour de la montée.
        #expect(tour == 2)
    }

    /// Sans bandeau, la mesure est absolue et un Dock qui se dévoile ressemble
    /// trait pour trait à un saut : là, l'aller-retour reste exigé.
    @Test("Faute de bandeau, le retour reste exigé")
    func sansBandeauLeRetourResteExige() {
        var detecteur = BounceDetector()
        let hauteur = Self.tailleIcone.height
        let releves = [
            releve([900]), releve([900]),
            releve([900 - hauteur]), releve([900 - hauteur]),   // montée franche
            releve([900]),                                       // le retour
        ]
        #expect(tourDeDeclenchement(&detecteur, releves) == 4)
    }

    /// Relevé réel du 03/08 : Dock masqué à y = 1117, seconde icône qui saute.
    /// Le bandeau, lui, ne bouge pas d'un point.
    private static let relevéDu3Aout: [[CGFloat]] = [
        [1117, 1117], [1117, 1117],
        [1117, 1084.783447], [1117, 1055.784424],
        [1117, 1092.109009], [1117, 1116.689697],
    ]

    private func releveReel(_ ordonnees: [CGFloat]) -> BounceDetector.Snapshot {
        releve(ordonnees, bandeau: 1117, hauteurs: [56.106445, 56.106445])
    }

    /// Sans bandeau lisible, on retombe sur des ordonnées absolues : la détection
    /// doit continuer de fonctionner, et le Dock qui glisse d'un bloc reste
    /// écarté par la solidarité des icônes.
    @Test("Faute de bandeau, la détection tient encore sur les ordonnées brutes")
    func sansBandeau() {
        var detecteur = BounceDetector()
        var declenches = rejouer(&detecteur, [
            releve([900, 900]), releve([900, 900]),
            releve([900, 850]), releve([900, 900]),
        ])
        #expect(declenches == [1])

        declenches = rejouer(&detecteur, [
            releve([830, 830]), releve([830, 830]), releve([900, 900]),
        ])
        #expect(declenches.isEmpty)
    }

    @Test("Le Dock entier qui se déplace ne déclenche rien")
    func translationEnBloc() {
        var detecteur = BounceDetector()
        // Changement de taille du Dock : les deux icônes montent ensemble.
        let releves = [releve([900, 900]), releve([900, 900]),
                       releve([860, 861]), releve([860, 861]), releve([860, 861])]
        #expect(rejouer(&detecteur, releves).isEmpty)
    }

    @Test("La magnification au survol ne déclenche rien")
    func magnification() {
        var detecteur = BounceDetector()
        // L'icône monte *et* grossit : c'est le curseur, pas un appel d'attention.
        let releves = [releve([900]), releve([900]),
                       releve([870], hauteurs: [78]), releve([900])]
        #expect(rejouer(&detecteur, releves).isEmpty)
    }

    @Test("Rien n'est retenu des tours où le curseur est sur le Dock")
    func sourisSurLeDock() {
        var detecteur = BounceDetector()
        let releves = [releve([900]), releve([900]),
                       releve([840], sourisSurLeDock: true),
                       releve([900], sourisSurLeDock: true)]
        #expect(rejouer(&detecteur, releves).isEmpty)
    }

    // MARK: - Changements d'effectif

    @Test("Un client lancé en cours de route ne fausse pas la détection")
    func clientLancePuisRebond() {
        var detecteur = BounceDetector()
        var declenches = rejouer(&detecteur, [releve([900]), releve([900])])
        // Un second client apparaît : les rangs se décalent, tout est repris.
        declenches += rejouer(&detecteur, [releve([900, 960]), releve([900, 960])])
        // C'est le deuxième qui réclame l'attention.
        declenches += rejouer(&detecteur, [releve([900, 910]), releve([900, 960])])
        #expect(declenches == [1])
    }

    @Test("Le rebond est rendu au rang de son icône")
    func rangRendu() {
        var detecteur = BounceDetector()
        let declenches = rejouer(&detecteur, [
            releve([900, 900, 900]), releve([900, 900, 900]),
            releve([900, 900, 850]),
            releve([900, 900, 900]),
        ])
        #expect(declenches == [2])
    }
}
