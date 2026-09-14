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

/// Rendu **vectoriel** de la marque Synfus : la Couvée — trois œufs de dragon,
/// l'émeraude écaillé devant, la turquoise mouchetée et le pourpre ondé qui
/// dépassent derrière. Un œuf par compte, le perso actif au premier plan :
/// c'est la barre de Synfus racontée en œufs.
///
/// Le dessin suit la grammaire visuelle d'Ankama — contour unique sombre,
/// volume par dégradé saturé, détails ton sur ton, brillance en croissant —
/// sans reprendre aucun asset du jeu : chaque tracé est original.
///
/// Moteur **pur** — entrées → `CGImage`, aucun état. Cette description unique
/// sert à l'icône du bundle (via `Tools/AppIconExport.swift`) et au symbole de
/// la barre de menus (via `SynfusGlyph`) : il n'y a pas de second dessin à
/// maintenir.
///
/// Repère de description : **256 × 256, y vers le bas** — celui de la maquette
/// validée sur la planche d'exploration (artifact « L'Œuf de Synfus »).
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

    private static let designSide: Double = 256
    /// Marge Apple pour une tuile macOS (spec : 824/1024 du côté).
    private static let roundedInsetRatio: Double = 50.0 / 512.0

    /// Aspect d'un œuf : large de 0,772 fois sa hauteur. Un œuf de dragon est
    /// un bloc — la maquette v2, à 0,81, tombait dans le galet aplati ; la v1,
    /// à 0,73, restait un œuf de poule.
    static let eggAspect: Double = 176.0 / 228.0

    /// Épaisseur du contour d'un œuf, en fraction de sa largeur.
    static let outlineRatio: Double = 12.0 / 176.0

    /// Épaisseur minimale d'un trait, **en pixels du rendu final** : en deçà,
    /// l'antialiasing l'étale en gris sale.
    private static let minStrokePixels: Double = 1.7

    /// Sous cette taille de rendu, les peaux (écailles, mouchetures, ondes)
    /// sont abandonnées : leurs traits ne survivent pas à la réduction. Les
    /// corps, la brillance et les contours suffisent à porter la marque.
    private static let texturesBelow: Int = 96

    // MARK: - Palette (maquette « L'Œuf de Synfus »)

    private static let backgroundInner = SynfusRGB(hex: 0x241D2A)
    private static let backgroundOuter = SynfusRGB(hex: 0x0F0B13)
    private static let outline = SynfusRGB(hex: 0x1A1410)

    /// L'émeraude — l'œuf de tête.
    private static let emeraldTop = SynfusRGB(hex: 0x7ED67F)
    private static let emeraldMid = SynfusRGB(hex: 0x3FA65C)
    private static let emeraldLow = SynfusRGB(hex: 0x1C6E38)
    private static let emeraldScaleDark = SynfusRGB(hex: 0x155A2E)
    private static let emeraldScaleLight = SynfusRGB(hex: 0x9FE8A6)
    private static let emeraldBelly = SynfusRGB(hex: 0x124424)

    /// La turquoise, mouchetée.
    private static let turquoiseTop = SynfusRGB(hex: 0x58C4D4)
    private static let turquoiseLow = SynfusRGB(hex: 0x16758F)
    private static let turquoiseSpot = SynfusRGB(hex: 0x0C556C)
    private static let turquoiseSpotCore = SynfusRGB(hex: 0x6FD4E2)
    private static let turquoiseBelly = SynfusRGB(hex: 0x0B4A5E)

    /// Le pourpre, parcouru d'ondes.
    private static let crimsonTop = SynfusRGB(hex: 0xE86A63)
    private static let crimsonLow = SynfusRGB(hex: 0xA31B33)
    private static let crimsonWaveDark = SynfusRGB(hex: 0x7F1029)
    private static let crimsonWaveLight = SynfusRGB(hex: 0xFF9D86)
    private static let crimsonBelly = SynfusRGB(hex: 0x6D0D24)

    private static let highlight = SynfusRGB(hex: 0xFFFFFF)

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

    /// L'œuf de dragon, tracé dans `rect` : pointe resserrée et haute, ventre
    /// très large sous la mi-hauteur, assise lourde. Points de contrôle
    /// normalisés depuis la maquette validée.
    static func dragonEgg(in rect: CGRect) -> CGPath {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        let path = CGMutablePath()
        path.move(to: p(0.500, 0.000))
        path.addCurve(to: p(0.000, 0.605), control1: p(0.273, 0.018), control2: p(0.000, 0.246))
        path.addCurve(to: p(0.500, 1.000), control1: p(0.000, 0.895), control2: p(0.216, 1.000))
        path.addCurve(to: p(1.000, 0.605), control1: p(0.784, 1.000), control2: p(1.000, 0.895))
        path.addCurve(to: p(0.500, 0.000), control1: p(1.000, 0.246), control2: p(0.727, 0.018))
        path.closeSubpath()
        return path
    }

    /// Cadre d'un œuf de la couvée : `center` et `width` dans le repère de la
    /// tuile, la hauteur suit l'aspect.
    private static func eggRect(center: CGPoint, width: Double) -> CGRect {
        let height = width / eggAspect
        return CGRect(x: center.x - width / 2, y: center.y - height / 2,
                      width: width, height: height)
    }

    /// La composition, recentrée optiquement dans la tuile : la masse visuelle
    /// (œufs + ombre) s'équilibre autour du centre, l'assise à peine plus
    /// lourde — un objet posé, pas un objet qui flotte.
    static var frontEggRect: CGRect { eggRect(center: CGPoint(x: 128, y: 132), width: 137.3) }
    static var leftEggRect: CGRect { eggRect(center: CGPoint(x: 62, y: 112), width: 88) }
    static var rightEggRect: CGRect { eggRect(center: CGPoint(x: 194, y: 112), width: 88) }

    // MARK: - Rendu

    /// Rend l'icône dans un bitmap carré de `pixelSize` pixels de côté.
    /// Renvoie `nil` seulement si CoreGraphics refuse d'allouer le contexte.
    static func image(pixelSize: Int, shape: Shape) -> CGImage? {
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

        draw(shape: shape, echelle: scale, textures: side >= texturesBelow, in: context)
        return context.makeImage()
    }

    /// Peint la marque dans le repère de description déjà installé. `echelle`
    /// est le facteur pixels/unité, pour ne jamais laisser un trait descendre
    /// sous `minStrokePixels` au rendu final.
    private static func draw(shape: Shape, echelle: Double, textures: Bool,
                             in context: CGContext) {
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
               radius: designSide * 0.70)

        // 2. L'ombre portée, sous toute la couvée.
        context.setFillColor(cgColor(SynfusRGB(hex: 0x000000), alpha: 0.38))
        context.fillEllipse(in: CGRect(x: 128 - 108, y: 220 - 13, width: 216, height: 26))

        // 3. Les deux œufs du fond, puis l'œuf de tête par-dessus.
        drawEgg(in: leftEggRect, body: [turquoiseTop, turquoiseLow], bodyStops: [0, 1],
                belly: turquoiseBelly, glossAlpha: 0.30, echelle: echelle,
                texture: textures ? .spots : nil, in: context)
        drawEgg(in: rightEggRect, body: [crimsonTop, crimsonLow], bodyStops: [0, 1],
                belly: crimsonBelly, glossAlpha: 0.30, echelle: echelle,
                texture: textures ? .waves : nil, in: context)
        drawEgg(in: frontEggRect, body: [emeraldTop, emeraldMid, emeraldLow],
                bodyStops: [0, 0.5, 1], belly: emeraldBelly, glossAlpha: 0.34,
                echelle: echelle, texture: textures ? .scales : nil, in: context)

        context.restoreGState()
    }

    /// Les trois peaux de la couvée.
    private enum Texture { case scales, spots, waves }

    /// Peint un œuf complet : corps en dégradé, peau, ombre de ventre,
    /// brillance, contour.
    private static func drawEgg(in rect: CGRect, body: [SynfusRGB], bodyStops: [CGFloat],
                                belly: SynfusRGB, glossAlpha: Double, echelle: Double,
                                texture: Texture?, in context: CGContext) {
        let egg = dragonEgg(in: rect)
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        // Unité de la maquette : les cotes des peaux sont exprimées pour un
        // œuf de 176 de large, et suivent son échelle.
        let u = rect.width / 176
        func trait(_ nominal: Double) -> Double {
            max(nominal * u, minStrokePixels / echelle)
        }

        // Corps : dégradé diagonal haut-gauche → bas-droit.
        context.saveGState()
        context.addPath(egg)
        context.clip()
        linear(in: context, colors: body, locations: bodyStops,
               from: p(0, 0), to: p(0.6, 1))

        // Peau, ton sur ton.
        switch texture {
        case .scales: drawScales(in: rect, trait: trait, in: context)
        case .spots: drawSpots(in: rect, in: context)
        case .waves: drawWaves(in: rect, trait: trait, in: context)
        case nil: break
        }

        // Ombre du ventre : l'assise de l'œuf s'enfonce dans la pénombre.
        let shadow = CGMutablePath()
        shadow.move(to: p(0, 0.754))
        shadow.addCurve(to: p(1, 0.754), control1: p(0.25, 0.877), control2: p(0.75, 0.877))
        shadow.addLine(to: p(1, 1.05))
        shadow.addLine(to: p(0, 1.05))
        shadow.closeSubpath()
        context.addPath(shadow)
        context.setFillColor(cgColor(belly, alpha: 0.55))
        context.fillPath()
        context.restoreGState()

        // Brillance en croissant, près de la pointe.
        let gloss = CGMutablePath()
        gloss.move(to: p(0.239, 0.175))
        gloss.addCurve(to: p(0.653, 0.053), control1: p(0.330, 0.070), control2: p(0.511, 0.026))
        gloss.addCurve(to: p(0.295, 0.276), control1: p(0.523, 0.083), control2: p(0.364, 0.154))
        gloss.addCurve(to: p(0.239, 0.175), control1: p(0.261, 0.241), control2: p(0.239, 0.206))
        gloss.closeSubpath()
        context.addPath(gloss)
        context.setFillColor(cgColor(highlight, alpha: glossAlpha))
        context.fillPath()

        // Le contour, unique et sombre — la signature Ankama.
        context.addPath(egg)
        context.setLineWidth(trait(12))
        context.setStrokeColor(cgColor(outline))
        context.strokePath()
    }

    /// Écailles en quinconce, à deux tons : le creux sombre, et le liseré de
    /// lumière que chaque rangée pose sur le ventre de la précédente.
    private static func drawScales(in rect: CGRect, trait: (Double) -> Double,
                                   in context: CGContext) {
        let u = rect.width / 176
        let tuileX = 40 * u, demiRangee = 14.5 * u
        let profondeur = 24 * u  // contrôle cubique ≈ demi-ellipse de 18 de creux

        func arcs(decalageY: Double) -> CGPath {
            let path = CGMutablePath()
            var rangee = 0
            var y = rect.minY + decalageY
            while y < rect.maxY + demiRangee {
                let depart = rect.minX + (rangee.isMultiple(of: 2) ? -tuileX / 2 : 0) - tuileX
                var x = depart
                while x < rect.maxX + tuileX {
                    path.move(to: CGPoint(x: x, y: y))
                    path.addCurve(to: CGPoint(x: x + tuileX, y: y),
                                  control1: CGPoint(x: x, y: y + profondeur),
                                  control2: CGPoint(x: x + tuileX, y: y + profondeur))
                    x += tuileX
                }
                rangee += 1
                y += demiRangee
            }
            return path
        }

        context.setLineCap(.round)
        context.addPath(arcs(decalageY: -3 * u))
        context.setLineWidth(trait(2.4))
        context.setStrokeColor(cgColor(emeraldScaleLight, alpha: 0.38))
        context.strokePath()
        context.addPath(arcs(decalageY: 0))
        context.setLineWidth(trait(5))
        context.setStrokeColor(cgColor(emeraldScaleDark))
        context.strokePath()
    }

    /// Mouchetures : tache sombre, cœur clair décentré — un caillou poli.
    private static func drawSpots(in rect: CGRect, in context: CGContext) {
        let u = rect.width / 176
        let tuileX = 52 * u, tuileY = 44 * u
        let taches: [(x: Double, y: Double, r: Double)] = [(12, 12, 8), (38, 32, 5.5)]

        var y = rect.minY
        while y < rect.maxY + tuileY {
            var x = rect.minX - tuileX
            while x < rect.maxX + tuileX {
                for tache in taches {
                    let centre = CGPoint(x: x + tache.x * u, y: y + tache.y * u)
                    let r = tache.r * u
                    context.setFillColor(cgColor(turquoiseSpot))
                    context.fillEllipse(in: CGRect(x: centre.x - r, y: centre.y - r,
                                                   width: r * 2, height: r * 2))
                    let coeur = r / 2
                    context.setFillColor(cgColor(turquoiseSpotCore, alpha: 0.5))
                    context.fillEllipse(in: CGRect(x: centre.x - 1.5 * u - coeur,
                                                   y: centre.y - 1.5 * u - coeur,
                                                   width: coeur * 2, height: coeur * 2))
                }
                x += tuileX
            }
            y += tuileY
        }
    }

    /// Ondes embossées : l'arête claire au-dessus, le creux sombre dessous.
    private static func drawWaves(in rect: CGRect, trait: (Double) -> Double,
                                  in context: CGContext) {
        func p(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
        }
        // Trois ondes, cotes normalisées de la maquette (œuf 176 × 228).
        let ondes: [(a: (Double, Double), c1: (Double, Double),
                     c2: (Double, Double), b: (Double, Double))] = [
            ((0, 0.351), (0.261, 0.254), (0.739, 0.254), (1, 0.351)),
            ((0, 0.544), (0.261, 0.456), (0.739, 0.456), (1, 0.544)),
            ((0.034, 0.737), (0.284, 0.649), (0.716, 0.649), (0.966, 0.737)),
        ]
        context.setLineCap(.round)
        for onde in ondes {
            for (decalage, largeur, couleur, alpha): (Double, Double, SynfusRGB, Double) in
                [(-0.0175, 3, crimsonWaveLight, 0.45), (0, 8, crimsonWaveDark, 1)] {
                let path = CGMutablePath()
                path.move(to: p(onde.a.0, onde.a.1 + decalage))
                path.addCurve(to: p(onde.b.0, onde.b.1 + decalage),
                              control1: p(onde.c1.0, onde.c1.1 + decalage),
                              control2: p(onde.c2.0, onde.c2.1 + decalage))
                context.addPath(path)
                context.setLineWidth(trait(largeur))
                context.setStrokeColor(cgColor(couleur, alpha: alpha))
                context.strokePath()
            }
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

    private static func radial(in context: CGContext, colors: [SynfusRGB], locations: [CGFloat],
                               center: CGPoint, radius: Double) {
        guard let gradient = CGGradient(colorsSpace: colorSpace,
                                        colors: colors.map { cgColor($0) } as CFArray,
                                        locations: locations) else { return }
        context.drawRadialGradient(gradient, startCenter: center, startRadius: 0,
                                   endCenter: center, endRadius: radius,
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
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
