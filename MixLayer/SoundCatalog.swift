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

/// A built-in background sound. Sounds without a file are shown as "Soon" until one is sourced.
struct BuiltInSound: Identifiable, Equatable {
    let id: String
    let name: String
    let symbol: String
    let fileName: String?
    let finish: DiscFinish

    var isAvailable: Bool { fileName != nil }

    /// Art printed on the disc: `disc-<id>` in Assets.xcassets/DiscArt. Replace the image there to change it.
    var artwork: UIImage? { UIImage(named: "disc-\(id)") }

    var url: URL? {
        guard let fileName else { return nil }
        return Bundle.main.url(forResource: fileName, withExtension: "wav")
    }
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
            name: "Rain",
            symbol: "cloud.rain.fill",
            fileName: "rain",
            finish: DiscFinish(
                sheen: rgb([(0.52, 0.72, 0.92), (0.22, 0.54, 0.87), (0.80, 0.90, 1.00), (0.52, 0.72, 0.92)]),
                caseColor: Color(red: 0.09, green: 0.37, blue: 0.65),
                glow: Color(red: 0.22, green: 0.54, blue: 0.87)
            )
        ),
        BuiltInSound(
            id: "forest",
            name: "Forest",
            symbol: "tree.fill",
            fileName: "forest",
            finish: DiscFinish(
                sheen: rgb([(0.36, 0.79, 0.65), (0.11, 0.62, 0.46), (0.75, 0.93, 0.80), (0.36, 0.79, 0.65)]),
                caseColor: Color(red: 0.06, green: 0.43, blue: 0.34),
                glow: Color(red: 0.11, green: 0.62, blue: 0.46)
            )
        ),
        BuiltInSound(
            id: "ocean",
            name: "Ocean",
            symbol: "water.waves",
            fileName: "ocean",
            finish: DiscFinish(
                sheen: rgb([(0.35, 0.70, 0.80), (0.05, 0.27, 0.49), (0.70, 0.90, 0.95), (0.35, 0.70, 0.80)]),
                caseColor: Color(red: 0.05, green: 0.27, blue: 0.49),
                glow: Color(red: 0.20, green: 0.55, blue: 0.75)
            )
        )
    ]

    static func sound(id: String?) -> BuiltInSound? {
        guard let id else { return nil }
        return sounds.first { $0.id == id }
    }

    private static func rgb(_ values: [(Double, Double, Double)]) -> [Color] {
        values.map { Color(red: $0.0, green: $0.1, blue: $0.2) }
    }
}
