import SwiftUI
import UIKit

/// The printed look of a disc and its case.
struct DiscFinish: Equatable {
    /// Colors swept around the disc, giving the iridescent CD sheen.
    let sheen: [Color]
    let caseColor: Color
    let glow: Color

    static let burned = DiscFinish(
        sheen: [
            Color(white: 0.93), Color(red: 0.80, green: 0.86, blue: 0.95), Color(white: 0.98),
            Color(red: 0.95, green: 0.84, blue: 0.90), Color(white: 0.86), Color(red: 0.84, green: 0.95, blue: 0.90),
            Color(white: 0.93)
        ],
        caseColor: Color(white: 0.16),
        glow: Color(red: 0.62, green: 0.70, blue: 0.86)
    )
}

enum SoundCategory: String, CaseIterable, Identifiable {
    case noise, rain, forest, ocean

    var id: String { rawValue }

    var title: String {
        switch self {
        case .noise: "Noise"
        case .rain: "Rain"
        case .forest: "Forest"
        case .ocean: "Ocean"
        }
    }
}

/// A built-in background sound. Sounds without a file are shown as "Soon" until one is sourced.
struct BuiltInSound: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let fileName: String?
    let finish: DiscFinish
    var category: SoundCategory = .noise
    /// Loops cut from recordings san downloaded for personal listening. They live in the
    /// git-ignored `MixLayer/PersonalSounds/` folder, are copied in at build time, and are
    /// hidden (not "Soon") when absent. Not licensed for App Store distribution.
    var isPersonal = false

    var isAvailable: Bool { url != nil }

    /// Art printed on the disc: `disc-<id>` in Assets.xcassets/DiscArt. Replace the image there to change it.
    var artwork: UIImage? { UIImage(named: "disc-\(id)") }

    var url: URL? {
        guard let fileName else { return nil }
        if isPersonal {
            return Bundle.main.url(forResource: fileName, withExtension: "m4a", subdirectory: "PersonalSounds")
        }
        return Bundle.main.url(forResource: fileName, withExtension: "wav")
    }

    /// Shown on the shelf: available sounds, plus "Soon" placeholders for catalog sounds.
    var isListed: Bool { !isPersonal || isAvailable }
}

enum SoundCatalog {
    static let sounds: [BuiltInSound] = [
        BuiltInSound(
            id: "brown-noise",
            name: "Brown noise",
            symbol: "waveform.path",
            fileName: "brown-noise",
            finish: DiscFinish(
                sheen: rgb([(0.93, 0.62, 0.25), (0.62, 0.34, 0.12), (0.98, 0.80, 0.52), (0.76, 0.45, 0.20), (0.93, 0.62, 0.25)]),
                caseColor: Color(red: 0.36, green: 0.21, blue: 0.08),
                glow: Color(red: 0.93, green: 0.58, blue: 0.20)
            )
        ),
        BuiltInSound(
            id: "pink-noise",
            name: "Pink noise",
            symbol: "wind",
            fileName: "pink-noise",
            finish: DiscFinish(
                sheen: rgb([(0.95, 0.58, 0.74), (0.72, 0.52, 0.95), (1.00, 0.82, 0.88), (0.86, 0.40, 0.62), (0.95, 0.58, 0.74)]),
                caseColor: Color(red: 0.42, green: 0.14, blue: 0.27),
                glow: Color(red: 0.92, green: 0.45, blue: 0.66)
            )
        ),
        BuiltInSound(
            id: "white-noise",
            name: "White noise",
            symbol: "aqi.medium",
            fileName: "white-noise",
            finish: DiscFinish(
                sheen: rgb([(0.86, 0.88, 0.92), (0.66, 0.78, 0.96), (0.98, 0.98, 1.00), (0.80, 0.92, 0.88), (0.86, 0.88, 0.92)]),
                caseColor: Color(red: 0.26, green: 0.27, blue: 0.30),
                glow: Color(red: 0.70, green: 0.78, blue: 0.92)
            )
        ),
        BuiltInSound(
            id: "rain",
            name: "Synth rain",
            symbol: "cloud.rain.fill",
            fileName: "rain",
            finish: DiscFinish(
                sheen: rgb([(0.52, 0.72, 0.92), (0.22, 0.54, 0.87), (0.80, 0.90, 1.00), (0.52, 0.72, 0.92)]),
                caseColor: Color(red: 0.09, green: 0.37, blue: 0.65),
                glow: Color(red: 0.22, green: 0.54, blue: 0.87)
            ),
            category: .rain
        ),
        BuiltInSound(
            id: "forest",
            name: "Synth forest",
            symbol: "tree.fill",
            fileName: "forest",
            finish: DiscFinish(
                sheen: rgb([(0.36, 0.79, 0.65), (0.11, 0.62, 0.46), (0.75, 0.93, 0.80), (0.36, 0.79, 0.65)]),
                caseColor: Color(red: 0.06, green: 0.43, blue: 0.34),
                glow: Color(red: 0.11, green: 0.62, blue: 0.46)
            ),
            category: .forest
        ),
        BuiltInSound(
            id: "ocean",
            name: "Synth ocean",
            symbol: "water.waves",
            fileName: "ocean",
            finish: DiscFinish(
                sheen: rgb([(0.35, 0.70, 0.80), (0.05, 0.27, 0.49), (0.70, 0.90, 0.95), (0.35, 0.70, 0.80)]),
                caseColor: Color(red: 0.05, green: 0.27, blue: 0.49),
                glow: Color(red: 0.20, green: 0.55, blue: 0.75)
            ),
            category: .ocean
        )
    ]

    static func sound(id: String?) -> BuiltInSound? {
        guard let id else { return nil }
        return (sounds + recordings).first { $0.id == id }
    }

