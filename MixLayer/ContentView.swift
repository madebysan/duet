import SwiftUI
import UniformTypeIdentifiers

/// One page of the disc carousel: a built-in sound, or the burned "Your mix" disc for your files.
enum CarouselItem: Hashable, Identifiable {
    case sound(String)
    case yourMix

    static let yourMixID = "your-mix"

    var id: String {
        switch self {
        case .sound(let id): "sound-\(id)"
        case .yourMix: Self.yourMixID
        }
    }

    static func id(for track: AudioTrack?) -> String? {
        guard let track else { return nil }
        return track.soundID.map { "sound-\($0)" } ?? yourMixID
    }
}

struct ContentView: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var isShowingFiles = false
    @State private var centeredID: String?
    @State private var commitTask: Task<Void, Never>?

    /// Sounds in shelf order (Noise, Rain, Forest, Ocean), then Your mix.
    private var items: [CarouselItem] {
        let available = SoundCatalog.all.filter(\.isAvailable)
        let ordered = SoundCategory.allCases.flatMap { category in available.filter { $0.category == category } }
        return ordered.map { .sound($0.id) } + [.yourMix]
    }

    private var isEmptyMixCentered: Bool {
        centeredID == CarouselItem.yourMixID && player.fileTracks.isEmpty
    }

    private var glow: Color {
        let track = player.currentTrack
        if let sound = SoundCatalog.sound(id: track?.soundID) {
            return sound.finish.glow
        }
        if let track, track.artwork != nil {
            return Color(uiColor: track.accentColor)
        }
        return track == nil ? MixTheme.accent : DiscFinish.burned.glow
    }

    var body: some View {
        VStack(spacing: 16) {
            if let problem = player.audioProblem {
                Text(problem)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.red.opacity(0.85))
                    .padding(.horizontal, 20)
            }

            DiscCarousel(
                items: items,
                centeredID: $centeredID,
                onTapCentered: tapCenteredDisc
            )

            nowPlayingRow
                .padding(.horizontal, 20)

            VolumeBar(percent: $player.volumePercent, tint: glow)
                .padding(.horizontal, 20)

            Spacer(minLength: 12)

            yourFilesButton
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
        }
        .padding(.top, 12)
        .background(background)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingFiles) {
            FilesSheet()
        }
        .onChange(of: player.currentTrack?.id, initial: true) { _, _ in
            // Keep the carousel on the loaded disc when playback changes elsewhere
            // (a file row, lock-screen next/previous, relaunch).
            guard let id = CarouselItem.id(for: player.currentTrack), id != centeredID else { return }
            withAnimation(MixTheme.slide) { centeredID = id }
        }
        .onChange(of: centeredID) { _, newID in
            guard let newID, newID != CarouselItem.id(for: player.currentTrack) else { return }
            Haptics.selection()
            // Wait for the swipe to settle so passing discs don't each start playing.
            commitTask?.cancel()
            commitTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(280))
                guard !Task.isCancelled else { return }
                commitSelection(newID)
            }
        }
    }

    private var nowPlayingRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isEmptyMixCentered ? "Your mix" : (player.currentTrack?.title ?? "Pick a disc"))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MixTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .contentTransition(.opacity)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(MixTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Haptics.impact(.heavy)
                if isEmptyMixCentered {
                    isShowingFiles = true
                } else {
                    player.togglePlayback()
                }
            } label: {
                Image(systemName: isEmptyMixCentered ? "plus" : (player.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MixTheme.background)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(MixTheme.textPrimary))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(isEmptyMixCentered ? "Add files" : (player.isPlaying ? "Pause" : "Play"))
        }
    }

    /// Opens Your files, a separate screen for managing your own audio.
    private var yourFilesButton: some View {
        Button {
            Haptics.impact(.light)
            isShowingFiles = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "opticaldisc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(MixTheme.textPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your files")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MixTheme.textPrimary)
                    Text(filesSummary)
                        .font(.system(size: 12))
                        .foregroundStyle(MixTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MixTheme.textTertiary)
            }
            .padding(.horizontal, 16)
            .frame(height: 60)
            .background(MixTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityHint("Opens your own audio files")
    }

    private var filesSummary: String {
        let count = player.fileTracks.count
        if count == 0 { return "Add audio from Files, iCloud, or Google Drive" }
        return "\(count) \(count == 1 ? "file" : "files") · \(player.fileMode.label)"
    }

    private var subtitle: String {
        if isEmptyMixCentered {
            return "Add files to burn your own disc"
        }

        guard let track = player.currentTrack else {
            return "Swipe to choose a disc"
        }

        let category = SoundCatalog.sound(id: track.soundID)?.category.title

        if !player.isPlaying && !player.hasStartedPlayback {
            return track.isSound ? "\(category ?? "Sound") · Ready" : "Ready · \(timeString(track.duration))"
        }

        if track.isSound {
            return "\(category ?? "Sound") · \(player.isPlaying ? "Looping" : "Paused")"
        }

        let duration = player.playbackDuration > 0 ? player.playbackDuration : track.duration
        let time = "\(timeString(player.playbackTime)) of \(timeString(duration))"
        return player.isPlaying ? "\(time) · \(player.fileMode.label)" : "Paused · \(time)"
    }

    private var background: some View {
        ZStack {
            MixTheme.background
            RadialGradient(
                colors: [glow.opacity(0.28), glow.opacity(0.06), .clear],
                center: .top,
                startRadius: 10,
                endRadius: 460
            )
            .animation(.easeInOut(duration: 0.6), value: player.currentTrack?.id)
        }
        .ignoresSafeArea()
    }

    /// Loads the centered disc. Keeps playing if something was playing; otherwise just loads it.
    private func commitSelection(_ id: String) {
        let track: AudioTrack?
        if id == CarouselItem.yourMixID {
            if let current = player.currentTrack, !current.isSound {
                track = current
            } else {
                track = player.fileTracks.first
            }
        } else {
            track = player.soundTracks.first { CarouselItem.id(for: $0) == id }
        }

        guard let track, track != player.currentTrack else { return }
        if player.isPlaying {
            player.play(track: track)
        } else {
            player.select(track: track)
        }
    }

    private func tapCenteredDisc() {
        Haptics.impact(.heavy)
        if isEmptyMixCentered {
            isShowingFiles = true
        } else {
            player.togglePlayback()
        }
    }
}

