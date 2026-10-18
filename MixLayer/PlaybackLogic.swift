import Foundation

/// Order of the discs for lock-screen next/previous. Every disc loops on its own, so there is
/// no play-all or shuffle; next/previous just walks the carousel and wraps at the ends.
enum PlaybackQueue {
    static func nextIndex(after current: Int?, count: Int) -> Int? {
        guard count > 0 else { return nil }
        guard let current, (0..<count).contains(current) else { return 0 }
        return (current + 1) % count
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

/// Geometry of the volume ring: a 270° arc that starts at 7:30 and ends at 4:30, clockwise.
enum VolumeDial {
    static let sweep = 270.0
    static let startAngle = -135.0

    /// Percent for a touch at (dx, dy) from the ring's center (y grows downward).
    /// Angles past either end clamp to 0 or 100.
    static func percent(dx: Double, dy: Double) -> Int {
        let angle = atan2(dx, -dy) * 180 / .pi // 0 at 12 o'clock, clockwise positive
        let clamped = min(max(angle, startAngle), startAngle + sweep)
        return Int(((clamped - startAngle) / sweep * 100).rounded())
    }

    /// Angle in degrees from 12 o'clock, clockwise, for a percent.
    static func angle(forPercent percent: Int) -> Double {
        startAngle + sweep * Double(min(max(percent, 0), 100)) / 100
    }
}
