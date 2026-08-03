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
        let bas: CGFloat = 1117
        let declenches = rejouer(&detecteur, [
            releve([bas, bas], bandeau: bas), releve([bas, bas], bandeau: bas),
            // Seule la seconde icône décolle : le bandeau, lui, ne bouge pas.
            releve([bas, 1084.783447], bandeau: bas),
            releve([bas, 1055.784424], bandeau: bas),
            releve([bas, 1092.109009], bandeau: bas),
            releve([bas, 1116.689697], bandeau: bas),
        ])
        #expect(declenches == [1])
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
