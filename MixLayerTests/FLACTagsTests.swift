import XCTest
import UIKit
@testable import MixLayer

final class FLACTagsTests: XCTestCase {
    private var fixture: URL {
        Bundle(for: Self.self).url(forResource: "tagged", withExtension: "flac")!
    }

    func testReadsVorbisCommentsAndCover() throws {
        let tags = try XCTUnwrap(FLACTags.read(from: fixture))
        XCTAssertEqual(tags.title, "Lantern room")
        XCTAssertEqual(tags.artist, "Duet demo")
        XCTAssertEqual(tags.album, "Fixtures")
        let picture = try XCTUnwrap(tags.picture)
        XCTAssertNotNil(UIImage(data: picture), "embedded cover should decode as an image")
    }

    func testRejectsNonFLAC() {
        XCTAssertNil(FLACTags.parse(Data("ID3\\u{3}".utf8)))
    }
}
