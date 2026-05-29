import AVFoundation
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class AudioPlayerModel: NSObject, ObservableObject {
    @Published private(set) var tracks: [AudioTrack] = []
    @Published private(set) var currentTrack: AudioTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var playbackDuration: TimeInterval = 0
    @Published var shuffleEnabled = true
    @Published var volume: Float = 0.32 {
        didSet {
            player?.volume = min(max(volume, 0), 1)
            updateNowPlayingInfo()
        }
    }
    @Published private(set) var status = "Ready"
    @Published private(set) var libraryName = "Sample Library"

    private let supportedExtensions = Set(["aac", "aif", "aiff", "caf", "m4a", "m4b", "mp3", "wav"])
    private let metadataCache = AudioMetadataCache()
    private var player: AVAudioPlayer?
    private var folderURL: URL?
    private var selectedFileURLs: [URL] = []
    private var isAccessingFolder = false
    private var securityScopedFileURLs: [URL] = []
    private var isObservingAudioSession = false
    private var notificationTokens: [NSObjectProtocol] = []
    private var progressTimer: Timer?

    func bootstrapLibrary() async {
        startObservingAudioSession()
        configureAudioSession()
        await refreshTracks()
    }

    func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            status = "Mix mode active"
            logAudioRoute(prefix: "configured")
        } catch {
            status = "Audio setup failed: \(error.localizedDescription)"
            print("MixLayer audio setup failed: \(error.localizedDescription)")
        }
    }

    func importFolder(url: URL) {
        stop()
        stopFolderAccess(resetLibraryName: false)
        stopFileAccess(resetLibraryName: false)

        guard url.startAccessingSecurityScopedResource() else {
            status = "Could not access folder"
            return
        }

        folderURL = url
        isAccessingFolder = true
        libraryName = url.lastPathComponent.isEmpty ? "Library" : url.lastPathComponent
        status = "Loading folder"

        Task {
            await refreshTracks()
        }
    }

    func importFiles(urls: [URL]) {
        stop()

        // When in folder mode, switching to file mode — start fresh
        if folderURL != nil {
            stopFolderAccess(resetLibraryName: false)
            selectedFileURLs = []
        }

        var acceptedURLs: [URL] = []

        for url in urls {
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }

            if url.startAccessingSecurityScopedResource() {
                securityScopedFileURLs.append(url)
                acceptedURLs.append(url)
            } else if FileManager.default.isReadableFile(atPath: url.path) {
                acceptedURLs.append(url)
            }
        }

        guard !acceptedURLs.isEmpty else { return }

        // Append to existing library, de-duplicating by URL
        let existing = Set(selectedFileURLs)
        let new = acceptedURLs.filter { !existing.contains($0) }
        guard !new.isEmpty else { return }

        selectedFileURLs.append(contentsOf: new)
        updateLibraryName()
        folderURL = nil
        isAccessingFolder = false
        status = "Loading files"

        Task {
            await refreshTracks()
        }
    }

    private func updateLibraryName() {
        guard !selectedFileURLs.isEmpty else {
            libraryName = "Sample Library"
            return
        }

        if selectedFileURLs.count == 1 {
            libraryName = selectedFileURLs[0].deletingPathExtension().lastPathComponent
        } else {
            let parents = Set(selectedFileURLs.map { $0.deletingLastPathComponent().standardizedFileURL.path })
            libraryName = parents.count == 1 ? selectedFileURLs[0].deletingLastPathComponent().lastPathComponent : "Selected Files"
        }
    }

    func clearLibrary() {
        stop()
        selectedFileURLs = []
        stopFileAccess(resetLibraryName: true)
        folderURL = nil
        isAccessingFolder = false
        tracks = []
        currentTrack = nil
        playbackDuration = 0
        libraryName = "Sample Library"
        status = "Ready"
    }

    func removeTrack(_ track: AudioTrack) {
        guard let index = tracks.firstIndex(of: track) else { return }

        tracks.remove(at: index)

        // Remove from selectedFileURLs if present
        if let urlIndex = selectedFileURLs.firstIndex(of: track.url) {
            selectedFileURLs.remove(at: urlIndex)
        }

        // Stop security-scoped access if this was a security-scoped URL
        if let scopedIndex = securityScopedFileURLs.firstIndex(of: track.url) {
            track.url.stopAccessingSecurityScopedResource()
            securityScopedFileURLs.remove(at: scopedIndex)
        }

        // If this was the current track, move to next or stop
        if currentTrack == track {
            if tracks.isEmpty {
                currentTrack = nil
                stop()
            } else {
                play(track: tracks[0])
            }
        }

        updateLibraryName()

        if tracks.isEmpty {
            libraryName = "Sample Library"
            status = "Ready"
        }
    }

    func playSample() {
        guard let sample = tracks.first(where: { $0.source == .bundled }) else {
            status = "Sample audio missing"
            return
        }

        play(track: sample)
    }

    func play(track: AudioTrack) {
        configureAudioSession()

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let nextPlayer = try AVAudioPlayer(contentsOf: track.url)
            nextPlayer.delegate = self
            nextPlayer.volume = volume
            nextPlayer.numberOfLoops = track.loops ? -1 : 0
            nextPlayer.prepareToPlay()
            nextPlayer.play()

            player = nextPlayer
            currentTrack = track
            playbackTime = 0
            playbackDuration = nextPlayer.duration
            isPlaying = true
            status = "Playing"
            UIApplication.shared.beginReceivingRemoteControlEvents()
            configureRemoteCommands()
            updateNowPlayingInfo()
            startProgressTimer()
            logAudioRoute(prefix: "playing \(track.title)")
        } catch {
            status = "Playback failed: \(error.localizedDescription)"
            print("MixLayer playback failed: \(error.localizedDescription)")
        }
    }

    func togglePlayback() {
        guard let player else {
            if let currentTrack {
                play(track: currentTrack)
            } else {
                playSample()
            }
            return
        }

        if player.isPlaying {
            player.pause()
            isPlaying = false
            status = "Paused"
            stopProgressTimer()
        } else {
            configureAudioSession()
            player.play()
            isPlaying = true
            status = "Playing"
            startProgressTimer()
        }

        updateNowPlayingInfo()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        playbackTime = 0
        playbackDuration = 0
        status = "Stopped"
        stopProgressTimer()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func playNext() {
        guard !tracks.isEmpty else {
            playSample()
            return
        }

        play(track: nextTrack())
    }

    func playPrevious() {
        guard let currentTrack,
              let index = tracks.firstIndex(of: currentTrack),
              !tracks.isEmpty else {
            playSample()
            return
        }

        let previousIndex = index == 0 ? tracks.count - 1 : index - 1
        play(track: tracks[previousIndex])
    }

    func refreshTracks() async {
        let nextTracks: [AudioTrack]
        if folderURL != nil {
            nextTracks = await folderTracks()
        } else if !selectedFileURLs.isEmpty {
            nextTracks = await selectedFileTracks()
        } else {
            nextTracks = await bundledTracks()
            libraryName = "Sample Library"
        }

        tracks = nextTracks

        if let currentTrack, tracks.contains(currentTrack) {
            playbackDuration = player?.duration ?? currentTrack.duration
        } else {
            currentTrack = tracks.first
            playbackTime = 0
            playbackDuration = tracks.first?.duration ?? 0
        }

        if folderURL != nil {
            status = nextTracks.isEmpty ? "No audio files" : "\(nextTracks.count) files"
        } else if !selectedFileURLs.isEmpty {
            status = nextTracks.isEmpty ? "No playable files" : "\(nextTracks.count) selected"
        } else if nextTracks.count == 1 {
            status = "Sample ready"
        }
    }

    private func bundledTracks() async -> [AudioTrack] {
        return []
    }

    private func folderTracks() async -> [AudioTrack] {
        guard let folderURL else {
            return []
        }

        return await loadTracks(from: collectAudioFiles(in: folderURL))
    }

    private func selectedFileTracks() async -> [AudioTrack] {
        let files = selectedFileURLs
            .compactMap(audioFileReference(for:))
            .sorted {
                $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
            }

        return await loadTracks(from: files)
    }

    private func loadTracks(from files: [AudioFileReference]) async -> [AudioTrack] {
        var tracks: [AudioTrack] = []
        var cacheChanged = false

        for file in files {
            let cachedMetadata = metadataCache.snapshot(
                for: file.url,
                fileSize: file.fileSize,
                modificationDate: file.modificationDate
            )

            let track = await AudioTrack.load(
                url: file.url,
                source: .folder,
                cachedMetadata: cachedMetadata
            )

            if cachedMetadata == nil {
                metadataCache.store(
                    track.metadataSnapshot,
                    for: file.url,
                    fileSize: file.fileSize,
                    modificationDate: file.modificationDate
                )
                cacheChanged = true
            }

            tracks.append(track)
        }

        if cacheChanged {
            metadataCache.save()
        }

        return tracks
    }

    private func audioFileReference(for url: URL) -> AudioFileReference? {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey]

        do {
            let values = try url.resourceValues(forKeys: keys)
            guard values.isRegularFile != false else {
                return nil
            }

            return AudioFileReference(
                url: url,
                fileSize: Int64(values.fileSize ?? 0),
                modificationDate: values.contentModificationDate
            )
        } catch {
            return nil
        }
    }

    private func collectAudioFiles(in folderURL: URL) -> [AudioFileReference] {
        var files: [AudioFileReference] = []
        let keys: [URLResourceKey] = [.isRegularFileKey, .localizedNameKey, .fileSizeKey, .contentModificationDateKey]
        let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            status = "Could not scan folder"
            return []
        }

        for case let fileURL as URL in enumerator {
            guard supportedExtensions.contains(fileURL.pathExtension.lowercased()) else {
                continue
            }

            do {
                let values = try fileURL.resourceValues(forKeys: Set(keys))
                if values.isRegularFile == true {
                    files.append(
                        AudioFileReference(
                            url: fileURL,
                            fileSize: Int64(values.fileSize ?? 0),
                            modificationDate: values.contentModificationDate
                        )
                    )
                }
            } catch {
                continue
            }
        }

        return files.sorted {
            $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending
        }
    }

    func seek(to progress: Double) {
        guard let player, playbackDuration > 0 else {
            return
        }

        let clampedProgress = min(max(progress, 0), 1)
        let nextTime = playbackDuration * clampedProgress
        player.currentTime = nextTime
        playbackTime = nextTime
        updateNowPlayingInfo()
    }

    private func stopFolderAccess(resetLibraryName: Bool = true) {
        if isAccessingFolder {
            folderURL?.stopAccessingSecurityScopedResource()
        }

        folderURL = nil
        isAccessingFolder = false
        if resetLibraryName {
            libraryName = "Sample Library"
        }
    }

    private func stopFileAccess(resetLibraryName: Bool = true) {
        for url in securityScopedFileURLs {
            url.stopAccessingSecurityScopedResource()
        }

        securityScopedFileURLs = []
        selectedFileURLs = []

        if resetLibraryName {
            libraryName = "Sample Library"
        }
    }

    private func nextTrack() -> AudioTrack {
        if shuffleEnabled, tracks.count > 1 {
            let candidates = tracks.filter { $0 != currentTrack }
            return candidates.randomElement() ?? tracks[0]
        }

        guard let currentTrack,
              let index = tracks.firstIndex(of: currentTrack) else {
            return tracks[0]
        }

        let nextIndex = tracks.index(after: index)
        return nextIndex == tracks.endIndex ? tracks[0] : tracks[nextIndex]
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true

        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false {
                    self?.togglePlayback()
                }
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true {
                    self?.togglePlayback()
                }
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayback()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playPrevious()
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTrack.title,
            MPMediaItemPropertyArtist: currentTrack.artistDisplay,
            MPMediaItemPropertyAlbumTitle: currentTrack.albumDisplay,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0
        ]

        if let player {
            info[MPMediaItemPropertyPlaybackDuration] = player.duration
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = player.currentTime
        }

        if let artwork = currentTrack.artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                artwork
            }
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func startProgressTimer() {
        stopProgressTimer()

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else {
                    return
                }

                self.playbackTime = player.currentTime
                self.playbackDuration = player.duration
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func logAudioRoute(prefix: String) {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
            .map { "\($0.portName) [\($0.portType.rawValue)]" }
            .joined(separator: ", ")
        print("MixLayer audio \(prefix). category=\(session.category.rawValue) options=\(session.categoryOptions.rawValue) outputs=\(outputs)")
    }

    private func startObservingAudioSession() {
        guard !isObservingAudioSession else {
            return
        }

        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        let interruptionToken = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                self?.handleInterruption(typeValue: typeValue, optionValue: optionValue)
            }
        }

        let routeToken = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.logAudioRoute(prefix: "route changed")
            }
        }

        notificationTokens = [interruptionToken, routeToken]
        isObservingAudioSession = true
    }

    private func handleInterruption(typeValue: UInt?, optionValue: UInt?) {
        let type = typeValue.flatMap(AVAudioSession.InterruptionType.init(rawValue:))
        let options = AVAudioSession.InterruptionOptions(rawValue: optionValue ?? 0)

        switch type {
        case .began:
            isPlaying = false
            status = "Interrupted"
            print("MixLayer interruption began")
        case .ended:
            status = options.contains(.shouldResume) ? "Interruption ended, can resume" : "Interruption ended"
            print("MixLayer interruption ended. shouldResume=\(options.contains(.shouldResume))")
        case .none:
            print("MixLayer interruption unknown")
        @unknown default:
            print("MixLayer interruption future type")
        }
    }
}

private struct AudioFileReference {
    let url: URL
    let fileSize: Int64
    let modificationDate: Date?
}

extension AudioPlayerModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.playNext()
        }
    }
}
