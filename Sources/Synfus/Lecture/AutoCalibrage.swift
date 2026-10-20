import CoreGraphics
import Foundation

/// Calibrer les zones d'un coup : une capture du contenu entier du perso
/// devant, son OCR, et `DetectionZones`. Les zones trouvées remplacent les
/// réglages et leur capture est gardée — le calibrage à la main repart d'elle ;
/// un élément absent de l'écran (combat, chasse) garde la sienne.
@MainActor
enum AutoCalibrage {
    /// Le temps de revenir au jeu et d'y ouvrir l'élément.
    static let delai = 5

    /// Le décompte avant une capture, seconde par seconde ; `false` s'il a été
    /// annulé (la tâche).
    static func decompter(tic: (Int?) -> Void) async -> Bool {
        for reste in stride(from: delai, to: 0, by: -1) {
            tic(reste)
            try? await Task.sleep(for: .seconds(1))
            if Task.isCancelled { tic(nil); return false }
        }
        tic(nil)
        return true
    }

    /// La capture du calibrage — le contenu entier, sans barre de titre, à
    /// l'échelle de la lecture : le repère des zones et ce que l'OCR recevra.
    /// Le perso devant, celui où l'on vient d'ouvrir l'élément, sinon celui
    /// qui a une fenêtre à l'écran. Le seul chemin des captures de calibrage.
    static func capturer() async -> Result<CGImage, Echec> {
        let manager = WindowManager.shared
        guard let client = manager.clients.first(where: { manager.isFrontmost($0) })
                ?? manager.clients.first(where: { !$0.dormant }) ?? manager.clients.first
        else { return .failure(Echec(L("calibration.aucunPerso"))) }
        guard let image = await WindowPreviewService.shared.captureImage(
            client, region: ZoneEcran.entiere.rect, maxWidth: nil, inventaireGarde: false,
            contenu: CaptureContenu(pleinEcran: client.pleinEcran, normaliser: true))
        else { return .failure(Echec(WindowPreviewService.shared.lastCaptureError ?? L("calibration.echec"))) }
        return .success(image)
    }

    struct Echec: Error {
        let message: String
        init(_ message: String) { self.message = message }
    }

    /// Les zones des éléments que montre la capture.
    static func detecter(sur image: CGImage) async -> [GenreLecture: ZoneEcran] {
        let textes = await LecteurEcran.shared.textes(image: image)
        let lignes = textes.map(\.texte)
        let titres = await LectureSuivi.shared.rangsDeTitres(lignes)
        let indices = await ChasseModele.shared.rangsDIndices(lignes)
        return DetectionZones.detecter(textes, titres: titres, indices: indices)
    }

    /// Pose les zones trouvées, en une écriture, et garde la capture de
    /// chacune hors du fil principal (un PNG par genre).
    static func appliquer(_ zones: [GenreLecture: ZoneEcran], capture image: CGImage) {
        let prefs = Preferences.shared
        prefs.enUneEcriture {
            for (genre, zone) in zones { prefs[keyPath: genre.reglage] = zone }
        }
        let genres = Array(zones.keys)
        Task.detached(priority: .utility) {
            for genre in genres { try? CapturesCalibrage.garder(image, pour: genre) }
        }
    }
}