    /// Every sound in shelf order: the catalog, then personal recordings.
    static var all: [BuiltInSound] { sounds + recordings }

    /// Loops cut from san's downloaded reference recordings (Downloads/ambient-references),
    /// one per source video. See `scripts/cut-personal-loops.sh`.
    static let recordings: [BuiltInSound] = [
        recording("steady-rain", "Steady rain", "cloud.rain.fill", .rain),
        recording("porch-rain", "Porch rain", "house.fill", .rain),
        recording("rain-on-leaves", "Rain on leaves", "leaf.fill", .rain),
        recording("gentle-rain", "Gentle rain", "cloud.drizzle.fill", .rain),
        recording("woodland", "Woodland", "bird.fill", .forest),
        recording("blackbird", "Blackbird", "bird", .forest),
        recording("forest-wind", "Forest wind", "wind", .forest),
        recording("soft-surf", "Soft surf", "water.waves", .ocean),
        recording("breakers", "Breakers", "figure.surfing", .ocean),
        recording("beach", "Beach", "beach.umbrella.fill", .ocean)
    ]

    private static func recording(_ id: String, _ name: String, _ symbol: String, _ category: SoundCategory) -> BuiltInSound {
        let base = sounds.first { $0.id == category.rawValue }!.finish
        return BuiltInSound(id: id, name: name, symbol: symbol, fileName: id, finish: base, category: category, isPersonal: true)
    }

    private static func rgb(_ values: [(Double, Double, Double)]) -> [Color] {
        values.map { Color(red: $0.0, green: $0.1, blue: $0.2) }
    }
}

// MARK: - Glow from the disc art

extension BuiltInSound {
    /// The glow around the disc, the ring arc, and the background light. Taken from the disc's
    /// own art (its most vivid colour) so a black disc with yellow spots glows yellow; falls
    /// back to the finish's glow when there's no art.
    var glow: Color {
        if let cached = GlowCache.get(id) { return cached }
        let color = artwork.flatMap(DiscAccent.vividColor(in:)).map(Color.init(uiColor:)) ?? finish.glow
        GlowCache.set(id, color)
        return color
    }
}

/// Computed once per disc; the image scan is cheap but runs during view updates.
private enum GlowCache {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var colors: [String: Color] = [:]

    static func get(_ id: String) -> Color? { lock.withLock { colors[id] } }
    static func set(_ id: String, _ color: Color) { lock.withLock { colors[id] = color } }
}

enum DiscAccent {
    /// The dominant vivid colour in an image: pixels are weighted by saturation² × brightness,
    /// grouped into 24 hue buckets, and the heaviest bucket's average wins. Greys, blacks, and
    /// the off-white label count for almost nothing. Mostly colourless art (white noise) keeps a
    /// pale tint of its average colour instead. Checked against every disc in `DiscAccentTests`.
    static func vividColor(in image: UIImage) -> UIColor? {
        guard let cg = image.cgImage else { return nil }
        let side = 40
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        guard let ctx = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        ctx.interpolationQuality = .medium
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))

        let bins = 24
        var weight = [Double](repeating: 0, count: bins)
        var sum = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: bins)
        var avg = (r: 0.0, g: 0.0, b: 0.0), count = 0.0

        for y in 0..<side {
            for x in 0..<side {
                // Only the vinyl ring: skip the corners and the centre label.
                let dx = Double(x) - Double(side) / 2 + 0.5, dy = Double(y) - Double(side) / 2 + 0.5
                let r = (dx * dx + dy * dy).squareRoot() / (Double(side) / 2)
                guard r > 0.38, r < 0.97 else { continue }

                let i = (y * side + x) * 4
                let red = Double(pixels[i]) / 255, green = Double(pixels[i + 1]) / 255, blue = Double(pixels[i + 2]) / 255
                avg.r += red; avg.g += green; avg.b += blue; count += 1

                let maxC = max(red, green, blue), minC = min(red, green, blue)
                guard maxC > 0.15, maxC - minC > 0.08 else { continue }
                let saturation = (maxC - minC) / maxC
                let hue = UIColor(red: red, green: green, blue: blue, alpha: 1).hueComponent
                let bin = min(Int(hue * Double(bins)), bins - 1)
                let w = saturation * saturation * maxC
                weight[bin] += w
                sum[bin].r += red * w; sum[bin].g += green * w; sum[bin].b += blue * w
            }
        }
        guard count > 0 else { return nil }

        // Merge each bucket with its neighbours so a hue split across a boundary still wins.
        let merged = (0..<bins).map { weight[$0] + 0.5 * (weight[($0 + bins - 1) % bins] + weight[($0 + 1) % bins]) }
        let best = merged.indices.max { merged[$0] < merged[$1] }!
        // Share of the ring that is clearly coloured in the winning hue. A few bright spots
        // (Blackbird's yellow on black) are enough; speckled grey (white noise) is not.
        let vividShare = weight[best] / count

        if vividShare < 0.006 {
            // Nearly colourless art: a soft tint of the average.
            return UIColor(red: avg.r / count, green: avg.g / count, blue: avg.b / count, alpha: 1)
                .adjusted(minSaturation: 0.12, minBrightness: 0.9)
        }
        let w = weight[best]
        return UIColor(red: sum[best].r / w, green: sum[best].g / w, blue: sum[best].b / w, alpha: 1)
            .adjusted(minSaturation: 0.55, minBrightness: 0.85)
    }
}

private extension UIColor {
    var hueComponent: Double {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Double(h)
    }

    func adjusted(minSaturation: CGFloat, minBrightness: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: max(s, minSaturation), brightness: max(b, minBrightness), alpha: 1)
    }
}
