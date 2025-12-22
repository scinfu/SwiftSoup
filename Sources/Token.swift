//
//  Token.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 18/10/16.
//

import Foundation

open class Token {
    var type: TokenType = TokenType.Doctype
    
    private init() {
    }
    
    @inline(__always)
    func tokenType() -> String {
        return String(describing: Swift.type(of: self))
    }
    
    /**
     * Reset the data represent by this token, for reuse. Prevents the need to create transfer objects for every
     * piece of data, which immediately get GCed.
     */
    @discardableResult
    @inline(__always)
    public func reset() -> Token {
        preconditionFailure("This method must be overridden")
    }
    
    @inline(__always)
    static func reset(_ sb: StringBuilder) {
        sb.clear()
    }
    
    @inline(__always)
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
        
        @inline(__always)
        func getName() -> [UInt8] {
            return Array(name.buffer)
        }
        
        @inline(__always)
        func getPubSysKey() -> [UInt8]? {
            return pubSysKey
        }
        
        @inline(__always)
        func getPublicIdentifier() -> [UInt8] {
            return Array(publicIdentifier.buffer)
        }
        
        @inline(__always)
        public func getSystemIdentifier() -> [UInt8] {
            return Array(systemIdentifier.buffer)
        }
        
        @inline(__always)
        public func isForceQuirks() -> Bool {
            return forceQuirks
        }
    }
    
    class Tag: Token {
        public var _tagName: [UInt8]?
        private var _tagNameS: ArraySlice<UInt8>?
        public var _normalName: [UInt8]? // lc version of tag name, for case insensitive tree build
        private var _pendingAttributeName: [UInt8]? // attribute names are generally caught in one hop, not accumulated
        private var _pendingAttributeNameS: ArraySlice<UInt8>? // fast path to avoid copying name slices
        private let _pendingAttributeValue: StringBuilder = StringBuilder() // but values are accumulated, from e.g. & in hrefs
        private var _pendingAttributeValueS: ArraySlice<UInt8>? // try to get attr vals in one shot, vs Builder
        private var _pendingAttributeValueSlices: [ArraySlice<UInt8>]? // multiple slices before materializing
        private var _pendingAttributeValueSlicesCount: Int = 0
        private var _hasEmptyAttributeValue: Bool = false // distinguish boolean attribute from empty string value
        private var _hasPendingAttributeValue: Bool = false
        fileprivate var _pendingAttributes: [PendingAttribute]? // lazily materialized into Attributes
        public var _selfClosing: Bool = false
        // start tags get attributes on construction. End tags get attributes on first new attribute (but only for parser convenience, not used).
        public var _attributes: Attributes?

        fileprivate enum PendingAttrValue {
            case none
            case empty
            case slice(ArraySlice<UInt8>)
            case slices([ArraySlice<UInt8>], Int)
            case bytes([UInt8])
        }

        fileprivate struct PendingAttribute {
            var nameSlice: ArraySlice<UInt8>?
            var nameBytes: [UInt8]?
            var value: PendingAttrValue
        }

        override init() {
            super.init()
        }
        
        @discardableResult
        @inline(__always)
        override func reset() -> Tag {
            if _tagName != nil {
                _tagName!.removeAll(keepingCapacity: true)
            } else {
                _tagName = nil
            }
            _tagNameS = nil
            _normalName = nil
            _pendingAttributeName = nil
            _pendingAttributeNameS = nil
            Token.reset(_pendingAttributeValue)
            _pendingAttributeValueS = nil
            _pendingAttributeValueSlices = nil
            _pendingAttributeValueSlicesCount = 0
            _hasEmptyAttributeValue = false
            _hasPendingAttributeValue = false
            _pendingAttributes = nil
            _selfClosing = false
            _attributes = nil
            return self
        }
        
        func newAttribute() throws {
            let pendingNameSlice = _pendingAttributeNameS
            let pendingNameBytes = _pendingAttributeName
            let hasNameSlice = pendingNameSlice != nil && !(pendingNameSlice?.isEmpty ?? true)
            let hasNameBytes = pendingNameBytes != nil && !(pendingNameBytes?.isEmpty ?? true)
            if hasNameSlice || hasNameBytes {
                let value: PendingAttrValue
                if _hasPendingAttributeValue {
                    if !_pendingAttributeValue.isEmpty {
                        value = .bytes(Array(_pendingAttributeValue.buffer))
                    } else if let slices = _pendingAttributeValueSlices {
                        value = .slices(slices, _pendingAttributeValueSlicesCount)
                    } else if let pendingSlice = _pendingAttributeValueS {
                        value = .slice(pendingSlice)
                    } else {
                        value = .bytes([])
                    }
                } else if _hasEmptyAttributeValue {
                    value = .empty
                } else {
                    value = .none
                }
                let pending = PendingAttribute(
                    nameSlice: hasNameSlice ? pendingNameSlice : nil,
                    nameBytes: hasNameBytes ? pendingNameBytes : nil,
                    value: value
                )
                if _pendingAttributes == nil {
                    _pendingAttributes = [pending]
                } else {
                    _pendingAttributes!.append(pending)
                }
            }
            _pendingAttributeName = nil
            _pendingAttributeNameS = nil
            _hasEmptyAttributeValue = false
            _hasPendingAttributeValue = false
            Token.reset(_pendingAttributeValue)
            _pendingAttributeValueS = nil
            _pendingAttributeValueSlices = nil
            _pendingAttributeValueSlicesCount = 0
        }
        
        @inline(__always)
        func finaliseTag() throws {
            // finalises for emit
            if (_pendingAttributeName != nil || _pendingAttributeNameS != nil) {
                // todo: check if attribute name exists; if so, drop and error
                try newAttribute()
            }
        }
        
        @inline(__always)
        func name() throws -> [UInt8] { // preserves case, for input into Tag.valueOf (which may drop case)
            if _tagName == nil, let tagNameSlice = _tagNameS, !tagNameSlice.isEmpty {
                _tagName = Array(tagNameSlice)
                _tagNameS = nil
            }
            try Validate.isFalse(val: (_tagName == nil || _tagName!.isEmpty) && (_tagNameS == nil || _tagNameS!.isEmpty))
            return _tagName!
        }
        
        @inline(__always)
        func normalName() -> [UInt8]? { // loses case, used in tree building for working out where in tree it should go
            if _normalName == nil {
                if let name = _tagName, !name.isEmpty {
                    _normalName = name.lowercased()
                } else if let nameSlice = _tagNameS, !nameSlice.isEmpty {
                    _normalName = Array(nameSlice.lowercased())
                }
            }
            return _normalName
        }

        @inline(__always)
        func tagNameSlice() -> ArraySlice<UInt8>? {
            if let name = _tagName {
                return name[...]
            }
            return _tagNameS
        }

        @inline(__always)
        func normalNameEquals(_ lower: [UInt8]) -> Bool {
            return normalNameEquals(lower[...])
        }

        @inline(__always)
        func normalNameEquals(_ lower: ArraySlice<UInt8>) -> Bool {
            if let name = _tagName, !name.isEmpty {
                return Token.Tag.equalsLowercased(name[...], lower)
            }
            if let nameSlice = _tagNameS, !nameSlice.isEmpty {
                return Token.Tag.equalsLowercased(nameSlice, lower)
            }
            return false
        }
        
        @discardableResult
        func name(_ name: [UInt8]) -> Tag {
            _tagName = name
            _tagNameS = nil
            _normalName = nil
            return self
        }
        
        @inline(__always)
        func isSelfClosing() -> Bool {
            return _selfClosing
        }
        
        @inline(__always)
        func getAttributes() -> Attributes {
            ensureAttributes()
            if _attributes == nil {
                _attributes = Attributes()
            }
            return _attributes!
        }

        @inline(__always)
        func ensureAttributes() {
            guard let pendingAttributes = _pendingAttributes, !pendingAttributes.isEmpty else { return }
            if _attributes == nil {
                _attributes = Attributes()
            }
            for pending in pendingAttributes {
                let key: [UInt8]
                if let nameBytes = pending.nameBytes {
                    key = nameBytes
                } else if let nameSlice = pending.nameSlice {
                    key = Array(nameSlice)
                } else {
                    continue
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
                _attributes?.put(attribute: attribute)
            }
            _pendingAttributes = nil
        }
        
        // these appenders are rarely hit in not null state-- caused by null chars.
        @inline(__always)
        func appendTagName(_ append: [UInt8]) {
            appendTagName(append[...])
        }
        
        // these appenders are rarely hit in not null state-- caused by null chars.
        @inline(__always)
        func appendTagName(_ append: ArraySlice<UInt8>) {
            guard !append.isEmpty else { return }
            if _tagName == nil {
                if _tagNameS == nil {
                    _tagNameS = append
                } else {
                    ensureTagName()
                    _tagName!.append(contentsOf: append)
                }
            } else {
                _tagName!.append(contentsOf: append)
            }
            _normalName = nil
        }
        
        @inline(__always)
        func appendTagName(_ append: UnicodeScalar) {
            appendTagName(ArraySlice(append.utf8))
        }

        @inline(__always)
        func appendTagNameByte(_ byte: UInt8) {
            ensureTagName()
            _tagName!.append(byte)
            _normalName = nil
        }

        @inline(__always)
        private func ensureTagName() {
            if _tagName == nil {
                if let tagNameSlice = _tagNameS {
                    _tagName = Array(tagNameSlice)
                    _tagNameS = nil
                } else {
                    _tagName = []
                }
            }
        }

        @inline(__always)
        private static func equalsLowercased(_ name: ArraySlice<UInt8>, _ lower: ArraySlice<UInt8>) -> Bool {
            if name.count != lower.count {
                return false
            }
            var nameIndex = name.startIndex
            var lowerIndex = lower.startIndex
            let nameEnd = name.endIndex
            while nameIndex < nameEnd {
                let b = name[nameIndex]
                let lowerByte = lower[lowerIndex]
                let normalized = (b >= 0x41 && b <= 0x5A) ? (b &+ 0x20) : b
                if normalized != lowerByte {
                    return false
                }
                nameIndex = name.index(after: nameIndex)
                lowerIndex = lower.index(after: lowerIndex)
            }
            return true
        }
        
        @inline(__always)
        func appendAttributeName(_ append: [UInt8]) {
            appendAttributeName(append[...])
        }
        
        @inline(__always)
        func appendAttributeName(_ append: ArraySlice<UInt8>) {
            guard !append.isEmpty else { return }
            if _pendingAttributeName == nil && _pendingAttributeNameS == nil {
                _pendingAttributeNameS = append
                return
            }
            ensureAttributeName()
            _pendingAttributeName!.append(contentsOf: append)
        }
        
        @inline(__always)
        func appendAttributeName(_ append: UnicodeScalar) {
            appendAttributeName(Array(append.utf8))
        }

        @inline(__always)
        func appendAttributeNameByte(_ byte: UInt8) {
            ensureAttributeName()
            _pendingAttributeName!.append(byte)
        }
        
        @inline(__always)
        func appendAttributeValue(_ append: ArraySlice<UInt8>) {
            if _pendingAttributeValue.isEmpty {
                if let existing = _pendingAttributeValueS {
                    _pendingAttributeValueSlices = [existing, append]
                    _pendingAttributeValueSlicesCount = existing.count + append.count
                    _pendingAttributeValueS = nil
                    _hasPendingAttributeValue = true
                    return
                }
                if _pendingAttributeValueSlices != nil {
                    _pendingAttributeValueSlices!.append(append)
                    _pendingAttributeValueSlicesCount += append.count
                    _hasPendingAttributeValue = true
                    return
                }
                _pendingAttributeValueS = append
                _hasPendingAttributeValue = true
                return
            }
            ensureAttributeValue()
            _pendingAttributeValue.append(append)
        }
        
        @inline(__always)
        func appendAttributeValue(_ append: UnicodeScalar) {
            ensureAttributeValue()
            _pendingAttributeValue.appendCodePoint(append)
        }

        @inline(__always)
        func appendAttributeValueByte(_ byte: UInt8) {
            ensureAttributeValue()
            _pendingAttributeValue.append(byte)
        }
        
        @inline(__always)
        func appendAttributeValue(_ append: [UnicodeScalar]) {
            ensureAttributeValue()
            _pendingAttributeValue.appendCodePoints(append)
        }
        
        @inline(__always)
        func appendAttributeValue(_ appendCodepoints: [Int]) {
            ensureAttributeValue()
            for codepoint in appendCodepoints {
                _pendingAttributeValue.appendCodePoint(UnicodeScalar(codepoint)!)
            }
        }
        
        @inline(__always)
        func setEmptyAttributeValue() {
            _hasEmptyAttributeValue = true
        }

        @inline(__always)
        private func ensureAttributeName() {
            if _pendingAttributeName == nil {
                if let pendingSlice = _pendingAttributeNameS {
                    _pendingAttributeName = Array(pendingSlice)
                    _pendingAttributeNameS = nil
                } else {
                    _pendingAttributeName = []
                }
            }
        }
        
        @inline(__always)
        private func ensureAttributeValue() {
            _hasPendingAttributeValue = true
            if let slices = _pendingAttributeValueSlices {
                for slice in slices {
                    _pendingAttributeValue.append(slice)
                }
                _pendingAttributeValueSlices = nil
                _pendingAttributeValueSlicesCount = 0
            }
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
        @inline(__always)
        override func reset() -> Tag {
            super.reset()
            return self
        }
        
        @discardableResult
        @inline(__always)
        func nameAttr(_ name: [UInt8], _ attributes: Attributes) -> StartTag {
            self._tagName = name
            self._attributes = attributes
            _pendingAttributes = nil
            _normalName = _tagName?.lowercased()
            return self
        }
        
        @inline(__always)
        public override func toString() throws -> String {
            ensureAttributes()
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
        
        @inline(__always)
        public override func toString() throws -> String {
            return "</" + String(decoding: try name(), as: UTF8.self) + ">"
        }
    }
    
    final class Comment: Token {
        let data: StringBuilder = StringBuilder()
        var bogus: Bool = false
        
        @discardableResult
        @inline(__always)
        override func reset() -> Token {
            Token.reset(data)
            bogus = false
            return self
        }
        
        override init() {
            super.init()
            type = TokenType.Comment
        }
        
        @inline(__always)
        func getData() -> [UInt8] {
            return Array(data.buffer)
        }
        
        @inline(__always)
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
        @inline(__always)
        override func reset() -> Token {
            data = nil
            return self
        }
        
        @discardableResult
        @inline(__always)
        func data(_ data: [UInt8]) -> Char {
            self.data = data
            return self
        }
        
        @inline(__always)
        func getData() -> [UInt8]? {
            return data
        }
        
        @inline(__always)
        public override func toString() throws -> String {
            try Validate.notNull(obj: data)
            return String(decoding: getData()!, as: UTF8.self)
        }
    }
    
    final class EOF: Token {
        override init() {
            super.init()
            type = Token.TokenType.EOF
        }
        
        @discardableResult
        @inline(__always)
        override func reset() -> Token {
            return self
        }
    }
    
    @inline(__always)
    func isDoctype() -> Bool {
        return type == TokenType.Doctype
    }
    
    @inline(__always)
    func asDoctype() -> Doctype {
        return self as! Doctype
    }
    
    @inline(__always)
    func isStartTag() -> Bool {
        return type == TokenType.StartTag
    }
    
    @inline(__always)
    func asStartTag() -> StartTag {
        return self as! StartTag
    }
    
    @inline(__always)
    func isEndTag() -> Bool {
        return type == TokenType.EndTag
    }
    
    @inline(__always)
    func asEndTag() -> EndTag {
        return self as! EndTag
    }
    
    @inline(__always)
    func isComment() -> Bool {
        return type == TokenType.Comment
    }
    
    @inline(__always)
    func asComment() -> Comment {
        return self as! Comment
    }
    
    @inline(__always)
    func isCharacter() -> Bool {
        return type == TokenType.Char
    }
    
    @inline(__always)
    func asCharacter() -> Char {
        return self as! Char
    }
    
    @inline(__always)
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
