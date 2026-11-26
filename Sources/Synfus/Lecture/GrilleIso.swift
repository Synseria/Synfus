import CoreGraphics

/// La grille isométrique du jeu, seul foyer de la conversion case ↔ point :
/// une case est un losange de demi-largeur `a` et de demi-hauteur `a/2`,
/// x vers le bas à droite, y vers le bas à gauche (le repère de `Harebourg`).
/// Les statiques travaillent en points ; une instance est la grille du combat
/// calibrée sur le contenu de la fenêtre du jeu, en fractions. Pur.
struct GrilleIso: Codable, Equatable, Sendable {
    struct Case: Hashable, Codable, Sendable {
        var x: Int
        var y: Int

        init(_ x: Int, _ y: Int) {
            self.x = x
            self.y = y
        }

        static func + (a: Case, b: Case) -> Case { Case(a.x + b.x, a.y + b.y) }
        static func - (a: Case, b: Case) -> Case { Case(a.x - b.x, a.y - b.y) }
    }

    /// Le centre de la case (0, 0), en fractions du contenu.
    var origine: CGPoint
    /// La demi-largeur `a` d'une case, en fraction de la **hauteur** du contenu :
    /// le jeu met son plateau à l'échelle de la hauteur.
    var demiLargeur: Double
    /// Largeur sur hauteur du contenu au calibrage : le jeu recadre son plateau
    /// quand le rapport change, la grille ne vaut plus.
    var rapport: Double

    /// Écart de rapport toléré (une fenêtre redimensionnée d'un point ou deux).
    static let toleranceRapport = 0.01

    // MARK: - En points

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

    // MARK: - Sur le contenu

    /// La demi-largeur en points d'un contenu de cette taille.
    func a(_ contenu: CGSize) -> CGFloat { CGFloat(demiLargeur) * contenu.height }

    private func centreOrigine(_ contenu: CGSize) -> CGPoint {
        CGPoint(x: origine.x * contenu.width, y: origine.y * contenu.height)
    }

    /// La case sous un point donné en fractions du contenu.
    func caseSous(fraction p: CGPoint, contenu: CGSize) -> Case {
        let point = CGPoint(x: p.x * contenu.width, y: p.y * contenu.height)
        let (x, y) = Self.caseSous(point, a: a(contenu), centre: centreOrigine(contenu))
        return Case(x, y)
    }

    /// Le centre de la case, en points du contenu (origine en haut à gauche).
    func centre(_ c: Case, contenu: CGSize) -> CGPoint {
        Self.projeter(c.x, c.y, a: a(contenu), centre: centreOrigine(contenu))
    }

    /// Les sommets de la case, en points du contenu.
    func losange(_ c: Case, contenu: CGSize) -> [CGPoint] {
        Self.losange(c.x, c.y, a: a(contenu), centre: centreOrigine(contenu))
    }

    /// La grille vaut-elle pour un contenu de cette taille ?
    func valable(pour contenu: CGSize) -> Bool {
        guard contenu.width > 0, contenu.height > 0, rapport > 0 else { return false }
        return abs(Double(contenu.width / contenu.height) / rapport - 1) <= Self.toleranceRapport
    }

    /// La grille de deux centres de cases cliqués, `ecart` étant B moins A en
    /// cases : `a` par moindres carrés sur les deux axes, origine en A. `nil`
    /// si l'écart est nul, la case minuscule, ou si le tracé n'est pas celui
    /// d'une grille 2:1 (pente à plus de 25 % de l'attendue).
    static func depuis(centreA: CGPoint, centreB: CGPoint, ecart: Case, contenu: CGSize) -> GrilleIso? {
        guard contenu.width > 0, contenu.height > 0 else { return nil }
        let dx = (centreB.x - centreA.x) * contenu.width
        let dy = (centreB.y - centreA.y) * contenu.height
        // Par case de `a` : dx = (ex − ey)·a, dy = (ex + ey)·a/2.
        let u = CGFloat(ecart.x - ecart.y), v = CGFloat(ecart.x + ecart.y) / 2
        let norme = u * u + v * v
        guard norme > 0 else { return nil }
        let a = (dx * u + dy * v) / norme
        guard a >= 4 else { return nil }
        let residu = hypot(dx - u * a, dy - v * a)
        guard residu <= 0.25 * a * sqrt(norme) else { return nil }
        return GrilleIso(origine: centreA, demiLargeur: Double(a / contenu.height),
                         rapport: Double(contenu.width / contenu.height))
    }
}
