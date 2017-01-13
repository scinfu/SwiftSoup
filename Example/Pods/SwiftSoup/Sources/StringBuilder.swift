/**
    Supports creation of a String from pieces
 https://gist.github.com/kristopherjohnson/1fc55e811d944a430289
*/
open class StringBuilder {
    fileprivate var stringValue: String

    /**
        Construct with initial String contents

        :param: string Initial value; defaults to empty string
    */
    public init(string: String = "") {
        self.stringValue = string
    }

    public init(_ size: Int) {
        self.stringValue = ""
    }

    /**
        Return the String object
        
        :return: String
    */
    open func toString() -> String {
        return stringValue
    }

    /**
        Return the current length of the String object
    */
    open var length: Int {
        return self.stringValue.characters.count
        //return countElements(stringValue)
    }

    /**
        Append a String to the object

        :param: string String
    
        :return: reference to this StringBuilder instance
    */
    open func append(_ string: String) {
        stringValue += string
    }

    open func appendCodePoint(_ chr: Character) {
        stringValue = stringValue + String(chr)
    }

    open func appendCodePoints(_ chr: [Character]) {
        for c in chr {
            stringValue = stringValue + String(c)
        }
    }

    open func appendCodePoint(_ ch: Int) {
        stringValue = stringValue + String(Character(UnicodeScalar(ch)!))
    }

	open func appendCodePoint(_ ch: UnicodeScalar) {
		stringValue = stringValue + String(ch)
	}

	open func appendCodePoints(_ chr: [UnicodeScalar]) {
		for c in chr {
			stringValue = stringValue + String(c)
		}
	}

    /**
        Append a Printable to the object
        
        :param: value a value supporting the Printable protocol
    
        :return: reference to this StringBuilder instance
    */
    @discardableResult
    open func append<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
        stringValue += value.description
        return self
    }

    @discardableResult
    open func insert<T: CustomStringConvertible>(_ offset: Int, _ value: T) -> StringBuilder {
        stringValue = stringValue.insert(string: value.description, ind: offset)
        return self
    }

    /**
        Append a String and a newline to the object
        
        :param: string String
    
        :return: reference to this StringBuilder instance
    */
    @discardableResult
    open func appendLine(_ string: String) -> StringBuilder {
        stringValue += string + "\n"
        return self
    }

    /**
        Append a Printable and a newline to the object
        
        :param: value a value supporting the Printable protocol
    
        :return: reference to this StringBuilder instance
    */
    @discardableResult
    open func appendLine<T: CustomStringConvertible>(_ value: T) -> StringBuilder {
        stringValue += value.description + "\n"
        return self
    }

    /**
        Reset the object to an empty string

        :return: reference to this StringBuilder instance
    */
    @discardableResult
    open func clear() -> StringBuilder {
        stringValue = ""
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
