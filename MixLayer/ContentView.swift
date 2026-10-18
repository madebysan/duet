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

    private var items: [CarouselItem] {
        player.discTracks.map { .track($0.id) } + [.addFiles]
    }

    private var isAddCentered: Bool { centeredID == CarouselItem.addFilesID }

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
        VStack(spacing: 0) {
            header
                .padding(.top, 20)
                .padding(.horizontal, 64)

            Spacer(minLength: 8)

            VolumeDialView(percent: $player.volumePercent, tint: glow) {
                DiscCarousel(items: items, centeredID: $centeredID, onTapCentered: tapCenteredDisc)
            }
            .frame(height: 360)

            volumeReadout
                .padding(.top, 6)

            Spacer(minLength: 8)

            bottomControls
                .padding(.bottom, 16)
        }
        .overlay(alignment: .topTrailing) {
            filesButton
                .padding(.top, 12)
                .padding(.trailing, 18)
        }
        .background(background)
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
        .onChange(of: centeredID) { _, newID in
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

    private var header: some View {
        VStack(spacing: 6) {
            Text(categoryLabel)
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(MixTheme.textSecondary)

            Text(isAddCentered ? "Add files" : (player.currentTrack?.title ?? "Swipe to choose"))
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(MixTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.opacity)

            Text(player.audioProblem ?? status)
                .font(.system(size: 13, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(player.audioProblem == nil ? MixTheme.textSecondary : .red.opacity(0.85))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var categoryLabel: String {
        if isAddCentered { return "Your files" }
        guard let track = player.currentTrack else { return " " }
        return SoundCatalog.sound(id: track.soundID)?.category.title ?? "Your files"
    }

    private var status: String {
        if isAddCentered { return "Bring your own audio" }
        guard let track = player.currentTrack else { return "Ready" }
        if !player.isPlaying {
            return player.hasStartedPlayback ? "Paused" : "Ready"
        }
        if track.isSound { return "Looping" }
        let duration = player.playbackDuration > 0 ? player.playbackDuration : track.duration
        return "Looping · \(timeString(player.playbackTime)) of \(timeString(duration))"
    }

    private var filesButton: some View {
        Button {
            Haptics.impact(.light)
            isShowingFiles = true
        } label: {
            Image(systemName: "opticaldisc")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MixTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .buttonStyle(PressScaleStyle())
        .accessibilityLabel("Your files")
    }

    // MARK: Volume and transport

    private var volumeReadout: some View {
        VStack(spacing: 2) {
            Text("\(player.volumePercent)%")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(MixTheme.textPrimary)
                .contentTransition(.numericText(value: Double(player.volumePercent)))
            Text("Volume · drag the ring")
                .font(.system(size: 12, weight: .semibold))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(MixTheme.textSecondary)
        }
        .accessibilityHidden(true)
    }

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

    private let radius: CGFloat = 160
    private let bandInner: CGFloat = 126
    private let bandOuter: CGFloat = 188

    var body: some View {
        ZStack {
            content()

            DialRing(percent: percent, tint: tint, radius: radius)
                .allowsHitTesting(false)

            Annulus(innerRatio: bandInner / bandOuter)
                .fill(Color.clear)
                .contentShape(Annulus(innerRatio: bandInner / bandOuter), eoFill: true)
                .frame(width: bandOuter * 2, height: bandOuter * 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let next = VolumeDial.percent(
                                dx: value.location.x - bandOuter,
                                dy: value.location.y - bandOuter
                            )
                            if next != percent {
                                if next / 5 != percent / 5 { Haptics.selection() }
                                percent = next
                            }
                        }
                )
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

    var body: some View {
        let fraction = VolumeDial.sweep / 360
        let knob = VolumeDial.angle(forPercent: percent) * .pi / 180

        ZStack {
            ForEach(0..<28, id: \.self) { k in
                let tickAngle = VolumeDial.startAngle + Double(k) * 10
                Capsule()
                    .fill(.white.opacity(tickAngle <= VolumeDial.angle(forPercent: percent) ? 0.55 : 0.14))
                    .frame(width: 2, height: 6)
                    .offset(y: -(radius + 17))
                    .rotationEffect(.degrees(tickAngle))
            }

            Circle()
                .trim(from: 0, to: fraction)
                .stroke(.white.opacity(0.1), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .trim(from: 0, to: fraction * Double(percent) / 100)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(135))

            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .shadow(color: .black.opacity(0.5), radius: 4, y: 2)
                .offset(x: radius * sin(knob), y: -radius * cos(knob))
        }
        .frame(width: radius * 2, height: radius * 2)
        .animation(.snappy(duration: 0.15), value: percent)
    }
}

/// A ring-shaped hit area: the band between `innerRatio` and the full radius (use with even-odd fill).
private struct Annulus: Shape {
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.addEllipse(in: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        let inner = r * innerRatio
        path.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner, width: inner * 2, height: inner * 2))
        return path
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
            emptyState
        } else {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Text("Each file is its own disc and loops until you change it.")
                        .font(.system(size: 13))
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
