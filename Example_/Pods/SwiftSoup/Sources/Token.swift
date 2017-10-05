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
		return String(describing: type(of: self))
	}

	/**
	* Reset the data represent by this token, for reuse. Prevents the need to create transfer objects for every
	* piece of data, which immediately get GCed.
	*/
	@discardableResult
	public func reset() -> Token {
		preconditionFailure("This method must be overridden")
	}

	static func reset(_ sb: StringBuilder) {
		sb.clear()
	}

	open func toString()throws->String {
		return String(describing: type(of: self))
	}

	final class Doctype: Token {
		let name: StringBuilder = StringBuilder()
        var pubSysKey: String?
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

		func getName() -> String {
			return name.toString()
		}
        
        func getPubSysKey()->String? {
            return pubSysKey;
        }
        

        
		func getPublicIdentifier() -> String {
			return publicIdentifier.toString()
		}

		open func getSystemIdentifier() -> String {
			return systemIdentifier.toString()
		}

		open func isForceQuirks() -> Bool {
			return forceQuirks
		}
	}

	class Tag: Token {
		public var _tagName: String?
		public var _normalName: String? // lc version of tag name, for case insensitive tree build
		private var _pendingAttributeName: String? // attribute names are generally caught in one hop, not accumulated
		private let _pendingAttributeValue: StringBuilder = StringBuilder() // but values are accumulated, from e.g. & in hrefs
		private var _pendingAttributeValueS: String? // try to get attr vals in one shot, vs Builder
		private var _hasEmptyAttributeValue: Bool = false // distinguish boolean attribute from empty string value
		private var _hasPendingAttributeValue: Bool = false
		public var _selfClosing: Bool = false
		// start tags get attributes on construction. End tags get attributes on first new attribute (but only for parser convenience, not used).
		public var _attributes: Attributes = Attributes()

		override init() {
			super.init()
		}

		@discardableResult
		override func reset() -> Tag {
			_tagName = nil
			_normalName = nil
			_pendingAttributeName = nil
			Token.reset(_pendingAttributeValue)
			_pendingAttributeValueS = nil
			_hasEmptyAttributeValue = false
			_hasPendingAttributeValue = false
			_selfClosing = false
			_attributes = Attributes()
			return self
		}

		func newAttribute()throws {
			//            if (_attributes == nil){
			//                _attributes = Attributes()
			//            }

			if (_pendingAttributeName != nil) {
				var attribute: Attribute
				if (_hasPendingAttributeValue) {
					attribute = try Attribute(key: _pendingAttributeName!, value: _pendingAttributeValue.length > 0 ? _pendingAttributeValue.toString() : _pendingAttributeValueS!)
				} else if (_hasEmptyAttributeValue) {
					attribute = try Attribute(key: _pendingAttributeName!, value: "")
				} else {
					attribute = try  BooleanAttribute(key: _pendingAttributeName!)
				}
				_attributes.put(attribute: attribute)
			}
			_pendingAttributeName = nil
			_hasEmptyAttributeValue = false
			_hasPendingAttributeValue = false
			Token.reset(_pendingAttributeValue)
			_pendingAttributeValueS = nil
		}

		func finaliseTag()throws {
			// finalises for emit
			if (_pendingAttributeName != nil) {
				// todo: check if attribute name exists; if so, drop and error
				try newAttribute()
			}
		}

		func name()throws->String { // preserves case, for input into Tag.valueOf (which may drop case)
			try Validate.isFalse(val: _tagName == nil || _tagName!.unicodeScalars.count == 0)
			return _tagName!
		}

		func normalName() -> String? { // loses case, used in tree building for working out where in tree it should go
			return _normalName
		}

		@discardableResult
		func name(_ name: String) -> Tag {
			_tagName = name
			_normalName = name.lowercased()
			return self
		}

		func isSelfClosing() -> Bool {
			return _selfClosing
		}

		func getAttributes() -> Attributes {
			return _attributes
		}

		// these appenders are rarely hit in not null state-- caused by null chars.
		func appendTagName(_ append: String) {
			_tagName = _tagName == nil ? append : _tagName!.appending(append)
			_normalName = _tagName?.lowercased()
		}

		func appendTagName(_ append: UnicodeScalar) {
			appendTagName("\(append)")
		}

		func appendAttributeName(_ append: String) {
			_pendingAttributeName = _pendingAttributeName == nil ? append : _pendingAttributeName?.appending(append)
		}

		func appendAttributeName(_ append: UnicodeScalar) {
			appendAttributeName("\(append)")
		}

		func appendAttributeValue(_ append: String) {
			ensureAttributeValue()
			if (_pendingAttributeValue.length == 0) {
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
			_attributes = Attributes()
			type = TokenType.StartTag
		}

		@discardableResult
		override func reset() -> Tag {
			super.reset()
			_attributes = Attributes()
			// todo - would prefer these to be null, but need to check Element assertions
			return self
		}

		@discardableResult
		func nameAttr(_ name: String, _ attributes: Attributes) -> StartTag {
			self._tagName = name
			self._attributes = attributes
			_normalName = _tagName?.lowercased()
			return self
		}

		open override func toString()throws->String {
			if (_attributes.size() > 0) {
				return try "<" + (name()) + " " + (_attributes.toString()) + ">"
			} else {
				return try "<" + name() + ">"
			}
		}
	}

	final class EndTag: Tag {
		override init() {
			super.init()
			type = TokenType.EndTag
		}

		open override func toString()throws->String {
			return "</" + (try name()) + ">"
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

		func getData() -> String {
			return data.toString()
		}

		open override func toString()throws->String {
			return "<!--" + getData() + "-->"
		}
	}

	final class Char: Token {
		public var data: String?

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
		func data(_ data: String) -> Char {
			self.data = data
			return self
		}

		func getData() -> String? {
			return data
		}

		open override func toString()throws->String {
			try Validate.notNull(obj: data)
			return getData()!
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
