//
//  TextNode.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/**
 A text node.
 */
open class TextNode: Node {
    /*
     TextNode is a node, and so by default comes with attributes and children. The attributes are seldom used, but use
     memory, and the child nodes are never used. So we don't have them, and override accessors to attributes to create
     them as needed on the fly.
     */
    private static let TEXT_KEY = "text".utf8Array
    var _text: [UInt8]
    private var _textSlice: ByteSlice? = nil

    /**
     Create a new TextNode representing the supplied (unencoded) text).
     
     - parameter text: raw text
     - parameter baseUri: base uri
     */
    public init(_ text: [UInt8], _ baseUri: [UInt8]?) {
        self._text = text
        super.init()
        self.baseUri = baseUri

    }

    @usableFromInline
    internal init(slice: ByteSlice, baseUri: [UInt8]?) {
        self._text = []
        self._textSlice = slice
        super.init()
        self.baseUri = baseUri
    }

    @usableFromInline
    internal convenience init(slice: ArraySlice<UInt8>, baseUri: [UInt8]?) {
        self.init(slice: ByteSlice.fromArraySlice(slice), baseUri: baseUri)
    }
    public convenience init(_ text: String, _ baseUri: String?) {
        self.init(text.utf8Array, baseUri?.utf8Array)
    }

    @inline(__always)
    public override func nodeNameUTF8() -> [UInt8] {
        return nodeName().utf8Array
    }
    
    @inline(__always)
    public override func nodeName() -> String {
        return "#text"
    }

    /**
     Get the text content of this text node.
     - returns: Unencoded, normalised text.
     - seealso: ``getWholeText()``
     */
    @inline(__always)
    open func text() -> String {
        return TextNode.normaliseWhitespace(wholeTextSlice())
    }

    /**
     Set the text content of this text node.
     - parameter text: unencoded text
     - returns: this, for chaining
     */
    @discardableResult
    @inline(__always)
    public func text(_ text: String) -> TextNode {
        _textSlice = nil
        _text = text.utf8Array
        guard let attributes = attributes else {
            bumpTextMutationVersion()
            markSourceDirty()
            return self
        }
        do {
            try attributes.put(TextNode.TEXT_KEY, _text)
        } catch {

        }
        bumpTextMutationVersion()
        markSourceDirty()
        return self
    }

    /**
     Get the (unencoded) text of this text node, including any newlines and spaces present in the original.
     - returns: text
     */
    @inline(__always)
    open func getWholeText() -> String {
        return String(decoding: getWholeTextUTF8(), as: UTF8.self)
    }
    
    @inline(__always)
    open func getWholeTextUTF8() -> [UInt8] {
        if let slice = _textSlice {
            let materialized = slice.toArray()
            _textSlice = nil
            _text = materialized
            if let attrs = attributes {
                do {
                    try attrs.put(TextNode.TEXT_KEY, materialized)
                } catch {}
            }
        }
        return attributes == nil ? _text : attributes!.get(key: TextNode.TEXT_KEY)
    }

    @usableFromInline
    internal func wholeTextSlice() -> ByteSlice {
        if attributes != nil {
            return ByteSlice.fromArray(getWholeTextUTF8())
        }
        if let slice = _textSlice {
            return slice
        }
        return ByteSlice.fromArray(_text)
    }

    @usableFromInline
    internal func appendSlice(_ slice: ByteSlice) {
        if attributes != nil {
            var bytes = getWholeTextUTF8()
            bytes.append(contentsOf: slice)
            do {
                try attributes?.put(TextNode.TEXT_KEY, bytes)
            } catch {}
        } else {
            if let existingSlice = _textSlice {
                _text = existingSlice.toArray()
                _textSlice = nil
            }
            _text.append(contentsOf: slice)
        }
        bumpTextMutationVersion()
        markSourceDirty()
    }

    @usableFromInline
    internal func extendSliceFromSourceRange(_ source: SourceBuffer, newRange: SourceRange) -> Bool {
        if attributes != nil || sourceRangeDirty {
            return false
        }
        guard let existingRange = sourceRange,
              existingRange.isValid,
              newRange.isValid,
              existingRange.end == newRange.start,
              newRange.end <= source.bytes.count
        else {
            return false
        }
        _text = []
        _textSlice = ByteSlice(storage: source.storage, start: existingRange.start, end: newRange.end)
        return true
    }

