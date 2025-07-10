/**
 Supports creation of a String from pieces
 Based on https://gist.github.com/kristopherjohnson/1fc55e811d944a430289
 */
open class StringBuilder {
    public var buffer: [UInt8] = []
    
    /**
     Construct with initial String contents
     
     :param: string Initial value; defaults to empty string
     */
    public init(string: String? = nil) {
        if let string, !string.isEmpty {
            buffer.append(contentsOf: string.utf8)
        }
        buffer.reserveCapacity(1024)
    }
    
    public init(_ size: Int) {
        buffer = Array()
        buffer.reserveCapacity(size)
    }
    
    /**
     Return the String object
     
     :return: String
     */
    @inline(__always)
    open func toString() -> String {
        return String(decoding: buffer, as: UTF8.self)
    }
    
    /**
     Return the current length of the String object
     */
    @inline(__always)
    open var xlength: Int {
        return buffer.count
    }
    
    @inline(__always)
    open var isEmpty: Bool {
        return buffer.isEmpty
    }
    
    /**
     Append a String to the object
     
     :param: string String
     
     :return: reference to this StringBuilder instance
     */
    @inline(__always)
    @discardableResult
    open func append(_ string: String) -> StringBuilder {
        buffer.append(contentsOf: string.utf8)
        return self
    }
    
    @inline(__always)
    open func append(_ chr: Character) {
        append(String(chr))
    }
    
    @inline(__always)
    open func appendCodePoints(_ chr: [Character]) {
        append(String(chr))
    }
    
    @inline(__always)
    open func appendCodePoint(_ ch: Int) {
        appendCodePoint(UnicodeScalar(ch)!)
    }
    
    @inlinable
    open func appendCodePoint(_ ch: UnicodeScalar) {
        let val = ch.value
        if val < 0x80 {
            // 1-byte ASCII
            buffer.append(UInt8(val))
        } else if val < 0x800 {
            // 2-byte sequence
            buffer.append(contentsOf: [
                UInt8(0xC0 | (val >> 6)),
                UInt8(0x80 | (val & 0x3F))
            ])
        } else if val < 0x10000 {
            // 3-byte sequence
            buffer.append(contentsOf: [
                UInt8(0xE0 | (val >> 12)),
                UInt8(0x80 | ((val >> 6) & 0x3F)),
                UInt8(0x80 | (val & 0x3F))
            ])
        } else {
            // 4-byte sequence
            buffer.append(contentsOf: [
                UInt8(0xF0 | (val >> 18)),
                UInt8(0x80 | ((val >> 12) & 0x3F)),
                UInt8(0x80 | ((val >> 6) & 0x3F)),
                UInt8(0x80 | (val & 0x3F))
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
     
     :param: value a value supporting the Printable protocol
     
     :return: reference to this StringBuilder instance
     */
//    @discardableResult
//    open func append<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
//        append(value.description)
//        return self
//    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: ArraySlice<UInt8>) -> StringBuilder {
        buffer.append(contentsOf: value)
        return self
    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: [UInt8]) -> StringBuilder {
        buffer.append(contentsOf: value)
        return self
    }
    
    @discardableResult
    @inline(__always)
    open func append(_ value: UInt8) -> StringBuilder {
        buffer.append(value)
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
     
     :param: string String
     
     :return: reference to this StringBuilder instance
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
     
     :param: value a value supporting the Printable protocol
     
     :return: reference to this StringBuilder instance
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
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
    @inline(__always)
    open func clear() -> StringBuilder {
        buffer.removeAll(keepingCapacity: true)
        return self
    }
}

/**
 Append a String to a StringBuilder using operator syntax
 
 :param: lhs StringBuilder
 :param: rhs String
 */
@inline(__always)
public func += (lhs: StringBuilder, rhs: String) {
    lhs.append(rhs)
}

/**
 Append a Printable to a StringBuilder using operator syntax
 
 :param: lhs Printable
 :param: rhs String
 */
@inline(__always)
public func += <T: CustomStringConvertible>(lhs: StringBuilder, rhs: T) {
    lhs.append(rhs.description)
}

/**
 Create a StringBuilder by concatenating the values of two StringBuilders
 
 :param: lhs first StringBuilder
 :param: rhs second StringBuilder
 
 :result StringBuilder
 */
@inline(__always)
public func +(lhs: StringBuilder, rhs: StringBuilder) -> StringBuilder {
    return StringBuilder(string: lhs.toString() + rhs.toString())
}
