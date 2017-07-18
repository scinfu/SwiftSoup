import Foundation
import Dispatch

/**
    There was an error thrown by the portal itself vs a user thrown variable
*/
public enum PortalError: String, Debuggable {
    /**
        Portal was destroyed w/o being closed
    */
    case notClosed

    /**
        Portal timedOut before it was closed.
    */
    case timedOut
}

/**
     This class is designed to make it possible to use asynchronous contexts in a synchronous environment.
*/
public final class Portal<T> {
    fileprivate var result: Result<T>? = .none
    private let semaphore: DispatchSemaphore
    private let lock = NSLock()

    fileprivate init(_ semaphore: DispatchSemaphore) {
        self.semaphore = semaphore
    }

    /**
         Close the portal with a successful result
    */
    public func close(with value: T) {
        lock.locked {
            guard result == nil else { return }
            result = .success(value)
            semaphore.signal()
        }
    }

    /**
         Close the portal with an appropriate error
    */
    public func close(with error: Error) {
        lock.locked {
            guard result == nil else { return }
            result = .failure(error)
            semaphore.signal()
        }
    }

    /**
         Dismiss the portal throwing a notClosed error.
    */
    public func destroy() {
        semaphore.signal()
    }
}

extension Portal {
    /**
         This function is used to enter an asynchronous supported context with a portal
         object that can be used to complete a given operation.
     
         timeout in SECONDS

             let value = try Portal<Int>.open { portal in
                 // .. do whatever necessary passing around `portal` object
                 // eventually call

                 portal.close(with: 42)

                 // or

                 portal.close(with: errorSignifyingFailure)
             }

         - warning: Calling close on a `portal` multiple times will have no effect.
    */
    public static func open(
        timeout: Double = (60 * 60),
        _ handler: @escaping (Portal) throws -> Void
        ) throws -> T {
        let semaphore = DispatchSemaphore(value: 0)
        let portal = Portal<T>(semaphore)
        background {
            do {
                try handler(portal)
            } catch {
                portal.close(with: error)
            }
        }
        let waitResult = semaphore.wait(timeout: timeout)
        switch waitResult {
        case .success:
            guard let result = portal.result else { throw PortalError.notClosed }
            return try result.extract()
        case .timedOut:
            throw PortalError.timedOut
        }
    }
}

extension Portal {
    /**
         Execute timeout operations
    */
    static func timeout(_ timeout: Double, operation: @escaping () throws -> T) throws -> T {
        return try Portal<T>.open(timeout: timeout) { portal in
            let value = try operation()
            portal.close(with: value)
        }
    }
}

extension PortalError {
    public var identifier: String {
        return rawValue
    }

    public var reason: String {
        switch self {
        case .notClosed:
            return "the portal finished, but was somehow not properly closed"
        case .timedOut:
            return "the portal timed out before it could finish its operation"
        }
    }

    public var possibleCauses: [String] {
        return [
            "user forgot to call `portal.close(with: )`"
        ]
    }

    public var suggestedFixes: [String] {
        return [
            "ensure the timeout length is adequate for required operation time",
            "make sure that `portal.close(with: )` is being called with an error or valid value"
        ]
    }
}
