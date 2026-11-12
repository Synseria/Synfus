import SwiftUI
import UniformTypeIdentifiers

/// Les classes, dans la page des personnages : la liste tirée de DofusDB et l'icône de chaque classe —
/// l'emblème de DofusDB, ou celle de l'utilisateur, qui prime.
struct BlocsClasses: View {
    @ObservedObject private var icons = ClassesStore.shared

    var body: some View {
        Bloc(L("reglages.classes"), aide: L("classes.icones.aide"), paresseux: true) {
            SourceClasses()
            Ligne(titre: L("classes.dossier")) {
                HStack(spacing: Jetons.Espace.deux) {
                    Button(L("classes.recharger")) { icons.reloadAll() }
                    Button(L("classes.ouvrirDossier")) { NSWorkspace.shared.open(icons.directory) }
                }
            }
            ForEach(icons.catalogue.breeds) { breed in
                classRow(breed)
            }
            Text(L("classes.mentionAnkama"))
                .font(Jetons.Typo.petit.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
                .rangee()
        } entete: {
            Text(L("classes.maj.contenu", icons.catalogue.breeds.count))
                .font(Jetons.Typo.note.police)
                .foregroundStyle(Color.jeton(\.encreSecondaire))
        }
    }

    private func classRow(_ breed: DofusClass.Breed) -> some View {
        let custom = icons.icon(forKey: breed.key)
        let provenance = icons.provenance(forKey: breed.key)

        return HStack(spacing: Jetons.Espace.deux) {
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
                        .font(Jetons.Typo.raccourci.police)
                        .foregroundStyle(Color.texteSurClasse)
                }
            }
            .frame(width: Jetons.Taille.cibleMin, height: Jetons.Taille.cibleMin)

            Text(breed.nomLocalise)

            Spacer()

            if custom != nil, let provenance {
                Text(provenance == .tienne ? L("classes.provenance.tienne") : L("classes.provenance.dofusdb"))
                    .font(Jetons.Typo.petit.police)
                    .foregroundStyle(Color.jeton(\.encreSecondaire))
            }
            // Retirer n'existe que s'il y a une icône posée à retirer.
            if custom != nil, provenance == .tienne {
                Button(L("classes.retirer")) { icons.removeIcon(forKey: breed.key) }
            }
            Button(custom == nil ? L("classes.choisir") : L("classes.remplacer")) { chooseIcon(for: breed) }
        }
        .rangee()
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