/// Your files lives on its own screen: managing your own audio is a different job from
/// picking a background sound.
private struct FilesSheet: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @Environment(\.dismiss) private var dismiss
    @State private var isImportingFiles = false

    var body: some View {
        NavigationStack {
            FilesPanel(isImportingFiles: $isImportingFiles)
                .padding(.top, 8)
                .frame(maxHeight: .infinity, alignment: .top)
                .background(MixTheme.background.ignoresSafeArea())
                .navigationTitle("Your files")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
        }
        .fileImporter(
            isPresented: $isImportingFiles,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            if case .success(let urls) = result {
                Haptics.impact(.medium)
                player.importFiles(urls: urls)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.dark)
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(MixTheme.tapSpring, value: configuration.isPressed)
    }
}

// MARK: - Disc carousel

/// Swipe sideways to change the disc. The centered disc lifts and glows once it's loaded;
/// neighbours peek in at the sides, smaller and dimmed. Tapping the centered disc plays or pauses.
private struct DiscCarousel: View {
    @EnvironmentObject private var player: AudioPlayerModel
    let items: [CarouselItem]
    @Binding var centeredID: String?
    let onTapCentered: () -> Void

    private let discSize: CGFloat = 220
    private var pageWidth: CGFloat { discSize }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                // Negative spacing pulls the shrunken neighbours in so both sides peek.
                LazyHStack(spacing: -60) {
                    ForEach(items) { item in
                        page(for: item)
                            .frame(width: pageWidth, height: discSize + 24)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.74)
                                    .brightness(phase.isIdentity ? 0 : -0.32)
                                    .saturation(phase.isIdentity ? 1 : 0.6)
                            }
                            .id(item.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, max((proxy.size.width - pageWidth) / 2, 0), for: .scrollContent)
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $centeredID, anchor: .center)
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
        .frame(height: discSize + 24)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Disc")
        .accessibilityValue(accessibilityValue)
        .accessibilityAdjustableAction { direction in
            guard let index = items.firstIndex(where: { $0.id == centeredID }) else { return }
            let next = direction == .increment ? index + 1 : index - 1
            if items.indices.contains(next) {
                withAnimation(MixTheme.slide) { centeredID = items[next].id }
            }
        }
        .accessibilityAction(named: player.isPlaying ? "Pause" : "Play", onTapCentered)
    }

    private var accessibilityValue: String {
        guard let id = centeredID else { return "" }
        if id == CarouselItem.yourMixID { return "Your mix" }
        return player.soundTracks.first { CarouselItem.id(for: $0) == id }?.title ?? ""
    }

    @ViewBuilder
    private func page(for item: CarouselItem) -> some View {
        let track = track(for: item)
        let isCentered = centeredID == item.id
        let isLoaded = isCentered && track != nil && track == player.currentTrack

        CarouselDisc(
            track: track,
            isLoaded: isLoaded,
            isSpinning: isLoaded && player.isPlaying,
            size: discSize
        )
        .animation(MixTheme.slide, value: isLoaded)
        .contentShape(Rectangle())
        .onTapGesture {
            if isCentered {
                onTapCentered()
            } else {
                withAnimation(MixTheme.slide) { centeredID = item.id }
            }
        }
    }

    private func track(for item: CarouselItem) -> AudioTrack? {
        switch item {
        case .sound(let id):
            return player.soundTracks.first { $0.soundID == id }
        case .yourMix:
            if let current = player.currentTrack, !current.isSound { return current }
            return player.fileTracks.first
        }
    }
}

