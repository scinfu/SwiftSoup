//
//  Attributes.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

/**
 The attributes of an Element.
 
 Attributes are treated as a map: there can be only one value associated with an attribute key/name.
 
 Attribute name and value comparisons are **case sensitive**. By default for HTML, attribute names are
 normalized to lower-case on parsing. That means you should use lower-case strings when referring to attributes by
 name.
 */
public struct AttributeMutation {
    public let keep: Bool
    public let newValue: [UInt8]?
    
    @inline(__always)
    public init(keep: Bool, newValue: [UInt8]? = nil) {
        self.keep = keep
        self.newValue = newValue
    }
}


open class Attributes: NSCopying {
    public static let dataPrefix: [UInt8] = "data-".utf8Array
    
    // Stored by lowercased key, but key case is checked against the copy inside
    // the Attribute on retrieval.
    @usableFromInline
    var attributes: [Attribute] = [] {
        @inline(__always)
        didSet {
            ownerElement?.markClassQueryIndexDirty()
            ownerElement?.markIdQueryIndexDirty()
            ownerElement?.markAttributeQueryIndexDirty()
            ownerElement?.markAttributeValueQueryIndexDirty()
            invalidateLowercasedKeysCache()
            invalidateKeyIndex()
        }
    }
    
    /// Set of lower‑cased UTF‑8 keys for fast O(1) ignore‑case look‑ups
    @usableFromInline
    internal var lowercasedKeysCache: Set<[UInt8]>? = nil
    
    @usableFromInline
    internal var hasUppercaseKeys: Bool = false

    @usableFromInline
    internal var keyIndex: [Array<UInt8>: Int]? = nil

    @usableFromInline
    internal var keyIndexDirty: Bool = true
    
    // TODO: Delegate would be cleaner...
    @usableFromInline
    weak var ownerElement: SwiftSoup.Element?
    
    public init() {
        attributes.reserveCapacity(16)
    }
    
    @usableFromInline
    @inline(__always)
    internal func updateLowercasedKeysCache() {
        lowercasedKeysCache = Set(
            attributes.map { attr in
                attr.getKeyUTF8().map(Self.asciiLowercase)
            }
        )
    }
    
    @usableFromInline
    @inline(__always)
    internal func invalidateLowercasedKeysCache() {
        lowercasedKeysCache = nil
    }

    @usableFromInline
    @inline(__always)
    internal func invalidateKeyIndex() {
        keyIndex = nil
        keyIndexDirty = true
    }

    @usableFromInline
    @inline(__always)
    func shouldBuildKeyIndex() -> Bool {
        return attributes.count >= 12
    }

    @usableFromInline
    @inline(__always)
    func ensureKeyIndex() {
        guard shouldBuildKeyIndex() else { return }
        if keyIndexDirty || keyIndex == nil {
            var rebuilt: [Array<UInt8>: Int] = [:]
            rebuilt.reserveCapacity(attributes.count)
            for (index, attr) in attributes.enumerated() {
                rebuilt[attr.getKeyUTF8()] = index
            }
            keyIndex = rebuilt
            keyIndexDirty = false
        }
    }

    @usableFromInline
    @inline(__always)
    func indexForKey(_ key: [UInt8]) -> Int? {
        if shouldBuildKeyIndex() {
            ensureKeyIndex()
            return keyIndex?[key]
        }
        return attributes.firstIndex(where: { $0.getKeyUTF8() == key })
    }
    
    /**
     Get an attribute value by key.
     - parameter key: the (case-sensitive) attribute key
     - returns: the attribute value if set; or empty string if not set.
     - seealso: ``hasKey(key:)-(String)``
     */
    @inline(__always)
    open func get(key: String) -> String {
        return String(decoding: get(key: key.utf8Array), as: UTF8.self)
    }
    
    @inline(__always)
    open func get(key: [UInt8]) -> [UInt8] {
        if let ix = indexForKey(key) {
            return attributes[ix].getValueUTF8()
        }
        return []
    }
    
    /**
     Get an attribute's value by case-insensitive key
     - parameter key: the attribute name
     - returns: the first matching attribute value if set; or empty string if not set.
     */
    @inline(__always)
    open func getIgnoreCase(key: String) throws -> String {
        return try String(decoding: getIgnoreCase(key: key.utf8Array), as: UTF8.self)
    }
    
