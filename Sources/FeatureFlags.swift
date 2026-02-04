import Foundation

public enum FeatureFlags {
    public static let lazySelectorIndexing: Bool = true

    private static let configLock = Mutex()
    private nonisolated(unsafe) static var didConfigure: Bool = false
    private static let selectorIndexLock = Mutex()
    private nonisolated(unsafe) static var selectorIndexingEnabled: Bool = false

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
        _ = env
        selectorIndexLock.lock()
        selectorIndexingEnabled = false
        selectorIndexLock.unlock()
    }

    @inline(__always)
    public static func enableSelectorIndexingIfNeeded(for root: Element?) {
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
        return selectorIndexingEnabled
    }
}
