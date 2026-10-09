import Testing
import Foundation
import AppKit
@testable import Synfus

/// Le localisateur sur une **vraie** capture, hors dépôt : le chemin vient de
/// `SYNFUS_CAPTURE`, le test est ignoré sans elle. C'est le banc de calibrage
/// des seuils, à lancer à la main :
///
///     SYNFUS_CAPTURE=~/Library/Logs/Synfus/captures/x.png sh test.sh RealCapture
///
/// Une capture du calibrage (`~/Library/Caches/Synfus/Calibrage/<genre>.png`)
/// est déjà le contenu à l'échelle de la lecture : `SYNFUS_PLEIN_ECRAN=1`.
/// `SYNFUS_ZONE=x,y,l,h` (fractions) remplace la zone par défaut.
struct RealCaptureTests {
    static var capturePath: String? { ProcessInfo.processInfo.environment["SYNFUS_CAPTURE"] }

    private static var zoneImposee: ZoneEcran? {
        guard let texte = ProcessInfo.processInfo.environment["SYNFUS_ZONE"] else { return nil }
        let v = texte.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
        return v.count == 4 ? ZoneEcran(x: v[0], y: v[1], largeur: v[2], hauteur: v[3]) : nil
    }

    /// La zone du genre, ou la capture telle quelle avec `SYNFUS_ZONE_ENTIERE=1`
    /// (déjà recadrée sur l'élément).
    private func zoneLue(_ parDefaut: ZoneEcran) throws -> CGImage {
        guard ProcessInfo.processInfo.environment["SYNFUS_ZONE_ENTIERE"] == "1" else {
            return try zoneCapturee(Self.zoneImposee ?? parDefaut)
        }
        let chemin = try #require(Self.capturePath)
        return try #require(SimulationCapture.charger(chemin))
    }

    /// Ce que fait la capture de la lecture de l'écran, rejoué sur un PNG de
    /// fenêtre en Retina (`SimulationCapture`), sans barre de titre sauf
    /// `SYNFUS_PLEIN_ECRAN=1`.
    private func zoneCapturee(_ zone: ZoneEcran) throws -> CGImage {
        let chemin = try #require(Self.capturePath)
        let pleine = try #require(SimulationCapture.charger(chemin))
        let pleinEcran = ProcessInfo.processInfo.environment["SYNFUS_PLEIN_ECRAN"] == "1"
        let image = try #require(SimulationCapture.zone(zone, dans: pleine, pleinEcran: pleinEcran))
        Sortie.dire("zone \(image.width) × \(image.height) px")
        return image
    }

    @Test("La position est lue sur la capture fournie", .enabled(if: capturePath != nil))
    func positionSurCaptureReelle() async throws {
        let image = try zoneLue(.positionParDefaut)
        let moteur = MoteurOCR()
        await moteur.prechauffer()
        guard case .lue(let signature, let lignes, let duree, _) = await moteur.lire(image: image, precedente: nil, mesure: .zone)
        else { Issue.record("rien lu"); return }
        Sortie.dire("OCR \(Int(duree * 1000)) ms : \(lignes)")
        let position = PositionCarte.lire(lignes)
        Sortie.dire("position : \(position?.coordonnees ?? "—") — \(position?.zone ?? "—")")
        #expect(position != nil)
        // La même image ne repasse pas par l'OCR.
        guard case .inchangee = await moteur.lire(image: image, precedente: signature, mesure: .zone) else {
            Issue.record("la signature n'a pas reconnu la même image"); return
        }
    }

    @Test("L'état de combat est lu sur la capture fournie", .enabled(if: capturePath != nil))
    func combatSurCaptureReelle() async throws {
        let image = try zoneLue(.combatParDefaut)
        let moteur = MoteurOCR()
        await moteur.prechauffer()
        guard case .lue(let signature, let lignes, let duree, let bouton) = await moteur.lire(image: image, precedente: nil, mesure: .bouton)
        else { Issue.record("rien lu"); return }
        let constat = LectureCombat.classer(lignes: lignes, couleur: bouton ?? signature.couleur ?? 0)
        Sortie.dire("OCR \(Int(duree * 1000)) ms : \(lignes) — zone colorée \(Int((signature.couleur ?? 0) * 100)) %, bouton \(bouton.map { "\(Int($0 * 100)) %" } ?? "—") → \(constat)")
        if let attendu = ProcessInfo.processInfo.environment["SYNFUS_COMBAT_ATTENDU"] {
            #expect("\(constat.genre)" == attendu)
        }
    }

    /// `SYNFUS_QUETES_ATTENDUES="Pense-bête|La voie du guerrier"` : les noms
    /// français attendus, dans l'ordre. Les quêtes sont celles que l'app a
    /// téléchargées (`~/Library/Application Support/Synfus/Quetes.json`).
    @Test("Le suivi de quêtes est lu sur la capture fournie", .enabled(if: capturePath != nil))
    func suiviQuetesSurCaptureReelle() async throws {
        let image = try zoneLue(.quetesParDefaut)
        let quetes = try #require(QuetesDofusDB.gardees(), "aucune quête gardée : ouvrir une fois la palette de l'app")
        let moteur = MoteurOCR()
        await moteur.prechauffer()
        guard case .lue(let signature, let lignes, let duree, _) = await moteur.lire(image: image, precedente: nil, mesure: .lignes)
        else { Issue.record("rien lu"); return }
        Sortie.dire("OCR \(Int(duree * 1000)) ms : \(lignes) — cadre \(signature.cadre.map { "\($0)" } ?? "—")"
              + "\(signature.auBord ? ", au bord" : ""), \(signature.empreinte.cases.count(where: \.self)) cases allumées")
        // La même image ne repasse pas par l'OCR.
        guard case .inchangee = await moteur.lire(image: image, precedente: signature, mesure: .lignes) else {
            Issue.record("la signature n'a pas reconnu la même image"); return
        }
        let debut = Date()
        let index = SuiviQuetes.Index(quetes)
        let indexe = Date()
        let reconnues = SuiviQuetes.reconnaitre(lignes, coupe: signature.auBord, dans: index).reconnues
        let noms = reconnues.map { reconnue in
            quetes.quetes.first { $0.id == reconnue.id }.flatMap { Lieu.traduit($0.noms, .fr) } ?? "#\(reconnue.id)"
        }
        Sortie.dire("index en \(Int(indexe.timeIntervalSince(debut) * 1000)) ms, reconnues en "
              + "\(Int(Date().timeIntervalSince(indexe) * 1000)) ms : "
              + zip(noms, reconnues).map {
                  "\($0) (étape \($1.etape.map { String($0 + 1) } ?? "—"), à faire \($1.aFaire), faits \($1.faits), "
                  + "non montrés \($1.nonMontres))"
              }.joined(separator: ", "))
        if let attendues = ProcessInfo.processInfo.environment["SYNFUS_QUETES_ATTENDUES"] {
            #expect(noms == attendues.split(separator: "|").map(String.init))
        }
    }
}
