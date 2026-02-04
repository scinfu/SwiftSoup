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
public func testBit(_ mask: (UInt64, UInt64, UInt64, UInt64), _ b: UInt8) -> Bool {
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

final class TrieNode: Sendable {
    // For fastest lookup: a 256-element array for direct indexing by byte
    let children: [TrieNode?]
    
    // Mark that a path ending at this node represents a complete string
    let isTerminal: Bool
    
    init(children: [TrieNode?], isTerminal: Bool) {
        assert(children.count == 256)
        self.children = children
        self.isTerminal = isTerminal
    }
}

class MutableTrieNode {
    // For fastest lookup: a 256-element array for direct indexing by byte
    var children: [MutableTrieNode?] = .init(repeating: nil, count: 256)
    
    // Mark that a path ending at this node represents a complete string
    var isTerminal: Bool = false
    
    func makeImmutable() -> TrieNode {
        return TrieNode.init(
            children: self.children.map { $0?.makeImmutable() },
            isTerminal: self.isTerminal
        )
    }
}

public struct ParsingStrings: Hashable, Equatable, Sendable {
    let multiByteChars: [[UInt8]]
    let multiByteCharLengths: [Int]
    public let multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)]
    public let multiByteSet: [ArraySlice<UInt8>]
    public let multiByteByteLookupsCount: Int
    public let singleByteMask: (UInt64, UInt64, UInt64, UInt64) // Precomputed set for single-byte lookups
    public let singleByteList: [UInt8]
    public let singleByteCount: Int
    public let isSingleByteOnly: Bool
    public let tagIdMaskLo: UInt64
    public let tagIdMaskHi: UInt64
    private let precomputedHash: Int
    private let root: TrieNode
    private let singleByteTable: [Bool]
    
    public init(_ strings: [String]) {
        self.init(strings.map { $0.utf8Array })
    }
    
    public init(_ strings: [[UInt8]]) {
        multiByteChars = strings
        multiByteCharLengths = strings.map { $0.count }
        let maxLen = multiByteCharLengths.max() ?? 0
        var singleByteOnly = true
        
        var multiByteByteLookups: [(UInt64, UInt64, UInt64, UInt64)] = Array(repeating: (0,0,0,0), count: maxLen)
        
        let trieRoot = MutableTrieNode()
        for bytes in strings {
            guard !bytes.isEmpty else { continue }
            
            var current = trieRoot
            for b in bytes {
                if current.children[Int(b)] == nil {
                    current.children[Int(b)] = MutableTrieNode()
                }
                current = current.children[Int(b)]!
            }
            current.isTerminal = true
        }
        self.root = trieRoot.makeImmutable()
        
        var byteMask: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        var singleBytes: [UInt8] = []
        var tagIdMaskLo: UInt64 = 0
        var tagIdMaskHi: UInt64 = 0
        for char in multiByteChars {
            if char.count == 1 {
                let byte = char[0]
                setBit(in: &byteMask, forByte: byte)
                if !singleBytes.contains(byte) {
                    singleBytes.append(byte)
                }
                if byte >= TokeniserStateVars.asciiUpperLimitByte {
                    singleByteOnly = false
                }
            } else {
                singleByteOnly = false
            }
            if let tagId = Token.Tag.tagIdForBytes(char) {
                let raw = Int(tagId.rawValue)
                if raw < 64 {
                    tagIdMaskLo |= (1 << UInt64(raw))
                } else if raw < 128 {
                    tagIdMaskHi |= (1 << UInt64(raw - 64))
                }
            }
            for (i, byte) in char.enumerated() {
                var mask = multiByteByteLookups[i]
                setBit(in: &mask, forByte: byte)
                multiByteByteLookups[i] = mask
            }
        }
        var table = [Bool](repeating: false, count: 256)
        for b in 0..<256 {
            table[b] = testBit(byteMask, UInt8(b))
        }
        self.singleByteTable = table
        self.singleByteMask = byteMask
        self.singleByteList = singleBytes
        self.singleByteCount = singleBytes.count
        self.isSingleByteOnly = singleByteOnly
        self.tagIdMaskLo = tagIdMaskLo
        self.tagIdMaskHi = tagIdMaskHi
        
        self.multiByteByteLookups = multiByteByteLookups
        multiByteByteLookupsCount = multiByteByteLookups.count
        
        multiByteSet = multiByteChars.map { ArraySlice($0) }
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
    
    @inline(__always)
    public static func ==(lhs: ParsingStrings, rhs: ParsingStrings) -> Bool {
        return lhs.multiByteChars == rhs.multiByteChars
    }
    
    @inline(__always)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(precomputedHash)
    }
    
    @inline(__always)
    public func contains(_ bytes: [UInt8]) -> Bool {
        return contains(ArraySlice(bytes))
    }

    @inline(__always)
    func contains(_ slice: ByteSlice) -> Bool {
        if slice.count == 1 {
            return contains(slice[0])
        }
        var index = 0
        for byte in slice {
            if index >= multiByteByteLookupsCount || !testBit(multiByteByteLookups[index], byte) {
                return false
            }
            index &+= 1
        }
        var node = root
        for byte in slice {
            guard let next = node.children[Int(byte)] else {
                return false
            }
            node = next
        }
        return node.isTerminal
    }

    @inline(__always)
    public func contains(_ slice: ArraySlice<UInt8>) -> Bool {
        if slice.count == 1 {
            return contains(slice[slice.startIndex])
        }
        var index = 0
        for byte in slice {
            if index >= multiByteByteLookupsCount || !testBit(multiByteByteLookups[index], byte) {
                return false
            }
            index &+= 1
        }
        var node = root
        for byte in slice {
            guard let next = node.children[Int(byte)] else {
                return false
            }
            node = next
        }
        return node.isTerminal
    }
    
    @inline(__always)
    public func contains(_ byte: UInt8) -> Bool {
        return singleByteTable[Int(byte)]
    }

    @inline(__always)
    internal func containsTagId(_ tagId: Token.Tag.TagId) -> Bool {
        let raw = Int(tagId.rawValue)
        if raw < 64 {
            return (tagIdMaskLo & (1 << UInt64(raw))) != 0
        }
        if raw < 128 {
            return (tagIdMaskHi & (1 << UInt64(raw - 64))) != 0
        }
        return false
    }
    
    @inline(__always)
    public func contains(_ scalar: UnicodeScalar) -> Bool {
        // Fast path for ASCII
        if scalar.value < UInt32(TokeniserStateVars.asciiUpperLimitByte) {
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
    @inline(__always)
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
