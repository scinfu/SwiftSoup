import Foundation

/**
 Supports creation of a String from pieces
 Based on https://gist.github.com/kristopherjohnson/1fc55e811d944a430289
 */
open class StringBuilder {
    private var internalBuffer: [UInt8] = []
    
    /// Number of bytes currently used in buffer
    private var size: Int = 0
    private static let poolLock = Mutex()
    @usableFromInline
    nonisolated(unsafe) static var pool: [StringBuilder] = []
    private static let poolLimit: Int = 16
    @usableFromInline
    static let useFastWrite: Bool = true
    @usableFromInline
    static let asciiUpperLimitScalar: UInt32 = 0x80
    @usableFromInline
    static let utf8TwoByteLimit: UInt32 = 0x800
    @usableFromInline
    static let utf8ThreeByteLimit: UInt32 = 0x10000
    @usableFromInline
    static let utf8Lead2Prefix: UInt32 = 0xC0
    @usableFromInline
    static let utf8Lead3Prefix: UInt32 = 0xE0
    @usableFromInline
    static let utf8Lead4Prefix: UInt32 = 0xF0
    @usableFromInline
    static let utf8ContinuationPrefix: UInt32 = 0x80
    @usableFromInline
    static let utf8SixBitMask: UInt32 = 0x3F
    
    /// Read-only view of the active buffer contents
    @inline(__always)
    public var buffer: ArraySlice<UInt8> {
        return internalBuffer[0..<size]
    }
    
    /**
     Construct with initial String contents
     
     - parameter string: Initial value; defaults to empty string
     */
    @inline(__always)
    public init(string: String? = nil) {
        if let string, !string.isEmpty {
            internalBuffer.append(contentsOf: string.utf8)
            size = internalBuffer.count
        }
        internalBuffer.reserveCapacity(1024)
    }
    
    @inline(__always)
    public init(_ capacity: Int) {
        internalBuffer = []
        internalBuffer.reserveCapacity(capacity)
    }

    @usableFromInline
    @inline(__always)
    static func acquire(_ capacity: Int = 0) -> StringBuilder {
        poolLock.lock()
        if let builder = pool.popLast() {
            poolLock.unlock()
            builder.clear()
            if capacity > builder.internalBuffer.capacity {
                builder.internalBuffer.reserveCapacity(capacity)
            }
            return builder
        }
        poolLock.unlock()
        return StringBuilder(capacity)
    }

    @usableFromInline
    @inline(__always)
    static func release(_ builder: StringBuilder) {
        builder.clear()
        if builder.internalBuffer.capacity > 1_048_576 {
            builder.internalBuffer = []
            builder.internalBuffer.reserveCapacity(1024)
        }
        poolLock.lock()
        if pool.count < poolLimit {
            pool.append(builder)
        }
        poolLock.unlock()
    }
    
    /**
     Return the String object
     
     - returns: String
     */
    @inline(__always)
    open func toString() -> String {
        return String(decoding: internalBuffer[0..<size], as: UTF8.self)
    }
    
    /**
     Return the current length of the String object
     */
    @inline(__always)
    open var length: Int {
        return size
    }
    
    @inline(__always)
    open var isEmpty: Bool {
        return size == 0
    }

    @inline(__always)
    open var lastByte: UInt8? {
        return size > 0 ? internalBuffer[size &- 1] : nil
    }

    @inline(__always)
    open func trimTrailingWhitespace() {
        while size > 0, internalBuffer[size &- 1].isWhitespace {
            size &-= 1
        }
    }
    
    /**
     Append a String to the object
     
     - parameter string: String
     
     - returns: reference to this StringBuilder instance
     */
    @discardableResult
    @inline(__always)
    open func append(_ string: String) -> StringBuilder {
        let bytes = string.utf8
        write(contentsOf: bytes)
        return self
    }
    
    @inline(__always)
    open func append(_ chr: Character) {
        append(String(chr))
    }

    @inline(__always)
    open func appendNewline() {
        write(TokeniserStateVars.newLineByte)
    }
    
    @inline(__always)
    open func appendCodePoints(_ chr: [Character]) {
        append(String(chr))
    }
    
    @inline(__always)
    open func appendCodePoint(_ ch: Int) {
        appendCodePoint(UnicodeScalar(ch)!)
    }