    @usableFromInline
    internal func appendBytes(_ bytes: [UInt8]) {
        appendSlice(ByteSlice.fromArray(bytes))
    }





    /**
     Test if this text node is blank -- that is, empty or only whitespace (including newlines).
     - returns: true if this document is empty or only whitespace, false if it contains any text content.
     */
    @inline(__always)
    open func isBlank() -> Bool {
        return StringUtil.isBlank(getWholeText())
    }

    /**
     Split this text node into two nodes at the specified string offset. After splitting, this node will contain the
     original text up to the offset, and will have a new text node sibling containing the text after the offset.
     - parameter offset: string offset point to split node at.
     - returns: the newly created text node containing the text after the offset.
     */
    open func splitText(_ offset: Int) throws -> TextNode {
        try Validate.isTrue(val: offset >= 0, msg: "Split offset must be not be negative")
        let current = getWholeTextUTF8()
        try Validate.isTrue(val: offset < current.count, msg: "Split offset must not be greater than current text length")

        let head: String = getWholeText().substring(0, offset)
        let tail: String = getWholeText().substring(offset)
        text(head)
        let tailNode: TextNode = TextNode(tail.utf8Array, self.getBaseUriUTF8())
        if (parent() != nil) {
            try parent()?.addChildren(siblingIndex+1, tailNode)
        }
        return tailNode
    }
    
    open func splitText(utf8Offset: Int) throws -> TextNode {
        // Ensure UTF-8 offset is within valid bounds
        try Validate.isTrue(val: utf8Offset >= 0, msg: "Split UTF-8 offset must not be negative")
        let current = getWholeTextUTF8()
        try Validate.isTrue(val: utf8Offset < current.count, msg: "Split UTF-8 offset must not exceed current text length in UTF-8 bytes")
        
        // Convert UTF-8 offset to extended grapheme cluster offset
        let graphemeOffset = Substring(getWholeText().utf8.prefix(utf8Offset)).count
        
        // Validate grapheme cluster offset
        try Validate.isTrue(val: graphemeOffset < current.count, msg: "Split grapheme cluster offset must not exceed current text length")
        
        return try splitText(graphemeOffset)
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
		if (out.prettyPrint() &&
			((siblingIndex == 0 && (parentNode as? Element) != nil &&  (parentNode as! Element).tag().formatAsBlock() && !isBlank()) ||
                (out.outline() && hasSiblingNodes() && !isBlank()) )) {
            indent(accum, depth, out)
		}

        if !out.prettyPrint() {
            let slice = wholeTextSlice()
            if !slice.isEmpty {
                let encoder = out.encoder()
                if encoder == .ascii {
                    for b in slice {
                        if b >= Entities.asciiUpperLimitByte {
                            Entities.escape(accum, slice, out, false, false, false)
                            return
                        }
                    }
                }
                let hasSpecial = slice.withUnsafeBufferPointer { buf -> Bool in
                    guard let base = buf.baseAddress else { return false }
                    let count = buf.count
                    if memchr(base, Int32(TokeniserStateVars.ampersandByte), count) != nil { return true }
                    if memchr(base, Int32(TokeniserStateVars.lessThanByte), count) != nil { return true }
                    if memchr(base, Int32(TokeniserStateVars.greaterThanByte), count) != nil { return true }
                    if let nbspLead = memchr(base, Int32(StringUtil.utf8NBSPLead), count) {
                        let lead = nbspLead.assumingMemoryBound(to: UInt8.self)
                        let idx = base.distance(to: lead)
                        if idx + 1 < count, base[idx + 1] == StringUtil.utf8NBSPTrail {
                            return true
                        }
                    }
                    return false
                }
                if !hasSpecial {
                    accum.append(slice)
                    return
                }
            }
            Entities.escape(accum, slice, out, false, false, false)
            return
        }
        let normaliseWhite: Bool
        if let par = parentNode as? Element,
           !Element.preserveWhitespace(par) {
            normaliseWhite = true
        } else {
            normaliseWhite = false
        }

        Entities.escape(accum, wholeTextSlice(), out, false, normaliseWhite, false)
    }

