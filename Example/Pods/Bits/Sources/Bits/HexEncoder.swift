/// Encodes and decodes bytes using the
/// Hexadeicmal encoding
///
/// https://en.wikipedia.org/wiki/Hexadecimal
public final class HexEncoder {
    /// Maps binary format to hex encoding
    static let encodingTable: [Byte: Byte] = [
         0: .zero,  1: .one,   2: .two, 3: .three,
         4: .four,  5: .five,  6: .six, 7: .seven,
         8: .eight, 9: .nine, 10: .a,  11: .b,
        12: .c,    13: .d,    14: .e,  15: .f
    ]

    /// Maps hex encoding to binary format
    /// - note: Supports upper and lowercase
    static let decodingTable: [Byte: Byte] = [
         .zero: 0,  .one: 1, .two: 2, .three: 3,
         .four: 4, .five: 5, .six: 6, .seven: 7,
        .eight: 8, .nine: 9,   .a: 10,    .b: 11,
            .c: 12,   .d: 13,  .e: 14,    .f: 15,
            .A: 10,   .B: 11,  .C: 12,    .D: 13,
            .E: 14,   .F: 15
    ]

    /// Static shared instance
    public static let shared = HexEncoder()

    /// When true, the encoder will discard
    /// any unknown characters while decoding.
    /// When false, undecodable characters will
    /// cause an early return.
    public let ignoreUndecodableCharacters: Bool

    /// Creates a new Hexadecimal encoder
    public init(ignoreUndecodableCharacters: Bool = true) {
        self.ignoreUndecodableCharacters = ignoreUndecodableCharacters
    }

    /// Encodes bytes into Hexademical format
    public func encode(_ message: Bytes) -> Bytes {
        var encoded: Bytes = []

        for byte in message {
            // move the top half of the byte down
            // 0x12345678 becomes 0x00001234
            let upper = byte >> 4

            // zero out the top half of the byte
            // 0x12345678 becomes 0x00005678
            let lower = byte & 0xF

            // encode the 4-bit numbers
            // using the 0-f encoding (2^4=16)
            encoded.append(encode(upper))
            encoded.append(encode(lower))
        }

        return encoded
    }

    /// Decodes hexadecimally encoded bytes into 
    /// binary format
    public func decode(_ message: Bytes) -> Bytes {
        var decoded: Bytes = []

        // create an iterator to easily 
        // fetch two at a time
        var i = message.makeIterator()

        // take bytes two at a time
        while let c1 = i.next(), let c2 = i.next() {
            // decode the first character from
            // letter representation to 4-bit number
            // e.g, "1" becomes 0x00000001
            let upper = decode(c1)
            guard upper != Byte.max || ignoreUndecodableCharacters else {
                return decoded
            }

            // decode the second character from
            // letter representation to a 4-bit number
            let lower = decode(c2)
            guard lower != Byte.max || ignoreUndecodableCharacters else {
                return decoded
            }

            // combine the two 4-bit numbers back
            // into the original byte, shifting
            // the first back up to its 8-bit position
            //
            // 0x00001234 << 4 | 0x00005678 
            // becomes:
            // 0x12345678
            let byte = upper << 4 | lower

            decoded.append(byte)
        }

        return decoded
    }

    // MARK: Private

    private func encode(_ byte: Byte) -> Byte {
        return HexEncoder.encodingTable[byte] ?? Byte.max
    }

    private func decode(_ byte: Byte) -> Byte {
        return HexEncoder.decodingTable[byte] ?? Byte.max
    }
}
