import Foundation

extension NSLock {
    public func locked(closure: () throws -> Void) rethrows {
        lock()
        defer { unlock() } // MUST be deferred to ensure lock releases if throws
        try closure()
    }
}

