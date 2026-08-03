import Testing
import Foundation
@testable import Synfus

/// Retrouver la fenêtre capturable d'un client est une hypothèse, comme
/// l'appariement des icônes du Dock : aucune API publique ne relie un
/// `AXUIElement` à une fenêtre de ScreenCaptureKit. On la teste donc à part.
struct WindowPreviewMatchTests {

    private typealias Candidat = WindowPreviewService.Candidate

    @Test("Le couple pid + titre désigne la fenêtre sans ambiguïté")
    func pidEtTitre() {
        let candidats = [
            Candidat(pid: 42, title: "Syn-App - Feca - 3.6.7.7 - Release"),
            Candidat(pid: 42, title: "Autre - Iop - 3.6.7.7 - Release"),
            Candidat(pid: 99, title: "Safari"),
        ]
        #expect(WindowPreviewService.match(
            pid: 42, title: "Autre - Iop - 3.6.7.7 - Release", among: candidats) == 1)
    }

    @Test("Un titre devenu obsolète se rattrape si le processus n'a qu'une fenêtre")
    func titrePerimeMaisFenetreUnique() {
        // Le titre change à la reconnexion ou au changement de perso, entre
        // l'inventaire et la capture.
        let candidats = [
            Candidat(pid: 42, title: "Syn-App - Feca - 3.6.7.8 - Release"),
            Candidat(pid: 99, title: "Safari"),
        ]
        #expect(WindowPreviewService.match(
            pid: 42, title: "Syn-App - Feca - 3.6.7.7 - Release", among: candidats) == 0)
    }

    @Test("Deux fenêtres du même processus et aucun titre qui colle : on renonce")
    func ambiguiteNonTranchee() {
        // Mieux vaut aucun aperçu que l'aperçu du mauvais perso.
        let candidats = [
            Candidat(pid: 42, title: "Un - Feca - 3.6.7.7 - Release"),
            Candidat(pid: 42, title: "Deux - Iop - 3.6.7.7 - Release"),
        ]
        #expect(WindowPreviewService.match(pid: 42, title: "Trois", among: candidats) == nil)
    }

    @Test("Aucune fenêtre du processus : aucun appariement")
    func aucunCandidat() {
        #expect(WindowPreviewService.match(
            pid: 42, title: "Syn-App", among: [Candidat(pid: 99, title: "Safari")]) == nil)
    }

    @Test("Une fenêtre sans titre reste appariable par son processus")
    func fenetreSansTitre() {
        #expect(WindowPreviewService.match(
            pid: 42, title: "Syn-App", among: [Candidat(pid: 42, title: nil)]) == 0)
    }
}
