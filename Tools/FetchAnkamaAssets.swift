import Foundation

// Télécharge les emblèmes des classes et les icônes de sorts dans
// Resources/Ankama/ — un dossier **ignoré par Git**.
//
// Synfus n'embarque et ne redistribue aucune image du jeu : les visuels de
// Dofus appartiennent à Ankama, et l'article 13.2 des CGU interdit de les
// distribuer sans accord écrit. Ce programme ne fait donc que *nommer* des
// adresses — c'est toi, joueur lié par ces CGU, qui déclenches la copie, vers
// ton seul disque, pour ton usage personnel. Rien n'est reversé au dépôt, et
// la CI, qui n'a pas ce dossier, produit des releases sans visuel Ankama.
//
//     Certaines illustrations sont la propriété d'Ankama Studio et de Dofus
//     — Tous droits réservés.
//
// La source est l'API communautaire DofusDB, non affiliée à Ankama : le CDN
// officiel refuse les accès directs (403). Elle est gracieusement offerte à
// la communauté — on la sollicite une fois, et ce qui est déjà là est laissé
// tel quel, sauf --force.
//
// Compilé avec DofusClass.swift par Tools/fetch-ankama-assets.sh : les clés de
// classe — donc les noms de fichiers — sont celles de l'app, sans copie.

private let api = URL(string: "https://api.dofusdb.fr")!
private let concurrency = 8

private struct Breed: Decodable {
    struct Name: Decodable { let fr: String }
    let id: Int
    let shortName: Name
    let breedSpellsId: [Int]
}

private struct Spell: Decodable {
    struct Name: Decodable { let fr: String }
    let id: Int
    let name: Name
    let img: String?
}

private struct Page<T: Decodable>: Decodable { let data: [T] }

/// Une variante : deux sorts interchangeables d'une classe. Le jeu en affiche
/// l'un ou l'autre — la barre d'un perso peut porter les deux dessins.
private struct Variant: Decodable {
    let breedId: Int
    let spellIds: [Int]
}

/// Les sorts « communs » (type 21 chez DofusDB) : ceux que tout joueur peut
/// poser dans sa barre — Libération, Cawotte, invocations… Pas ceux des
/// monstres, ni les sorts déclenchés.
private let commonSpellsType = 21
private let commonKey = "communs"

/// Une entrée de l'index `sorts.json`, celui que liront la reconnaissance des
/// sorts et le Stream Deck.
private struct SpellEntry: Encodable {
    let id: Int
    let nom: String
    let classe: String
    let fichier: String
}

private enum Erreur: Error, CustomStringConvertible {
    case http(Int, URL)
    case pasUnPNG(URL)
    case classeInconnue(String)
    case argument(String)

    var description: String {
        switch self {
        case .http(let code, let url): return "HTTP \(code) — \(url)"
        case .pasUnPNG(let url): return "la réponse n'est pas un PNG — \(url)"
        case .classeInconnue(let nom):
            return "classe « \(nom) » inconnue de DofusClass.swift — l'ajouter d'abord"
        case .argument(let a): return "argument inconnu : \(a)"
        }
    }
}

/// Un nom de fichier sûr : ni séparateur ni caractère réservé, les espaces en `_`.
private func cleanName(_ name: String) -> String {
    let forbidden = CharacterSet(charactersIn: "<>:\"/\\|?*")
    let cleaned = name.unicodeScalars.map { forbidden.contains($0) ? "" : String($0) }.joined()
    return cleaned.split(whereSeparator: \.isWhitespace).joined(separator: "_")
}

private struct Options {
    var force = false
    var liste = false
    var destination = URL(fileURLWithPath: "Resources/Ankama", isDirectory: true)
}

@main
struct FetchAnkamaAssets {
    static func main() async {
        do {
            try await run(options: try parse(CommandLine.arguments.dropFirst()))
        } catch {
            FileHandle.standardError.write(Data("\n❌ \(error)\n".utf8))
            exit(1)
        }
    }

