import Foundation

#if canImport(Darwin)
import Darwin
#endif

enum CrashTrace {
    static func installIfNeeded() {
        guard ProcessInfo.processInfo.environment["SWIFTSOUP_SIGSEGV_TRACE"] == "1" else {
            return
        }
        #if canImport(Darwin)
        let handler: @convention(c) (Int32) -> Void = { signal in
            var stack = [UnsafeMutableRawPointer?](repeating: nil, count: 64)
            let count = backtrace(&stack, Int32(stack.count))
            backtrace_symbols_fd(&stack, count, STDERR_FILENO)
            _exit(signal)
        }
        signal(SIGSEGV, handler)
        signal(SIGBUS, handler)
        signal(SIGABRT, handler)
        signal(SIGTRAP, handler)
        #endif
    }
}