// MARK: - Your files

private struct FilesPanel: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @Binding var isImportingFiles: Bool

    var body: some View {
        if player.fileTracks.isEmpty && !player.isLoadingFiles {
            emptyState
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    ForEach(PlaybackMode.allCases) { mode in
                        Button {
                            Haptics.selection()
                            player.fileMode = mode
                        } label: {
                            Text(mode.label)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(player.fileMode == mode ? MixTheme.background : MixTheme.textSecondary)
                                .padding(.horizontal, 12)
                                .frame(height: 32)
                                .background(player.fileMode == mode ? MixTheme.textPrimary : MixTheme.surface)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(player.fileMode == mode ? .isSelected : [])
                    }

                    Spacer(minLength: 0)

                    Menu {
                        Button(role: .destructive) {
                            player.removeAllFiles()
                        } label: {
                            Label("Remove all files", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MixTheme.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(MixTheme.surface)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("More")
                }
                .padding(.horizontal, 20)

                addFilesButton
                    .padding(.horizontal, 20)

                if let problem = player.fileImportProblem {
                    Text(problem)
                        .font(.system(size: 13))
                        .foregroundStyle(.red.opacity(0.85))
                        .padding(.horizontal, 20)
                }

                List {
                    ForEach(player.fileTracks) { track in
                        Button {
                            Haptics.impact(.medium)
                            player.play(track: track)
                        } label: {
                            FileRow(
                                track: track,
                                isCurrent: player.currentTrack == track,
                                isPlaying: player.isPlaying && player.currentTrack == track
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparatorTint(.white.opacity(0.08))
                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation { player.removeFile(track) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
    }

    private var addFilesButton: some View {
        Button {
            Haptics.impact(.medium)
            isImportingFiles = true
        } label: {
            Label("Add files", systemImage: "plus")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MixTheme.textPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(MixTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.10), lineWidth: 1)
                )
        }
        .buttonStyle(PressScaleStyle())
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "opticaldisc")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(MixTheme.textSecondary)

            Text("Burn your own disc")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(MixTheme.textPrimary)

            Text("Pick audio from Files, iCloud, or Google Drive. Duet remembers it for next time.")
                .font(.system(size: 14))
                .foregroundStyle(MixTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let problem = player.fileImportProblem {
                Text(problem)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            addFilesButton
                .padding(.top, 6)
        }
        .padding(.horizontal, 32)
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
}

private struct FileRow: View {
    let track: AudioTrack
    let isCurrent: Bool
    let isPlaying: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let artwork = track.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    MixTheme.surface
                    Image(systemName: "music.note")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(MixTheme.textTertiary)
                }
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isCurrent ? MixTheme.textPrimary : MixTheme.textPrimary.opacity(0.88))
                    .lineLimit(1)
                Text(track.artist ?? track.url.pathExtension.uppercased())
                    .font(.system(size: 12))
                    .foregroundStyle(MixTheme.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if isCurrent {
                Image(systemName: "waveform")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MixTheme.accent)
                    .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                    .accessibilityHidden(true)
            }

            Text(timeString(track.duration))
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(MixTheme.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? (isPlaying ? "Playing" : "Paused") : "")
    }
}

func timeString(_ value: TimeInterval) -> String {
    guard value.isFinite, value > 0 else {
        return "0:00"
    }

    let total = Int(value.rounded())
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    let seconds = total % 60
    return hours > 0
        ? "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
        : "\(minutes):\(String(format: "%02d", seconds))"
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerModel())
}
