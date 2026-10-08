import Foundation

/// L'API publique de DofusDB, la seule source réseau de Synfus : carte,
/// quêtes, indices de chasse et classes en viennent. Une requête, la pagination et la
/// péremption des listes gardées, écrites une fois.
enum DofusDB {
    struct Page<Element: Decodable>: Decodable {
        let total: Int
        let data: [Element]
    }

    /// Un nom traduit tel que l'API le donne ; Synfus ne parle que fr, en et es.
    struct Noms: Codable, Sendable {
        let fr: String?
        let en: String?
        let es: String?

        var parLangue: [String: String] {
            ["fr": fr, "en": en, "es": es].compactMapValues { $0 }
        }
    }

    /// Les listes du jeu — zaaps, indices — changent aux mises à jour, quelques
    /// fois par an.
    static let peremption: TimeInterval = 30 * 24 * 3600
    /// Le plafond de page de l'API.
    static let parPage = 50
    private static let api = URL(string: "https://api.dofusdb.fr")!

    /// Les seuls champs à rendre : les sous-zones portent la liste de leurs
    /// cartes, dix fois plus lourde que ce qu'on en lit.
    static func selection(_ champs: [String]) -> [URLQueryItem] {
        champs.map { URLQueryItem(name: "$select[]", value: $0) }
    }

    /// La vue d'une carte du jeu, en demi-taille (`ImagesDofusDB` la garde).
    static func imageCarte(_ carte: Int) -> URL {
        api.appending(path: "img/maps/0.5/\(carte).jpg")
    }

    /// L'emblème d'une classe, par son identifiant DofusDB (`ImagesDofusDB` le garde).
    static func emblemeClasse(_ classe: Int) -> URL {
        api.appending(path: "img/breeds/symbol_\(classe).png")
    }

    /// Jamais téléchargée (`nil`), ou trop vieille.
    static func perimee(depuis date: Date?, maintenant: Date) -> Bool {
        guard let date else { return true }
        return maintenant.timeIntervalSince(date) > peremption
    }

    static func page<Element: Decodable>(_ chemin: String, _ filtres: [URLQueryItem]) async throws -> Page<Element> {
        var url = URLComponents(url: api.appending(path: chemin), resolvingAgainstBaseURL: false)!
        url.queryItems = filtres
        let (donnees, reponse) = try await URLSession.shared.data(from: url.url!)
        if let http = reponse as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Page<Element>.self, from: donnees)
    }

    /// Toutes les pages, plusieurs à la fois : la première dit le total, les
    /// autres partent ensemble, `simultanees` au plus — pour les grandes
    /// listes (quêtes), qu'une page à la fois ferait attendre une minute.
    static func toutesEnParallele<Element: Decodable & Sendable>(
        _ chemin: String, _ filtres: [URLQueryItem], simultanees: Int = 6
    ) async throws -> [Element] {
        func pageA(_ debut: Int) async throws -> Page<Element> {
            try await page(chemin, filtres + [URLQueryItem(name: "$limit", value: "\(parPage)"),
                                              URLQueryItem(name: "$skip", value: "\(debut)")])
        }
        let premiere = try await pageA(0)
        let debuts = Array(stride(from: parPage, to: premiere.total, by: parPage))
        var pages: [Int: [Element]] = [0: premiere.data]
        try await withThrowingTaskGroup(of: (Int, [Element]).self) { groupe in
            var suivant = 0
            func lancer() {
                guard suivant < debuts.count else { return }
                let debut = debuts[suivant]
                suivant += 1
                groupe.addTask { (debut, try await pageA(debut).data) }
            }
            for _ in 0..<simultanees { lancer() }
            while let (debut, elements) = try await groupe.next() {
                pages[debut] = elements
                lancer()
            }
        }
        return pages.keys.sorted().flatMap { pages[$0] ?? [] }
    }

    /// Toutes les pages, `parPage` à la fois.
    static func toutes<Element: Decodable>(_ chemin: String, _ filtres: [URLQueryItem]) async throws -> [Element] {
        var elements: [Element] = []
        while true {
            let page: Page<Element> = try await page(
                chemin, filtres + [URLQueryItem(name: "$limit", value: "\(parPage)"),
                                   URLQueryItem(name: "$skip", value: "\(elements.count)")])
            elements += page.data
            if page.data.isEmpty || elements.count >= page.total { return elements }
        }
    }
}
