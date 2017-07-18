extension Sequence where Iterator.Element == Byte {
    /// Converts a slice of bytes to
    /// string. Courtesy of @vzsg
    public func makeString() -> String {
        let array = Array(self) + [0]
        
        return array.withUnsafeBytes { rawBuffer in
            guard let pointer = rawBuffer.baseAddress?.assumingMemoryBound(to: CChar.self) else { return nil }
            return String(validatingUTF8: pointer)
        } ?? ""
    }

    /**
        Converts a byte representation
        of a hex value into an `Int`.
        as opposed to it's Decimal value
     
        ie: "10" == 16, not 10
    */
    public var hexInt: Int? {
        var int: Int = 0

        for byte in self {
            int = int * 16

            if byte >= .zero && byte <= .nine {
                int += Int(byte - .zero)
            } else if byte >= .A && byte <= .F {
                int += Int(byte - .A) + 10
            } else if byte >= .a && byte <= .f {
                int += Int(byte - .a) + 10
            } else {
                return nil
            }
        }

        return int
    }

    /**
        Converts a utf8 byte representation
        of a decimal value into an `Int` 
        as opposed to it's Hex value,
     
        ie: "10" == 10, not 16
    */
    public var decimalInt: Int? {
        var int: Int = 0

        for byte in self {
            int = int * 10
            if byte.isDigit {
                int += Int(byte - .zero)
            } else {
                return nil
            }
        }

        return int
    }

    /**
        Transforms anything between Byte.A ... Byte.Z
        into the range Byte.a ... Byte.z
    */
    public var lowercased: Bytes {
        var data = Bytes()

        for byte in self {
            if (.A ... .Z).contains(byte) {
                data.append(byte + (.a - .A))
            } else {
                data.append(byte)
            }
        }

        return data
    }

    /**
        Transforms anything between Byte.a ... Byte.z
        into the range Byte.A ... Byte.Z
    */
    public var uppercased: Bytes {
        var bytes = Bytes()

        for byte in self {
            if (.a ... .z).contains(byte) {
                bytes.append(byte - (.a - .A))
            } else {
                bytes.append(byte)
            }
        }

        return bytes
    }
}