    private static func parse(_ arguments: ArraySlice<String>) throws -> Options {
        var options = Options()
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--force": options.force = true
            case "--liste", "--list", "-n": options.liste = true
            case "--dest":
                guard let path = iterator.next() else { throw Erreur.argument("--dest sans chemin") }
                options.destination = URL(fileURLWithPath: path, isDirectory: true)
            case "-h", "--help":
                print("""
                Usage : ./Tools/fetch-ankama-assets.sh [--force] [--liste] [--dest DIR]
                  --force   remplace les fichiers déjà présents
                  --liste   montre ce qui serait fait, sans rien écrire
                  --dest    dossier de sortie (défaut : Resources/Ankama)
                """)
                exit(0)
            default: throw Erreur.argument(argument)
            }
        }
        return options
    }

    private static func run(options: Options) async throws {
        let session = URLSession.shared
        print("==> Destination : \(options.destination.path)")

        print("Récupération des classes…")
        let breeds = try await fetchJSON(Page<Breed>.self, from: api.appending(path: "breeds")
            .appending(queryItems: [URLQueryItem(name: "$limit", value: "50")]), session: session).data

        // La clé de fichier est celle de l'app — même pliage que `DofusClass.key(for:)`.
        // Les sorts d'une classe : ceux de la fiche de classe **et** leurs
        // variantes — le jeu affiche l'un ou l'autre dessin selon le choix du
        // joueur, la reconnaissance doit connaître les deux.
        print("Récupération des variantes et des sorts communs…")
        let variants = try await fetchAll(Variant.self, from: api.appending(path: "spell-variants"), session: session)
        let commons = try await fetchAll(Spell.self, from: api.appending(path: "spells")
            .appending(queryItems: [URLQueryItem(name: "typeId", value: "\(commonSpellsType)")]), session: session)
        var classes: [(key: String, breedId: Int, spellIds: [Int])] = []
        for breed in breeds {
            guard let key = DofusClass.key(for: breed.shortName.fr), DofusClass.breed(forKey: key) != nil
            else { throw Erreur.classeInconnue(breed.shortName.fr) }
            let ids = Set(breed.breedSpellsId + variants.filter { $0.breedId == breed.id }.flatMap(\.spellIds))
            classes.append((key, breed.id, ids.sorted()))
        }
        classes.append((commonKey, 0, commons.map(\.id).sorted()))
        let spellIDs = Array(Set(classes.flatMap(\.spellIds))).sorted()
        print("Classes : \(classes.count - 1) (+ communs) — sorts uniques : \(spellIDs.count)\n")

        var compteur = Compteur()

        print("Emblèmes des classes…")
        let classesDir = options.destination.appending(path: "Classes", directoryHint: .isDirectory)
        try await batches(classes.filter { $0.breedId > 0 }) { classe in
            let url = api.appending(path: "img/breeds/symbol_\(classe.breedId).png")
            return try await download(url, to: classesDir.appending(path: "\(classe.key).png"),
                                      options: options, session: session)
        } progress: { done, total, results in
            compteur.add(results)
            print("  \(done)/\(total)")
        }

        print("Fiches des sorts…")
        var spells: [Int: Spell] = [:]
        try await batches(spellIDs) { id in
            try await fetchJSON(Spell.self, from: api.appending(path: "spells/\(id)"), session: session)
        } progress: { done, total, results in
            for spell in results { spells[spell.id] = spell }
            print("  \(done)/\(total)")
        }

        print("Icônes des sorts…")
        var index: [SpellEntry] = []
        var downloads: [(spell: Spell, key: String, target: URL, fichier: String)] = []
        for classe in classes {
            let dir = options.destination.appending(path: "Sorts/\(classe.key)", directoryHint: .isDirectory)
            // Le nom du sort fait le nom du fichier — on veut pouvoir s'y retrouver
            // dans le dossier. Deux sorts de même nom dans une classe (ça arrive :
            // variantes) se distinguent par leur identifiant.
            let named = classe.spellIds.compactMap { id -> (Spell, String)? in
                guard let spell = spells[id], let img = spell.img, !img.isEmpty else { return nil }
                return (spell, cleanName(spell.name.fr))
            }
            var seen: [String: Int] = [:]
            for (_, name) in named { seen[name, default: 0] += 1 }
            for (spell, name) in named {
                let base = seen[name, default: 0] > 1 ? "\(name)_\(spell.id)" : name
                let fichier = "Sorts/\(classe.key)/\(base).png"
                downloads.append((spell, classe.key, dir.appending(path: "\(base).png"), fichier))
                index.append(SpellEntry(id: spell.id, nom: spell.name.fr, classe: classe.key, fichier: fichier))
            }
        }
        try await batches(downloads) { item in
            guard let url = URL(string: item.spell.img ?? "") else { return Resultat.echec }
            return try await download(url, to: item.target, options: options, session: session)
        } progress: { done, total, results in
            compteur.add(results)
            print("  \(done)/\(total)")
        }

        if !options.liste {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(index.sorted { ($0.classe, $0.id) < ($1.classe, $1.id) })
                .write(to: options.destination.appending(path: "sorts.json"), options: .atomic)
        }

        print("""

        Téléchargés : \(compteur.telecharges)
        Déjà présents : \(compteur.conserves)
        Échecs : \(compteur.echecs)
        \(options.liste ? "(simulation — rien n'a été écrit)" : "✓ Terminé → \(options.destination.path)")
        Relance ./build.sh --install pour embarquer les images, ou Réglages → Classes → Recharger.
        """)
        if compteur.echecs > 0 { exit(1) }
    }

    // MARK: - Téléchargement

    private enum Resultat { case telecharge, conserve, echec }

    private struct Compteur {
        var telecharges = 0, conserves = 0, echecs = 0
        mutating func add(_ results: [Resultat]) {
            for r in results {
                switch r {
                case .telecharge: telecharges += 1
                case .conserve: conserves += 1
                case .echec: echecs += 1
                }
            }
        }
    }

    /// Écrit d'abord un `.partiel` puis renomme : un téléchargement interrompu
    /// ne laisse jamais un PNG tronqué sous le nom définitif.
    private static func download(_ url: URL, to target: URL, options: Options,
                                 session: URLSession) async throws -> Resultat {
        let manager = FileManager.default
        if manager.fileExists(atPath: target.path), !options.force { return .conserve }
        if options.liste {
            print("    \(target.lastPathComponent)  ←  \(url)")
            return .telecharge
        }
        do {
            let data = try await fetchData(from: url, session: session)
            guard data.starts(with: [0x89, 0x50, 0x4E, 0x47]) else { throw Erreur.pasUnPNG(url) }
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            let partial = target.appendingPathExtension("partiel")
            try data.write(to: partial)
            _ = try? manager.removeItem(at: target)
            try manager.moveItem(at: partial, to: target)
            return .telecharge
        } catch {
            FileHandle.standardError.write(Data("    ✗ \(target.lastPathComponent) : \(error)\n".utf8))
            return .echec
        }
    }

    /// Toutes les pages d'une liste : l'API plafonne à 50 par réponse.
    private static func fetchAll<T: Decodable>(_ type: T.Type, from url: URL, session: URLSession) async throws -> [T] {
        var all: [T] = []
        var skip = 0
        while true {
            let page = try await fetchJSON(PagedList<T>.self, from: url.appending(queryItems: [
                URLQueryItem(name: "$limit", value: "50"), URLQueryItem(name: "$skip", value: "\(skip)"),
            ]), session: session)
            all += page.data
            skip += page.data.count
            if page.data.isEmpty || skip >= page.total { break }
        }
        return all
    }

    private struct PagedList<T: Decodable>: Decodable { let total: Int; let data: [T] }

    private static func fetchJSON<T: Decodable>(_ type: T.Type, from url: URL,
                                                session: URLSession) async throws -> T {
        try JSONDecoder().decode(type, from: try await fetchData(from: url, session: session))
    }

    /// Trois tentatives, à délai croissant — l'API communautaire a ses humeurs.
    private static func fetchData(from url: URL, session: URLSession) async throws -> Data {
        var lastError: Error = Erreur.http(0, url)
        for attempt in 1...3 {
            do {
                let (data, response) = try await session.data(from: url)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard (200..<300).contains(code) else { throw Erreur.http(code, url) }
                return data
            } catch {
                lastError = error
                if attempt < 3 { try await Task.sleep(for: .seconds(attempt)) }
            }
        }
        throw lastError
    }

    /// Lots de `concurrency` tâches parallèles, pour ne pas assaillir l'API.
    private static func batches<Item, Output: Sendable>(
        _ items: [Item],
        _ work: @escaping @Sendable (Item) async throws -> Output,
        progress: ([Output]) -> Void
    ) async throws where Item: Sendable {
        var done = 0
        for start in stride(from: 0, to: items.count, by: concurrency) {
            let batch = Array(items[start..<min(start + concurrency, items.count)])
            let results = try await withThrowingTaskGroup(of: Output.self) { group in
                for item in batch { group.addTask { try await work(item) } }
                var collected: [Output] = []
                for try await result in group { collected.append(result) }
                return collected
            }
            done += batch.count
            progress(results)
        }
    }

    private static func batches<Item, Output: Sendable>(
        _ items: [Item],
        _ work: @escaping @Sendable (Item) async throws -> Output,
        progress: (Int, Int, [Output]) -> Void
    ) async throws where Item: Sendable {
        var done = 0
        try await batches(items, work) { results in
            done += results.count
            progress(done, items.count, results)
        }
    }
}
