import Foundation

@usableFromInline
enum DebugTrace {
    @usableFromInline
    static let enabled: Bool = {
        ProcessInfo.processInfo.environment["SWIFTSOUP_TRACE_SELECTORS"] == "1"
    }()

    @inline(__always)
    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let text = message()
        FileHandle.standardError.write((text + "\n").data(using: .utf8) ?? Data())
    }
}
