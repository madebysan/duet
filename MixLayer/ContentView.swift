import SwiftUI
import UniformTypeIdentifiers

/// One page of the disc carousel: a sound or one of your files, then a blank "Add files" disc.
enum CarouselItem: Hashable, Identifiable {
    case track(String)
    case addFiles

    static let addFilesID = "add-files"

    var id: String {
        switch self {
        case .track(let id): id
        case .addFiles: Self.addFilesID
        }
    }
}

/// Main screen ("Dial"): the disc sits inside a volume ring. Swipe inside the ring to change
/// discs, drag the ring to set the volume, tap the disc or the play button to play or pause.
struct ContentView: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var isShowingFiles = false
    @State private var centeredID: String?
    @State private var commitTask: Task<Void, Never>?
    /// Which disc the name block shows; follows the carousel so the name changes as you swipe.
    @State private var headerID: String?
    /// +1 when moving to the next disc, -1 to the previous; picks the slide direction for the name.
    @State private var swipeDirection = 1
    @GestureState private var nameDrag: CGFloat = 0

    private var items: [CarouselItem] {
        player.discTracks.map { .track($0.id) } + [.addFiles]
    }

    private var isAddCentered: Bool { centeredID == CarouselItem.addFilesID }

    private var glow: Color {
        let track = player.currentTrack
        if let sound = SoundCatalog.sound(id: track?.soundID) {
            return sound.glow
        }
        if let track, track.artwork != nil {
            return Color(uiColor: track.accentColor)
        }
        return track == nil ? MixTheme.accent : DiscFinish.burned.glow
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 8)

            // Dial, then the disc's name, then the controls, centered as one group.
            // The ring shows the volume, so there's no separate readout.
            VolumeDialView(percent: $player.volumePercent, tint: glow) {
                DiscCarousel(items: items, centeredID: $centeredID, onTapCentered: tapCenteredDisc)
            }
            .frame(height: 344)

            header
                .padding(.top, 20)
                .padding(.horizontal, 40)
                .contentShape(Rectangle())
                .highPriorityGesture(swipeGesture(followsFinger: true))

            // Your files get a slim scrub line; the row keeps its height for built-in sounds
            // so the controls don't jump when you change discs.
            ScrubLine(
                time: player.playbackTime,
                duration: player.playbackDuration > 0 ? player.playbackDuration : (player.currentTrack?.duration ?? 0),
                tint: glow,
                onSeek: { player.seek(to: $0) }
            )
            .opacity(showsScrubLine ? 1 : 0)
            .allowsHitTesting(showsScrubLine)
            .accessibilityHidden(!showsScrubLine)
            .animation(.easeOut(duration: 0.2), value: showsScrubLine)
            .padding(.top, 14)
            .padding(.horizontal, 40)

            bottomControls
                .padding(.top, 26)

            Spacer(minLength: 8)
        }
        // Empty areas of the screen also swipe between discs.
        .background(
            Color.clear
                .contentShape(Rectangle())
                .gesture(swipeGesture(followsFinger: false))
        )
        .overlay(alignment: .topTrailing) {
            filesButton
                .padding(.top, 12)
                .padding(.trailing, 18)
        }
        .background(background)
        // Text follows the system size, but the 344 pt dial and the controls don't, so past
        // the first accessibility size the centered group would no longer fit an iPhone SE.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $isShowingFiles) {
            FilesSheet()
        }
        .onChange(of: player.currentTrack?.id, initial: true) { _, id in
            // Keep the carousel on the loaded disc when playback changes elsewhere
            // (a file in the sheet, lock-screen next/previous, relaunch).
            guard let id, id != centeredID else { return }
            withAnimation(MixTheme.slide) { centeredID = id }
        }
        .onChange(of: centeredID, initial: true) { oldID, newID in
            if let oldIndex = items.firstIndex(where: { $0.id == oldID }),
               let newIndex = items.firstIndex(where: { $0.id == newID }) {
                swipeDirection = newIndex >= oldIndex ? 1 : -1
            }
            withAnimation(.snappy(duration: 0.3)) { headerID = newID }

            guard let newID, newID != player.currentTrack?.id else { return }
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

    // MARK: Header

    /// The name block for the centered disc. Only one name is visible: on change the old one
    /// slides out and the next slides in from the swipe direction, clipped to this block.
    private var header: some View {
        ZStack {
            nameBlock
                .id(headerID ?? "none")
                .transition(.asymmetric(
                    insertion: .move(edge: swipeDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: swipeDirection > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
        }
        .offset(x: nameDrag * 0.5)
        .opacity(1 - min(abs(nameDrag) / 320, 0.6))
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var nameBlock: some View {
        VStack(spacing: 6) {
            Text(categoryLabel)
                .font(.caption.weight(.semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(MixTheme.textSecondary)

            Text(isAddCentered ? "Add files" : (displayedTrack?.title ?? "Swipe to choose"))
                .scaledFont(size: 30, relativeTo: .title, weight: .bold, design: .rounded)
                .foregroundStyle(MixTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)

            // No Ready/Looping/Paused label: the play button and spinning disc already say it.
            // This line only appears for an audio problem or the Add files hint.
            if let note = player.audioProblem ?? (isAddCentered ? "Bring your own audio" : nil) {
                Text(note)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(player.audioProblem == nil ? MixTheme.textSecondary : .red.opacity(0.85))
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// The centered disc's track, which can lead the player's current track by a moment while a
    /// swipe settles.
    private var displayedTrack: AudioTrack? {
        player.discTracks.first { $0.id == headerID } ?? player.currentTrack
    }

    private var categoryLabel: String {
        if isAddCentered { return "Your files" }
        guard let track = displayedTrack else { return " " }
        return SoundCatalog.sound(id: track.soundID)?.category.title ?? "Your files"
    }

    /// Only for your own files, and only once the centered file is the loaded one.
    private var showsScrubLine: Bool {
        guard let track = player.currentTrack, !track.isSound else { return false }
        return track == displayedTrack && !isAddCentered
    }

    private var filesButton: some View {
        Button {
            Haptics.impact(.light)
            isShowingFiles = true
        } label: {
            Image(systemName: "music.note.list")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MixTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Your files")
    }

    // MARK: Volume and transport

    private var bottomControls: some View {
        HStack(spacing: 36) {
            nudgeButton(systemName: "minus", label: "Lower volume", up: false)

            Button {
                Haptics.impact(.heavy)
                tapCenteredDisc()
            } label: {
                Image(systemName: isAddCentered ? "plus" : (player.isPlaying ? "pause.fill" : "play.fill"))
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(MixTheme.background)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 76, height: 76)
                    .background(Circle().fill(MixTheme.textPrimary))
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityLabel(isAddCentered ? "Add files" : (player.isPlaying ? "Pause" : "Play"))

            nudgeButton(systemName: "plus", label: "Raise volume", up: true)
        }
    }

    private func nudgeButton(systemName: String, label: String, up: Bool) -> some View {
        Button {
            Haptics.impact(.light)
            withAnimation(.snappy(duration: 0.18)) {
                player.volumePercent = VolumeStep.stepped(from: player.volumePercent, up: up)
            }
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MixTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(MixTheme.surface))
        }
        .buttonStyle(PressScaleStyle())
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(label)
    }

    private var background: some View {
        ZStack {
            MixTheme.background
            RadialGradient(
                colors: [glow.opacity(0.26), glow.opacity(0.05), .clear],
                center: UnitPoint(x: 0.5, y: 0.45),
                startRadius: 10,
                endRadius: 360
            )
            .animation(.easeInOut(duration: 0.6), value: player.currentTrack?.id)
        }
        .ignoresSafeArea()
    }

    // MARK: Swiping

    /// Horizontal swipe that moves one disc. On the name it follows the finger a little first.
    private func swipeGesture(followsFinger: Bool) -> some Gesture {
        DragGesture(minimumDistance: 20)
            .updating($nameDrag) { value, state, _ in
                guard followsFinger, abs(value.translation.width) > abs(value.translation.height) else { return }
                state = value.translation.width
            }
            .onEnded { value in
                let dx = value.translation.width, dy = value.translation.height
                guard abs(dx) > abs(dy) else { return }
                let projected = value.predictedEndTranslation.width
                if dx < -50 || projected < -160 {
                    step(by: 1)
                } else if dx > 50 || projected > 160 {
                    step(by: -1)
                }
            }
    }

    private func step(by delta: Int) {
        guard let index = items.firstIndex(where: { $0.id == centeredID }) else { return }
        let next = index + delta
        guard items.indices.contains(next) else { return }
        withAnimation(MixTheme.slide) { centeredID = items[next].id }
    }

    // MARK: Selection

    /// Loads the centered disc. Keeps playing if something was playing; otherwise just loads it.
    private func commitSelection(_ id: String) {
        guard let track = player.discTracks.first(where: { $0.id == id }), track != player.currentTrack else { return }
        if player.isPlaying {
            player.play(track: track)
        } else {
            player.select(track: track)
        }
    }

    private func tapCenteredDisc() {
        if isAddCentered {
            isShowingFiles = true
        } else {
            player.togglePlayback()
        }
    }
}

/// Elapsed time, a slim line you can drag to jump anywhere, and the total. The line thickens
/// while dragging; the jump happens when you let go, so the audio doesn't stutter.
private struct ScrubLine: View {
    let time: TimeInterval
    let duration: TimeInterval
    let tint: Color
    let onSeek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    private var fraction: Double {
        if let dragFraction { return dragFraction }
        guard duration > 0 else { return 0 }
        return min(max(time / duration, 0), 1)
    }

    var body: some View {
        HStack(spacing: 12) {
            timeLabel(timeString(fraction * duration), alignment: .trailing)

            GeometryReader { proxy in
                let height: CGFloat = dragFraction == nil ? 3 : 7
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.14))
                    Capsule().fill(tint).frame(width: proxy.size.width * fraction)
                }
                .frame(height: height)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragFraction == nil { Haptics.selection() }
                            withAnimation(.snappy(duration: 0.12)) {
                                dragFraction = min(max(value.location.x / max(proxy.size.width, 1), 0), 1)
                            }
                        }
                        .onEnded { _ in
                            if let dragFraction { onSeek(dragFraction * duration) }
                            withAnimation(.snappy(duration: 0.2)) { dragFraction = nil }
                        }
                )
            }
            .frame(height: 30)

            timeLabel(timeString(duration), alignment: .leading)
        }
        .font(.caption.weight(.medium))
        .monospacedDigit()
        .foregroundStyle(MixTheme.textSecondary)
        .accessibilityElement()
        .accessibilityLabel("Position")
        .accessibilityValue("\(timeString(time)) of \(timeString(duration))")
        .accessibilityAdjustableAction { direction in
            let step: TimeInterval = direction == .increment ? 15 : -15
            onSeek(time + step)
        }
    }

    /// One line, never wrapped. Both labels reserve the width of the longest time this file can
    /// show ("0:00" up to "10:00:00"), so the line keeps its length while the elapsed time ticks.
    private func timeLabel(_ text: String, alignment: Alignment) -> some View {
        Text(timeString(duration).replacingOccurrences(of: #"\d"#, with: "8", options: .regularExpression))
            .hidden()
            .overlay(alignment: alignment) { Text(text).fixedSize() }
            .lineLimit(1)
            .fixedSize()
    }
}

struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(MixTheme.tapSpring, value: configuration.isPressed)
    }
}

// MARK: - Volume dial

/// A 270° volume ring drawn around its content. Only the ring band takes touches, so swipes
/// and taps inside it reach the disc carousel underneath.
private struct VolumeDialView<Content: View>: View {
    @Binding var percent: Int
    let tint: Color
    @ViewBuilder let content: () -> Content

    // Ring sits just outside the 236 pt disc. Only the knob takes touches: a 56 pt circle
    // around the 13 pt knob. Taps elsewhere on the ring fall through to the disc swipe.
    private let radius: CGFloat = 140
    private let handleSize: CGFloat = 56
    @State private var isDragging = false

    var body: some View {
        let layer = radius * 2 + handleSize
        let knob = VolumeDial.angle(forPercent: percent) * .pi / 180

        ZStack {
            content()

            DialRing(percent: percent, tint: tint, radius: radius, isDragging: isDragging)
                .allowsHitTesting(false)

            ZStack {
                Circle()
                    .fill(Color.clear)
                    .frame(width: handleSize, height: handleSize)
                    .contentShape(Circle())
                    .offset(x: radius * sin(knob), y: -radius * cos(knob))
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("volumeDial"))
                            .onChanged { value in
                                if !isDragging {
                                    isDragging = true
                                    Haptics.selection()
                                }
                                let next = VolumeDial.percent(
                                    dx: value.location.x - layer / 2,
                                    dy: value.location.y - layer / 2
                                )
                                if next != percent {
                                    if next / 5 != percent / 5 { Haptics.selection() }
                                    percent = next
                                }
                            }
                            .onEnded { _ in isDragging = false }
                    )
            }
            .frame(width: layer, height: layer)
            .coordinateSpace(name: "volumeDial")
            .accessibilityElement()
            .accessibilityLabel("Volume")
            .accessibilityValue("\(percent) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: percent = VolumeStep.stepped(from: percent, up: true)
                case .decrement: percent = VolumeStep.stepped(from: percent, up: false)
                @unknown default: break
                }
            }
        }
    }
}

private struct DialRing: View {
    let percent: Int
    let tint: Color
    let radius: CGFloat
    var isDragging = false

    var body: some View {
        let fraction = VolumeDial.sweep / 360
        let knob = VolumeDial.angle(forPercent: percent) * .pi / 180

        ZStack {
            ForEach(0..<28, id: \.self) { k in
                let tickAngle = VolumeDial.startAngle + Double(k) * 10
                Capsule()
                    .fill(.white.opacity(tickAngle <= VolumeDial.angle(forPercent: percent) ? 0.55 : 0.14))
                    .frame(width: 1.5, height: 4)
                    .offset(y: -(radius + 11))
                    .rotationEffect(.degrees(tickAngle))
            }

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.white.opacity(0.1), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: fraction * Double(percent) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .fill(.white)
                .frame(width: isDragging ? 18 : 13, height: isDragging ? 18 : 13)
                .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
                .offset(x: radius * sin(knob), y: -radius * cos(knob))
        }
        .frame(width: radius * 2, height: radius * 2)
        .animation(.snappy(duration: 0.15), value: percent)
    }
}

/// Your files lives on its own screen: managing your own audio is a different job from
/// picking a disc.
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
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Disc carousel

/// Swipe sideways to change the disc. The centered disc lifts and glows once it's loaded;
/// neighbours peek in at the screen edges, smaller and dimmed.
private struct DiscCarousel: View {
    @EnvironmentObject private var player: AudioPlayerModel
    let items: [CarouselItem]
    @Binding var centeredID: String?
    let onTapCentered: () -> Void

    private let discSize: CGFloat = 236
    private var pageWidth: CGFloat { discSize }

    var body: some View {
        GeometryReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    ForEach(items) { item in
                        page(for: item)
                            .frame(width: pageWidth, height: discSize + 24)
                            .scrollTransition(axis: .horizontal) { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.65)
                                    .brightness(phase.isIdentity ? 0 : -0.3)
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
            .frame(maxHeight: .infinity)
        }
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
        if id == CarouselItem.addFilesID { return "Add files" }
        return player.discTracks.first { $0.id == id }?.title ?? ""
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
        .contentShape(Circle())
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
        case .track(let id): player.discTracks.first { $0.id == id }
        case .addFiles: nil
        }
    }
}

