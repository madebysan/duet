import AVFoundation
import Foundation
import MediaPlayer
import UIKit

@MainActor
final class AudioPlayerModel: NSObject, ObservableObject {
    @Published private(set) var soundTracks: [AudioTrack] = []
    @Published private(set) var fileTracks: [AudioTrack] = []
    @Published private(set) var currentTrack: AudioTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var playbackTime: TimeInterval = 0
    @Published private(set) var playbackDuration: TimeInterval = 0
    @Published private(set) var isLoadingFiles = false
    /// False until something has played this session, so the UI can say "Ready" instead of "Paused".
    @Published private(set) var hasStartedPlayback = false
    @Published private(set) var audioProblem: String?
    @Published private(set) var fileImportProblem: String?

    /// Volume as a whole percent, 0...100.
    @Published var volumePercent: Int = 30 {
        didSet {
            let clamped = min(max(volumePercent, 0), 100)
            guard clamped == volumePercent else {
                volumePercent = clamped
                return
            }
            player?.volume = Float(volumePercent) / 100
            defaults.set(volumePercent, forKey: Keys.volume)
        }
    }

    /// Every disc in carousel order: sounds (Noise, Rain, Forest, Ocean), then your files.
    var discTracks: [AudioTrack] { soundTracks + fileTracks }

    private enum Keys {
        static let volume = "volumePercent"
        static let fileBookmarks = "fileBookmarks"
        static let lastSelection = "lastSelection"
    }

    private let supportedExtensions = Set(["aac", "aif", "aiff", "caf", "m4a", "m4b", "mp3", "wav"])
    private let metadataCache = AudioMetadataCache()
    private let defaults = UserDefaults.standard
    private var player: AVAudioPlayer?
    private var fileURLs: [URL] = []
    private var securityScopedURLs: Set<URL> = []
    private var resumeAfterInterruption = false
    private var isObservingAudioSession = false
    private var notificationTokens: [NSObjectProtocol] = []
    private var progressTimer: Timer?

    override init() {
        super.init()
        if defaults.object(forKey: Keys.volume) != nil {
            volumePercent = defaults.integer(forKey: Keys.volume)
        }
    }

    // MARK: - Startup

    func bootstrapLibrary() async {
        startObservingAudioSession()
        configureAudioSession()
        soundTracks = SoundCategory.allCases.flatMap { category in
            SoundCatalog.all.filter { $0.category == category }.compactMap { sound in
                sound.url.map { AudioTrack.builtIn(sound, url: $0) }
            }
        }
        restoreFileURLs()
        await reloadFileTracks()
        restoreLastSelection()
    }

