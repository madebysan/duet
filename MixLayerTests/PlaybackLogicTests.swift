import XCTest
@testable import MixLayer

final class PlaybackLogicTests: XCTestCase {
    // MARK: Volume stepping

    func testVolumeStepsByOneUpToTenThenByFive() {
        XCTAssertEqual(VolumeStep.stepped(from: 0, up: true), 1)
        XCTAssertEqual(VolumeStep.stepped(from: 9, up: true), 10)
        XCTAssertEqual(VolumeStep.stepped(from: 10, up: true), 15)
        XCTAssertEqual(VolumeStep.stepped(from: 15, up: false), 10)
        XCTAssertEqual(VolumeStep.stepped(from: 10, up: false), 9)
        XCTAssertEqual(VolumeStep.stepped(from: 1, up: false), 0)
    }

    func testVolumeStepSnapsDraggedValuesAndClamps() {
        XCTAssertEqual(VolumeStep.stepped(from: 37, up: true), 40)
        XCTAssertEqual(VolumeStep.stepped(from: 37, up: false), 30)
        XCTAssertEqual(VolumeStep.stepped(from: 100, up: true), 100)
        XCTAssertEqual(VolumeStep.stepped(from: 0, up: false), 0)
    }

    // MARK: Queue

    func testNextWrapsToStart() {
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 1, count: 4), 2)
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 3, count: 4), 0)
    }

    func testPreviousWrapsToEnd() {
        XCTAssertEqual(PlaybackQueue.previousIndex(before: 2, count: 4), 1)
        XCTAssertEqual(PlaybackQueue.previousIndex(before: 0, count: 3), 2)
    }

    func testEmptyAndUnknownCurrent() {
        XCTAssertNil(PlaybackQueue.nextIndex(after: nil, count: 0))
        XCTAssertEqual(PlaybackQueue.nextIndex(after: nil, count: 3), 0)
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 7, count: 3), 0)
        XCTAssertNil(PlaybackQueue.previousIndex(before: 1, count: 0))
    }

    // MARK: Volume dial

    func testDialEndsAndMiddle() {
        XCTAssertEqual(VolumeDial.percent(dx: 0, dy: -100), 50)      // 12 o'clock
        XCTAssertEqual(VolumeDial.percent(dx: -70.7, dy: 70.7), 0)   // 7:30
        XCTAssertEqual(VolumeDial.percent(dx: 70.7, dy: 70.7), 100)  // 4:30
    }

    func testDialClampsBelowTheGap() {
        XCTAssertEqual(VolumeDial.percent(dx: -1, dy: 100), 0)
        XCTAssertEqual(VolumeDial.percent(dx: 1, dy: 100), 100)
    }

    func testDialAngleRoundTrips() {
        for p in [0, 1, 25, 65, 100] {
            let a = VolumeDial.angle(forPercent: p) * .pi / 180
            XCTAssertEqual(VolumeDial.percent(dx: sin(a) * 100, dy: -cos(a) * 100), p)
        }
    }

    // MARK: Disc spin

    func testSpinIsContinuousWhenPausing() {
        let start = Date(timeIntervalSince1970: 1_000)
        let playing = DiscSpin(start: start, baseAngle: 0, isSpinning: true)
        let pauseAt = start.addingTimeInterval(5)
        let before = playing.angle(at: pauseAt).truncatingRemainder(dividingBy: 360)

        let paused = playing.transitioned(toSpinning: false, at: pauseAt)
        XCTAssertEqual(paused.angle(at: pauseAt), before, accuracy: 0.0001)
    }

    func testSpinDownSettlesAndStops() {
        let start = Date(timeIntervalSince1970: 1_000)
        let paused = DiscSpin(start: start, baseAngle: 90, isSpinning: false)
        let settled = paused.angle(at: start.addingTimeInterval(DiscSpin.ramp))
        XCTAssertEqual(paused.angle(at: start.addingTimeInterval(10)), settled, accuracy: 0.0001)
        XCTAssertGreaterThan(settled, 90)
    }

    func testSpinReachesFullSpeedAfterRamp() {
        let start = Date(timeIntervalSince1970: 1_000)
        let spin = DiscSpin(start: start, baseAngle: 0, isSpinning: true)
        let a = spin.angle(at: start.addingTimeInterval(2))
        let b = spin.angle(at: start.addingTimeInterval(3))
        XCTAssertEqual(b - a, DiscSpin.degreesPerSecond, accuracy: 0.0001)
    }
}
