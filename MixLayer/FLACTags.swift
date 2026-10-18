import Foundation

/// Reads the tags Apple's metadata APIs skip in FLAC files: Vorbis comments (title, artist,
/// album) and the embedded PICTURE block (cover art). Only the metadata blocks at the start
/// of the file are read, never the audio.
struct FLACTags: Equatable {
    var title: String?
    var artist: String?
    var album: String?
    var picture: Data?

    static func read(from url: URL) -> FLACTags? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        // Metadata blocks sit before the audio; 16 MB covers even large cover images.
        guard let data = try? handle.read(upToCount: 16 * 1024 * 1024) else { return nil }
        return parse(data)
    }

    static func parse(_ data: Data) -> FLACTags? {
        let bytes = [UInt8](data)
        guard bytes.count >= 4, bytes[0..<4].elementsEqual("fLaC".utf8) else { return nil }

        var tags = FLACTags()
        var offset = 4
        var isLast = false
        var frontCover: Data?
        var anyPicture: Data?

        while !isLast, offset + 4 <= bytes.count {
            let header = bytes[offset]
            isLast = header & 0x80 != 0
            let type = header & 0x7F
            let length = Int(bytes[offset + 1]) << 16 | Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3])
            let start = offset + 4
            let end = start + length
            guard end <= bytes.count else { break }
            let block = Array(bytes[start..<end])

            switch type {
            case 4: readVorbisComments(block, into: &tags)
            case 6:
                if let (pictureType, image) = readPicture(block) {
                    if pictureType == 3, frontCover == nil { frontCover = image }
                    if anyPicture == nil { anyPicture = image }
                }
            default: break
            }
            offset = end
        }

        tags.picture = frontCover ?? anyPicture
        return tags
    }

    // Vorbis comment block: little-endian lengths, "KEY=value" UTF-8 strings.
    private static func readVorbisComments(_ b: [UInt8], into tags: inout FLACTags) {
        var i = 0
        func le32() -> Int? {
            guard i + 4 <= b.count else { return nil }
            defer { i += 4 }
            return Int(b[i]) | Int(b[i + 1]) << 8 | Int(b[i + 2]) << 16 | Int(b[i + 3]) << 24
        }
        guard let vendorLength = le32(), i + vendorLength <= b.count else { return }
        i += vendorLength
        guard let count = le32() else { return }

        for _ in 0..<count {
            guard let length = le32(), i + length <= b.count else { return }
            let entry = String(decoding: b[i..<(i + length)], as: UTF8.self)
            i += length
            guard let eq = entry.firstIndex(of: "=") else { continue }
            let key = entry[..<eq].uppercased()
            let value = String(entry[entry.index(after: eq)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { continue }
            switch key {
            case "TITLE": if tags.title == nil { tags.title = value }
            case "ARTIST": if tags.artist == nil { tags.artist = value }
            case "ALBUMARTIST": if tags.artist == nil { tags.artist = value }
            case "ALBUM": if tags.album == nil { tags.album = value }
            default: break
            }
        }
    }

    // PICTURE block: big-endian picture type, MIME, description, dimensions, then image bytes.
    private static func readPicture(_ b: [UInt8]) -> (Int, Data)? {
        var i = 0
        func be32() -> Int? {
            guard i + 4 <= b.count else { return nil }
            defer { i += 4 }
            return Int(b[i]) << 24 | Int(b[i + 1]) << 16 | Int(b[i + 2]) << 8 | Int(b[i + 3])
        }
        guard let pictureType = be32(), let mimeLength = be32(), i + mimeLength <= b.count else { return nil }
        i += mimeLength
        guard let descriptionLength = be32(), i + descriptionLength <= b.count else { return nil }
        i += descriptionLength
        i += 16 // width, height, colour depth, indexed colours
        guard let dataLength = be32(), dataLength > 0, i + dataLength <= b.count else { return nil }
        return (pictureType, Data(b[i..<(i + dataLength)]))
    }
}
