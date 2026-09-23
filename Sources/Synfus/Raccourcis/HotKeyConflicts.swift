import Foundation

/// Les combinaisons qu'on a données deux fois.
///
/// Le système refuse la seconde inscription d'une même combinaison
/// (`RegisterEventHotKey` rend une erreur), et elle atterrit dans
/// `HotKeyManager.rejected` — mais cette liste ne dit que la combinaison, pas
/// le geste qu'elle devait déclencher. L'utilisateur voyait donc son raccourci
/// affiché, bien en place dans les réglages, et sans effet, sans savoir lequel
/// des deux l'emportait.
///
/// Pure : on lui donne les combinaisons enregistrées, elle rend celles qui font
/// doublon. Les réglages marquent alors **chaque** ligne concernée.
enum HotKeyConflicts {

    /// Les combinaisons présentes plus d'une fois. Les emplacements vides
    /// (`nil`) ne comptent pas : ne pas avoir de raccourci n'est pas un
    /// conflit, même partagé.
    static func doublons(_ raccourcis: [HotKey?]) -> Set<HotKey> {
        var vues: Set<HotKey> = []
        var doubles: Set<HotKey> = []
        for raccourci in raccourcis.compactMap({ $0 }) {
            if !vues.insert(raccourci).inserted { doubles.insert(raccourci) }
        }
        return doubles
    }
}
