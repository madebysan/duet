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
    static let tuck = Animation.easeIn(duration: 0.22)
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

/// The square case the disc lives in. Sounds get a printed color and symbol; files show artwork.
struct DiscCase: View {
    let track: AudioTrack?
    let sound: BuiltInSound?
    let finish: DiscFinish

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(finish.caseColor)

            if let artwork = track?.artwork {
                Image(uiImage: artwork)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            } else if let sound {
                Image(systemName: sound.symbol)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .padding(16)
            } else if track != nil {
                VStack(alignment: .leading, spacing: 4) {
                    Image(systemName: "opticaldisc.fill")
                        .font(.system(size: 24, weight: .semibold))
                    Text("Your mix")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(.white.opacity(0.88))
                .padding(16)
            } else {
                Image(systemName: "opticaldisc")
                    .font(.system(size: 30, weight: .regular))
                    .foregroundStyle(MixTheme.textTertiary)
                    .padding(16)
            }

            // Case hinge and sheen.
            LinearGradient(
                colors: [.white.opacity(0.16), .clear, .black.opacity(0.18)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .allowsHitTesting(false)

            Rectangle()
                .fill(.white.opacity(0.10))
                .frame(width: 5)
                .padding(.vertical, 10)
                .padding(.leading, 9)
                .frame(maxHeight: .infinity, alignment: .leading)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 16, y: 10)
        .accessibilityHidden(true)
    }
}

/// The case with its disc sliding out to the right while a track is loaded.
struct DiscStage: View {
    let track: AudioTrack?
    let isOut: Bool
    let isSpinning: Bool
    var caseSize: CGFloat = 136

    private var sound: BuiltInSound? { SoundCatalog.sound(id: track?.soundID) }
    private var finish: DiscFinish { sound?.finish ?? .burned }

    var body: some View {
        let discSize = caseSize * 0.92

        ZStack(alignment: .leading) {
            SpinningDisc(finish: finish, artwork: sound?.artwork, isSpinning: isSpinning)
                .frame(width: discSize, height: discSize)
                .shadow(color: finish.glow.opacity(isOut ? 0.45 : 0), radius: 24)
                .offset(x: isOut ? caseSize * 0.6 : caseSize * 0.04)

            DiscCase(track: track, sound: sound, finish: finish)
                .frame(width: caseSize, height: caseSize)
        }
        .frame(width: caseSize * 1.56, height: caseSize, alignment: .leading)
        .frame(maxWidth: .infinity)
    }
}