    func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            audioProblem = nil
            logAudioRoute(prefix: "configured")
        } catch {
            audioProblem = "Audio setup failed. Restart Duet."
            print("Duet audio setup failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Your files

    func importFiles(urls: [URL]) {
        var added: [URL] = []

        for url in urls where supportedExtensions.contains(url.pathExtension.lowercased()) {
            guard !fileURLs.contains(url) else { continue }

            if url.startAccessingSecurityScopedResource() {
                securityScopedURLs.insert(url)
                added.append(url)
            } else if FileManager.default.isReadableFile(atPath: url.path) {
                added.append(url)
            }
        }

        guard !added.isEmpty else {
            fileImportProblem = urls.isEmpty ? nil : "Those files couldn't be opened. Try picking them again."
            return
        }

        fileImportProblem = nil
        fileURLs.append(contentsOf: added)
        saveFileBookmarks()

        Task {
            await reloadFileTracks()
        }
    }

    func removeFile(_ track: AudioTrack) {
        let wasCurrent = currentTrack == track
        fileTracks.removeAll { $0 == track }
        fileURLs.removeAll { $0 == track.url }
        if securityScopedURLs.remove(track.url) != nil {
            track.url.stopAccessingSecurityScopedResource()
        }
        saveFileBookmarks()

        if wasCurrent {
            unloadCurrentTrack()
        }
    }

    func removeAllFiles() {
        if currentTrack?.source == .file {
            unloadCurrentTrack()
        }
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs = []
        fileURLs = []
        fileTracks = []
        saveFileBookmarks()
    }

    private func reloadFileTracks() async {
        isLoadingFiles = true
        let references = fileURLs
            .compactMap(audioFileReference(for:))
            .sorted { $0.url.lastPathComponent.localizedStandardCompare($1.url.lastPathComponent) == .orderedAscending }
        fileTracks = await loadTracks(from: references)
        isLoadingFiles = false
    }

    private func saveFileBookmarks() {
        let bookmarks = fileURLs.compactMap { try? $0.bookmarkData() }
        defaults.set(bookmarks, forKey: Keys.fileBookmarks)
    }

    private func restoreFileURLs() {
        guard let bookmarks = defaults.array(forKey: Keys.fileBookmarks) as? [Data] else { return }
        var restored: [URL] = []
        var needsResave = false

        for bookmark in bookmarks {
            var isStale = false
            guard let url = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &isStale) else {
                needsResave = true
                continue
            }
            if url.startAccessingSecurityScopedResource() {
                securityScopedURLs.insert(url)
            }
            needsResave = needsResave || isStale
            restored.append(url)
        }

        fileURLs = restored
        if needsResave {
            saveFileBookmarks()
        }
    }

    // MARK: - Playback

    func play(track: AudioTrack) {
        configureAudioSession()

        do {
            try AVAudioSession.sharedInstance().setActive(true)
            let nextPlayer = try AVAudioPlayer(contentsOf: track.url)
            nextPlayer.delegate = self
            nextPlayer.volume = Float(volumePercent) / 100
            // Every disc, built-in or yours, loops on its own until you change it.
            nextPlayer.numberOfLoops = -1
            nextPlayer.prepareToPlay()
            nextPlayer.play()

            player?.stop()
            player = nextPlayer
            currentTrack = track
            playbackTime = 0
            playbackDuration = nextPlayer.duration
            isPlaying = true
            hasStartedPlayback = true
            rememberSelection(track)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            configureRemoteCommands()
            updateNowPlayingInfo()
            startProgressTimer()
            logAudioRoute(prefix: "playing \(track.title)")
        } catch {
            audioProblem = "\(track.title) couldn't play. It may have moved."
            print("Duet playback failed: \(error.localizedDescription)")
        }
    }

    /// Loads a track into the player without starting it (swiping the carousel while paused).
    func select(track: AudioTrack) {
        guard track != currentTrack else { return }
        player?.stop()
        player = nil
        isPlaying = false
        hasStartedPlayback = false
        currentTrack = track
        playbackTime = 0
        playbackDuration = track.duration
        stopProgressTimer()
        rememberSelection(track)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    func togglePlayback() {
        guard let player else {
            if let track = currentTrack ?? soundTracks.first {
                play(track: track)
            }
            return
        }

        if player.isPlaying {
            pause()
        } else {
            resume()
        }
    }

    func playNext() {
        let queue = discTracks
        if let index = PlaybackQueue.nextIndex(after: currentTrack.flatMap { queue.firstIndex(of: $0) }, count: queue.count) {
            play(track: queue[index])
        }
    }

    func playPrevious() {
        let queue = discTracks
        if let index = PlaybackQueue.previousIndex(before: currentTrack.flatMap { queue.firstIndex(of: $0) }, count: queue.count) {
            play(track: queue[index])
        }
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    private func resume() {
        configureAudioSession()
        try? AVAudioSession.sharedInstance().setActive(true)
        player?.play()
        isPlaying = player?.isPlaying ?? false
        startProgressTimer()
        updateNowPlayingInfo()
    }

    private func unloadCurrentTrack() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTrack = nil
        playbackTime = 0
        playbackDuration = 0
        stopProgressTimer()
        defaults.removeObject(forKey: Keys.lastSelection)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    /// Discs loop forever, so this only fires if decoding stops early.
    private func trackFinished() {
        isPlaying = false
        stopProgressTimer()
        updateNowPlayingInfo()
    }

    // MARK: - Remembering the last selection

    private func rememberSelection(_ track: AudioTrack) {
        let value = track.soundID.map { "sound:\($0)" } ?? "file:\(track.url.lastPathComponent)"
        defaults.set(value, forKey: Keys.lastSelection)
    }

    /// Shows the last disc in the player without starting playback.
    private func restoreLastSelection() {
        let value = defaults.string(forKey: Keys.lastSelection) ?? ""
        if value.hasPrefix("sound:") {
            let id = String(value.dropFirst(6))
            currentTrack = soundTracks.first { $0.soundID == id }
        } else if value.hasPrefix("file:") {
            let name = String(value.dropFirst(5))
            currentTrack = fileTracks.first { $0.url.lastPathComponent == name }
        }
        currentTrack = currentTrack ?? soundTracks.first
        playbackDuration = currentTrack?.duration ?? 0
    }

    // MARK: - Metadata

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
                source: .file,
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

    // MARK: - System integration

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
            MPMediaItemPropertyArtist: currentTrack.isSound ? "Duet" : currentTrack.artistDisplay,
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

        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
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
        print("Duet audio \(prefix). category=\(session.category.rawValue) options=\(session.categoryOptions.rawValue) outputs=\(outputs)")
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
            resumeAfterInterruption = isPlaying
            isPlaying = false
            stopProgressTimer()
            print("Duet interruption began")
        case .ended:
            print("Duet interruption ended. shouldResume=\(options.contains(.shouldResume))")
            if resumeAfterInterruption, options.contains(.shouldResume) {
                resume()
            }
            resumeAfterInterruption = false
        case .none:
            print("Duet interruption unknown")
        @unknown default:
            print("Duet interruption future type")
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
            self.trackFinished()
        }
    }
}