    @inline(__always)
    open func getIgnoreCase(key: [UInt8]) throws -> [UInt8] {
        try Validate.notEmpty(string: key)
        if lowercasedKeysCache == nil {
            updateLowercasedKeysCache()
        }
        guard lowercasedKeysCache?.contains(key.lowercased()) ?? false else { return [] }
        if let attr = attributes.first(where: { $0.getKeyUTF8().caseInsensitiveCompare(key) == .orderedSame }) {
            return attr.getValueUTF8()
        }
        return []
    }
    
    /**
     Set a new attribute, or replace an existing one by key.
     - parameter key: attribute key
     - parameter value: attribute value
     */
    @inline(__always)
    open func put(_ key: [UInt8], _ value: [UInt8]) throws {
        let attr = try Attribute(key: key, value: value)
        put(attribute: attr)
    }
    
    @inline(__always)
    open func put(_ key: String, _ value: String) throws {
        return try put(key.utf8Array, value.utf8Array)
    }
    
    /**
     Set a new boolean attribute, remove attribute if value is false.
     - parameter key: attribute key
     - parameter value: attribute value
     */
    @inline(__always)
    open func put(_ key: [UInt8], _ value: Bool) throws {
        if (value) {
            try put(attribute: BooleanAttribute(key: key))
        } else {
            try remove(key: key)
        }
    }
    
    /**
     Set a new attribute, or replace an existing one by (case-sensitive) key.
     - parameter attribute: attribute
     */
    @inline(__always)
    open func put(attribute: Attribute) {
        let key = attribute.getKeyUTF8()
        let hasUppercase = Attributes.containsAsciiUppercase(key)
        let normalizedKey = hasUppercase ? key.lowercased() : key
        if let ix = indexForKey(key) {
            attributes[ix] = attribute
            if !keyIndexDirty, keyIndex != nil {
                keyIndex?[key] = ix
            }
        } else {
            attributes.append(attribute)
            if !keyIndexDirty, keyIndex != nil {
                keyIndex?[key] = attributes.count - 1
            }
        }
        if !hasUppercaseKeys && hasUppercase {
            hasUppercaseKeys = true
        }
        invalidateLowercasedKeysCache()
        if normalizedKey == UTF8Arrays.class_ {
            ownerElement?.markClassQueryIndexDirty()
        }
        if normalizedKey == SwiftSoup.Element.idString {
            ownerElement?.markIdQueryIndexDirty()
        }
        ownerElement?.markAttributeQueryIndexDirty()
        ownerElement?.markAttributeValueQueryIndexDirty(for: key)
    }
    
    /**
     Remove an attribute by key. <b>Case sensitive.</b>
     - parameter key: attribute key to remove
     */
    @inline(__always)
    open func remove(key: String) throws {
        try remove(key: key.utf8Array)
    }
    
    @inlinable
    open func remove(key: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        if let ix = indexForKey(key) {
            attributes.remove(at: ix)
            invalidateLowercasedKeysCache()
            invalidateKeyIndex()
            let normalizedKey = key.lowercased()
            if normalizedKey == UTF8Arrays.class_ {
                ownerElement?.markClassQueryIndexDirty()
            }
            if normalizedKey == SwiftSoup.Element.idString {
                ownerElement?.markIdQueryIndexDirty()
            }
            ownerElement?.markAttributeQueryIndexDirty()
            ownerElement?.markAttributeValueQueryIndexDirty(for: key)
        }
    }
    
    /**
     Remove an attribute by key. <b>Case insensitive.</b>
     - parameter key: attribute key to remove
     */
    @inlinable
    open func removeIgnoreCase(key: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        if let ix = attributes.firstIndex(where: { $0.getKeyUTF8().caseInsensitiveCompare(key) == .orderedSame}) {
            let normalizedKey = key.lowercased()
            attributes.remove(at: ix)
            invalidateLowercasedKeysCache()
            invalidateKeyIndex()
            if normalizedKey == UTF8Arrays.class_ {
                ownerElement?.markClassQueryIndexDirty()
            }
            if normalizedKey == SwiftSoup.Element.idString {
                ownerElement?.markIdQueryIndexDirty()
            }
            ownerElement?.markAttributeQueryIndexDirty()
            ownerElement?.markAttributeValueQueryIndexDirty(for: key)
        }
    }