    @inline(__always)
    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
    }

    /**
     Create a new TextNode from HTML encoded (aka escaped) data.
     - parameter encodedText: Text containing encoded HTML (e.g. `&amp;lt;`)
     - parameter baseUri: Base uri
     - returns: TextNode containing unencoded data (e.g. `&lt;`)
     */
    @inline(__always)
    public static func createFromEncoded(_ encodedText: String, _ baseUri: String) throws -> TextNode {
        let text = try Entities.unescape(encodedText.utf8Array)
        return TextNode(text, baseUri.utf8Array)
    }

    @inline(__always)
    static public func normaliseWhitespace(_ text: String) -> String {
        return StringUtil.normaliseWhitespace(text)
    }

    @inline(__always)
    static public func normaliseWhitespace(_ text: [UInt8]) -> String {
        return StringUtil.normaliseWhitespace(text)
    }

    @inline(__always)
    static public func normaliseWhitespace(_ text: ArraySlice<UInt8>) -> String {
        return StringUtil.normaliseWhitespace(text)
    }

    @inline(__always)
    static func normaliseWhitespace(_ text: ByteSlice) -> String {
        return StringUtil.normaliseWhitespace(text)
    }

    @inline(__always)
    static public func stripLeadingWhitespace(_ text: String) -> String {
        return text.replaceFirst(of: "^\\s+", with: "")
        //return text.replaceFirst("^\\s+", "")
    }

    @inlinable
    @inline(__always)
    static public func lastCharIsWhitespace(_ sb: StringBuilder) -> Bool {
        return sb.lastByte == TokeniserStateVars.spaceByte
    }

    // attribute fiddling. create on first access.
    @inline(__always)
    private func ensureAttributes() {
        if (attributes == nil) {
            attributes = Attributes()
            do {
                if let slice = _textSlice {
                    _text = Array(slice)
                    _textSlice = nil
                }
                try attributes?.put(TextNode.TEXT_KEY, _text)
            } catch {}
        }
    }

    open override func attr(_ attributeKey: [UInt8]) throws -> [UInt8] {
        ensureAttributes()
        return try super.attr(attributeKey)
    }
    
    open override func attr(_ attributeKey: String) throws -> String {
        ensureAttributes()
        return try super.attr(attributeKey)
    }

    open override func getAttributes() -> Attributes {
        ensureAttributes()
        return super.getAttributes()!
    }

    open override func attr(_ attributeKey: [UInt8], _ attributeValue: [UInt8]) throws -> Node {
        ensureAttributes()
        return try super.attr(attributeKey, attributeValue)
    }
    
    open override func attr(_ attributeKey: String, _ attributeValue: String) throws -> Node {
        ensureAttributes()
        return try super.attr(attributeKey, attributeValue)
    }

    open override func hasAttr(_ attributeKey: String) -> Bool {
        ensureAttributes()
        return super.hasAttr(attributeKey)
    }

    open override func removeAttr(_ attributeKey: [UInt8]) throws -> Node {
        ensureAttributes()
        return try super.removeAttr(attributeKey)
    }
    
    open override func removeAttr(_ attributeKey: String) throws -> Node {
        ensureAttributes()
        return try super.removeAttr(attributeKey)
    }

    open override func absUrl(_ attributeKey: String) throws -> String {
        ensureAttributes()
        return try super.absUrl(attributeKey)
    }
    
    open override func absUrl<T: Collection>(_ attributeKey: T) throws -> [UInt8] where T.Element == UInt8 {
        ensureAttributes()
        return try super.absUrl(attributeKey)
    }

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = TextNode(getWholeTextUTF8(), baseUri)
		return super.copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = TextNode(getWholeTextUTF8(), baseUri)
		return super.copy(clone: clone, parent: parent)
	}

    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = TextNode(getWholeTextUTF8(), baseUri)
        return copy(clone: clone, parent: parent, copyChildren: false, rebuildIndexes: false)
    }

	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
