import Foundation

// SynfusDeck — le plugin Stream Deck de Synfus.
//
// Lancé par le logiciel Elgato avec `-port -pluginUUID -registerEvent -info`,
// il s'enregistre sur son WebSocket local, puis se connecte au socket Unix de
// Synfus pour recevoir l'état (perso actif, barre, sorts, touches) et afficher
// les icônes. À l'appui d'une touche de sort, **c'est lui** qui frappe la
// touche du jeu — Synfus, lui, n'émet jamais d'évènement. Une pression, une
// frappe : le Stream Deck est un clavier de plus, rien n'est rejoué.

@main
struct SynfusDeck {
    static func main() async {
        let arguments = Arguments(CommandLine.arguments)
        guard let port = arguments["-port"].flatMap(Int.init),
              let pluginUUID = arguments["-pluginUUID"],
              let registerEvent = arguments["-registerEvent"]
        else {
            FileHandle.standardError.write(Data("SynfusDeck : à lancer par le logiciel Stream Deck.\n".utf8))
            exit(2)
        }
        await Plugin.shared.start(port: port, pluginUUID: pluginUUID, registerEvent: registerEvent)
        // Le processus vit tant que le logiciel Stream Deck le garde.
        while true { try? await Task.sleep(for: .seconds(3600)) }
    }
}

/// `-clé valeur` → dictionnaire.
struct Arguments {
    private let values: [String: String]

    init(_ arguments: [String]) {
        var values: [String: String] = [:]
        var iterator = arguments.dropFirst().makeIterator()
        while let key = iterator.next() {
            guard key.hasPrefix("-"), let value = iterator.next() else { continue }
            values[key] = value
        }
        self.values = values
    }

    subscript(key: String) -> String? { values[key] }
}
