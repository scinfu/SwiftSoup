#if os(Linux)
    @_exported import Glibc
#else
    @_exported import Darwin.C
#endif

extension Byte {
    private static let max32 = UInt32(Byte.max)

    /**
        Create a single random byte
    */
    public static func randomByte() -> Byte {
        #if os(Linux)
            let val = Byte(Glibc.random() % Int(max32))
        #else
            let val = Byte(arc4random_uniform(max32))
        #endif
        return val
    }
}

extension UnsignedInteger {
    /**
        Return a random value for the given type. 
        This should NOT be considered cryptographically secure.
    */
    public static func random() -> Self {
        let size = MemoryLayout<Self>.size
        var bytes: [Byte] = []
        (1...size).forEach { _ in
            let randomByte = Byte.randomByte()
            bytes.append(randomByte)
        }
        return Self(bytes: bytes)
    }
}
