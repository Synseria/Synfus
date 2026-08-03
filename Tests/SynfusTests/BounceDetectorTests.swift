import Testing
import CoreGraphics
@testable import Synfus

/// Le détecteur est une machine à états pure : on peut lui rejouer un Dock
/// entier — masquage automatique compris — sans écran ni Accessibilité.
struct BounceDetectorTests {

    private static let tailleIcone = CGSize(width: 52, height: 52)

    /// Fabrique un relevé à partir des ordonnées de chaque icône.
    private func releve(
        _ ordonnees: [CGFloat],
        visibles: Bool = true,
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
            onScreen: visibles ? Set(cles) : [],
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

    // MARK: - Le faux positif d'origine

    @Test("Un Dock en masquage automatique ne déclenche rien en remontant")
    func dockMasquePuisSurvole() {
        var detecteur = BounceDetector()
        var releves = [releve([900]), releve([900])]
        // Le Dock se masque : les icônes glissent hors de l'écran.
        releves += Array(repeating: releve([970], visibles: false), count: 5)
        // Survol : il remonte, reste déployé, puis se masque de nouveau. C'est un
        // aller-retour parfait — seule la visibilité le distingue d'un rebond.
        releves += Array(repeating: releve([900], sourisSurLeDock: true), count: 8)
        releves += Array(repeating: releve([970], visibles: false), count: 5)
        #expect(rejouer(&detecteur, releves).isEmpty)
    }

    @Test("Un Dock masqué ne sert jamais de position de repos")
    func positionMasqueeJamaisPriseCommeRepos() {
        var detecteur = BounceDetector()
        // Sans la garde de visibilité, le y hors écran deviendrait la référence
        // et la remontée suivante passerait pour un saut de 70 points.
        var releves = [releve([900]), releve([900])]
        releves += Array(repeating: releve([970], visibles: false), count: 20)
        releves += Array(repeating: releve([900]), count: 3)
        #expect(rejouer(&detecteur, releves).isEmpty)
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
