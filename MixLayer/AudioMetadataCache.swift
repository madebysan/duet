import Foundation

final class AudioMetadataCache {
    private struct CacheFile: Codable {
        var entries: [String: Entry]
    }

    private struct Entry: Codable {
        let fileSize: Int64
        let modificationTime: TimeInterval
        let metadata: AudioTrack.MetadataSnapshot
        let cachedAt: Date
    }

    private var entries: [String: Entry] = [:]
    private let cacheURL: URL

    init(fileManager: FileManager = .default) {
        let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = supportDirectory.appendingPathComponent("MetadataCache", isDirectory: true)
        cacheURL = directory.appendingPathComponent("audio-metadata.json")

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var excludedDirectory = directory
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try? excludedDirectory.setResourceValues(resourceValues)

        load()
    }

    func snapshot(for url: URL, fileSize: Int64, modificationDate: Date?) -> AudioTrack.MetadataSnapshot? {
        let key = cacheKey(for: url)
        guard let entry = entries[key],
              entry.fileSize == fileSize,
              abs(entry.modificationTime - modificationTime(for: modificationDate)) < 1 else {
            return nil
        }

        return entry.metadata
    }

    func store(_ snapshot: AudioTrack.MetadataSnapshot, for url: URL, fileSize: Int64, modificationDate: Date?) {
        let key = cacheKey(for: url)
        entries[key] = Entry(
            fileSize: fileSize,
            modificationTime: modificationTime(for: modificationDate),
            metadata: snapshot,
            cachedAt: Date()
        )
    }

    func save() {
        pruneIfNeeded()

        do {
            let payload = CacheFile(entries: entries)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: cacheURL, options: [.atomic])
        } catch {
            print("Duet metadata cache save failed: \(error.localizedDescription)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: cacheURL)
            entries = try JSONDecoder().decode(CacheFile.self, from: data).entries
        } catch {
            entries = [:]
        }
    }

    private func pruneIfNeeded(maxEntries: Int = 2_000) {
        guard entries.count > maxEntries else {
            return
        }

        entries = Dictionary(
            uniqueKeysWithValues: entries
                .sorted { $0.value.cachedAt > $1.value.cachedAt }
                .prefix(maxEntries)
                .map { ($0.key, $0.value) }
        )
    }

    private func cacheKey(for url: URL) -> String {
        url.standardizedFileURL.path
    }

    private func modificationTime(for date: Date?) -> TimeInterval {
        date?.timeIntervalSince1970 ?? 0
    }
}
