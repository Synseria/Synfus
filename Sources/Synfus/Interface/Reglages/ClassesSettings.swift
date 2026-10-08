import SwiftUI
import UniformTypeIdentifiers

/// Onglet Classes : la liste tirée de DofusDB et l'icône de chaque classe —
/// l'emblème de DofusDB, ou celle de l'utilisateur, qui prime.
struct ClassesSettings: View {
    @ObservedObject private var icons = ClassesStore.shared

    var body: some View {
        PageReglages(titre: L("reglages.classes"), sousTitre: L("classes.sousTitre")) {
            Section {
                SourceClasses()
                Ligne(titre: L("classes.dossier"), sousTexte: L("classes.mentionAnkama")) {
                    HStack(spacing: 8) {
                        Button(L("classes.recharger")) { icons.reloadAll() }
                        Button(L("classes.ouvrirDossier")) { NSWorkspace.shared.open(icons.directory) }
                    }
                }
                ForEach(icons.catalogue.breeds) { breed in
                    classRow(breed)
                }
            } header: {
                SectionTitle(L("classes.icones"), help: L("classes.icones.aide"))
            }
        }
    }

    private func classRow(_ breed: DofusClass.Breed) -> some View {
        let custom = icons.icon(forKey: breed.key)
        let provenance = icons.provenance(forKey: breed.key)

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
                    Text(icons.catalogue.abbreviation(for: breed.label))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 24, height: 24)

            Text(breed.nomLocalise)

            Spacer()

            if custom != nil, let provenance {
                Text(provenance == .tienne ? L("classes.provenance.tienne") : L("classes.provenance.dofusdb"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            if provenance == .tienne {
                Button(L("classes.retirer")) { icons.removeIcon(forKey: breed.key) }
            }
            Button(custom == nil ? L("classes.choisir") : L("classes.remplacer")) { chooseIcon(for: breed) }
        }
        .padding(.vertical, 1)
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            drop(providers, for: breed)
        }
    }

    private func chooseIcon(for breed: DofusClass.Breed) {
        let panel = NSOpenPanel()
        panel.title = L("classes.iconePour", breed.nomLocalise)
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