    @inline(__always)
    open func appendSpaces(_ count: Int) {
        if count <= 0 { return }
        let newSize = size + count
        if internalBuffer.count < newSize {
            internalBuffer.reserveCapacity(newSize)
        }
        if newSize <= internalBuffer.count {
            internalBuffer.withUnsafeMutableBufferPointer { dst in
                guard let base = dst.baseAddress else { return }
                base.advanced(by: size).initialize(repeating: TokeniserStateVars.spaceByte, count: count)
            }
            size = newSize
            return
        }
        if size < internalBuffer.count {
            let fillCount = internalBuffer.count - size
            if fillCount > 0 {
                internalBuffer.withUnsafeMutableBufferPointer { dst in
                    guard let base = dst.baseAddress else { return }
                    base.advanced(by: size).initialize(repeating: TokeniserStateVars.spaceByte, count: fillCount)
                }
            }
        }
        let appendCount = newSize - internalBuffer.count
        if appendCount > 0 {
            internalBuffer.append(contentsOf: repeatElement(TokeniserStateVars.spaceByte, count: appendCount))
        }
        size = newSize
    }
    
    @inline(__always)
    open func appendCodePoint(_ ch: UnicodeScalar) {
        let val = ch.value
        if val < StringBuilder.asciiUpperLimitScalar {
            // 1-byte ASCII
            write(UInt8(val))
        } else if val < StringBuilder.utf8TwoByteLimit {
            // 2-byte sequence
            let lead = StringBuilder.utf8Lead2Prefix | (val >> 6)
            let trail = StringBuilder.utf8ContinuationPrefix | (val & StringBuilder.utf8SixBitMask)
            write(contentsOf: [
                UInt8(lead),
                UInt8(trail)
            ])
        } else if val < StringBuilder.utf8ThreeByteLimit {
            // 3-byte sequence
            let lead = StringBuilder.utf8Lead3Prefix | (val >> 12)
            let mid = StringBuilder.utf8ContinuationPrefix | ((val >> 6) & StringBuilder.utf8SixBitMask)
            let trail = StringBuilder.utf8ContinuationPrefix | (val & StringBuilder.utf8SixBitMask)
            write(contentsOf: [
                UInt8(lead),
                UInt8(mid),
                UInt8(trail)
            ])
        } else {
            // 4-byte sequence
            let lead = StringBuilder.utf8Lead4Prefix | (val >> 18)
            let mid0 = StringBuilder.utf8ContinuationPrefix | ((val >> 12) & StringBuilder.utf8SixBitMask)
            let mid1 = StringBuilder.utf8ContinuationPrefix | ((val >> 6) & StringBuilder.utf8SixBitMask)
            let trail = StringBuilder.utf8ContinuationPrefix | (val & StringBuilder.utf8SixBitMask)
            write(contentsOf: [
                UInt8(lead),
                UInt8(mid0),
                UInt8(mid1),
                UInt8(trail)
            ])
        }
    }
    
    @inline(__always)
    open func appendCodePoints(_ chr: [UnicodeScalar]) {
        for chr in chr {
            appendCodePoint(chr)
        }
    }
    
