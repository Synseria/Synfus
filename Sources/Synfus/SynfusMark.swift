import CoreGraphics
import Foundation

/// Couleur opaque en composantes 0…1 — volontairement **sans AppKit ni SwiftUI** :
/// `SynfusMark` doit rester compilable hors de l'app, le générateur
/// `Tools/generate-app-icons.sh` le compilant tel quel pour produire le `.icns`.
struct SynfusRGB: Equatable, Sendable {
    let red: Double, green: Double, blue: Double

    init(hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }
}

/// Rendu **vectoriel** de la marque Synfus : l'œuf, et les fenêtres qu'il abrite.
///
/// Moteur **pur** — entrées → `CGImage`, aucun état. C'est cette description
/// unique qui sert à l'icône du bundle (via `Tools/AppIconExport.swift`), au
/// symbole de la barre de menus et à la poignée de la barre flottante
/// (via `SynfusGlyph`) : il n'y a pas de second dessin à maintenir.
///
/// Repère de description : **280 × 280, y vers le bas**, celui de la maquette
/// [Resources/Synfus.svg](Resources/Synfus.svg). La mise à l'échelle et le
/// retournement vers le bitmap CoreGraphics sont faits au moment du rendu.
enum SynfusMark {

    /// Cadrage de la tuile.
    enum Shape {
        /// macOS : marge Apple + coins arrondis dessinés dans l'image — le
        /// `.icns` n'applique aucun masque, la forme doit être dans le pixel.
        case rounded
        /// Dessin pleine page, sans coins arrondis.
        case fullBleed
    }

    // MARK: - Repère

    private static let designSide: Double = 280
    private static let cornerRadius: Double = 62
    /// Marge Apple pour une tuile macOS (spec : 824/1024 du côté).
    private static let roundedInsetRatio: Double = 50.0 / 512.0

    /// Part de la tuile qu'occupe l'œuf, traits compris.
    ///
    /// La maquette le posait à 214/280 ≈ 0,76 : à côté des icônes système, qui
    /// remplissent leur tuile, il paraissait petit et flottant. Le dessin est
    /// inchangé, seul son cadrage l'est — une homothétie unique autour du centre.
    static let defaultFillRatio: Double = 0.90

    /// Rectangle englobant de l'œuf dans la maquette. Tout le reste du dessin
    /// (fenêtres, reflet) est exprimé en fractions de ce rectangle, si bien que
    /// changer le cadrage de l'œuf emmène l'intérieur avec lui.
    private static let eggBox = CGRect(x: 62, y: 34, width: 156, height: 214)

    /// Épaisseur du contour de l'œuf et des fenêtres dans la maquette.
    private static let strokeWidth: Double = 7

    /// Épaisseur minimale d'un trait, **en pixels du rendu final**.
    ///
    /// En dessous, l'antialiasing étale le trait en un gris pâle et irrégulier :
    /// c'est ce qui donne l'impression d'une texture sale sur le contour aux
    /// petites définitions. Le trait de la maquette (2,5 % du côté) ne mesure
    /// que 0,7 px à 32 px de large.
    private static let minStrokePixels: Double = 1.7

    /// Plafond de l'épaississement, dans le repère : au-delà, le contour mange
    /// l'intérieur de l'œuf et la silhouette se referme.
    private static let maxStrokeWidth: Double = 17

    /// Épaisseur à employer pour un rendu de `side` pixels, traits ramenés à au
    /// moins `minStrokePixels`. C'est la seule entorse au dessin de la maquette,
    /// et elle ne joue que sous ~128 px.
    private static func strokeWidth(pixelSize side: Int, fillRatio: Double, shape: Shape) -> Double {
        let s = Double(max(1, side))
        let inset = shape == .rounded ? s * roundedInsetRatio : 0
        let bounds = eggBox.insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
        // Facteur total appliqué au repère : cadrage de la tuile, puis homothétie
        // qui porte l'œuf à `fillRatio`.
        let echelle = (s - 2 * inset) / designSide
            * (fillRatio * designSide / max(bounds.width, bounds.height))
        guard echelle > 0 else { return strokeWidth }
        return min(max(strokeWidth, minStrokePixels / echelle), maxStrokeWidth)
    }

    /// Sous cette taille, les fenêtres sont pleines : leur contour, plus fin
    /// encore que celui de l'œuf, ne survit pas à la réduction.
    private static let filledWindowsBelow: Int = 96

    // MARK: - Palette (maquette Synfus.svg)

