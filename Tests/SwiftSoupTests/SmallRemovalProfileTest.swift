import Foundation
import XCTest
@testable import SwiftSoup

final class SmallRemovalProfileTest: XCTestCase {
    /// SWIFTSOUP_REMOVE_PROFILE=1 swift test -c release --filter SmallRemovalProfileTest
    func testSmallRemovalProfile() throws {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_REMOVE_PROFILE"] == "1" else {
            throw XCTSkip("Set SWIFTSOUP_REMOVE_PROFILE=1 to measure empty and singleton removals")
        }
        let count = 20_000
        let tag = try Tag.valueOf("div")
        let leafTag = try Tag.valueOf("i")
        for kind in ["empty", "detached", "attached"] {
            for iteration in -2..<5 {
                var parents: [Element] = []
                var selections: [Elements] = []
                parents.reserveCapacity(count)
                selections.reserveCapacity(count)
                for _ in 0..<count {
                    if kind == "empty" {
                        selections.append(Elements())
                    } else {
                        let child = Element(leafTag, "")
                        selections.append(Elements([child]))
                        if kind == "attached" {
                            let parent = Element(tag, "")
                            try parent.appendChild(child)
                            parents.append(parent)
                        }
                    }
                }
                try withExtendedLifetime(parents) {
                    let start = DispatchTime.now().uptimeNanoseconds
                    for selection in selections { try selection.remove() }
                    let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
                    XCTAssertTrue(selections.allSatisfy { $0.array().allSatisfy { $0.parent() == nil } })
                    XCTAssertTrue(parents.allSatisfy { $0.getChildNodes().isEmpty })
                    if iteration >= 0 {
                        print("Small removal \(kind): \(elapsed) ms for \(count) calls sample \(iteration)")
                    }
                }
            }
        }
    }
}
