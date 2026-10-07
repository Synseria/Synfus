import Foundation

/// L'API publique de DofusDB, la seule source réseau de Synfus : zaaps et
/// indices de chasse en viennent. Une requête, la pagination et la
/// péremption des listes gardées, écrites une fois.
enum DofusDB {
    struct Page<Element: Decodable>: Decodable {
        let total: Int
        let data: [Element]
    }

    /// Un nom traduit tel que l'API le donne ; Synfus ne parle que fr, en et es.
    struct Noms: Decodable, Sendable {
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