    private static let backgroundInner = SynfusRGB(hex: 0x241A3E)
    private static let backgroundOuter = SynfusRGB(hex: 0x0D0916)
    /// Coquille : le dégradé du contour, bleu → violet → rose.
    private static let shellStart = SynfusRGB(hex: 0x4F7BD9)
    private static let shellMid = SynfusRGB(hex: 0x7B3FD4)
    private static let shellEnd = SynfusRGB(hex: 0xD14FA6)
    /// Intérieur de l'œuf : un creux plus sombre que le fond de la tuile.
    private static let innerTop = SynfusRGB(hex: 0x2C1F52)
    private static let innerMid = SynfusRGB(hex: 0x171029)
    private static let innerEdge = SynfusRGB(hex: 0x0F0A1C)
    private static let highlight = SynfusRGB(hex: 0x8F7BFF)
    private static let windowColor = SynfusRGB(hex: 0xE6D9FF)

    // MARK: - Géométrie

    /// Superellipse — la forme des tuiles macOS depuis Big Sur. Un
    /// `CGPath(roundedRect:)` raccorde un arc de cercle à un côté droit, et la
    /// cassure se voit à côté des icônes du système.
    static func squircle(in rect: CGRect, exposant n: Double = 5) -> CGPath {
        let path = CGMutablePath()
        let a = rect.width / 2, b = rect.height / 2
        let steps = 720
        for i in 0...steps {
            let t = Double(i) / Double(steps) * 2 * .pi
            let ct = cos(t), st = sin(t)
            let point = CGPoint(
                x: rect.midX + a * copysign(pow(abs(ct), 2 / n), ct),
                y: rect.midY + b * copysign(pow(abs(st), 2 / n), st)
            )
            i == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    /// Contour de l'œuf, tracé dans `rect` : pointe resserrée en haut, base
    /// pleine. Points de contrôle normalisés depuis la maquette.
    static func egg(in rect: CGRect) -> CGPath {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let path = CGMutablePath()
        path.move(to: p(0.500, 0.000))
        path.addCurve(to: p(0.000, 0.579), control1: p(0.218, 0.000), control2: p(0.000, 0.290))
        path.addCurve(to: p(0.500, 1.000), control1: p(0.000, 0.841), control2: p(0.224, 1.000))
        path.addCurve(to: p(1.000, 0.579), control1: p(0.776, 1.000), control2: p(1.000, 0.841))
        path.addCurve(to: p(0.500, 0.000), control1: p(1.000, 0.290), control2: p(0.782, 0.000))
        path.closeSubpath()
        return path
    }

    /// Une fenêtre du motif intérieur.
    struct Window {
        /// Position et taille, en fractions du rectangle de l'œuf.
        let x, y, width, height, radius: Double
        /// Pleine, ou seulement cernée comme dans la maquette.
        let filled: Bool
    }

    /// Deux fenêtres empilées à gauche, une haute à droite : le motif de la barre
    /// flottante, plusieurs clients côte à côte.
    static let windows: [Window] = [
        Window(x: 0.218, y: 0.393, width: 0.244, height: 0.121, radius: 0.038, filled: false),
        Window(x: 0.218, y: 0.570, width: 0.244, height: 0.084, radius: 0.038, filled: true),
        Window(x: 0.551, y: 0.393, width: 0.244, height: 0.262, radius: 0.051, filled: false),
    ]

    static func rect(of window: Window, in rect: CGRect) -> CGRect {
        CGRect(x: rect.minX + window.x * rect.width,
               y: rect.minY + window.y * rect.height,
               width: window.width * rect.width,
               height: window.height * rect.height)
    }

    // MARK: - Rendu

    /// Rend l'icône dans un bitmap carré de `pixelSize` pixels de côté.
    /// Renvoie `nil` seulement si CoreGraphics refuse d'allouer le contexte.
    static func image(pixelSize: Int, shape: Shape,
                      fillRatio: Double = defaultFillRatio) -> CGImage? {
        let side = max(1, pixelSize)
        guard let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: 0,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        // Repère de description : origine en haut-gauche, y vers le bas.
        let s = Double(side)
        context.translateBy(x: 0, y: s)
        context.scaleBy(x: 1, y: -1)

        let inset = shape == .rounded ? s * roundedInsetRatio : 0
        let scale = (s - 2 * inset) / designSide
        context.translateBy(x: inset, y: inset)
        context.scaleBy(x: scale, y: scale)

        draw(shape: shape, fillRatio: fillRatio,
             trait: strokeWidth(pixelSize: side, fillRatio: fillRatio, shape: shape),
             fenetresPleines: side < filledWindowsBelow,
             in: context)
        return context.makeImage()
    }

    /// Peint la marque dans le repère de description déjà installé.
    private static func draw(shape: Shape, fillRatio: Double, trait: Double,
                             fenetresPleines: Bool, in context: CGContext) {
        let tile = CGRect(x: 0, y: 0, width: designSide, height: designSide)

        // 1. La tuile, et son dégradé radial descendant vers les bords.
        let tilePath: CGPath = shape == .rounded
            ? squircle(in: tile)
            : CGPath(rect: tile, transform: nil)
        context.saveGState()
        context.addPath(tilePath)
        context.clip()
        radial(in: context,
               colors: [backgroundInner, backgroundOuter], locations: [0, 1],
               center: CGPoint(x: designSide * 0.5, y: designSide * 0.42),
               radius: designSide * 0.65, aspect: 1)
        context.restoreGState()

        // 2. L'œuf, cadré dans la tuile par une homothétie autour du centre. La
        //    tuile vient d'être peinte hors de cette transformation : ses coins
        //    ne bougent pas.
        context.saveGState()
        defer { context.restoreGState() }

        let bounds = eggBox.insetBy(dx: -strokeWidth / 2, dy: -strokeWidth / 2)
        let k = fillRatio * designSide / max(bounds.width, bounds.height)
        let center = designSide / 2
        context.translateBy(x: center, y: center)
        context.scaleBy(x: k, y: k)
        context.translateBy(x: -bounds.midX, y: -bounds.midY)

        let egg = egg(in: eggBox)

        // Creux intérieur.
        context.saveGState()
        context.addPath(egg)
        context.clip()
        radial(in: context,
               colors: [innerTop, innerMid, innerEdge], locations: [0, 0.7, 1],
               center: CGPoint(x: eggBox.midX, y: eggBox.minY + eggBox.height * 0.40),
               radius: eggBox.width * 0.70, aspect: eggBox.height / eggBox.width)

        // Reflet : une ellipse inclinée, très peu opaque, qui donne son galbe à
        // la coquille sans la faire briller.
        context.saveGState()
        let reflet = CGPoint(x: eggBox.minX + eggBox.width * 0.321,
                             y: eggBox.minY + eggBox.height * 0.243)
        context.translateBy(x: reflet.x, y: reflet.y)
        context.rotate(by: -18 * .pi / 180)
        context.scaleBy(x: 1, y: (eggBox.height * 0.187) / (eggBox.width * 0.167))
        context.setFillColor(cgColor(highlight, alpha: 0.12))
        context.addEllipse(in: CGRect(x: -eggBox.width * 0.167, y: -eggBox.width * 0.167,
                                      width: eggBox.width * 0.334, height: eggBox.width * 0.334))
        context.fillPath()
        context.restoreGState()

        context.restoreGState()

        // 3. Le contour de la coquille : un dégradé, donc un tracé converti en
        //    surface puis rempli — CoreGraphics ne sait pas caresser un dégradé.
        context.saveGState()
        context.addPath(egg)
        context.setLineWidth(trait)
        context.replacePathWithStrokedPath()
        context.clip()
        linear(in: context, colors: [shellStart, shellMid, shellEnd], locations: [0, 0.45, 1],
               from: CGPoint(x: eggBox.minX, y: eggBox.minY),
               to: CGPoint(x: eggBox.maxX, y: eggBox.maxY))
        context.restoreGState()

        // 4. Les fenêtres.
        context.setLineWidth(trait)
        context.setStrokeColor(cgColor(windowColor))
        context.setFillColor(cgColor(windowColor))
        for window in windows {
            let plein = window.filled || fenetresPleines
            let cadre = rect(of: window, in: eggBox)
            let r = window.radius * eggBox.width
            let path = CGPath(
                roundedRect: plein ? cadre : cadre.insetBy(dx: trait / 2, dy: trait / 2),
                cornerWidth: r, cornerHeight: r, transform: nil
            )
            context.addPath(path)
            context.drawPath(using: plein ? .fill : .stroke)
        }
    }

    // MARK: - Dégradés

    private static func linear(in context: CGContext, colors: [SynfusRGB], locations: [CGFloat],
                               from: CGPoint, to: CGPoint) {
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: colors.map { cgColor($0) } as CFArray,
                                        locations: locations) else { return }
        context.drawLinearGradient(gradient, start: from, end: to, options: [])
    }

    /// Dégradé radial, éventuellement écrasé en ellipse par `aspect` — la bande
    /// de l'œuf est plus haute que large.
    private static func radial(in context: CGContext, colors: [SynfusRGB], locations: [CGFloat],
                               center: CGPoint, radius: Double, aspect: Double) {
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: colors.map { cgColor($0) } as CFArray,
                                        locations: locations) else { return }
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: 1, y: aspect)
        context.drawRadialGradient(gradient, startCenter: .zero, startRadius: 0,
                                   endCenter: .zero, endRadius: radius,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    /// **sRGB**, et le même des deux côtés (contexte *et* couleurs) : les teintes
    /// sont des hex de maquette, donc sRGB par définition. Dessiner un `CGColor`
    /// sRGB dans un contexte `DeviceRGB` fait passer CoreGraphics par une
    /// conversion de gamma qui éclaircit tout le rendu.
    static let colorSpace: CGColorSpace =
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()

    private static func cgColor(_ color: SynfusRGB, alpha: Double = 1) -> CGColor {
        CGColor(colorSpace: colorSpace, components: [color.red, color.green, color.blue, alpha])
            ?? CGColor(red: color.red, green: color.green, blue: color.blue, alpha: alpha)
    }
}
