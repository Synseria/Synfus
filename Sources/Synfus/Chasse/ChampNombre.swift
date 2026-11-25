import SwiftUI
import AppKit
import SynseriaDesign

/// Le champ nombre d'un axe du départ (X ou Y) : étiquette d'axe + champ entier
/// (nombre seul accepté) + stepper (flèches haut/bas) et roulette de la souris
/// pour incrémenter / décrémenter facilement.
struct ChampNombre: View {
    /// Les coordonnées d'une carte du Monde des Douze tiennent entre -100 et 100.
    static let minimum = -100
    static let maximum = 100

    /// Étiquette d'axe (« X »/« Y ») quand le champ en a une ; sans étiquette
    /// pour les deux champs du départ, centrés au-dessus de la boussole.
    var axe: String? = nil
    @Binding var valeur: Int?
    /// Largeur du champ (stepper compris).
    var largeur: CGFloat = 56
    /// Encadrement de l'axe : accent si la position lue du perso y est, danger sinon.
    var bon: Bool? = nil

    var body: some View {
        HStack(spacing: Jetons.espace1) {
            if let axe {
                Text(axe)
                    .font(Jetons.typoMeta.font)
                    .foregroundStyle(Color.jeton(\.encre2))
            }
            ChampNombreNS(valeur: $valeur)
                .frame(width: largeur, height: Jetons.hauteurControle)
                .overlay {
                    if let bon {
                        RoundedRectangle(cornerRadius: Jetons.rayon1, style: .circular)
                            .strokeBorder(bon ? Color.jeton(\.accent) : Color.jeton(\.danger),
                                          lineWidth: Jetons.epaisseurFilet)
                            .opacity(0.7)
                    }
                }
        }
    }
}

/// Le champ entier + son stepper, en NSView (la roulette de la souris n'a pas
/// d'équivalent SwiftUI sur macOS).
private struct ChampNombreNS: NSViewRepresentable {
    @Binding var valeur: Int?

    func makeNSView(context: Context) -> NSView {
        let coord = context.coordinator
        coord.parent = self
        let champ = NSTextField()
        champ.delegate = coord
        let formateur = NumberFormatter()
        formateur.numberStyle = .none
        formateur.allowsFloats = false
        formateur.minimum = ChampNombre.minimum as NSNumber
        formateur.maximum = ChampNombre.maximum as NSNumber
        champ.formatter = formateur
        champ.bezelStyle = .roundedBezel
        champ.alignment = .right
        let stepper = NSStepper()
        stepper.minValue = Double(ChampNombre.minimum)
        stepper.maxValue = Double(ChampNombre.maximum)
        stepper.increment = 1
        stepper.target = coord
        stepper.action = #selector(Coordinator.stepperChange(_:))
        coord.champ = champ
        coord.stepper = stepper
        let ligne = NSStackView()
        ligne.orientation = .horizontal
        ligne.spacing = 4
        ligne.addArrangedSubview(champ)
        ligne.addArrangedSubview(stepper)
        champ.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let zone = ZoneRoulette()
        zone.onDelta = { coord.roulette($0) }
        zone.addSubview(ligne)
        ligne.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ligne.leadingAnchor.constraint(equalTo: zone.leadingAnchor),
            ligne.trailingAnchor.constraint(equalTo: zone.trailingAnchor),
            ligne.centerYAnchor.constraint(equalTo: zone.centerYAnchor),
        ])
        coord.synchroniser(valeur)
        return zone
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.synchroniser(valeur)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    /// Relie le champ, le stepper et la roulette au binding.
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: ChampNombreNS!
        weak var champ: NSTextField?
        weak var stepper: NSStepper?

        func synchroniser(_ valeur: Int?) {
            guard let champ, let stepper else { return }
            let n = valeur ?? 0
            if champ.integerValue != n { champ.integerValue = n }
            if Int(stepper.doubleValue) != n { stepper.doubleValue = Double(n) }
        }

        func borner(_ n: Int) -> Int {
            min(ChampNombre.maximum, max(ChampNombre.minimum, n))
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let champ = notification.object as? NSTextField else { return }
            parent.valeur = champ.stringValue.isEmpty ? nil : borner(champ.integerValue)
        }

        @objc func stepperChange(_ stepper: NSStepper) {
            parent.valeur = borner(Int(stepper.integerValue))
        }

        func roulette(_ delta: Int) {
            parent.valeur = borner((parent.valeur ?? 0) + delta)
        }
    }
}

/// Une zone qui attrape la roulette de la souris (molette haut = +1, bas = -1).
private final class ZoneRoulette: NSView {
    var onDelta: ((Int) -> Void)?
    override func scrollWheel(with event: NSEvent) {
        guard let onDelta else { return super.scrollWheel(with: event) }
        onDelta(event.scrollingDeltaY >= 0 ? 1 : -1)
    }
}
