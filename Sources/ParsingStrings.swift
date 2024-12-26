import Foundation

@inline(__always)
func setBit(in mask: inout (UInt64, UInt64, UInt64, UInt64), forByte b: UInt8) {
    let idx = Int(b >> 6)
    let shift = b & 63
    switch idx {
    case 0: mask.0 |= (1 << shift)
    case 1: mask.1 |= (1 << shift)
    case 2: mask.2 |= (1 << shift)
    default: mask.3 |= (1 << shift)
    }
}

@inline(__always)
func testBit(_ mask: (UInt64, UInt64, UInt64, UInt64), _ b: UInt8) -> Bool {
    let idx = Int(b >> 6)
    let shift = b & 63
    let val: UInt64
    switch idx {
    case 0: val = mask.0
    case 1: val = mask.1
    case 2: val = mask.2
    default: val = mask.3
    }
    return (val & (1 << shift)) != 0
}

public struct ParsingStrings: Hashable, Equatable {
    let multiByteChars: [[UInt8]]
    let multiByteCharLengths: [Int]
    let multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)]
    let multiByteSet: Set<ArraySlice<UInt8>>
    let multiByteByteLookupsCount: Int
    let singleByteSet: Set<UInt8> // Precomputed set for single-byte lookups
    private let precomputedHash: Int
    
    public init(_ strings: [String]) {
        self.init(strings.map { $0.utf8Array })
    }
    
    public init(_ strings: [[UInt8]]) {
        multiByteChars = strings
        multiByteCharLengths = strings.map { $0.count }
        let maxLen = multiByteCharLengths.max() ?? 0
        
        var multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)] = Array(repeating: (0,0,0,0), count: maxLen)
        var singleByteSet = Set<UInt8>() // Initialize single-byte set
        
        for char in multiByteChars {
            if char.count == 1 {
                // Add single-byte characters directly to the set
                singleByteSet.insert(char[0])
            }
            for (i, byte) in char.enumerated() {
                var mask = multiByteByteLookups[i]
                setBit(in: &mask, forByte: byte)
                multiByteByteLookups[i] = mask
            }
        }
        self.multiByteByteLookups = multiByteByteLookups
        multiByteByteLookupsCount = multiByteByteLookups.count
        
        self.singleByteSet = singleByteSet
        multiByteSet = Set(multiByteChars.map { ArraySlice($0) })
        self.precomputedHash = Self.computeHash(
            multiByteChars: multiByteChars,
            multiByteByteLookups: multiByteByteLookups
        )
    }
    
    public init(_ strings: [UnicodeScalar]) {
        self.init(strings.map { Array($0.utf8) })
    }
    
    private static func computeHash(
        multiByteChars: [[UInt8]],
        multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)]
    ) -> Int {
        var hasher = Hasher()
        for char in multiByteChars {
            hasher.combine(char.count)
            for b in char {
                hasher.combine(b)
            }
        }
        for mbb in multiByteByteLookups {
            hasher.combine(mbb.0)
            hasher.combine(mbb.1)
            hasher.combine(mbb.2)
            hasher.combine(mbb.3)
        }
        return hasher.finalize()
    }
    
    public static func ==(lhs: ParsingStrings, rhs: ParsingStrings) -> Bool {
        return lhs.multiByteChars == rhs.multiByteChars
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(precomputedHash)
    }
    
    public func contains(_ slice: ArraySlice<UInt8>) -> Bool {
        var index = 0
        for byte in slice {
            if index >= multiByteByteLookupsCount || !testBit(multiByteByteLookups[index], byte) {
                return false
            }
            index &+= 1
        }
        return multiByteSet.contains(slice)
    }
    
    public func contains(_ byte: UInt8) -> Bool {
        // Directly check the precomputed single-byte set
        return singleByteSet.contains(byte)
    }
    
    public func contains(_ scalar: UnicodeScalar) -> Bool {
        let utf8Bytes = Array(scalar.utf8)
        return contains(ArraySlice(utf8Bytes))
    }
}
