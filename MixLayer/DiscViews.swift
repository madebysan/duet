import SwiftUI
import UIKit

enum MixTheme {
    static let background = Color(red: 0.04, green: 0.04, blue: 0.04)
    static let surface = Color(red: 0.10, green: 0.10, blue: 0.10)
    static let surfaceLight = Color(red: 0.15, green: 0.15, blue: 0.15)
    static let textPrimary = Color.white
    static let textSecondary = Color(white: 0.62)
    static let textTertiary = Color(white: 0.38)
    static let accent = Color(red: 0.10, green: 0.65, blue: 1.00)
    static let slide = Animation.spring(response: 0.45, dampingFraction: 0.82)
    static let tapSpring = Animation.spring(response: 0.3, dampingFraction: 0.62)
}

enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

/// A CD face: printed art (or the finish's sheen), clear inner ring, and the spindle hole.
struct DiscFace: View {
    let finish: DiscFinish
    var artwork: UIImage? = nil

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)

            ZStack {
                if let artwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())

                    // Keep a hint of the iridescent CD sheen over the print.
                    Circle()
                        .fill(AngularGradient(colors: finish.sheen, center: .center))
                        .opacity(0.28)
                        .blendMode(.overlay)
                } else {
                    Circle()
                        .fill(AngularGradient(colors: finish.sheen, center: .center))
                }

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.0), .white.opacity(0.18), .white.opacity(0.0)],
                            center: .center,
                            startRadius: size * 0.2,
                            endRadius: size * 0.5
                        )
                    )

                // Highlight streak so the rotation reads even on soft finishes.
                Capsule()
                    .fill(.white.opacity(0.35))
                    .frame(width: size * 0.035, height: size * 0.26)
                    .offset(y: -size * 0.3)
                    .blur(radius: size * 0.006)

                Circle()
                    .fill(.white.opacity(artwork == nil ? 0.45 : 0.32))
                    .background(Circle().fill(.ultraThinMaterial))
                    .frame(width: size * 0.34, height: size * 0.34)

                Circle()
                    .strokeBorder(.black.opacity(0.12), lineWidth: max(size * 0.006, 0.5))
                    .frame(width: size * 0.34, height: size * 0.34)

                Circle()
                    .fill(MixTheme.background)
                    .frame(width: size * 0.13, height: size * 0.13)
            }
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// A disc that eases up to speed when playing and spins down when paused.
struct SpinningDisc: View {
    let finish: DiscFinish
    var artwork: UIImage? = nil
    let isSpinning: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var spin = DiscSpin.resting
    @State private var isAnimating = false

    var body: some View {
        TimelineView(.animation(paused: !isAnimating || reduceMotion)) { context in
            DiscFace(finish: finish, artwork: artwork)
                .rotationEffect(.degrees(reduceMotion ? 0 : spin.angle(at: context.date)))
        }
        .onAppear {
            spin = DiscSpin(start: .distantPast, baseAngle: 0, isSpinning: isSpinning)
            isAnimating = isSpinning
        }
        .onChange(of: isSpinning) { _, spinning in
            spin = spin.transitioned(toSpinning: spinning, at: .now)
            isAnimating = true

            if !spinning {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(DiscSpin.ramp + 0.05))
                    if !spin.isSpinning {
                        isAnimating = false
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// A bare CD in the carousel: lifts and glows once loaded, spins while playing.
/// With no track (Your mix before any files are added) it shows an empty dashed disc.
struct CarouselDisc: View {
    let track: AudioTrack?
    let isLoaded: Bool
    let isSpinning: Bool
    var size: CGFloat = 220

    private var sound: BuiltInSound? { SoundCatalog.sound(id: track?.soundID) }
    private var finish: DiscFinish { sound?.finish ?? .burned }

    var body: some View {
        Group {
            if let track {
                SpinningDisc(finish: finish, artwork: sound?.artwork ?? track.artwork, isSpinning: isSpinning)
            } else {
                Circle()
                    .strokeBorder(MixTheme.textTertiary, style: StrokeStyle(lineWidth: 2, dash: [6, 6]))
                    .overlay(
                        Image(systemName: "plus")
                            .font(.system(size: 34, weight: .semibold))
                            .foregroundStyle(MixTheme.textSecondary)
                    )
            }
        }
        .frame(width: size, height: size)
        .shadow(color: (sound?.glow ?? finish.glow).opacity(isLoaded ? 0.5 : 0), radius: 32)
        .shadow(color: .black.opacity(track == nil ? 0 : 0.5), radius: 18, y: 12)
        .scaleEffect(isLoaded ? 1 : 0.94)
        .accessibilityHidden(true)
    }
}
