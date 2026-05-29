import AVFoundation
import CoreImage
import Foundation
import UIKit

struct AudioTrack: Identifiable, Equatable {
    enum Source: String {
        case bundled
        case folder
    }

    let id: String
    let url: URL
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval
    let artwork: UIImage?
    let accentColor: UIColor
    let source: Source
    let loops: Bool

    struct MetadataSnapshot: Codable, Equatable {
        let title: String
        let artist: String?
        let album: String?
        let duration: TimeInterval
        let artworkData: Data?
        let accentRed: Double
        let accentGreen: Double
        let accentBlue: Double

        var artwork: UIImage? {
            artworkData.flatMap(UIImage.init(data:))
        }

        var accentColor: UIColor {
            UIColor(
                red: CGFloat(accentRed),
                green: CGFloat(accentGreen),
                blue: CGFloat(accentBlue),
                alpha: 1
            )
        }

        init(track: AudioTrack) {
            title = track.title
            artist = track.artist
            album = track.album
            duration = track.duration
            artworkData = track.artwork?.cacheArtworkData

            let components = track.accentColor.rgbComponents
            accentRed = components.red
            accentGreen = components.green
            accentBlue = components.blue
        }
    }

    var artistDisplay: String {
        artist?.nilIfBlank ?? "Unknown Artist"
    }

    var albumDisplay: String {
        album?.nilIfBlank ?? sourceLabel
    }

    var sourceLabel: String {
        switch source {
        case .bundled:
            "Built-in"
        case .folder:
            "Folder"
        }
    }

    var metadataSnapshot: MetadataSnapshot {
        MetadataSnapshot(track: self)
    }

    static func load(
        url: URL,
        titleOverride: String? = nil,
        source: Source,
        loops: Bool = false,
        cachedMetadata: MetadataSnapshot? = nil
    ) async -> AudioTrack {
        if let cachedMetadata {
            return AudioTrack(
                url: url,
                title: titleOverride?.nilIfBlank ?? cachedMetadata.title,
                artist: cachedMetadata.artist,
                album: cachedMetadata.album,
                duration: cachedMetadata.duration,
                artwork: cachedMetadata.artwork,
                accentColor: cachedMetadata.accentColor,
                source: source,
                loops: loops
            )
        }

        let metadata = await AudioTrack.readMetadata(from: url)
        let fallbackTitle = url.deletingPathExtension().lastPathComponent
        let artwork = metadata.artwork?.scaledForCache(maxDimension: 512)

        return AudioTrack(
            url: url,
            title: titleOverride?.nilIfBlank ?? metadata.title?.nilIfBlank ?? fallbackTitle,
            artist: metadata.artist?.nilIfBlank,
            album: metadata.album?.nilIfBlank,
            duration: metadata.duration,
            artwork: artwork,
            accentColor: artwork?.averageColor?.saturatedAccent ?? AudioTrack.fallbackAccent(for: titleOverride ?? metadata.title ?? fallbackTitle),
            source: source,
            loops: loops
        )
    }

    private init(
        url: URL,
        title: String,
        artist: String?,
        album: String?,
        duration: TimeInterval,
        artwork: UIImage?,
        accentColor: UIColor,
        source: Source,
        loops: Bool
    ) {
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artwork = artwork
        self.accentColor = accentColor
        self.source = source
        self.loops = loops
        self.id = "\(source.rawValue)-\(url.absoluteString)"
    }

    static func == (lhs: AudioTrack, rhs: AudioTrack) -> Bool {
        lhs.id == rhs.id
    }

    private static func readMetadata(from url: URL) async -> TrackMetadata {
        let asset = AVURLAsset(url: url)
        let commonMetadata = (try? await asset.load(.commonMetadata)) ?? []
        let artwork = await metadataData(for: .commonIdentifierArtwork, in: commonMetadata).flatMap(UIImage.init(data:))
        let duration = CMTimeGetSeconds((try? await asset.load(.duration)) ?? .zero)

        return TrackMetadata(
            title: await metadataString(for: .commonIdentifierTitle, in: commonMetadata),
            artist: await metadataString(for: .commonIdentifierArtist, in: commonMetadata),
            album: await metadataString(for: .commonIdentifierAlbumName, in: commonMetadata),
            duration: duration.isFinite ? duration : 0,
            artwork: artwork
        )
    }

    private static func metadataString(for identifier: AVMetadataIdentifier, in metadata: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first else {
            return nil
        }

        return try? await item.load(.stringValue)
    }

    private static func metadataData(for identifier: AVMetadataIdentifier, in metadata: [AVMetadataItem]) async -> Data? {
        guard let item = AVMetadataItem.metadataItems(from: metadata, filteredByIdentifier: identifier).first else {
            return nil
        }

        return try? await item.load(.dataValue)
    }

    private static func fallbackAccent(for seed: String) -> UIColor {
        let palette = [
            UIColor(red: 1.00, green: 0.18, blue: 0.34, alpha: 1.0),
            UIColor(red: 0.10, green: 0.65, blue: 1.00, alpha: 1.0),
            UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1.0),
            UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1.0),
            UIColor(red: 0.75, green: 0.35, blue: 0.95, alpha: 1.0)
        ]
        let index = abs(seed.hashValue) % palette.count
        return palette[index]
    }
}

private struct TrackMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let duration: TimeInterval
    let artwork: UIImage?
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension UIImage {
    var cacheArtworkData: Data? {
        scaledForCache(maxDimension: 512).jpegData(compressionQuality: 0.82) ?? pngData()
    }

    func scaledForCache(maxDimension: CGFloat) -> UIImage {
        let largestSide = max(size.width, size.height)
        guard largestSide > maxDimension, largestSide > 0 else {
            return self
        }

        let scale = maxDimension / largestSide
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else {
            return nil
        }

        let extent = inputImage.extent
        let parameters: [String: Any] = [
            kCIInputImageKey: inputImage,
            kCIInputExtentKey: CIVector(
                x: extent.origin.x,
                y: extent.origin.y,
                z: extent.size.width,
                w: extent.size.height
            )
        ]

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: parameters),
              let outputImage = filter.outputImage else {
            return nil
        }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }
}

private extension UIColor {
    var rgbComponents: (red: Double, green: Double, blue: Double) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return (0.32, 0.58, 0.92)
        }

        return (Double(red), Double(green), Double(blue))
    }

    var saturatedAccent: UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }

        return UIColor(
            hue: hue,
            saturation: max(saturation, 0.62),
            brightness: max(brightness, 0.78),
            alpha: 1
        )
    }
}
