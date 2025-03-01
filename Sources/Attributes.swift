//
//  Attributes.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * The attributes of an Element.
 * <p>
 * Attributes are treated as a map: there can be only one value associated with an attribute key/name.
 * </p>
 * <p>
 * Attribute name and value comparisons are  <b>case sensitive</b>. By default for HTML, attribute names are
 * normalized to lower-case on parsing. That means you should use lower-case strings when referring to attributes by
 * name.
 * </p>
 *
 * 
 */
open class Attributes: NSCopying {

    public static var dataPrefix: [UInt8] = "data-".utf8Array

    // Stored by lowercased key, but key case is checked against the copy inside
    // the Attribute on retrieval.
    @usableFromInline
    lazy var attributes: [Attribute] = []
    internal var lowercasedKeysCache: [[UInt8]]? = nil

	public init() {}
    
    @usableFromInline
    internal func updateLowercasedKeysCache() {
        lowercasedKeysCache = attributes.map { $0.getKeyUTF8().map { Self.asciiLowercase($0) } }
    }
    
    @usableFromInline
    internal func invalidateLowercasedKeysCache() {
        lowercasedKeysCache = nil
    }
    
    /**
     Get an attribute value by key.
     @param key the (case-sensitive) attribute key
     @return the attribute value if set; or empty string if not set.
     @see #hasKey(String)
     */
    open func get(key: String) -> String {
        return String(decoding: get(key: key.utf8Array), as: UTF8.self)
    }
    
    open func get(key: [UInt8]) -> [UInt8] {
        if let attr = attributes.first(where: { $0.getKeyUTF8() == key }) {
            return attr.getValueUTF8()
        }
        return []
    }

    /**
     * Get an attribute's value by case-insensitive key
     * @param key the attribute name
     * @return the first matching attribute value if set; or empty string if not set.
     */
    open func getIgnoreCase(key: String) throws -> String {
        return try String(decoding: getIgnoreCase(key: key.utf8Array), as: UTF8.self)
    }
    
    open func getIgnoreCase(key: [UInt8]) throws -> [UInt8] {
        try Validate.notEmpty(string: key)
        if let attr = attributes.first(where: { $0.getKeyUTF8().caseInsensitiveCompare(key) == .orderedSame }) {
            return attr.getValueUTF8()
        }
        return []
    }

    /**
     Set a new attribute, or replace an existing one by key.
     @param key attribute key
     @param value attribute value
     */
    open func put(_ key: [UInt8], _ value: [UInt8]) throws {
        let attr = try Attribute(key: key, value: value)
        put(attribute: attr)
    }
    
    open func put(_ key: String, _ value: String) throws {
        return try put(key.utf8Array, value.utf8Array)
    }

    /**
     Set a new boolean attribute, remove attribute if value is false.
     @param key attribute key
     @param value attribute value
     */
    open func put(_ key: [UInt8], _ value: Bool) throws {
        if (value) {
            try put(attribute: BooleanAttribute(key: key))
        } else {
            try remove(key: key)
        }
    }

    /**
     Set a new attribute, or replace an existing one by (case-sensitive) key.
     @param attribute attribute
     */
    open func put(attribute: Attribute) {
        let key = attribute.getKeyUTF8()
        if let ix = attributes.firstIndex(where: { $0.getKeyUTF8() == key }) {
            attributes[ix] = attribute
        } else {
            attributes.append(attribute)
        }
        invalidateLowercasedKeysCache()
    }
    
    /**
     Remove an attribute by key. <b>Case sensitive.</b>
     @param key attribute key to remove
     */
    open func remove(key: String) throws {
        try remove(key: key.utf8Array)
    }
    
    open func remove(key: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        if let ix = attributes.firstIndex(where: { $0.getKeyUTF8() == key }) {
            attributes.remove(at: ix)
            invalidateLowercasedKeysCache()
        }
    }

    /**
     Remove an attribute by key. <b>Case insensitive.</b>
     @param key attribute key to remove
     */
    open func removeIgnoreCase(key: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        if let ix = attributes.firstIndex(where: { $0.getKeyUTF8().caseInsensitiveCompare(key) == .orderedSame}) {
            attributes.remove(at: ix)
            invalidateLowercasedKeysCache()
        }
    }

