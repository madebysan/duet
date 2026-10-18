import XCTest
import UIKit
@testable import MixLayer

final class DiscAccentTests: XCTestCase {
    private func hueSatBright(_ id: String) throws -> (h: Double, s: Double, b: Double) {
        let image = try XCTUnwrap(UIImage(named: "disc-\(id)", in: Bundle(for: AudioPlayerModel.self), with: nil))
        let color = try XCTUnwrap(DiscAccent.vividColor(in: image))
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h) * 360, Double(s), Double(b))
    }

    func testBlackbirdGlowsYellowNotGreen() throws {
        let c = try hueSatBright("blackbird")
        XCTAssert((20...60).contains(c.h), "Blackbird hue \(c.h)° should be orange-yellow")
        XCTAssertGreaterThan(c.s, 0.5)
    }

    func testWhiteNoiseStaysPale() throws {
        XCTAssertLessThan(try hueSatBright("white-noise").s, 0.3)
    }

    func testEveryDiscHasABrightGlow() throws {
        let ids = ["brown-noise", "pink-noise", "white-noise", "rain", "steady-rain", "porch-rain", "rain-on-leaves",
                   "gentle-rain", "forest", "woodland", "blackbird", "forest-wind", "ocean", "soft-surf", "breakers", "beach"]
        for id in ids {
            let c = try hueSatBright(id)
            print(String(format: "GLOW %@ hue %3.0f°  sat %.2f  bright %.2f", id as NSString, c.h, c.s, c.b))
            XCTAssertGreaterThanOrEqual(c.b, 0.85, id)
        }
    }
}
