//
//  Token.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 18/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class Token {
    var type: TokenType = TokenType.Doctype
    
    private init() {
    }
    
    func tokenType() -> String {
        return String(describing: Swift.type(of: self))
    }
    
    /**
     * Reset the data represent by this token, for reuse. Prevents the need to create transfer objects for every
     * piece of data, which immediately get GCed.
     */
    @discardableResult
    public func reset() -> Token {
        preconditionFailure("This method must be overridden")
    }
    
    @inlinable
    static func reset(_ sb: StringBuilder) {
        sb.clear()
    }
    
    open func toString() throws -> String {
        return String(describing: Swift.type(of: self))
    }
    
    final class Doctype: Token {
        let name: StringBuilder = StringBuilder()
        var pubSysKey: [UInt8]?
        let publicIdentifier: StringBuilder = StringBuilder()
        let systemIdentifier: StringBuilder = StringBuilder()
        var forceQuirks: Bool  = false
        
        override init() {
            super.init()
            type = TokenType.Doctype
        }
        
        @discardableResult
        override func reset() -> Token {
            Token.reset(name)
            pubSysKey = nil
            Token.reset(publicIdentifier)
            Token.reset(systemIdentifier)
            forceQuirks = false
            return self
        }
        
        func getName() -> [UInt8] {
            return name.buffer
        }
        
        func getPubSysKey() -> [UInt8]? {
            return pubSysKey
        }
        
        func getPublicIdentifier() -> [UInt8] {
            return publicIdentifier.buffer
        }
        
        public func getSystemIdentifier() -> [UInt8] {
            return systemIdentifier.buffer
        }
        
        public func isForceQuirks() -> Bool {
            return forceQuirks
        }
    }
    
    class Tag: Token {
        public var _tagName: [UInt8]?
        public var _normalName: [UInt8]? // lc version of tag name, for case insensitive tree build
        private var _pendingAttributeName: [UInt8]? // attribute names are generally caught in one hop, not accumulated
        private let _pendingAttributeValue: StringBuilder = StringBuilder() // but values are accumulated, from e.g. & in hrefs
        private var _pendingAttributeValueS: ArraySlice<UInt8>? // try to get attr vals in one shot, vs Builder
        private var _hasEmptyAttributeValue: Bool = false // distinguish boolean attribute from empty string value
        private var _hasPendingAttributeValue: Bool = false
        public var _selfClosing: Bool = false
        // start tags get attributes on construction. End tags get attributes on first new attribute (but only for parser convenience, not used).
        public var _attributes: Attributes?
        
        override init() {
            super.init()
        }
        
        @discardableResult
        @inlinable
        override func reset() -> Tag {
            _tagName = nil
            _normalName = nil
            _pendingAttributeName = nil
            Token.reset(_pendingAttributeValue)
            _pendingAttributeValueS = nil
            _hasEmptyAttributeValue = false
            _hasPendingAttributeValue = false
            _selfClosing = false
            _attributes = nil
            return self
        }
        
        func newAttribute() throws {
            if let pendingAttr = _pendingAttributeName, !pendingAttr.isEmpty {
                var attribute: Attribute
                if _hasPendingAttributeValue {
                    attribute = try Attribute(
                        key: pendingAttr,
                        value: !_pendingAttributeValue.isEmpty ? _pendingAttributeValue.buffer : Array(_pendingAttributeValueS!)
                    )
                } else if _hasEmptyAttributeValue {
                    attribute = try Attribute(key: pendingAttr, value: [])
                } else {
                    attribute = try BooleanAttribute(key: pendingAttr)
                }
                if _attributes == nil {
                    _attributes = Attributes()
                }
                _attributes?.put(attribute: attribute)
            }
            _pendingAttributeName?.removeAll(keepingCapacity: true)
            _hasEmptyAttributeValue = false
            _hasPendingAttributeValue = false
            Token.reset(_pendingAttributeValue)
            _pendingAttributeValueS = nil
        }
        
        @inlinable
        func finaliseTag() throws {
            // finalises for emit
            if (_pendingAttributeName != nil) {
                // todo: check if attribute name exists; if so, drop and error
                try newAttribute()
            }
        }
        
        @inlinable
        func name() throws -> [UInt8] { // preserves case, for input into Tag.valueOf (which may drop case)
            try Validate.isFalse(val: _tagName == nil || _tagName!.isEmpty)
            return _tagName!
        }
        
        @inline(__always)
        func normalName() -> [UInt8]? { // loses case, used in tree building for working out where in tree it should go
            return _normalName
        }
        
        @discardableResult
        func name(_ name: [UInt8]) -> Tag {
            _tagName = name
            _normalName = name.lowercased()
            return self
        }
        
        @inline(__always)
        func isSelfClosing() -> Bool {
            return _selfClosing
        }
        
        @inline(__always)
        func getAttributes() -> Attributes {
            if _attributes == nil {
                _attributes = Attributes()
            }
            return _attributes!
        }
        
        // these appenders are rarely hit in not null state-- caused by null chars.
        @inlinable
        func appendTagName(_ append: [UInt8]) {
            appendTagName(append[...])
        }
        
        // these appenders are rarely hit in not null state-- caused by null chars.
        @inlinable
        func appendTagName(_ append: ArraySlice<UInt8>) {
            _tagName = _tagName == nil ? Array(append) : (_tagName! + Array(append))
            _normalName = _tagName?.lowercased()
        }
        
        @inlinable
        func appendTagName(_ append: UnicodeScalar) {
            appendTagName(ArraySlice(append.utf8))
        }
        
        func appendAttributeName(_ append: [UInt8]) {
            appendAttributeName(append[...])
        }
        
        func appendAttributeName(_ append: ArraySlice<UInt8>) {
            _pendingAttributeName = _pendingAttributeName == nil ? Array(append) : ((_pendingAttributeName ?? []) + Array(append))
        }
        
        func appendAttributeName(_ append: UnicodeScalar) {
            appendAttributeName(Array(append.utf8))
        }
        
        func appendAttributeValue(_ append: ArraySlice<UInt8>) {
            ensureAttributeValue()
            if _pendingAttributeValue.isEmpty {
                _pendingAttributeValueS = append
            } else {
                _pendingAttributeValue.append(append)
            }
        }
        
        func appendAttributeValue(_ append: UnicodeScalar) {
            ensureAttributeValue()
            _pendingAttributeValue.appendCodePoint(append)
        }
        
        func appendAttributeValue(_ append: [UnicodeScalar]) {
            ensureAttributeValue()
            _pendingAttributeValue.appendCodePoints(append)
        }
        
        func appendAttributeValue(_ appendCodepoints: [Int]) {
            ensureAttributeValue()
            for codepoint in appendCodepoints {
                _pendingAttributeValue.appendCodePoint(UnicodeScalar(codepoint)!)
            }
        }
        
        func setEmptyAttributeValue() {
            _hasEmptyAttributeValue = true
        }
        
        private func ensureAttributeValue() {
            _hasPendingAttributeValue = true
            // if on second hit, we'll need to move to the builder
            if (_pendingAttributeValueS != nil) {
                _pendingAttributeValue.append(_pendingAttributeValueS!)
                _pendingAttributeValueS = nil
            }
        }
    }
    
    final class StartTag: Tag {
        override init() {
            super.init()
            type = TokenType.StartTag
        }
        
        @discardableResult
        @inlinable
        override func reset() -> Tag {
            super.reset()
            return self
        }
        
        @discardableResult
        func nameAttr(_ name: [UInt8], _ attributes: Attributes) -> StartTag {
            self._tagName = name
            self._attributes = attributes
            _normalName = _tagName?.lowercased()
            return self
        }
        
        public override func toString() throws -> String {
            if let _attributes, !_attributes.attributes.isEmpty {
                return "<" + String(decoding: try name(), as: UTF8.self) + " " + (try _attributes.toString()) + ">"
            } else {
                return "<" + String(decoding: try name(), as: UTF8.self) + ">"
            }
        }
    }
    
    final class EndTag: Tag {
        override init() {
            super.init()
            type = TokenType.EndTag
        }
        
        public override func toString() throws -> String {
            return "</" + String(decoding: try name(), as: UTF8.self) + ">"
        }
    }
    
    final class Comment: Token {
        let data: StringBuilder = StringBuilder()
        var bogus: Bool = false
        
        @discardableResult
        override func reset() -> Token {
            Token.reset(data)
            bogus = false
            return self
        }
        
        override init() {
            super.init()
            type = TokenType.Comment
        }
        
        func getData() -> [UInt8] {
            return data.buffer
        }
        
        public override func toString() throws -> String {
            return "<!--" + String(decoding: getData(), as: UTF8.self) + "-->"
        }
    }
    
    final class Char: Token {
        public var data: [UInt8]?
        
        override init() {
            super.init()
            type = TokenType.Char
        }
        
        @discardableResult
        override func reset() -> Token {
            data = nil
            return self
        }
        
        @discardableResult
        func data(_ data: [UInt8]) -> Char {
            self.data = data
            return self
        }
        
        func getData() -> [UInt8]? {
            return data
        }
        
        public override func toString() throws -> String {
            try Validate.notNull(obj: data)
            return String(decoding: getData()!, as: UTF8.self) ?? ""
        }
    }
    
    final class EOF: Token {
        override init() {
            super.init()
            type = Token.TokenType.EOF
        }
        
        @discardableResult
        override func reset() -> Token {
            return self
        }
    }
    
    func isDoctype() -> Bool {
        return type == TokenType.Doctype
    }
    
    func asDoctype() -> Doctype {
        return self as! Doctype
    }
    
    func isStartTag() -> Bool {
        return type == TokenType.StartTag
    }
    
    func asStartTag() -> StartTag {
        return self as! StartTag
    }
    
    func isEndTag() -> Bool {
        return type == TokenType.EndTag
    }
    
    func asEndTag() -> EndTag {
        return self as! EndTag
    }
    
    func isComment() -> Bool {
        return type == TokenType.Comment
    }
    
    func asComment() -> Comment {
        return self as! Comment
    }
    
    func isCharacter() -> Bool {
        return type == TokenType.Char
    }
    
    func asCharacter() -> Char {
        return self as! Char
    }
    
    func isEOF() -> Bool {
        return type == TokenType.EOF
    }
    
    public enum TokenType {
        case Doctype
        case StartTag
        case EndTag
        case Comment
        case Char
        case EOF
    }
}

extension Token: CustomDebugStringConvertible {
    public var debugDescription: String {
        do {
            return try self.toString()
        } catch {
            return "Error while get string debug"
        }
    }
}
