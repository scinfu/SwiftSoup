/**
 Supports creation of a String from pieces
 Based on https://gist.github.com/kristopherjohnson/1fc55e811d944a430289
 */
open class StringBuilder {
    internal var buffer: [UInt8] = []
    
    /**
     Construct with initial String contents
     
     :param: string Initial value; defaults to empty string
     */
    public init(string: String = "") {
        if !string.isEmpty {
            buffer.append(contentsOf: string.utf8)
        }
    }
    
    public init(_ size: Int) {
        self.buffer = Array()
    }
    
    /**
     Return the String object
     
     :return: String
     */
    open func toString() -> String {
        return String(decoding: buffer, as: UTF8.self)
    }
    
    /**
     Return the current length of the String object
     */
    open var xlength: Int {
        return buffer.count
    }
    
    open var isEmpty: Bool {
        return buffer.isEmpty
    }
    
    /**
     Append a String to the object
     
     :param: string String
     
     :return: reference to this StringBuilder instance
     */
    open func append(_ string: String) {
        buffer.append(contentsOf: string.utf8)
    }
    
    open func appendCodePoint(_ chr: Character) {
        append(String(chr))
    }
    
    open func appendCodePoints(_ chr: [Character]) {
        append(String(chr))
    }
    
    open func appendCodePoint(_ ch: Int) {
        append(String(UnicodeScalar(ch)!))
    }
    
    open func appendCodePoint(_ ch: UnicodeScalar) {
        append(String(ch))
    }
    
    open func appendCodePoints(_ chr: [UnicodeScalar]) {
        append(String(String.UnicodeScalarView(chr)))
    }
    
    /**
     Append a Printable to the object
     
     :param: value a value supporting the Printable protocol
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
    open func append<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
        append(value.description)
        return self
    }
    
    @discardableResult
    open func append(_ value: UnicodeScalar) -> StringBuilder {
        append(value.description)
        return self
    }
    
    /**
     Append a String and a newline to the object
     
     :param: string String
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
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
public func += (lhs: StringBuilder, rhs: String) {
    lhs.append(rhs)
}

/**
 Append a Printable to a StringBuilder using operator syntax
 
 :param: lhs Printable
 :param: rhs String
 */
public func += <T: CustomStringConvertible>(lhs: StringBuilder, rhs: T) {
    lhs.append(rhs.description)
}

/**
 Create a StringBuilder by concatenating the values of two StringBuilders
 
 :param: lhs first StringBuilder
 :param: rhs second StringBuilder
 
 :result StringBuilder
 */
public func +(lhs: StringBuilder, rhs: StringBuilder) -> StringBuilder {
    return StringBuilder(string: lhs.toString() + rhs.toString())
}
