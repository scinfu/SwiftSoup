/**
 Supports creation of a String from pieces
 Based on https://gist.github.com/kristopherjohnson/1fc55e811d944a430289
 */
open class StringBuilder {
    fileprivate var buffer: [String] = []

    /**
     Construct with initial String contents
     
     :param: string Initial value; defaults to empty string
     */
    public init(string: String = "") {
        if string != "" {
            buffer.append(string)
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
        return buffer.joined()
    }

    /**
     Return the current length of the String object
     */
    open var xlength: Int {
        return buffer.map { $0.count }.reduce(0, +)
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
        buffer.append(string)
    }

    open func appendCodePoint(_ chr: Character) {
        buffer.append(String(chr))
    }

    open func appendCodePoints(_ chr: [Character]) {
        buffer.append(String(chr))
    }

    open func appendCodePoint(_ ch: Int) {
        buffer.append(String(UnicodeScalar(ch)!))
    }

    open func appendCodePoint(_ ch: UnicodeScalar) {
        buffer.append(String(ch))
    }

    open func appendCodePoints(_ chr: [UnicodeScalar]) {
        buffer.append(String(String.UnicodeScalarView(chr)))
    }

    /**
     Append a Printable to the object
     
     :param: value a value supporting the Printable protocol
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
    open func append<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
        buffer.append(value.description)
        return self
    }

    @discardableResult
    open func append(_ value: UnicodeScalar) -> StringBuilder {
        buffer.append(value.description)
        return self
    }

    /**
     Append a String and a newline to the object
     
     :param: string String
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
    open func appendLine(_ string: String) -> StringBuilder {
        buffer.append(string)
        buffer.append("\n")
        return self
    }

    /**
     Append a Printable and a newline to the object
     
     :param: value a value supporting the Printable protocol
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
    open func appendLine<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
        buffer.append(value.description)
        buffer.append("\n")
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
