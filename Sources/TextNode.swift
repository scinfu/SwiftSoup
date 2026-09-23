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
    private var _textSlices: [ByteSlice]? = nil
    private var _textSlicesCount: Int = 0

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
        self._textSlices = nil
        self._textSlicesCount = 0
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
        _textSlices = nil
        _textSlicesCount = 0
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
    private func materializeTextIfNeeded() {
        if let slices = _textSlices {
            var out: [UInt8] = []
            out.reserveCapacity(_textSlicesCount)
            for slice in slices {
                out.append(contentsOf: slice)
            }
            _text = out
            _textSlices = nil
            _textSlicesCount = 0
            _textSlice = nil
            return
        }
        if let slice = _textSlice {
            _text = slice.toArray()
            _textSlice = nil
        }
    }
    
    @inline(__always)
    open func getWholeTextUTF8() -> [UInt8] {
        if let attrs = attributes {
            if let slice = attrs.valueSliceCaseSensitive(TextNode.TEXT_KEY) {
                return slice.toArray()
            }
            return []
        }
        materializeTextIfNeeded()
        return _text
    }

    @usableFromInline
    internal func wholeTextSlice() -> ByteSlice {
        if attributes != nil {
            return ByteSlice.fromArray(getWholeTextUTF8())
        }
        if let slice = _textSlice {
            return slice
        }
        if _textSlices != nil {
            materializeTextIfNeeded()
        }
        return ByteSlice.fromArray(_text)
    }

    @usableFromInline
    internal func appendSlice(_ slice: ByteSlice) {
        guard !slice.isEmpty else { return }
        if let attrs = attributes {
            attrs.appendValueSlice(key: TextNode.TEXT_KEY, slice: slice)
        } else if _textSlices != nil {
            _textSlices!.append(slice)
            _textSlicesCount += slice.count
        } else if let existingSlice = _textSlice {
            _textSlices = [existingSlice, slice]
            _textSlicesCount = existingSlice.count + slice.count
            _textSlice = nil
        } else if !_text.isEmpty {
            _text.append(contentsOf: slice)
        } else {
            _textSlice = slice
        }
        bumpTextMutationVersion()
        markSourceDirty()
    }

    @usableFromInline
    internal func extendSliceFromSourceRange(_ source: SourceBuffer, newRange: SourceRange) -> Bool {
        if attributes != nil || sourceRangeDirty || _textSlices != nil || !_text.isEmpty {
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
        _textSlices = nil
        _textSlicesCount = 0
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
        if type(of: self) == TextNode.self {
            // Keep the authoritative byte getter and its materialization behavior,
            // but do not decode the whole value merely to test for ASCII whitespace.
            return StringUtil.isBlankTextBytes(getWholeTextUTF8())
        }
        return StringUtil.isBlank(getWholeText())
    }

    /**
     Split this text node at an extended grapheme cluster (Swift `Character`) offset.
     The original node keeps the prefix; the returned node contains the suffix and
     is inserted immediately after it when attached. An offset equal to the number
     of characters is valid and creates an empty suffix.
     - parameter offset: character offset, from zero through the character count
     - returns: the newly created text node
     - throws: if the offset is outside those bounds, without changing the tree
     */
    open func splitText(_ offset: Int) throws -> TextNode {
        try Validate.isTrue(val: offset >= 0, msg: "Split offset must not be negative")
        // Take one snapshot: subclasses may override the public getter.
        let current = getWholeText()
        guard let split = current.index(current.startIndex, offsetBy: offset, limitedBy: current.endIndex) else {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException,
                                  Message: "Split offset must not exceed the character count")
        }
        return try splitText(head: String(current[..<split]), tail: String(current[split...]))
    }

    /**
     Split at an exact UTF-8 byte offset on a Unicode scalar boundary. This can
     separate scalars within a grapheme (such as a letter and its combining mark).
     Zero and the byte count are valid. Invalid UTF-8 or an offset inside a scalar
     throws before the node or its parent is modified; bytes are never repaired.
     */
    open func splitText(utf8Offset: Int) throws -> TextNode {
        try Validate.isTrue(val: utf8Offset >= 0, msg: "Split UTF-8 offset must not be negative")
        let current = getWholeTextUTF8()
        try Validate.isTrue(val: utf8Offset <= current.count,
                            msg: "Split UTF-8 offset must not exceed the byte count")
        guard let head = String(bytes: current[..<utf8Offset], encoding: .utf8),
              let tail = String(bytes: current[utf8Offset...], encoding: .utf8) else {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException,
                                  Message: "Split UTF-8 offset must separate valid Unicode scalar sequences")
        }
        return try splitText(head: head, tail: tail)
    }

    private func splitText(head: String, tail: String) throws -> TextNode {
        let tailNode = TextNode(Array(tail.utf8), getBaseUriUTF8())
        text(head)
        if let parent = parent() {
            try parent.addChildren(siblingIndex + 1, tailNode)
        }
        return tailNode
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
        if out.syntax() == .html,
           let element = parentNode as? Element,
           element.serializesAsRawText() {
            accum.append(wholeTextSlice())
            return
        }
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
                    if Entities.containsNonBreakingSpace(buf) { return true }
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
        guard attributes == nil else { return }
        materializeTextIfNeeded()
        let created = Attributes()
        // Populate before attaching the owner: materialization is not a DOM edit.
        try? created.put(TextNode.TEXT_KEY, _text)
        attributes = created
    }

    internal override func ensureAttributesForWrite() -> Attributes {
        ensureAttributes()
        return attributes!
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

    open override func hasAttr(_ attributeKey: [UInt8]) -> Bool {
        ensureAttributes()
        return super.hasAttr(attributeKey)
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