    /**
     Append a Printable to the object
     
     - parameter value: a value supporting the Printable protocol
     
     - returns: reference to this StringBuilder instance
     */
    //    @discardableResult
    //    open func append<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
    //        append(value.description)
    //        return self
    //    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: ArraySlice<UInt8>) -> StringBuilder {
        if value.count == 1, let byte = value.first {
            write(byte)
            return self
        }
        write(contentsOf: value)
        return self
    }

    @discardableResult
    @inline(__always)
    @usableFromInline
    func append(_ value: ByteSlice) -> StringBuilder {
        if value.count == 1, let byte = value.first {
            write(byte)
            return self
        }
        write(contentsOf: value)
        return self
    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: [UInt8]) -> StringBuilder {
        if value.count == 1 {
            write(value[0])
            return self
        }
        write(contentsOf: value)
        return self
    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: UInt8) -> StringBuilder {
        write(value)
        return self
    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: UnicodeScalar) -> StringBuilder {
        appendCodePoint(value)
        return self
    }
    
    /**
     Append a String and a newline to the object
     
     - parameter string: String
     
     - returns: reference to this StringBuilder instance
     */
    @discardableResult
    @inline(__always)
    open func appendLine(_ string: String) -> StringBuilder {
        append(string)
        append("\n")
        return self
    }
    
    /**
     Append a Printable and a newline to the object
     
     - parameter value: a value supporting the Printable protocol
     
     - returns: reference to this StringBuilder instance
     */
    @discardableResult
    @inline(__always)
    open func appendLine<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
        append(value.description)
        append("\n")
        return self
    }
    
    /**
     Reset the object to an empty string
     
     - returns: reference to this StringBuilder instance
     */
    @discardableResult
    @inline(__always)
    open func clear() -> StringBuilder {
        size = 0
        return self
    }

    @usableFromInline
    @inline(__always)
    internal func takeBuffer() -> [UInt8] {
        if size == 0 {
            return []
        }
        if size == internalBuffer.count {
            let out = internalBuffer
            internalBuffer = []
            internalBuffer.reserveCapacity(1024)
            size = 0
            return out
        }
        let out = Array(internalBuffer[0..<size])
        size = 0
        return out
    }

    
    @usableFromInline
    @inline(__always)
    internal func write(_ byte: UInt8) {
        if size < internalBuffer.count {
            internalBuffer[size] = byte
        } else {
            internalBuffer.append(byte)
        }
        size += 1
    }
    
    @usableFromInline
    @inline(__always)
    internal func write(contentsOf bytes: [UInt8]) {
        if Self.useFastWrite {
            let count = bytes.count
            if count == 0 { return }
            let newSize = size + count
            if size == internalBuffer.count {
                internalBuffer.append(contentsOf: bytes)
                size = newSize
                return
            }
            let available = internalBuffer.count - size
            if available > 0 {
                let firstCount = min(count, available)
                internalBuffer.withUnsafeMutableBufferPointer { dst in
                    bytes.withUnsafeBufferPointer { src in
                        guard let dstBase = dst.baseAddress, let srcBase = src.baseAddress else { return }
                        dstBase.advanced(by: size).update(from: srcBase, count: firstCount)
                    }
                }
                if count > available {
                    internalBuffer.append(contentsOf: bytes[available...])
                }
                size = newSize
                return
            }
        }
        let newSize = size + bytes.count
        if size == internalBuffer.count {
            internalBuffer.append(contentsOf: bytes)
        } else if newSize <= internalBuffer.count {
            internalBuffer.replaceSubrange(size..<newSize, with: bytes)
        } else {
            internalBuffer.replaceSubrange(size..<internalBuffer.count, with: bytes)
        }
        size = newSize
    }
    
    @usableFromInline
    @inline(__always)
    internal func write(contentsOf bytes: String.UTF8View) {
        if Self.useFastWrite, let didCopy = bytes.withContiguousStorageIfAvailable({ buffer -> Bool in
            let count = buffer.count
            if count == 0 { return true }
            let newSize = size + count
            if size == internalBuffer.count {
                internalBuffer.append(contentsOf: buffer)
                size = newSize
                return true
            }
            let available = internalBuffer.count - size
            if available > 0 {
                let firstCount = min(count, available)
                internalBuffer.withUnsafeMutableBufferPointer { dst in
                    guard let dstBase = dst.baseAddress, let srcBase = buffer.baseAddress else { return }
                    dstBase.advanced(by: size).update(from: srcBase, count: firstCount)
                }
                if count > available {
                    internalBuffer.append(contentsOf: buffer[available...])
                }
                size = newSize
                return true
            }
            return false
        }), didCopy {
            return
        }
        if size == internalBuffer.count {
            internalBuffer.append(contentsOf: bytes)
            size = internalBuffer.count
            return
        }
        let newSize = size + bytes.count
        if newSize <= internalBuffer.count {
            internalBuffer.replaceSubrange(size..<newSize, with: bytes)
        } else {
            internalBuffer.replaceSubrange(size..<internalBuffer.count, with: bytes)
        }
        size = newSize
    }
    
    @usableFromInline
    @inline(__always)
    internal func write(contentsOf bytes: ArraySlice<UInt8>) {
        if Self.useFastWrite {
            let count = bytes.count
            if count == 0 { return }
            let newSize = size + count
            if size == internalBuffer.count {
                internalBuffer.append(contentsOf: bytes)
                size = newSize
                return
            }
            let available = internalBuffer.count - size
            if available > 0 {
                let firstCount = min(count, available)
                internalBuffer.withUnsafeMutableBufferPointer { dst in
                    bytes.withUnsafeBufferPointer { src in
                        guard let dstBase = dst.baseAddress, let srcBase = src.baseAddress else { return }
                        dstBase.advanced(by: size).update(from: srcBase, count: firstCount)
                    }
                }
                if count > available {
                    internalBuffer.append(contentsOf: bytes[bytes.index(bytes.startIndex, offsetBy: available)...])
                }
                size = newSize
                return
            }
        }
        let newSize = size + bytes.count
        if size == internalBuffer.count {
            internalBuffer.append(contentsOf: bytes)
        } else if newSize <= internalBuffer.count {
            internalBuffer.replaceSubrange(size..<newSize, with: bytes)
        } else {
            internalBuffer.replaceSubrange(size..<internalBuffer.count, with: bytes)
        }
        size = newSize
    }

    @usableFromInline
    @inline(__always)
    internal func write(contentsOf bytes: ByteSlice) {
        if Self.useFastWrite {
            let count = bytes.count
            if count == 0 { return }
            let newSize = size + count
            if size == internalBuffer.count {
                internalBuffer.append(contentsOf: bytes)
                size = newSize
                return
            }
            let available = internalBuffer.count - size
            if available > 0 {
                let firstCount = min(count, available)
                internalBuffer.withUnsafeMutableBufferPointer { dst in
                    bytes.withUnsafeBufferPointer { src in
                        guard let dstBase = dst.baseAddress, let srcBase = src.baseAddress else { return }
                        dstBase.advanced(by: size).update(from: srcBase, count: firstCount)
                    }
                }
                if count > available {
                    internalBuffer.append(contentsOf: bytes[bytes.index(bytes.startIndex, offsetBy: available)...])
                }
                size = newSize
                return
            }
        }
        let newSize = size + bytes.count
        if size == internalBuffer.count {
            internalBuffer.append(contentsOf: bytes)
        } else if newSize <= internalBuffer.count {
            internalBuffer.replaceSubrange(size..<newSize, with: bytes)
        } else {
            internalBuffer.replaceSubrange(size..<internalBuffer.count, with: bytes)
        }
        size = newSize
    }

    @usableFromInline
    @inline(__always)
    internal func write(contentsOf basePtr: UnsafePointer<UInt8>, count: Int) {
        if count == 0 { return }
        let newSize = size + count
        if size == internalBuffer.count {
            internalBuffer.append(contentsOf: UnsafeBufferPointer(start: basePtr, count: count))
            size = newSize
            return
        }
        let available = internalBuffer.count - size
        if available > 0 {
            let firstCount = min(count, available)
            internalBuffer.withUnsafeMutableBufferPointer { dst in
                guard let dstBase = dst.baseAddress else { return }
                dstBase.advanced(by: size).update(from: basePtr, count: firstCount)
            }
            if count > available {
                internalBuffer.append(
                    contentsOf: UnsafeBufferPointer(
                        start: basePtr.advanced(by: firstCount),
                        count: count - firstCount
                    )
                )
            }
            size = newSize
            return
        }
        internalBuffer.append(contentsOf: UnsafeBufferPointer(start: basePtr, count: count))
        size = newSize
    }
}

/**
 Append a String to a StringBuilder using operator syntax
 
 - parameter lhs: StringBuilder
 - parameter rhs: String
 */
@inline(__always)
public func += (lhs: StringBuilder, rhs: String) {
    lhs.append(rhs)
}

/**
 Append a Printable to a StringBuilder using operator syntax
 
 - parameter lhs: Printable
 - parameter rhs: String
 */
@inline(__always)
public func += <T: CustomStringConvertible>(lhs: StringBuilder, rhs: T) {
    lhs.append(rhs.description)
}

/**
 Create a StringBuilder by concatenating the values of two StringBuilders
 
 - parameter lhs: first StringBuilder
 - parameter rhs: second StringBuilder
 
 - returns: StringBuilder
 */
@inline(__always)
public func +(lhs: StringBuilder, rhs: StringBuilder) -> StringBuilder {
    return StringBuilder(string: lhs.toString() + rhs.toString())
}
