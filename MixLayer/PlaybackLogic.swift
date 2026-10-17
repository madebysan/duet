import Foundation

/// How Your files plays after the current file ends. Sounds always loop one.
enum PlaybackMode: String, CaseIterable, Identifiable {
    case loopOne
    case playAll
    case shuffle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .loopOne: "Loop one"
        case .playAll: "Play all"
        case .shuffle: "Shuffle"
        }
    }
}

enum PlaybackQueue {
    /// Index to play after `current` finishes or when skipping forward.
    /// `playAll` wraps to the start; `shuffle` never repeats the current file when there is a choice.
    static func nextIndex(
        after current: Int?,
        count: Int,
        mode: PlaybackMode,
        random: (Range<Int>) -> Int = { Int.random(in: $0) }
    ) -> Int? {
        guard count > 0 else { return nil }
        guard let current, (0..<count).contains(current) else { return 0 }

        switch mode {
        case .loopOne:
            return current
        case .playAll:
            return (current + 1) % count
        case .shuffle:
            guard count > 1 else { return current }
            let pick = random(0..<(count - 1))
            return pick >= current ? pick + 1 : pick
        }
    }

    static func previousIndex(before current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current, (0..<count).contains(current) else { return 0 }
        return current == 0 ? count - 1 : current - 1
    }
}

/// Volume stepping for the − and + buttons: 1% steps up to 10%, 5% steps above.
enum VolumeStep {
    static func stepped(from percent: Int, up: Bool) -> Int {
        let step = up ? (percent < 10 ? 1 : 5) : (percent <= 10 ? 1 : 5)
        let snapped = Int((Double(percent) / Double(step)).rounded()) * step
        return min(max(snapped + (up ? step : -step), 0), 100)
    }
}

/// Disc rotation as a pure function of time, so the spin can ease up when playback
/// starts and spin down when it pauses without per-frame state.
struct DiscSpin: Equatable {
    static let degreesPerSecond = 360.0 / 2.6
    static let ramp: TimeInterval = 0.6

    var start: Date
    var baseAngle: Double
    var isSpinning: Bool

    static let resting = DiscSpin(start: .distantPast, baseAngle: 0, isSpinning: false)

    func angle(at date: Date) -> Double {
        let elapsed = max(0, date.timeIntervalSince(start))
        let speed = Self.degreesPerSecond
        let ramp = Self.ramp

        if isSpinning {
            let travelled = elapsed < ramp
                ? speed * elapsed * elapsed / (2 * ramp)
                : speed * (elapsed - ramp / 2)
            return baseAngle + travelled
        } else {
            let travelled = elapsed < ramp
                ? speed * (elapsed - elapsed * elapsed / (2 * ramp))
                : speed * ramp / 2
            return baseAngle + travelled
        }
    }

    func transitioned(toSpinning spinning: Bool, at date: Date) -> DiscSpin {
        guard spinning != isSpinning else { return self }
        let current = angle(at: date).truncatingRemainder(dividingBy: 360)
        return DiscSpin(start: date, baseAngle: current, isSpinning: spinning)
    }
}
