/**
 Supports creation of a String from pieces
 https://gist.github.com/kristopherjohnson/1fc55e811d944a430289
 */
open class StringBuilder {
    fileprivate var stringValue: Bytes = []
    
    /**
     Construct with initial String contents
     
     :param: string Initial value; defaults to empty string
     */
    public init(string: String = "") {
        self.stringValue.append(contentsOf:string.makeBytes())
    }
    public init(_ size: Int) {}
    public init() {}
    
    /**
     Return the String object
     
     :return: String
     */
    open func toString() -> String {
        return stringValue.makeString()
    }
    
    /**
     Return the current length of the String object
     */
    open var length: Int {
        return self.stringValue.count
        //return countElements(stringValue)
    }
    
    @discardableResult
    public func append(_ value: String)->StringBuilder {
        self.stringValue.append(contentsOf: value.makeBytes())
        return self
    }
    
    @discardableResult
    public func append(_ value: UnicodeScalar)->StringBuilder {
        self.stringValue.append(Byte(value.value))
        return self
    }
    
    @discardableResult
    public func append(_ value: Byte)->StringBuilder {
        self.stringValue.append(value)
        return self
    }

    @discardableResult
    public func append(_ value: Bytes)->StringBuilder {
        self.stringValue.append(contentsOf:value)
        return self
    }
    
    @discardableResult
    public func append(_ value: Character)->StringBuilder {
        let bytes : Bytes = value.unicodeScalars.flatMap { Byte($0.value) }
        self.append(bytes)
        return self
    }
    
    
    @discardableResult
    public func insert(_ index: Int, _ value: String)->StringBuilder {
        self.stringValue.insert(contentsOf: value.makeBytes(), at: index)
        return self
    }

    
    /**
     Reset the object to an empty string
     
     :return: reference to this StringBuilder instance
     */
    @discardableResult
    open func clear() -> StringBuilder {
        stringValue = Array();
        return self
    }
}

