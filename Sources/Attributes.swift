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

    @usableFromInline
    internal enum PendingAttrValue {
        case none
        case empty
        case slice(ArraySlice<UInt8>)
        case slices([ArraySlice<UInt8>], Int)
        case bytes([UInt8])
    }

    @usableFromInline
    internal struct PendingAttribute {
        var nameSlice: ArraySlice<UInt8>?
        var nameBytes: [UInt8]?
        var hasUppercase: Bool
        var value: PendingAttrValue
    }

    @usableFromInline
    static let disableLowercasedKeyIndex: Bool =
        ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_LOWERCASED_KEY_INDEX"] == "1"
    
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
            ownerElement?.markSourceDirty()
            invalidateLowercasedKeysCache()
            invalidateKeyIndex()
        }
    }
    
    /// Set of lower‑cased UTF‑8 keys for fast O(1) ignore‑case look‑ups
    @usableFromInline
    internal var lowercasedKeysCache: Set<[UInt8]>? = nil

    @usableFromInline
    internal var lowercasedKeyIndex: [Array<UInt8>: Int]? = nil

    @usableFromInline
    internal var lowercasedKeyIndexDirty: Bool = true
    
    @usableFromInline
    internal var hasUppercaseKeys: Bool = false

    @usableFromInline
    internal var keyIndex: [Array<UInt8>: Int]? = nil

    @usableFromInline
    internal var keyIndexDirty: Bool = true

    @usableFromInline
    internal var pendingAttributes: [PendingAttribute]? = nil
    
    @usableFromInline
    internal var pendingAttributesCount: Int = 0
    
    // TODO: Delegate would be cleaner...
    @usableFromInline
    weak var ownerElement: SwiftSoup.Element?
    
    public init() {
        attributes.reserveCapacity(16)
    }

    @usableFromInline
    @inline(__always)
    internal func appendPending(_ pending: PendingAttribute) {
        if !attributes.isEmpty {
            // If materialized already, fall back to regular put.
            let key: [UInt8]
            if let nameBytes = pending.nameBytes {
                key = nameBytes
            } else if let nameSlice = pending.nameSlice {
                key = Array(nameSlice)
            } else {
                return
            }
            let attribute: Attribute
            switch pending.value {
            case .none:
                attribute = try! BooleanAttribute(key: key)
            case .empty:
                attribute = try! Attribute(key: key, value: [])
            case .slice(let slice):
                attribute = try! Attribute(key: key, value: Array(slice))
            case .slices(let slices, let count):
                var value: [UInt8] = []
                value.reserveCapacity(count)
                for slice in slices {
                    value.append(contentsOf: slice)
                }
                attribute = try! Attribute(key: key, value: value)
            case .bytes(let bytes):
                attribute = try! Attribute(key: key, value: bytes)
            }
            putMaterialized(attribute)
            return
        }

        if pendingAttributes == nil {
            pendingAttributes = [pending]
            pendingAttributesCount = 1
        } else {
            pendingAttributes!.append(pending)
            pendingAttributesCount &+= 1
        }
        if !hasUppercaseKeys && pending.hasUppercase {
            hasUppercaseKeys = true
        }
        invalidateLowercasedKeysCache()
        invalidateKeyIndex()
        ownerElement?.markClassQueryIndexDirty()
        ownerElement?.markIdQueryIndexDirty()
        ownerElement?.markAttributeQueryIndexDirty()
        ownerElement?.markAttributeValueQueryIndexDirty()
        ownerElement?.markSourceDirty()
    }

    @usableFromInline
    @inline(__always)
    internal func ensureMaterialized() {
        guard let pending = pendingAttributes, !pending.isEmpty else { return }
        pendingAttributes = nil
        pendingAttributesCount = 0
        attributes.reserveCapacity(attributes.count + pending.count)
        for pendingAttr in pending {
            let key: [UInt8]
            if let nameBytes = pendingAttr.nameBytes {
                key = nameBytes
            } else if let nameSlice = pendingAttr.nameSlice {
                key = Array(nameSlice)
            } else {
                continue
            }
            let attribute: Attribute
            switch pendingAttr.value {
            case .none:
                attribute = try! BooleanAttribute(key: key)
            case .empty:
                attribute = try! Attribute(key: key, value: [])
            case .slice(let slice):
                attribute = try! Attribute(key: key, value: Array(slice))
            case .slices(let slices, let count):
                var value: [UInt8] = []
                value.reserveCapacity(count)
                for slice in slices {
                    value.append(contentsOf: slice)
                }
                attribute = try! Attribute(key: key, value: value)
            case .bytes(let bytes):
                attribute = try! Attribute(key: key, value: bytes)
            }
            putMaterialized(attribute)
        }
    }

    @inline(__always)
    internal func putMaterialized(_ attribute: Attribute) {
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
    
    @usableFromInline
    @inline(__always)
    internal func updateLowercasedKeysCache() {
        ensureMaterialized()
        lowercasedKeysCache = Set(
            attributes.map { attr in
                attr.getKeyUTF8().map(Self.asciiLowercase)
            }
        )
    }

    @usableFromInline
    @inline(__always)
    internal func ensureLowercasedKeyIndex() {
        ensureMaterialized()
        guard shouldBuildKeyIndex() else { return }
        if lowercasedKeyIndexDirty || lowercasedKeyIndex == nil {
            var rebuilt: [Array<UInt8>: Int] = [:]
            rebuilt.reserveCapacity(attributes.count)
            for (index, attr) in attributes.enumerated() {
                let lowerKey = attr.getKeyUTF8().map(Self.asciiLowercase)
                if rebuilt[lowerKey] == nil {
                    rebuilt[lowerKey] = index
                }
            }
            lowercasedKeyIndex = rebuilt
            lowercasedKeyIndexDirty = false
        }
    }
    
    @usableFromInline
    @inline(__always)
    internal func invalidateLowercasedKeysCache() {
        lowercasedKeysCache = nil
        lowercasedKeyIndex = nil
        lowercasedKeyIndexDirty = true
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
        ensureMaterialized()
        return attributes.count >= 12
    }

    @usableFromInline
    @inline(__always)
    func ensureKeyIndex() {
        ensureMaterialized()
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
        ensureMaterialized()
        if !Self.disableLowercasedKeyIndex, shouldBuildKeyIndex() {
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
        if attributes.isEmpty, let pendingValue = pendingValueCaseSensitive(key) {
            return pendingValue
        }
        ensureMaterialized()
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
        if attributes.isEmpty, let pendingValue = pendingValueIgnoreCase(key) {
            return pendingValue
        }
        ensureMaterialized()
        try Validate.notEmpty(string: key)
        if !Self.disableLowercasedKeyIndex, shouldBuildKeyIndex() {
            ensureLowercasedKeyIndex()
            if let lowercasedKeyIndex {
                if key.allSatisfy({ $0 < 65 || $0 > 90 }) {
                    if let ix = lowercasedKeyIndex[key] {
                        return attributes[ix].getValueUTF8()
                    }
                    return []
                }
                var lowerQuery: [UInt8] = []
                lowerQuery.reserveCapacity(key.count)
                for b in key {
                    lowerQuery.append(Self.asciiLowercase(b))
                }
                if let ix = lowercasedKeyIndex[lowerQuery] {
                    return attributes[ix].getValueUTF8()
                }
                return []
            }
        }
        if lowercasedKeysCache == nil {
            updateLowercasedKeysCache()
        }
        if key.allSatisfy({ $0 < 65 || $0 > 90 }) {
            guard lowercasedKeysCache?.contains(key) ?? false else { return [] }
        } else {
            guard lowercasedKeysCache?.contains(key.lowercased()) ?? false else { return [] }
        }
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
        ensureMaterialized()
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
        ensureMaterialized()
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
        ensureMaterialized()
        putMaterialized(attribute)
    }
    
    /**
     Remove an attribute by key. <b>Case sensitive.</b>
     - parameter key: attribute key to remove
     */
    @inline(__always)
    open func remove(key: String) throws {
        ensureMaterialized()
        try remove(key: key.utf8Array)
    }
    
    @inlinable
    open func remove(key: [UInt8]) throws {
        ensureMaterialized()
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
        ensureMaterialized()
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
        ensureMaterialized()
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
        ensureMaterialized()
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
        if attributes.isEmpty, pendingHasKeyCaseSensitive(key) {
            return true
        }
        ensureMaterialized()
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
        if attributes.isEmpty, pendingHasKeyIgnoreCase(key) {
            return true
        }
        ensureMaterialized()
        guard !key.isEmpty else { return false }
        if shouldBuildKeyIndex() {
            ensureLowercasedKeyIndex()
            if let lowercasedKeyIndex {
                if let key = key as? [UInt8], key.allSatisfy({ $0 < 65 || $0 > 90 }) {
                    return lowercasedKeyIndex[key] != nil
                }
                var lowerQuery: [UInt8] = []
                lowerQuery.reserveCapacity(key.count)
                for b in key {
                    lowerQuery.append(Self.asciiLowercase(b))
                }
                return lowercasedKeyIndex[lowerQuery] != nil
            }
        }
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

    @inline(__always)
    @usableFromInline
    internal func pendingHasKeyCaseSensitive(_ key: [UInt8]) -> Bool {
        return pendingValueCaseSensitive(key) != nil
    }

    @inline(__always)
    @usableFromInline
    internal func pendingHasKeyIgnoreCase<T: Collection>(_ key: T) -> Bool where T.Element == UInt8 {
        return pendingValueIgnoreCase(key) != nil
    }

    @inline(__always)
    @usableFromInline
    internal func pendingValueCaseSensitive(_ key: [UInt8]) -> [UInt8]? {
        guard !key.isEmpty, attributes.isEmpty, let pending = pendingAttributes, !pending.isEmpty else {
            return nil
        }
        for pendingAttr in pending {
            if let nameBytes = pendingAttr.nameBytes {
                if nameBytes == key {
                    return materializePendingValue(pendingAttr.value)
                }
            } else if let nameSlice = pendingAttr.nameSlice {
                if equalsSlice(nameSlice, key) {
                    return materializePendingValue(pendingAttr.value)
                }
            }
        }
        return nil
    }

    @inline(__always)
    @usableFromInline
    internal func pendingValueIgnoreCase<T: Collection>(_ key: T) -> [UInt8]? where T.Element == UInt8 {
        guard !key.isEmpty, attributes.isEmpty, let pending = pendingAttributes, !pending.isEmpty else {
            return nil
        }
        for pendingAttr in pending {
            if let nameBytes = pendingAttr.nameBytes {
                if equalsIgnoreCase(nameBytes, key) {
                    return materializePendingValue(pendingAttr.value)
                }
            } else if let nameSlice = pendingAttr.nameSlice {
                if equalsIgnoreCase(nameSlice, key) {
                    return materializePendingValue(pendingAttr.value)
                }
            }
        }
        return nil
    }

    @inline(__always)
    @usableFromInline
    internal func materializePendingValue(_ value: PendingAttrValue) -> [UInt8] {
        switch value {
        case .none:
            return []
        case .empty:
            return []
        case .slice(let slice):
            return Array(slice)
        case .slices(let slices, let count):
            var bytes: [UInt8] = []
            bytes.reserveCapacity(count)
            for slice in slices {
                bytes.append(contentsOf: slice)
            }
            return bytes
        case .bytes(let bytes):
            return bytes
        }
    }

    @inline(__always)
    @usableFromInline
    internal func equalsSlice(_ slice: ArraySlice<UInt8>, _ key: [UInt8]) -> Bool {
        if slice.count != key.count {
            return false
        }
        var i = key.startIndex
        var j = slice.startIndex
        let end = key.endIndex
        while i < end {
            if key[i] != slice[j] {
                return false
            }
            i = key.index(after: i)
            j = slice.index(after: j)
        }
        return true
    }

    @inline(__always)
    @usableFromInline
    internal func equalsIgnoreCase<T: Collection>(_ bytes: [UInt8], _ key: T) -> Bool where T.Element == UInt8 {
        if bytes.count != key.count {
            return false
        }
        var i = bytes.startIndex
        for b in key {
            if Self.asciiLowercase(bytes[i]) != Self.asciiLowercase(b) {
                return false
            }
            i = bytes.index(after: i)
        }
        return true
    }

    @inline(__always)
    @usableFromInline
    internal func equalsIgnoreCase<T: Collection>(_ slice: ArraySlice<UInt8>, _ key: T) -> Bool where T.Element == UInt8 {
        if slice.count != key.count {
            return false
        }
        var i = slice.startIndex
        for b in key {
            if Self.asciiLowercase(slice[i]) != Self.asciiLowercase(b) {
                return false
            }
            i = slice.index(after: i)
        }
        return true
    }
    
    /**
     Get the number of attributes in this set.
     - returns: size
     */
    @inline(__always)
    open func size() -> Int {
        ensureMaterialized()
        return attributes.count
    }
    
    /**
     Add all the attributes from the incoming set to this set.
     - parameter incoming: attributes to add to these attributes.
     */
    @inline(__always)
    open func addAll(incoming: Attributes?) {
        ensureMaterialized()
        guard let incoming = incoming else { return }
        incoming.ensureMaterialized()
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
        ensureMaterialized()
        return attributes
    }
    
    /**
     Retrieves a filtered view of attributes that are HTML5 custom data attributes; that is, attributes with keys
     starting with `data-`.
     - returns: map of custom data attributes.
     */
    @inline(__always)
    open func dataset() -> [String: String] {
        ensureMaterialized()
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

    @usableFromInline
    @inline(__always)
    internal func appendPendingHtml(_ attr: PendingAttribute, _ accum: StringBuilder, _ out: OutputSettings) {
        let keySlice: ArraySlice<UInt8>
        if let nameSlice = attr.nameSlice {
            keySlice = nameSlice
        } else if let nameBytes = attr.nameBytes {
            keySlice = nameBytes[...]
        } else {
            return
        }
        accum.append(keySlice)

        var valueBytes: [UInt8]? = nil
        var valueSlice: ArraySlice<UInt8>? = nil
        var hasValue = false
        switch attr.value {
        case .none:
            hasValue = false
        case .empty:
            hasValue = true
            valueBytes = []
        case .slice(let slice):
            hasValue = true
            valueSlice = slice
        case .slices(let slices, let count):
            hasValue = true
            var combined: [UInt8] = []
            combined.reserveCapacity(count)
            for slice in slices {
                combined.append(contentsOf: slice)
            }
            valueBytes = combined
        case .bytes(let bytes):
            hasValue = true
            valueBytes = bytes
        }

        let keyLowerSlice: ArraySlice<UInt8>
        if attr.hasUppercase {
            var lower: [UInt8] = []
            lower.reserveCapacity(keySlice.count)
            for b in keySlice {
                let normalized = (b >= 65 && b <= 90) ? (b &+ 32) : b
                lower.append(normalized)
            }
            keyLowerSlice = lower[...]
        } else {
            keyLowerSlice = keySlice
        }
        let isImplicitBoolean = {
            switch attr.value {
            case .none: return true
            default: return false
            }
        }()
        let isBoolean = isImplicitBoolean || Attribute.booleanAttributes.contains(keyLowerSlice)

        var shouldCollapse = false
        if out.syntax() == OutputSettings.Syntax.html && isBoolean {
            if !hasValue {
                shouldCollapse = true
            } else if let valueBytes {
                shouldCollapse = valueBytes.isEmpty
            } else if let valueSlice {
                shouldCollapse = valueSlice.isEmpty
            }
        }

        if !shouldCollapse {
            accum.append(UTF8Arrays.attributeEqualsQuoteMark)
            if let valueBytes {
                Entities.escape(accum, valueBytes, out, true, false, false)
            } else if let valueSlice {
                Entities.escape(accum, valueSlice, out, true, false, false)
            }
            accum.append(UTF8Arrays.quoteMark)
        }
    }
    
    @inlinable
    public func html(accum: StringBuilder, out: OutputSettings ) throws {
        if attributes.isEmpty, let pending = pendingAttributes, !pending.isEmpty {
            for attr in pending {
                accum.append(UTF8Arrays.whitespace)
                appendPendingHtml(attr, accum, out)
            }
            return
        }
        ensureMaterialized()
        for attr in attributes {
            accum.append(UTF8Arrays.whitespace)
            attr.html(accum: accum, out: out)
        }
    }
    
    @inline(__always)
    open func toString()throws -> String {
        return try html()
    }

    @usableFromInline
    @inline(__always)
    internal static func equalsIgnoreCase(_ lhs: ArraySlice<UInt8>, _ rhs: ArraySlice<UInt8>) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var i = lhs.startIndex
        var j = rhs.startIndex
        while i < lhs.endIndex {
            let b1 = lhs[i]
            let b2 = rhs[j]
            let lower1 = (b1 >= 65 && b1 <= 90) ? (b1 &+ 32) : b1
            let lower2 = (b2 >= 65 && b2 <= 90) ? (b2 &+ 32) : b2
            if lower1 != lower2 { return false }
            i = lhs.index(after: i)
            j = rhs.index(after: j)
        }
        return true
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
        ensureMaterialized()
        that.ensureMaterialized()
        return (attributes == that.attributes)
    }
    
    @inline(__always)
    open func lowercaseAllKeys() {
        ensureMaterialized()
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
        ownerElement?.markSourceDirty()
    }
    
    @inline(__always)
    public func copy(with zone: NSZone? = nil) -> Any {
        ensureMaterialized()
        let clone = Attributes()
        clone.attributes = attributes
        clone.hasUppercaseKeys = hasUppercaseKeys
        clone.lowercasedKeysCache = nil
        clone.lowercasedKeyIndex = nil
        clone.lowercasedKeyIndexDirty = true
        clone.keyIndex = nil
        clone.keyIndexDirty = true
        return clone
    }
    
    @inline(__always)
    open func clone() -> Attributes {
        ensureMaterialized()
        return self.copy() as! Attributes
    }
    
    @inline(__always)
    fileprivate static func dataKey(key: [UInt8]) -> [UInt8] {
        return dataPrefix + key
    }
    
    @inline(__always)
    internal static func containsAsciiUppercase(_ key: [UInt8]) -> Bool {
        for b in key {
            if b >= 65 && b <= 90 {
                return true
            }
        }
        return false
    }

    @inline(__always)
    internal static func containsAsciiUppercase(_ key: ArraySlice<UInt8>) -> Bool {
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
        ensureMaterialized()
        return AnyIterator(attributes.makeIterator())
    }
}
