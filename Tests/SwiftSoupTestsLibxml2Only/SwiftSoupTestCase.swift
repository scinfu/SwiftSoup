import XCTest
@testable import SwiftSoup

class SwiftSoupTestCase: XCTestCase {
    class var allowLibxml2Only: Bool { true }

    override func setUpWithError() throws {
        try super.setUpWithError()
        CrashTrace.installIfNeeded()
        Parser.setTestDefaultBackendOverride(Self.testBackendOverride())
        if isLibxml2OnlyMode(), !Self.allowLibxml2Only {
            throw XCTSkip("Skipping SwiftSoup behavior tests under libxml2Only.")
        }
    }

    private class func testBackendOverride() -> Parser.Backend? {
#if SWIFTSOUP_TEST_BACKEND_LIBXML2
    #if canImport(CLibxml2) || canImport(libxml2)
        #if SWIFTSOUP_TEST_LIBXML2_ONLY
        return .libxml2(swiftSoupParityMode: .libxml2Only)
        #else
        return .libxml2(swiftSoupParityMode: .swiftSoupParity)
        #endif
    #else
        return .swiftSoup
    #endif
#else
        return nil
#endif
    }
}