    /**
     Tests if these attributes contain an attribute with this key.
     @param key case-sensitive key to check for
     @return true if key exists, false otherwise
     */
    open func hasKey(key: String) -> Bool {
        return hasKey(key: key.utf8Array)
    }
    
    open func hasKey(key: [UInt8]) -> Bool {
        return attributes.contains(where: { $0.getKeyUTF8() == key })
    }

    /**
     Tests if these attributes contain an attribute with this key.
     @param key key to check for
     @return true if key exists, false otherwise
     */
    @inlinable
    open func hasKeyIgnoreCase(key: String) -> Bool {
        return hasKeyIgnoreCase(key: key.utf8Array)
    }
    
    @inline(__always)
    internal static func asciiLowercase(_ byte: UInt8) -> UInt8 {
        return (byte >= 65 && byte <= 90) ? (byte + 32) : byte
    }
    
    open func hasKeyIgnoreCase<T: Collection>(key: T) -> Bool where T.Element == UInt8 {
        try? Validate.notEmpty(string: Array(key))
        if lowercasedKeysCache == nil {
            updateLowercasedKeysCache()
        }
        let lowerQuery = key.lazy.map { Self.asciiLowercase($0) }
        return lowercasedKeysCache!.contains { $0.elementsEqual(lowerQuery) }
    }
    
    /**
     Get the number of attributes in this set.
     @return size
     */
    open func size() -> Int {
        return attributes.count
    }

    /**
     Add all the attributes from the incoming set to this set.
     @param incoming attributes to add to these attributes.
     */
    open func addAll(incoming: Attributes?) {
        guard let incoming = incoming else { return }
        for attr in incoming.attributes {
            put(attribute: attr)
        }
    }

    /**
     Get the attributes as a List, for iteration. Do not modify the keys of the attributes via this view, as changes
     to keys will not be recognised in the containing set.
     @return an view of the attributes as a List.
     */
    open func asList() -> [Attribute] {
        return attributes
    }

    /**
     * Retrieves a filtered view of attributes that are HTML5 custom data attributes; that is, attributes with keys
     * starting with {@code data-}.
     * @return map of custom data attributes.
     */
    open func dataset() -> [String: String] {
        let prefixLength = Attributes.dataPrefix.count
        let pairs = attributes.filter { $0.isDataAttribute() }
            .map { ($0.getKey().substring(prefixLength), $0.getValue()) }
        return Dictionary(uniqueKeysWithValues: pairs)
    }

    /**
     Get the HTML representation of these attributes.
     @return HTML
     @throws SerializationException if the HTML representation of the attributes cannot be constructed.
     */
    open func html()throws -> String {
        let accum = StringBuilder()
        try html(accum: accum, out: Document([]).outputSettings()) // output settings a bit funky, but this html() seldom used
        return accum.toString()
    }

    @inlinable
    public func html(accum: StringBuilder, out: OutputSettings ) throws {
        for attr in attributes {
            accum.append(UTF8Arrays.whitespace)
            attr.html(accum: accum, out: out)
        }
    }

    open func toString()throws -> String {
        return try html()
    }

    /**
     * Checks if these attributes are equal to another set of attributes, by comparing the two sets
     * @param o attributes to compare with
     * @return if both sets of attributes have the same content
     */
    open func equals(o: AnyObject?) -> Bool {
        if(o == nil) {return false}
        if (self === o.self) {return true}
        guard let that = o as? Attributes else {return false}
		return (attributes == that.attributes)
    }
    
    open func lowercaseAllKeys() {
        for ix in attributes.indices {
            attributes[ix].key = attributes[ix].key.lowercased()
        }
    }

    public func copy(with zone: NSZone? = nil) -> Any {
        let clone = Attributes()
        clone.attributes = attributes
        return clone
    }

    open func clone() -> Attributes {
        return self.copy() as! Attributes
    }

    fileprivate static func dataKey(key: [UInt8]) -> [UInt8] {
        return dataPrefix + key
    }

}

extension Attributes: Sequence {
    public func makeIterator() -> AnyIterator<Attribute> {
        return AnyIterator(attributes.makeIterator())
    }
}