// MARK: - Your files

private struct FilesPanel: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @Binding var isImportingFiles: Bool

    var body: some View {
        if player.fileTracks.isEmpty && !player.isLoadingFiles {
            ScrollView {
                emptyState
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            // The note and Add files scroll with the list, so at large text sizes they don't
            // crowd the files out of a half-height sheet.
            List {
                header
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 12, trailing: 20))

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

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Text("Each file is its own disc and loops until you change it.")
                    .font(.footnote)
                    .foregroundStyle(MixTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

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

            addFilesButton

            if let problem = player.fileImportProblem {
                Text(problem)
                    .font(.footnote)
                    .foregroundStyle(.red.opacity(0.85))
            }
        }
    }

    private var addFilesButton: some View {
        Button {
            Haptics.impact(.medium)
            isImportingFiles = true
        } label: {
            // Not a Label: inside a List a Label widens its icon gap.
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Add files")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(MixTheme.textPrimary)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
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
                .font(.system(.headline, design: .rounded, weight: .bold))
                .foregroundStyle(MixTheme.textPrimary)

            Text("Pick audio from Files, iCloud, or Google Drive. Duet remembers it for next time.")
                .scaledFont(size: 14, relativeTo: .subheadline)
                .foregroundStyle(MixTheme.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let problem = player.fileImportProblem {
                Text(problem)
                    .font(.footnote)
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

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        HStack(spacing: 12) {
            artwork

            if typeSize.isAccessibilitySize {
                // Big text: the title gets the whole width, and the duration moves to the
                // details line so it still fits on one line.
                VStack(alignment: .leading, spacing: 3) {
                    title.lineLimit(2)
                    HStack(spacing: 8) {
                        details
                        Spacer(minLength: 8)
                        status
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    title.lineLimit(1)
                    details
                }

                Spacer(minLength: 8)

                status
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(isCurrent ? (isPlaying ? "Playing" : "Paused") : "")
    }

    private var artwork: some View {
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
    }

    private var title: some View {
        Text(track.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isCurrent ? MixTheme.textPrimary : MixTheme.textPrimary.opacity(0.88))
    }

    private var details: some View {
        Text(track.artist ?? track.url.pathExtension.uppercased())
            .font(.caption)
            .foregroundStyle(MixTheme.textSecondary)
            .lineLimit(1)
    }

    @ViewBuilder
    private var status: some View {
        if isCurrent {
            Image(systemName: "waveform")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(MixTheme.accent)
                .symbolEffect(.variableColor.iterative, isActive: isPlaying)
                .accessibilityHidden(true)
        }

        // Never wraps or shrinks; a long title truncates instead.
        Text(timeString(track.duration))
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(MixTheme.textTertiary)
            .lineLimit(1)
            .fixedSize()
    }
}

extension View {
    /// A design size (in points at the default text size) that grows and shrinks with Dynamic
    /// Type like the given text style, for sizes no text style matches exactly.
    func scaledFont(
        size: CGFloat,
        relativeTo style: Font.TextStyle,
        weight: Font.Weight = .regular,
        design: Font.Design = .default
    ) -> some View {
        modifier(ScaledFont(size: size, style: style, weight: weight, design: design))
    }
}

private struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    init(size: CGFloat, style: Font.TextStyle, weight: Font.Weight, design: Font.Design) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: style)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
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
