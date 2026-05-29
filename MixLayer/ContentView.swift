import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct ContentView: View {
    @EnvironmentObject private var player: AudioPlayerModel
    @State private var isImportingFiles = false
    @State private var isQueuePresented = false
    @State private var pulseTrigger = 0

    private var currentTrack: AudioTrack? {
        player.currentTrack ?? player.tracks.first
    }

    private var accent: Color {
        Color(uiColor: currentTrack?.accentColor ?? MixTheme.fallbackAccent)
    }

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.height < 860
            let horizontalPadding: CGFloat = 24
            let topPadding: CGFloat = 18
            let bottomPadding = max(proxy.safeAreaInsets.bottom + 10, 16)
            let screenWidth = min(proxy.size.width, UIScreen.main.bounds.width)
            let contentWidth = max(screenWidth - (horizontalPadding * 2), 0)
            let contentHeight = max(proxy.size.height - topPadding - bottomPadding, 0)
            let artworkSize = max(0, min(contentWidth - 56, compact ? 246 : 278))

            ZStack {
                PlayerBackground(track: currentTrack)

                VStack(spacing: compact ? 9 : 12) {
                    topBar(width: contentWidth)

                    ArtworkHero(track: currentTrack, accent: accent, size: artworkSize)
                        .frame(width: contentWidth)
                        .clipped()
                        .padding(.top, compact ? 14 : 20)

                    metadataBlock(width: contentWidth)
                        .padding(.top, compact ? 4 : 8)

                    Spacer(minLength: compact ? 22 : 36)

                    ProgressStrip(player: player, accent: accent)
                        .frame(width: contentWidth)
                        .clipped()
                        .padding(.top, compact ? 0 : 2)

                    TransportControls(
                        player: player,
                        accent: accent,
                        pulseTrigger: $pulseTrigger
                    )
                    .frame(width: contentWidth)
                    .clipped()
                    .padding(.top, compact ? 10 : 14)

                    bottomControls(width: contentWidth)
                        .padding(.top, compact ? 8 : 12)
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .top)
                .clipped()
                .position(x: proxy.size.width / 2, y: topPadding + (contentHeight / 2))
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $isImportingFiles,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                haptic(.heavy)
                player.importFiles(urls: urls)
            case .failure:
                break
            }
        }
        .sheet(isPresented: $isQueuePresented) {
            TrackQueueSheet(
                player: player,
                accent: accent,
                onPickTrack: { track in
                    haptic(.medium)
                    player.play(track: track)
                    isQueuePresented = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .preferredColorScheme(.dark)
        }
    }

    private func topBar(width: CGFloat) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("MIXLAYER")
                    .font(MixTheme.label)
                    .tracking(3)
                    .foregroundStyle(MixTheme.textSecondary)

                HStack(spacing: 7) {
                    Circle()
                        .fill(player.isPlaying ? accent : MixTheme.textTertiary)
                        .frame(width: 7, height: 7)
                        .shadow(color: player.isPlaying ? accent.opacity(0.65) : .clear, radius: 8)

                    Text(player.status.uppercased())
                        .font(MixTheme.sublabel)
                        .tracking(1.8)
                        .foregroundStyle(player.isPlaying ? MixTheme.textPrimary : MixTheme.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 10) {
                IconCircleButton(systemName: "folder.fill", accent: accent) {
                    haptic(.medium)
                    isImportingFiles = true
                }
                .accessibilityLabel("Add music")

                IconCircleButton(systemName: "list.bullet", accent: accent) {
                    haptic(.medium)
                    isQueuePresented = true
                }
                .accessibilityLabel("Open track list")
            }
        }
        .frame(width: width)
        .clipped()
    }

    private func metadataBlock(width: CGFloat) -> some View {
        VStack(spacing: 8) {
            Text(currentTrack?.title ?? "Pick a Track")
                .font(.system(size: 27, weight: .bold, design: .rounded))
                .foregroundStyle(MixTheme.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.76)
                .truncationMode(.tail)
                .allowsTightening(true)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true)

            Text(metadataSubtitle)
                .font(MixTheme.label)
                .tracking(1.6)
                .foregroundStyle(MixTheme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
                .truncationMode(.tail)
                .allowsTightening(true)
                .frame(width: width)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: width)
        .clipped()
    }

    private var metadataSubtitle: String {
        guard let currentTrack else {
            return "ADD MUSIC"
        }

        let artist = currentTrack.artistDisplay
        let album = currentTrack.albumDisplay
        return "\(artist) / \(album)".uppercased()
    }

    private func bottomControls(width: CGFloat) -> some View {
        return HStack(spacing: 12) {
            Button {
                haptic(.light)
                withAnimation(MixTheme.tapSpring) {
                    player.shuffleEnabled.toggle()
                }
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 17, weight: .bold))
                .foregroundStyle(player.shuffleEnabled ? MixTheme.background : MixTheme.textSecondary)
                    .frame(width: 52, height: 44)
                .background(player.shuffleEnabled ? accent : MixTheme.surfaceLight)
                .clipShape(Capsule())
            }
            .accessibilityLabel(player.shuffleEnabled ? "Disable shuffle" : "Enable shuffle")

            VolumeStepper(volume: volumeBinding, accent: accent)
                .frame(maxWidth: .infinity)
        }
        .frame(width: width)
        .clipped()
    }

    private var volumeBinding: Binding<Double> {
        Binding {
            Double(player.volume)
        } set: { value in
            player.volume = Float(value)
        }
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        generator.prepare()
        pulseTrigger += 1
    }
}

