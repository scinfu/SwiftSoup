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