    /**
     Remove multiple attributes by exact key bytes in a single pass.
     - parameter keys: attribute keys to remove (case sensitive)
     */
    @inline(__always)
    open func removeAll(keys: [[UInt8]]) {
        guard !keys.isEmpty else { return }
        guard !attributes.isEmpty else { return }

        var removedKeys: [[UInt8]] = []
        removedKeys.reserveCapacity(Swift.min(keys.count, attributes.count))
        var writeIndex = 0
        let originalCount = attributes.count
        for readIndex in 0..<originalCount {
            let attr = attributes[readIndex]
            let key = attr.getKeyUTF8()
            var shouldRemove = false
            for removalKey in keys {
                if removalKey == key {
                    shouldRemove = true
                    break
                }
            }
            if shouldRemove {
                removedKeys.append(key)
            } else {
                if writeIndex != readIndex {
                    attributes[writeIndex] = attr
                }
                writeIndex += 1
            }
        }

        guard !removedKeys.isEmpty else { return }
        if writeIndex < originalCount {
            attributes.removeLast(originalCount - writeIndex)
        }
        invalidateLowercasedKeysCache()
        invalidateKeyIndex()

        if let ownerElement {
            for key in removedKeys {
                let normalizedKey = key.lowercased()
                if normalizedKey == UTF8Arrays.class_ {
                    ownerElement.markClassQueryIndexDirty()
                }
                if normalizedKey == SwiftSoup.Element.idString {
                    ownerElement.markIdQueryIndexDirty()
                }
                ownerElement.markAttributeValueQueryIndexDirty(for: key)
            }
            ownerElement.markAttributeQueryIndexDirty()
        }
    }

    /**
     Compact the attribute list in one pass, allowing in-place mutation of values.
     - parameter body: return whether to keep the attribute and optionally a new value.
     */
    @inline(__always)
    open func compactAndMutate(_ body: (Attribute) -> AttributeMutation) {
        guard !attributes.isEmpty else { return }

        let ownerElement = self.ownerElement
        var didMutate = false
        var dirtyClass = false
        var dirtyId = false

        @inline(__always)
        func markDirty(for key: [UInt8]) {
            let normalizedKey = key.lowercased()
            if normalizedKey == UTF8Arrays.class_ {
                dirtyClass = true
            }
            if normalizedKey == SwiftSoup.Element.idString {
                dirtyId = true
            }
            ownerElement?.markAttributeValueQueryIndexDirty(for: key)
        }

        var writeIndex = 0
        let originalCount = attributes.count
        for readIndex in 0..<originalCount {
            let attr = attributes[readIndex]
            let decision = body(attr)
            if let newValue = decision.newValue {
                _ = attr.setValue(value: newValue)
                if ownerElement != nil {
                    markDirty(for: attr.getKeyUTF8())
                }
                didMutate = true
            }
            if decision.keep {
                if writeIndex != readIndex {
                    attributes[writeIndex] = attr
                }
                writeIndex += 1
            } else {
                if ownerElement != nil {
                    markDirty(for: attr.getKeyUTF8())
                }
                didMutate = true
            }
        }

        if writeIndex < originalCount {
            attributes.removeLast(originalCount - writeIndex)
            didMutate = true
        }

        guard didMutate else { return }

        invalidateLowercasedKeysCache()
        if writeIndex < originalCount {
            invalidateKeyIndex()
        }

        if let ownerElement {
            if dirtyClass {
                ownerElement.markClassQueryIndexDirty()
            }
            if dirtyId {
                ownerElement.markIdQueryIndexDirty()
            }
            ownerElement.markAttributeQueryIndexDirty()
        }
    }

    
    /**
     Tests if these attributes contain an attribute with this key.
     - parameter key: case-sensitive key to check for
     - returns: true if key exists, false otherwise
     */
    @inline(__always)
    open func hasKey(key: String) -> Bool {
        return hasKey(key: key.utf8Array)
    }
    
    @inline(__always)
    open func hasKey(key: [UInt8]) -> Bool {
        return indexForKey(key) != nil
    }
    
    /**
     Tests if these attributes contain an attribute with this key.
     - parameter key: key to check for
     - returns: true if key exists, false otherwise
     */
    @inline(__always)
    open func hasKeyIgnoreCase(key: String) -> Bool {
        return hasKeyIgnoreCase(key: key.utf8Array)
    }
    
    @inline(__always)
    @usableFromInline
    internal static func asciiLowercase(_ byte: UInt8) -> UInt8 {
        return (byte >= 65 && byte <= 90) ? (byte + 32) : byte
    }
    
    @inlinable
    open func hasKeyIgnoreCase<T: Collection>(key: T) -> Bool where T.Element == UInt8 {
        guard !key.isEmpty else { return false }
        if lowercasedKeysCache == nil {
            updateLowercasedKeysCache()
        }
        if let key = key as? [UInt8], key.allSatisfy({ $0 < 65 || $0 > 90 }) {
            return lowercasedKeysCache!.contains(key)
        }
        var lowerQuery: [UInt8] = []
        lowerQuery.reserveCapacity(key.count)
        for b in key {
            lowerQuery.append(Self.asciiLowercase(b))
        }
        return lowercasedKeysCache!.contains(lowerQuery)
    }
    