private struct PlayerBackground: View {
    let track: AudioTrack?

    private var accent: Color {
        Color(uiColor: track?.accentColor ?? MixTheme.fallbackAccent)
    }

    var body: some View {
        ZStack {
            MixTheme.background.ignoresSafeArea()

            if let artwork = track?.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .blur(radius: 56)
                    .saturation(1.35)
                    .opacity(0.36)
                    .overlay(MixTheme.background.opacity(0.56).ignoresSafeArea())
            }

            RadialGradient(
                colors: [
                    accent.opacity(0.38),
                    accent.opacity(0.10),
                    .clear
                ],
                center: .top,
                startRadius: 20,
                endRadius: 520
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .black.opacity(0.08),
                    .black.opacity(0.58),
                    .black.opacity(0.88)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

private struct ArtworkHero: View {
    let track: AudioTrack?
    let accent: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            accent.opacity(0.38),
                            accent.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 12,
                        endRadius: size * 0.65
                    )
                )
                .frame(width: size * 1.18, height: size * 1.18)

            Group {
                if let artwork = track?.artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                } else {
                    FallbackArtwork(track: track, accent: accent)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
            .shadow(color: accent.opacity(0.35), radius: 32, y: 20)
            .shadow(color: .black.opacity(0.55), radius: 26, y: 18)
        }
        .frame(width: size, height: size)
    }
}

private struct FallbackArtwork: View {
    let track: AudioTrack?
    let accent: Color

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    accent,
                    accent.opacity(0.58),
                    MixTheme.surface
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 2)
                .scaleEffect(1.35)

            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 1)
                .scaleEffect(0.72)

            VStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                Text(initials)
                    .font(.system(size: 64, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.28), radius: 10, y: 6)
        }
    }

    private var initials: String {
        let title = track?.title ?? "ML"
        let parts = title
            .split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
        let value = String(parts).uppercased()
        return value.isEmpty ? "ML" : value
    }
}

private struct TransportControls: View {
    @ObservedObject var player: AudioPlayerModel
    let accent: Color
    @Binding var pulseTrigger: Int

    var body: some View {
        HStack(spacing: 0) {
            Button {
                haptic(.medium)
                player.playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MixTheme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(MixTheme.surface)
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Previous track")

            Button {
                haptic(.heavy)
                player.togglePlayback()
            } label: {
                ZStack {
                    ForEach(0..<3, id: \.self) { index in
                        PulseRing(
                            accent: accent,
                            delay: Double(index) * 0.08,
                            trigger: pulseTrigger
                        )
                    }

                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 31, weight: .bold))
                        .foregroundStyle(MixTheme.background)
                        .offset(x: player.isPlaying ? 0 : 2)
                        .frame(width: 74, height: 74)
                        .background(accent)
                        .clipShape(Circle())
                        .shadow(color: accent.opacity(0.43), radius: 18, y: 10)
                }
                .frame(width: 74, height: 74)
            }
            .frame(width: 90)
            .accessibilityLabel(player.isPlaying ? "Pause" : "Play")

            Button {
                haptic(.medium)
                player.playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MixTheme.textPrimary)
                    .frame(width: 52, height: 52)
                    .background(MixTheme.surface)
                    .clipShape(Circle())
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Next track")
        }
        .frame(maxWidth: 278)
        .frame(maxWidth: .infinity)
        .buttonStyle(.plain)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        generator.prepare()
        pulseTrigger += 1
    }
}

private struct PulseRing: View {
    let accent: Color
    let delay: Double
    let trigger: Int

    @State private var scale: CGFloat = 0.55
    @State private var opacity: Double = 0

    var body: some View {
        Circle()
            .stroke(accent, lineWidth: 2)
            .frame(width: 74, height: 74)
            .scaleEffect(scale)
            .opacity(opacity)
            .onChange(of: trigger) {
                scale = 0.55
                opacity = 0.7
                withAnimation(.easeOut(duration: 0.72).delay(delay)) {
                    scale = 1.45
                    opacity = 0
                }
            }
    }
}

private struct ProgressStrip: View {
    @ObservedObject var player: AudioPlayerModel
    let accent: Color

    private var progressBinding: Binding<Double> {
        Binding {
            guard player.playbackDuration > 0 else {
                return 0
            }
            return player.playbackTime / player.playbackDuration
        } set: { value in
            player.seek(to: value)
        }
    }

