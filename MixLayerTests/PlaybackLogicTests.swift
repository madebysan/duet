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

    func testLoopOneRepeatsCurrent() {
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 2, count: 4, mode: .loopOne), 2)
    }

    func testPlayAllWrapsToStart() {
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 1, count: 4, mode: .playAll), 2)
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 3, count: 4, mode: .playAll), 0)
    }

    func testShuffleNeverRepeatsCurrentWhenThereIsAChoice() {
        for pick in 0..<3 {
            let next = PlaybackQueue.nextIndex(after: 1, count: 4, mode: .shuffle, random: { _ in pick })
            XCTAssertNotEqual(next, 1)
        }
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 0, count: 1, mode: .shuffle), 0)
    }

    func testEmptyAndUnknownCurrent() {
        XCTAssertNil(PlaybackQueue.nextIndex(after: nil, count: 0, mode: .playAll))
        XCTAssertEqual(PlaybackQueue.nextIndex(after: nil, count: 3, mode: .playAll), 0)
        XCTAssertEqual(PlaybackQueue.nextIndex(after: 7, count: 3, mode: .shuffle), 0)
        XCTAssertEqual(PlaybackQueue.previousIndex(before: 0, count: 3), 2)
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
