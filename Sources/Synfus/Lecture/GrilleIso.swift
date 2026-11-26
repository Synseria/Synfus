import CoreGraphics

/// La grille isométrique du jeu, seul foyer de la conversion case ↔ point :
/// une case est un losange de demi-largeur `a` et de demi-hauteur `a/2`,
/// x vers le bas à droite, y vers le bas à gauche (le repère de `Harebourg`).
/// Pur.
enum GrilleIso {
    /// Le centre de la case, la case (0, 0) étant centrée sur `centre`.
    static func projeter(_ x: Int, _ y: Int, a: CGFloat, centre: CGPoint) -> CGPoint {
        CGPoint(x: centre.x + CGFloat(x - y) * a, y: centre.y + CGFloat(x + y) * a / 2)
    }

    /// La case dont le losange contient le point. Dans le repère des cases,
    /// le losange est le carré `max(|dx|, |dy|) ≤ ½` : arrondir chaque
    /// coordonnée est exact.
    static func caseSous(_ point: CGPoint, a: CGFloat, centre: CGPoint) -> (x: Int, y: Int) {
        let u = (point.x - centre.x) / a        // x − y
        let v = (point.y - centre.y) / (a / 2)  // x + y
        return (Int(((u + v) / 2).rounded()), Int(((v - u) / 2).rounded()))
    }

    /// Les quatre sommets du losange de la case : haut, droite, bas, gauche.
    static func losange(_ x: Int, _ y: Int, a: CGFloat, centre: CGPoint) -> [CGPoint] {
        let p = projeter(x, y, a: a, centre: centre)
        return [CGPoint(x: p.x, y: p.y - a / 2), CGPoint(x: p.x + a, y: p.y),
                CGPoint(x: p.x, y: p.y + a / 2), CGPoint(x: p.x - a, y: p.y)]
    }
}
