// Un « Un grand + vignettes » posé par Synfus, et ce qu'en fait une bascule. Pur : les cadres
// lus arrivent de `WindowArranger`, qui seul touche l'Accessibilité.

import CoreGraphics

/// La place de chaque fenêtre d'un rangement `.principale`, et laquelle est le grand. Quand
/// Synfus amène un perso devant, il prend la place du grand et l'ancien grand prend la sienne ;
/// un clic sur une fenêtre ne passe jamais par ici. La disposition ne vaut que tant que les
/// fenêtres sont où Synfus les a laissées : une fenêtre déplacée ou redimensionnée à la main,
/// passée en plein écran, sur un autre bureau ou fermée, et elle est abandonnée — l'utilisateur
/// a repris la main, Synfus ne la lui reprend pas.
struct AgencementPrincipal: Equatable {
    /// `voulu` : le cadre que la disposition donne à cette place, celui qu'on échange.
    /// `lu` : celui que la fenêtre a pris — un client peut plafonner une taille, et c'est ce
    /// cadre-là qui dit si elle a bougé depuis.
    struct Place: Equatable {
        var voulu: CGRect
        var lu: CGRect
    }

    struct Permutation: Equatable {
        let amene: String
        let cadreAmene: CGRect
        let ancienGrand: String
        let cadreAncienGrand: CGRect
    }

    enum Suite: Equatable {
        /// Déjà le grand, ou hors de la disposition (autre équipe, écarté au rangement).
        case rien
        case permuter(Permutation)
        /// Une des deux fenêtres n'est plus à sa place : la disposition n'est plus en cours.
        case abandonner
    }

    /// Écart toléré entre un cadre relu et celui qu'on attend : l'arrondi d'un client, pas un
    /// geste de l'utilisateur.
    static let tolerance: CGFloat = 4

    /// Clé : `DofusClient.slotKey`.
    private(set) var places: [String: Place]
    private(set) var grand: String

    /// `nil` si le grand n'a pas de place : sans lui, rien à échanger.
    init?(places: [String: Place], grand: String) {
        guard places[grand] != nil else { return nil }
        self.places = places
        self.grand = grand
    }

    /// Ce que fait une bascule de Synfus vers `cle`. `lus` : les cadres relus à l'instant ; une
    /// fenêtre absente est une fenêtre qu'on ne peut plus lire.
    func suite(amene cle: String, lus: [String: CGRect]) -> Suite {
        guard estVignette(cle), let placeAmenee = places[cle], let placeGrand = places[grand] else { return .rien }
        guard let luAmene = lus[cle], let luGrand = lus[grand],
              Self.proches(luAmene, placeAmenee.lu), Self.proches(luGrand, placeGrand.lu)
        else { return .abandonner }
        return .permuter(Permutation(amene: cle, cadreAmene: placeGrand.voulu,
                                     ancienGrand: grand, cadreAncienGrand: placeAmenee.voulu))
    }

    /// Une bascule vers `cle` déplacerait des fenêtres : de quoi décider avant toute lecture AX.
    func estVignette(_ cle: String) -> Bool { cle != grand && places[cle] != nil }

    /// L'agencement une fois la permutation posée ; `lus` : les cadres relus après la pose.
    /// `nil` si une des deux fenêtres n'a pu être relue.
    func apres(_ permutation: Permutation, lus: [String: CGRect]) -> AgencementPrincipal? {
        guard let luAmene = lus[permutation.amene], let luAncien = lus[permutation.ancienGrand]
        else { return nil }
        var suivant = self
        suivant.places[permutation.amene] = Place(voulu: permutation.cadreAmene, lu: luAmene)
        suivant.places[permutation.ancienGrand] = Place(voulu: permutation.cadreAncienGrand, lu: luAncien)
        suivant.grand = permutation.amene
        return suivant
    }

    private static func proches(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
