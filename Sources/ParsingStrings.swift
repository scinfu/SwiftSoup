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

final class TrieNode {
    // For fastest lookup: a 256-element array for direct indexing by byte
    var children: [TrieNode?] = .init(repeating: nil, count: 256)
    
    // Mark that a path ending at this node represents a complete string
    var isTerminal: Bool = false
}

public struct ParsingStrings: Hashable, Equatable {
    let multiByteChars: [[UInt8]]
    let multiByteCharLengths: [Int]
    let multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)]
    let multiByteSet: Set<ArraySlice<UInt8>>
    let multiByteByteLookupsCount: Int
    public var singleByteMask: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0) // Precomputed set for single-byte lookups
    private let precomputedHash: Int
    private let root = TrieNode()
    
    public init(_ strings: [String]) {
        self.init(strings.map { $0.utf8Array })
    }
    
    public init(_ strings: [[UInt8]]) {
        multiByteChars = strings
        multiByteCharLengths = strings.map { $0.count }
        let maxLen = multiByteCharLengths.max() ?? 0
        
        var multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)] = Array(repeating: (0,0,0,0), count: maxLen)
        
        for bytes in strings {
            guard !bytes.isEmpty else { continue }
            
            var current = root
            for b in bytes {
                if current.children[Int(b)] == nil {
                    current.children[Int(b)] = TrieNode()
                }
                current = current.children[Int(b)]!
            }
            current.isTerminal = true
        }
        
        for char in multiByteChars {
            if char.count == 1 {
                setBit(in: &singleByteMask, forByte: char[0])
            }
            for (i, byte) in char.enumerated() {
                var mask = multiByteByteLookups[i]
                setBit(in: &mask, forByte: byte)
                multiByteByteLookups[i] = mask
            }
        }
        self.multiByteByteLookups = multiByteByteLookups
        multiByteByteLookupsCount = multiByteByteLookups.count
        
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
    
    @inlinable
    public func contains(_ byte: UInt8) -> Bool {
        let idx = Int(byte >> 6)
        let shift = byte & 63
        
        // Pick which 64-bit in the tuple:
        let val: UInt64
        switch idx {
        case 0: val = singleByteMask.0
        case 1: val = singleByteMask.1
        case 2: val = singleByteMask.2
        default: val = singleByteMask.3
        }
        
        // If the corresponding bit is set, membership is true
        return (val & (1 << shift)) != 0
    }
    
    @inlinable
    public func contains(_ scalar: UnicodeScalar) -> Bool {
        // Fast path for ASCII
        if scalar.value < 0x80 {
            return contains(UInt8(scalar.value))
        }
        
        var buffer = [UInt8](repeating: 0, count: 4)
        var length = 0
        for b in scalar.utf8 {
            buffer[length] = b
            length &+= 1
        }
        let slice = buffer[..<length]
        
        // Walk the trie:
        return containsTrie(slice)
    }
}

extension ParsingStrings {
    /// Checks membership by walking our trie.
    /// Returns true if `slice` exactly matches a terminal path.
    public func containsTrie(_ slice: ArraySlice<UInt8>) -> Bool {
        // Early single-byte check
        if slice.count == 1 {
            return contains(slice.first!)
        }
        
        var current = root
        for b in slice {
            guard let child = current.children[Int(b)] else {
                return false
            }
            current = child
        }
        return current.isTerminal
    }
}
