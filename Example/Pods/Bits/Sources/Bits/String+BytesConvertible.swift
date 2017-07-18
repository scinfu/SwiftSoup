extension String: BytesConvertible {
    /**
         UTF8 Array representation of string
    */
    public func makeBytes() -> Bytes {
        return Bytes(utf8)
    }

    /**
         Initializes a string with a UTF8 byte array
    */
    public init(bytes: Bytes) {
        self = bytes.makeString()
    }
}
