//
//  Attribute.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class Attribute {
    /// The element type of a dictionary: a tuple containing an individual
    /// key-value pair.

    static let booleanAttributes = ParsingStrings([
        "allowfullscreen", "async", "autofocus", "checked", "compact", "controls", "declare", "default", "defer",
        "disabled", "formnovalidate", "hidden", "inert", "ismap", "itemscope", "multiple", "muted", "nohref",
        "noresize", "noshade", "novalidate", "nowrap", "open", "readonly", "required", "reversed", "seamless",
        "selected", "sortable", "truespeed", "typemustmatch"
    ])

    var key: [UInt8]
    var value: [UInt8]

    public init(key: [UInt8], value: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        self.key = key.trim()
        self.value = value
    }
    
    public convenience init(key: String, value: String) throws {
        try self.init(key: key.utf8Array, value: value.utf8Array)
    }

    /**
     Get the attribute key.
     @return the attribute key
     */
    open func getKey() -> String {
        return String(decoding: getKeyUTF8(), as: UTF8.self)
    }
    
    open func getKeyUTF8() -> [UInt8] {
        return key
    }

    /**
     Set the attribute key; case is preserved.
     @param key the new key; must not be null
     */
    open func setKey(key: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        self.key = key.trim()
    }
    
    open func setKey(key: String) throws {
        try setKey(key: key.utf8Array)
    }

    /**
     Get the attribute value.
     @return the attribute value
     */
    open func getValue() -> String {
        return String(decoding: getValueUTF8(), as: UTF8.self)
    }
    
    open func getValueUTF8() -> [UInt8] {
        return value
    }

    /**
     Set the attribute value.
     @param value the new attribute value; must not be null
     */
    @discardableResult
    open func setValue(value: [UInt8]) -> [UInt8] {
        let old = self.value
        self.value = value
        return old
    }

    /**
     Get the HTML representation of this attribute; e.g. {@code href="index.html"}.
     @return HTML
     */
    public func html() -> String {
        let accum = StringBuilder()
		html(accum: accum, out: (Document("")).outputSettings())
        return accum.toString()
    }

    public func html(accum: StringBuilder, out: OutputSettings ) {
        accum.append(key)
        if (!shouldCollapseAttribute(out: out)) {
            accum.append(UTF8Arrays.attributeEqualsQuoteMark)
            Entities.escape(accum, Array(value), out, true, false, false)
            accum.append(UTF8Arrays.quoteMark)
        }
    }

    /**
     Get the string representation of this attribute, implemented as {@link #html()}.
     @return string
     */
    open func toString() -> String {
        return html()
    }

    /**
     * Create a new Attribute from an unencoded key and a HTML attribute encoded value.
     * @param unencodedKey assumes the key is not encoded, as can be only run of simple \w chars.
     * @param encodedValue HTML attribute encoded value
     * @return attribute
     */
    public static func createFromEncoded(unencodedKey: [UInt8], encodedValue: [UInt8]) throws -> Attribute {
        let value = try Entities.unescape(string: encodedValue, strict: true)
        return try Attribute(key: unencodedKey, value: value)
    }

    public func isDataAttribute() -> Bool {
        return key.starts(with: Attributes.dataPrefix) && key.count > Attributes.dataPrefix.count
    }

    /**
     * Collapsible if it's a boolean attribute and value is empty or same as name
     *
     * @param out Outputsettings
     * @return  Returns whether collapsible or not
     */
    public final func shouldCollapseAttribute(out: OutputSettings) -> Bool {
        return (value.isEmpty || value.equalsIgnoreCase(string: key))
            && out.syntax() == OutputSettings.Syntax.html
            && isBooleanAttribute()
    }

    public func isBooleanAttribute() -> Bool {
        return Attribute.booleanAttributes.contains(key.lowercased()[...])
    }

    public func hashCode() -> Int {
        var result = key.hashValue
        result = 31 * result + value.hashValue
        return result
    }

    public func clone() -> Attribute {
        do {
            return try Attribute(key: key, value: value)
        } catch Exception.Error( _, let  msg) {
            print(msg)
        } catch {

        }
        return try! Attribute(key: [], value: [])
    }
}

extension Attribute: Equatable {
	static public func == (lhs: Attribute, rhs: Attribute) -> Bool {
		return lhs.value == rhs.value && lhs.key == rhs.key
	}

}
