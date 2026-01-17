import XCTest

@inline(__always)
func isLibxml2OnlyMode() -> Bool {
#if SWIFTSOUP_TEST_BACKEND_LIBXML2
    #if SWIFTSOUP_TEST_LIBXML2_ONLY
    return true
    #else
    return false
    #endif
#else
    let env = ProcessInfo.processInfo.environment
    guard let backend = env["SWIFTSOUP_TEST_BACKEND"]?.lowercased(),
          backend == "libxml2" else {
        return false
    }
    guard let raw = env["SWIFTSOUP_TEST_LIBXML2_SKIP_FALLBACKS"]?.lowercased() else {
        return false
    }
    return raw == "1" || raw == "true" || raw == "yes"
#endif
}
