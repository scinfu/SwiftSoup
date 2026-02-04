#if PROFILE
import Foundation

public enum Profiler {
    @usableFromInline
    nonisolated(unsafe) static var totals: [String: (count: UInt64, nanos: UInt64)] = [:]

    @inline(__always)
    public static func start(_ name: StaticString) -> UInt64 {
        _ = name
        return DispatchTime.now().uptimeNanoseconds
    }

    @inline(__always)
    public static func end(_ name: StaticString, _ start: UInt64) {
        let delta = DispatchTime.now().uptimeNanoseconds &- start
        let key = String(describing: name)
        if let existing = totals[key] {
            totals[key] = (existing.count &+ 1, existing.nanos &+ delta)
        } else {
            totals[key] = (1, delta)
        }
    }

    @inline(__always)
    public static func startDynamic(_ name: String) -> UInt64 {
        _ = name
        return DispatchTime.now().uptimeNanoseconds
    }

    @inline(__always)
    public static func endDynamic(_ name: String, _ start: UInt64) {
        let delta = DispatchTime.now().uptimeNanoseconds &- start
        if let existing = totals[name] {
            totals[name] = (existing.count &+ 1, existing.nanos &+ delta)
        } else {
            totals[name] = (1, delta)
        }
    }

    public static func reset() {
        totals.removeAll()
    }

    public static func report(top: Int = 30) -> String {
        let sorted = totals.sorted { $0.value.nanos > $1.value.nanos }
        var lines: [String] = []
        lines.reserveCapacity(min(top, sorted.count) + 1)
        lines.append("Profiler totals (top \(top))")
        let limit = top > 0 ? min(top, sorted.count) : sorted.count
        for (name, data) in sorted.prefix(limit) {
            let totalMs = Double(data.nanos) / 1_000_000.0
            let avgNs = data.nanos / max(data.count, 1)
            let avgUs = Double(avgNs) / 1_000.0
            lines.append(String(format: "%@ — %.2f ms total, %llu calls, %.3f us avg", name, totalMs, data.count, avgUs))
        }
        return lines.joined(separator: "\n")
    }
}
#else
public enum Profiler {
    @inline(__always)
    public static func start(_ name: StaticString) -> UInt64 { 0 }

    @inline(__always)
    public static func end(_ name: StaticString, _ start: UInt64) {}

    @inline(__always)
    public static func startDynamic(_ name: String) -> UInt64 { 0 }

    @inline(__always)
    public static func endDynamic(_ name: String, _ start: UInt64) {}

    public static func reset() {}
    public static func report(top: Int = 0) -> String { "" }
}
#endif
