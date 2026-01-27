import Foundation

public enum FeatureFlags {
    public nonisolated(unsafe) static var lazySelectorIndexing: Bool = false
    public nonisolated(unsafe) static var closureBasedParsing: Bool = false

    private static let configLock = Mutex()
    private nonisolated(unsafe) static var didConfigure: Bool = false
    private static let selectorIndexLock = Mutex()
    private nonisolated(unsafe) static var selectorIndexingEnabled: Bool = true

    @inline(__always)
    public static func configureFromEnvironmentOnce(_ env: [String: String] = ProcessInfo.processInfo.environment) {
        configLock.lock()
        if didConfigure {
            configLock.unlock()
            return
        }
        didConfigure = true
        configLock.unlock()
        configureFromEnvironment(env)
    }

    @inline(__always)
    public static func configureFromEnvironment(_ env: [String: String] = ProcessInfo.processInfo.environment) {
        if let value = env["SWIFTSOUP_LAZY_SELECTOR_INDEXING"] {
            lazySelectorIndexing = FeatureFlags.isEnabled(value)
        }
        if let value = env["SWIFTSOUP_CLOSURE_BASED_PARSE"] {
            closureBasedParsing = FeatureFlags.isEnabled(value)
        }

        if lazySelectorIndexing {
            selectorIndexLock.lock()
            selectorIndexingEnabled = false
            selectorIndexLock.unlock()
        } else {
            selectorIndexLock.lock()
            selectorIndexingEnabled = true
            selectorIndexLock.unlock()
        }
    }

    @inline(__always)
    public static func enableSelectorIndexingIfNeeded(for root: Element?) {
        guard lazySelectorIndexing else { return }
        selectorIndexLock.lock()
        let wasEnabled = selectorIndexingEnabled
        if !selectorIndexingEnabled {
            selectorIndexingEnabled = true
        }
        selectorIndexLock.unlock()
        if !wasEnabled, let root {
            root.markQueryIndexesDirty()
        }
    }

    @inline(__always)
    public static func shouldTrackSelectorIndexes() -> Bool {
        if !lazySelectorIndexing {
            return true
        }
        return selectorIndexingEnabled
    }

    @inline(__always)
    private static func isEnabled(_ value: String) -> Bool {
        switch value.lowercased() {
        case "1", "true", "yes", "on":
            return true
        default:
            return false
        }
    }
}
