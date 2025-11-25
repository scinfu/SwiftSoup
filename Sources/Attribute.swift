//
//  Attribute.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
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
    
    @usableFromInline
    var key: [UInt8]
    @usableFromInline
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
     - returns: the attribute key
     */
    @inline(__always)
    open func getKey() -> String {
        return String(decoding: getKeyUTF8(), as: UTF8.self)
    }
    
    @inline(__always)
    open func getKeyUTF8() -> [UInt8] {
        return key
    }
    
    /**
     Set the attribute key; case is preserved.
     - parameter key: the new key
     */
    @inline(__always)
    open func setKey(key: [UInt8]) throws {
        try Validate.notEmpty(string: key)
        self.key = key.trim()
    }
    
    @inline(__always)
    open func setKey(key: String) throws {
        try setKey(key: key.utf8Array)
    }
    
    /**
     Get the attribute value.
     - returns: the attribute value
     */
    @inline(__always)
    open func getValue() -> String {
        return String(decoding: getValueUTF8(), as: UTF8.self)
    }
    
    @inline(__always)
    open func getValueUTF8() -> [UInt8] {
        return value
    }
    
    /**
     Set the attribute value.
     - parameter value: the new attribute value
     */
    @discardableResult
    @inline(__always)
    open func setValue(value: [UInt8]) -> [UInt8] {
        let old = self.value
        self.value = value
        return old
    }
    
    /**
     Get the HTML representation of this attribute; e.g. `href="index.html"`.
     - returns: HTML
     */
    @inline(__always)
    public func html() -> String {
        let accum = StringBuilder()
        html(accum: accum, out: (Document([])).outputSettings())
        return accum.toString()
    }
    
    @inline(__always)
    public func html(accum: StringBuilder, out: OutputSettings) {
        accum.append(key)
        if (!shouldCollapseAttribute(out: out)) {
            accum.append(UTF8Arrays.attributeEqualsQuoteMark)
            Entities.escape(accum, value, out, true, false, false)
            accum.append(UTF8Arrays.quoteMark)
        }
    }
    
    /**
     Get the string representation of this attribute, implemented as ``html()``.
     - returns: string
     */
    @inline(__always)
    open func toString() -> String {
        return html()
    }
    
    /**
     Create a new Attribute from an unencoded key and a HTML attribute encoded value.
     - parameter unencodedKey: assumes the key is not encoded, as can be only run of simple `\w` chars.
     - parameter encodedValue: HTML attribute encoded value
     - returns: attribute
     */
    @inline(__always)
    public static func createFromEncoded(unencodedKey: [UInt8], encodedValue: [UInt8]) throws -> Attribute {
        let value = try Entities.unescape(string: encodedValue, strict: true)
        return try Attribute(key: unencodedKey, value: value)
    }
    
    @inline(__always)
    public func isDataAttribute() -> Bool {
        return key.starts(with: Attributes.dataPrefix) && key.count > Attributes.dataPrefix.count
    }
    
    /**
     Collapsible if it's a boolean attribute and value is empty or same as name
     
     - parameter out: Outputsettings
     - returns:  Returns whether collapsible or not
     */
    @inline(__always)
    public final func shouldCollapseAttribute(out: OutputSettings) -> Bool {
        return (value.isEmpty || value.equalsIgnoreCase(string: key))
        && out.syntax() == OutputSettings.Syntax.html
        && isBooleanAttribute()
    }
    
    @inline(__always)
    public func isBooleanAttribute() -> Bool {
        return Attribute.booleanAttributes.contains(key.lowercased()[...])
    }
    
    @inline(__always)
    public func hashCode() -> Int {
        var result = key.hashValue
        result = 31 * result + value.hashValue
        return result
    }
    
    @inline(__always)
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
    @inline(__always)
    static public func == (lhs: Attribute, rhs: Attribute) -> Bool {
        return lhs.value == rhs.value && lhs.key == rhs.key
    }
    
}


extension Attribute: CustomStringConvertible {
    @inline(__always)
    public var description: String {
        return "\(getKey())=\"\(getValue())\""
    }
}

extension Attribute: CustomDebugStringConvertible {
    private static let space = " "
    public var debugDescription: String {
        return "<\(String(describing: type(of: self))): \(Unmanaged.passUnretained(self).toOpaque()) \(self.description)>"
    }
}