    /**
     Get the number of attributes in this set.
     - returns: size
     */
    @inline(__always)
    open func size() -> Int {
        return attributes.count
    }
    
    /**
     Add all the attributes from the incoming set to this set.
     - parameter incoming: attributes to add to these attributes.
     */
    @inline(__always)
    open func addAll(incoming: Attributes?) {
        guard let incoming = incoming else { return }
        for attr in incoming.attributes {
            put(attribute: attr)
        }
    }
    
    /**
     Get the attributes as a List, for iteration. Do not modify the keys of the attributes via this view, as changes
     to keys will not be recognised in the containing set.
     - returns: an view of the attributes as a List.
     */
    @inline(__always)
    open func asList() -> [Attribute] {
        return attributes
    }
    
    /**
     Retrieves a filtered view of attributes that are HTML5 custom data attributes; that is, attributes with keys
     starting with `data-`.
     - returns: map of custom data attributes.
     */
    @inline(__always)
    open func dataset() -> [String: String] {
        let prefixLength = Attributes.dataPrefix.count
        let pairs = attributes.filter { $0.isDataAttribute() }
            .map { ($0.getKey().substring(prefixLength), $0.getValue()) }
        return Dictionary(uniqueKeysWithValues: pairs)
    }
    
    /**
     Get the HTML representation of these attributes.
     - returns: HTML
     */
    @inline(__always)
    open func html() throws -> String {
        let accum = StringBuilder()
        try html(accum: accum, out: Document([]).outputSettings()) // output settings a bit funky, but this html() seldom used
        return accum.toString()
    }
    
    /**
     Get the HTML representation of these attributes.
     - returns: HTML
     */
    @inline(__always)
    open func htmlUTF8() throws -> [UInt8] {
        let accum = StringBuilder()
        try html(accum: accum, out: Document([]).outputSettings()) // output settings a bit funky, but this html() seldom used
        return Array(accum.buffer)
    }
    
    @inlinable
    public func html(accum: StringBuilder, out: OutputSettings ) throws {
        for attr in attributes {
            accum.append(UTF8Arrays.whitespace)
            attr.html(accum: accum, out: out)
        }
    }
    
    @inline(__always)
    open func toString()throws -> String {
        return try html()
    }
    
    /**
     Checks if these attributes are equal to another set of attributes, by comparing the two sets
     - parameter o: attributes to compare with
     - returns: if both sets of attributes have the same content
     */
    @inline(__always)
    open func equals(o: AnyObject?) -> Bool {
        if(o == nil) {return false}
        if (self === o.self) {return true}
        guard let that = o as? Attributes else {return false}
        return (attributes == that.attributes)
    }
    
    @inline(__always)
    open func lowercaseAllKeys() {
        guard hasUppercaseKeys else { return }
        for ix in attributes.indices {
            attributes[ix].key = attributes[ix].key.lowercased()
        }
        hasUppercaseKeys = false
        invalidateLowercasedKeysCache()
        invalidateKeyIndex()
        ownerElement?.markClassQueryIndexDirty()
        ownerElement?.markIdQueryIndexDirty()
        ownerElement?.markAttributeQueryIndexDirty()
        ownerElement?.markAttributeValueQueryIndexDirty()
    }
    
    @inline(__always)
    public func copy(with zone: NSZone? = nil) -> Any {
        let clone = Attributes()
        clone.attributes = attributes
        clone.hasUppercaseKeys = hasUppercaseKeys
        clone.lowercasedKeysCache = nil
        clone.keyIndex = nil
        clone.keyIndexDirty = true
        return clone
    }
    
    @inline(__always)
    open func clone() -> Attributes {
        return self.copy() as! Attributes
    }
    
    @inline(__always)
    fileprivate static func dataKey(key: [UInt8]) -> [UInt8] {
        return dataPrefix + key
    }
    
    @inline(__always)
    fileprivate static func containsAsciiUppercase(_ key: [UInt8]) -> Bool {
        for b in key {
            if b >= 65 && b <= 90 {
                return true
            }
        }
        return false
    }
    
}

extension Attributes: Sequence {
    public func makeIterator() -> AnyIterator<Attribute> {
        return AnyIterator(attributes.makeIterator())
    }
}
