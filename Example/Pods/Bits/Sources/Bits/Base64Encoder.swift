/// Encodes and decodes bytes using the 
/// Base64 encoding
///
/// https://en.wikipedia.org/wiki/Base64
public final class Base64Encoder {

    /// Static shared instance
    public static let shared = Base64Encoder.regular

    /// Standard Base64Encoder
    public static var regular: Base64Encoder {
        return Base64Encoder()
    }

    // Base64URLEncoder
    // - note: uses hyphens and underscores
    //         in place of plus and forwardSlash
    public static var url: Base64Encoder {
        let encodeMap: Base64Encoder.ByteMap = { byte in
            switch byte {
            case 62:
                return .hyphen
            case 63:
                return .underscore
            default:
                return nil
            }
        }
        
        let decodeMap: Base64Encoder.ByteMap = { byte in
            switch byte {
            case Byte.hyphen:
                return 62
            case Byte.underscore:
                return 63
            default:
                return nil
            }
        }
        
        return Base64Encoder(
            padding: nil,
            encodeMap: encodeMap,
            decodeMap: decodeMap
        )
    }

    /// Maps binary format to base64 encoding
    static let encodingTable: [Byte: Byte] = [
         0: .A,      1: .B,     2: .C,     3: .D,
         4: .E,      5: .F,     6: .G,     7: .H,
         8: .I,      9: .J,    10: .K,    11: .L,
        12: .M,     13: .N,    14: .O,    15: .P,
        16: .Q,     17: .R,    18: .S,    19: .T,
        20: .U,     21: .V,    22: .W,    23: .X,
        24: .Y,     25: .Z,    26: .a,    27: .b,
        28: .c,     29: .d,    30: .e,    31: .f,
        32: .g,     33: .h,    34: .i,    35: .j,
        36: .k,     37: .l,    38: .m,    39: .n,
        40: .o,     41: .p,    42: .q,    43: .r,
        44: .s,     45: .t,    46: .u,    47: .v,
        48: .w,     49: .x,    50: .y,    51: .z,
        52: .zero,  53: .one,  54: .two,  55: .three,
        56: .four,  57: .five, 58: .six,  59: .seven,
        60: .eight, 61: .nine, 62: .plus, 63: .forwardSlash
    ]

    /// Maps base64 encoding into binary format
    static let decodingTable: [Byte: Byte] = [
             .A: 0,     .B: 1,     .C: 2,             .D: 3,
             .E: 4,     .F: 5,     .G: 6,             .H: 7,
             .I: 8,     .J: 9,     .K: 10,            .L: 11,
             .M: 12,    .N: 13,    .O: 14,            .P: 15,
             .Q: 16,    .R: 17,    .S: 18,            .T: 19,
             .U: 20,    .V: 21,    .W: 22,            .X: 23,
             .Y: 24,    .Z: 25,    .a: 26,            .b: 27,
             .c: 28,    .d: 29,    .e: 30,            .f: 31,
             .g: 32,    .h: 33,    .i: 34,            .j: 35,
             .k: 36,    .l: 37,    .m: 38,            .n: 39,
             .o: 40,    .p: 41,    .q: 42,            .r: 43,
             .s: 44,    .t: 45,    .u: 46,            .v: 47,
             .w: 48,    .x: 49,    .y: 50,            .z: 51,
          .zero: 52,  .one: 53,  .two: 54,        .three: 55,
          .four: 56, .five: 57,  .six: 58,        .seven: 59,
         .eight: 60, .nine: 61, .plus: 62, .forwardSlash: 63
    ]

    /// Typealias for optionally mapping a byte
    public typealias ByteMap = (Byte) -> Byte?

    /// Byte to use for padding base64
    /// if nil, no padding will be used
    public let padding: Byte?

    /// If set, bytes returned will have priority
    /// over the encoding table. Encoding table
    /// will be used as a fallback
    public let encodeMap: ByteMap?

    /// If set, bytes returned will have priority
    /// over the decoding table. Decoding table
    /// will be used as a fallback
    public let decodeMap: ByteMap?

    /// Creates a new Base64 encoder
    public init(
        padding: Byte? = .equals,
        encodeMap: ByteMap? = nil,
        decodeMap: ByteMap? = nil
    ) {
        self.padding = padding
        self.encodeMap = encodeMap
        self.decodeMap = decodeMap
    }

    /// Encodes bytes into Base64 format
    public func encode(_ bytes: Bytes) -> Bytes {
        if bytes.count == 0 {
            return []
        }

        let len = bytes.count
        var offset: Int = 0
        var c1: UInt8
        var c2: UInt8
        var result: Bytes = []

        while offset < len {
            c1 = bytes[offset] & 0xff
            offset += 1
            result.append(encode((c1 >> 2) & 0x3f))
            c1 = (c1 & 0x03) << 4
            if offset >= len {
                result.append(encode(c1 & 0x3f))
                if let padding = self.padding {
                    result.append(padding)
                    result.append(padding)
                }
                break
            }

            c2 = bytes[offset] & 0xff
            offset += 1
            c1 |= (c2 >> 4) & 0x0f
            result.append(encode(c1 & 0x3f))
            c1 = (c2 & 0x0f) << 2
            if offset >= len {
                result.append(encode(c1 & 0x3f))
                if let padding = self.padding {
                    result.append(padding)
                }
                break
            }

            c2 = bytes[offset] & 0xff
            offset += 1
            c1 |= (c2 >> 6) & 0x03
            result.append(encode(c1 & 0x3f))
            result.append(encode(c2 & 0x3f))
        }

        return result
    }

    /// Decodes bytes into binary format
    public func decode(_ s: Bytes) -> Bytes {
        let maxolen = s.count

        var off: Int = 0
        var olen: Int = 0
        var result = Bytes(repeating: 0, count: maxolen)

        var c1: Byte
        var c2: Byte
        var c3: Byte
        var c4: Byte
        var o: Byte

        while off < s.count - 1 && olen < maxolen {
            c1 = decode(s[off])
            off += 1
            c2 = decode(s[off])
            off += 1
            if c1 == Byte.max || c2 == Byte.max {
                break
            }

            o = c1 << 2
            o |= (c2 & 0x30) >> 4
            result[olen] = o
            olen += 1
            if olen >= maxolen || off >= s.count {
                break
            }

            c3 = decode(s[off])
            off += 1
            if c3 == Byte.max {
                break
            }

            o = (c2 & 0x0f) << 4
            o |= (c3 & 0x3c) >> 2
            result[olen] = o
            olen += 1
            if olen >= maxolen || off >= s.count {
                break
            }

            c4 = decode(s[off])
            off += 1
            if c4 == Byte.max {
                break
            }
            o = (c3 & 0x03) << 6
            o |= c4
            result[olen] = o
            olen += 1
        }

        return Array(result[0..<olen])
    }

    // MARK: Private

    private func encode(_ x: Byte) -> Byte {
        return encodeMap?(x)
            ?? Base64Encoder.encodingTable[x]
            ?? Byte.max
    }

    private func decode(_ x: Byte) -> Byte {
        return decodeMap?(x)
            ?? Base64Encoder.decodingTable[x]
            ?? Byte.max
    }
}