    var body: some View {
        VStack(spacing: 7) {
            Slider(value: progressBinding, in: 0...1)
                .tint(accent)
                .disabled(player.playbackDuration == 0)

            HStack {
                Text(timeString(player.playbackTime))
                Spacer()
                Text(timeString(player.playbackDuration))
            }
            .font(MixTheme.sublabel)
            .tracking(1.3)
            .foregroundStyle(MixTheme.textTertiary)
        }
    }

    private func timeString(_ value: TimeInterval) -> String {
        guard value.isFinite, value > 0 else {
            return "0:00"
        }

        let totalSeconds = Int(value.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

private struct VolumeStepper: View {
    @Binding var volume: Double
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Button {
                adjustVolume(by: -0.1)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 38, height: 38)
                    .background(MixTheme.surface)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Lower volume")

            VStack(spacing: 1) {
                Text("\(volumePercentage)%")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(MixTheme.textPrimary)
                    .monospacedDigit()

                Text("VOLUME")
                    .font(MixTheme.sublabel)
                    .tracking(1.4)
                    .foregroundStyle(MixTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)

            Button {
                adjustVolume(by: 0.1)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .black))
                    .frame(width: 38, height: 38)
                    .background(accent)
                    .foregroundStyle(MixTheme.background)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Raise volume")
        }
        .frame(height: 48)
        .padding(.horizontal, 8)
        .background(MixTheme.surfaceLight)
        .clipShape(Capsule())
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MixLayer volume \(volumePercentage) percent")
    }

    private var volumePercentage: Int {
        Int((volume * 100).rounded())
    }

    private func adjustVolume(by delta: Double) {
        let stepSize: Double = delta > 0
            ? (volume < 0.10 ? 0.01 : 0.05)
            : (volume <= 0.10 ? 0.01 : 0.05)
        let snapped = (volume / stepSize).rounded() * stepSize
        let next = snapped + (delta > 0 ? stepSize : -stepSize)
        volume = min(max(next, 0), 1)
    }
}

private struct IconCircleButton: View {
    let systemName: String
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(MixTheme.textPrimary)
                .frame(width: 45, height: 45)
                .background(MixTheme.surface.opacity(0.92))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(accent.opacity(0.24), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TrackQueueSheet: View {
    @ObservedObject var player: AudioPlayerModel
    let accent: Color
    let onPickTrack: (AudioTrack) -> Void

    var body: some View {
        ZStack {
            MixTheme.background.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LIBRARY")
                            .font(MixTheme.label)
                            .tracking(3)
                            .foregroundStyle(MixTheme.textSecondary)

                        Text("\(player.libraryName.uppercased()) / \(player.tracks.count) FILES")
                            .font(MixTheme.sublabel)
                            .tracking(1.8)
                            .foregroundStyle(MixTheme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)
                    }

                    Spacer()

                    if !player.tracks.isEmpty {
                        Button("Clear") {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                player.clearLibrary()
                            }
                        }
                        .font(MixTheme.label)
                        .tracking(1.8)
                        .foregroundStyle(MixTheme.textTertiary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(MixTheme.surface)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(player.tracks) { track in
                            TrackRow(
                                track: track,
                                isCurrent: player.currentTrack == track,
                                isPlaying: player.isPlaying,
                                accent: accent
                            ) {
                                onPickTrack(track)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        player.removeTrack(track)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red.opacity(0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

private struct TrackRow: View {
    let track: AudioTrack
    let isCurrent: Bool
    let isPlaying: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                SmallArtwork(track: track)
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(MixTheme.textPrimary)
                        .lineLimit(1)

                    Text("\(track.artistDisplay) / \(track.albumDisplay)".uppercased())
                        .font(MixTheme.sublabel)
                        .tracking(1.1)
                        .foregroundStyle(MixTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isCurrent ? (isPlaying ? "speaker.wave.2.fill" : "checkmark") : "play.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(isCurrent ? accent : MixTheme.textTertiary)
                    .frame(width: 28)
            }
            .padding(12)
            .background(isCurrent ? accent.opacity(0.16) : MixTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isCurrent ? accent.opacity(0.35) : .white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct SmallArtwork: View {
    let track: AudioTrack

    var body: some View {
        Group {
            if let artwork = track.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
            } else {
                FallbackArtwork(track: track, accent: Color(uiColor: track.accentColor))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(.white.opacity(0.10), lineWidth: 1)
        )
    }
}

private enum MixTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let surfaceLight = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.38)
    static let fallbackAccent = UIColor(red: 0.10, green: 0.65, blue: 1.00, alpha: 1.0)
    static let label = Font.system(size: 13, weight: .semibold, design: .monospaced)
    static let sublabel = Font.system(size: 11, weight: .semibold, design: .monospaced)
    static let tapSpring = Animation.spring(response: 0.3, dampingFraction: 0.62)
}

#Preview {
    ContentView()
        .environmentObject(AudioPlayerModel())
}
