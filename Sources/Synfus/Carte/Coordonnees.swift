/// Une position telle qu'on la montre : `[x,y]`, comme le jeu l'écrit — collée
/// dans le chat, elle devient un lien vers la carte. Les commandes (`/travel`,
/// `/zaap`) gardent leur syntaxe, sans crochets (`ItineraireZaap`).
enum Coordonnees {
    static func texte(_ x: Int, _ y: Int) -> String { "[\(x),\(y)]" }
}
