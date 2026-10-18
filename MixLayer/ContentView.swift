import SwiftUI
import UniformTypeIdentifiers

enum LibraryTab: String, CaseIterable, Identifiable {
    case sounds
    case files

    var id: String { rawValue }

    var label: String {
        switch self {
        case .sounds: "Sounds"
        case .files: "Your files"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var tab: LibraryTab = .sounds
    @State private var isImportingFiles = false
    @State private var displayedTrack: AudioTrack?
    @State private var isDiscOut = false
    @State private var hasSetInitialTab = false

    private var glow: Color {
        if let sound = SoundCatalog.sound(id: displayedTrack?.soundID) {
            return sound.finish.glow
        }
        if let track = displayedTrack, track.artwork != nil {
            return Color(uiColor: track.accentColor)
        }
        return displayedTrack == nil ? MixTheme.accent : DiscFinish.burned.glow
    }

    var body: some View {
        VStack(spacing: 16) {
            header
                .padding(.horizontal, 20)

            DiscStage(track: displayedTrack, isOut: isDiscOut, isSpinning: player.isPlaying)
                .padding(.top, 4)

            nowPlayingRow
                .padding(.horizontal, 20)

            VolumeBar(percent: $player.volumePercent, tint: glow)
                .padding(.horizontal, 20)

            LibraryTabPicker(selection: $tab)
                .padding(.horizontal, 20)

            Group {
                switch tab {
                case .sounds:
                    SoundShelf(currentTrack: player.currentTrack) { track in
                        Haptics.impact(.medium)
                        player.play(track: track)
                    }
                case .files:
                    FilesPanel(isImportingFiles: $isImportingFiles)
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 8)
        .background(background)
        .preferredColorScheme(.dark)
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
        .onChange(of: player.currentTrack?.id, initial: true) { _, _ in
            swapDisc(to: player.currentTrack)
        }
    }

    private var header: some View {
        HStack {
            Text("Duet")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(MixTheme.textPrimary)

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(player.audioProblem == nil ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(player.audioProblem ?? "Mixing with other apps")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(MixTheme.textSecondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MixTheme.surface)
            .clipShape(Capsule())
        }
    }

    private var nowPlayingRow: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentTrack?.title ?? "Pick a sound")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(MixTheme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(MixTheme.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                Haptics.impact(.heavy)
                player.togglePlayback()
            } label: {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(MixTheme.background)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(MixTheme.textPrimary))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
        }
    }

    private var subtitle: String {
        guard let track = player.currentTrack else {
            return "Choose a disc below"
        }

        if !player.isPlaying && !player.hasStartedPlayback {
            return track.isSound ? "Ready" : "Ready · \(timeString(track.duration))"
        }

        if track.isSound {
            return player.isPlaying ? "Looping" : "Paused"
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
            .animation(.easeInOut(duration: 0.6), value: displayedTrack?.id)
        }
        .ignoresSafeArea()
    }

    /// Tucks the old disc into its case, swaps the case, then slides the new disc out.
    private func swapDisc(to track: AudioTrack?) {
        if !hasSetInitialTab, let track {
            tab = track.isSound ? .sounds : .files
            hasSetInitialTab = true
        }

        guard displayedTrack != nil, isDiscOut else {
            displayedTrack = track
            withAnimation(MixTheme.slide) { isDiscOut = track != nil }
            return
        }

        withAnimation(MixTheme.tuck) { isDiscOut = false }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(240))
            displayedTrack = player.currentTrack
            withAnimation(MixTheme.slide) { isDiscOut = displayedTrack != nil }
        }
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(MixTheme.tapSpring, value: configuration.isPressed)
    }
}

private struct LibraryTabPicker: View {
    @Binding var selection: LibraryTab
    @Namespace private var highlight

    var body: some View {
        HStack(spacing: 2) {
            ForEach(LibraryTab.allCases) { item in
                Button {
                    Haptics.selection()
                    withAnimation(.snappy(duration: 0.25)) { selection = item }
                } label: {
                    Text(item.label)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selection == item ? MixTheme.textPrimary : MixTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background {
                            if selection == item {
                                Capsule()
                                    .fill(MixTheme.surfaceLight)
                                    .matchedGeometryEffect(id: "tab", in: highlight)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == item ? .isSelected : [])
            }
        }
        .padding(3)
        .background(MixTheme.surface)
        .clipShape(Capsule())
    }
}

// MARK: - Sounds

private struct SoundShelf: View {
    @EnvironmentObject private var player: AudioPlayerModel
    let currentTrack: AudioTrack?
    let onPick: (AudioTrack) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                ForEach(SoundCategory.allCases) { category in
                    let sounds = SoundCatalog.all.filter { $0.category == category && $0.isListed }
                    if !sounds.isEmpty {
                        Section {
                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(sounds) { sound in
                                    shelfItem(for: sound)
                                }
                            }
                        } header: {
                            Text(category.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(MixTheme.textSecondary)
                                .accessibilityAddTraits(.isHeader)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func shelfItem(for sound: BuiltInSound) -> some View {
        if let track = player.soundTracks.first(where: { $0.soundID == sound.id }) {
            Button {
                onPick(track)
            } label: {
                ShelfDisc(sound: sound, isLoaded: currentTrack == track)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(sound.name)
            .accessibilityAddTraits(currentTrack == track ? .isSelected : [])
        } else {
            ComingSoonDisc(sound: sound)
        }
    }
}

private struct ShelfDisc: View {
    let sound: BuiltInSound
    let isLoaded: Bool

    var body: some View {
        VStack(spacing: 8) {
            DiscFace(finish: sound.finish, artwork: sound.artwork)
                .frame(width: 78, height: 78)
                .padding(4)
                .overlay(
                    Circle().strokeBorder(isLoaded ? sound.finish.glow : .clear, lineWidth: 2)
                )
                .shadow(color: sound.finish.glow.opacity(isLoaded ? 0.5 : 0), radius: 12)

            Text(sound.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isLoaded ? MixTheme.textPrimary : MixTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ComingSoonDisc: View {
    let sound: BuiltInSound

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                DiscFace(finish: sound.finish, artwork: sound.artwork)
                    .saturation(0.2)
                    .opacity(0.3)

                Circle()
                    .strokeBorder(MixTheme.textTertiary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                Text("Soon")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MixTheme.textPrimary.opacity(0.8))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(MixTheme.background.opacity(0.7)))
            }
            .frame(width: 78, height: 78)
            .padding(4)

            Text(sound.name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MixTheme.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(sound.name), coming soon")
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
