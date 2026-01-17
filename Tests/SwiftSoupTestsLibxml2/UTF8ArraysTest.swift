import XCTest
@testable import SwiftSoup

final class UTF8ArraysTest: SwiftSoupTestCase {
    func testCommonTagConstants() {
        XCTAssertEqual(UTF8Arrays.embed, "embed".utf8Array)
        XCTAssertEqual(UTF8Arrays.noframes, "noframes".utf8Array)
        XCTAssertEqual(UTF8Arrays.noscript, "noscript".utf8Array)
    }
}
