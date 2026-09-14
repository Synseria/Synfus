import SwiftUI
import UniformTypeIdentifiers

/// Onglet Classes : icônes fournies par l'utilisateur, une par classe.
struct ClassesSettings: View {
    @ObservedObject private var icons = ClassIconStore.shared

    /// Synfus n'embarque aucune image de classe : les portraits du jeu
    /// appartiennent à Ankama. Chacun met donc les siennes, par glisser-déposer
    /// ou en remplissant le dossier à la main.
    var body: some View {
        Form {
            Section {
                Text("Chaque classe peut recevoir l'image de ton choix : un portrait, "
                     + "une capture d'écran, n'importe quel PNG ou JPEG. Sans image, "
                     + "Synfus affiche la pastille colorée.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Ouvrir le dossier") { NSWorkspace.shared.open(icons.directory) }
                    Button("Recharger") { icons.reloadAll() }
                    Spacer()
                }
                .font(.system(size: 11))

                Text("Tu peux aussi y déposer les fichiers directement, nommés d'après "
                     + "la classe : iop.png, cra.png, xelor.png… puis « Recharger ».")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Emblèmes officiels") {
                Text("Le script Tools/fetch-class-icons.sh du dépôt remplit ce dossier "
                     + "avec les emblèmes des 19 classes. Synfus ne redistribue aucune "
                     + "image du jeu : c'est ta machine qui les télécharge, pour ton "
                     + "usage personnel.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Text("Certaines illustrations sont la propriété d'Ankama Studio et de "
                     + "Dofus — Tous droits réservés.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Section("Icônes") {
                ForEach(DofusClass.breeds) { breed in
                    classRow(breed)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func classRow(_ breed: DofusClass.Breed) -> some View {
        let custom = icons.icon(forKey: breed.key)

        return HStack(spacing: 10) {
            ZStack {
                if let custom {
                    Image(nsImage: custom)
                        .resizable()
                        .interpolation(.high)
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Circle().fill(breed.color)
                    Text(String(breed.key.prefix(2)).capitalized)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)

            Text(breed.label)

            Spacer()

            if custom != nil {
                Button("Retirer") { icons.removeIcon(forKey: breed.key) }
                    .font(.system(size: 11))
            }
            Button(custom == nil ? "Choisir…" : "Remplacer…") { chooseIcon(for: breed) }
                .font(.system(size: 11))
        }
        .padding(.vertical, 1)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            drop(providers, for: breed)
        }
    }

    private func chooseIcon(for breed: DofusClass.Breed) {
        let panel = NSOpenPanel()
        panel.title = "Icône pour \(breed.label)"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        if !icons.setIcon(from: url, forKey: breed.key) {
            NSSound.beep()
        }
    }

    private func drop(_ providers: [NSItemProvider], for breed: DofusClass.Breed) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in
                if !icons.setIcon(from: url, forKey: breed.key) { NSSound.beep() }
            }
        }
        return true
    }
}
