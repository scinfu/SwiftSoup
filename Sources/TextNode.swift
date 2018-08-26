//
//  TextNode.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 A text node.
 */
open class TextNode: Node {
    /*
     TextNode is a node, and so by default comes with attributes and children. The attributes are seldom used, but use
     memory, and the child nodes are never used. So we don't have them, and override accessors to attributes to create
     them as needed on the fly.
     */
    private static let TEXT_KEY: String = "text"
    var _text: String

    /**
     Create a new TextNode representing the supplied (unencoded) text).
     
     @param text raw text
     @param baseUri base uri
     @see #createFromEncoded(String, String)
     */
    public init(_ text: String, _ baseUri: String?) {
        self._text = text
        super.init()
        self.baseUri = baseUri

    }

    open override func nodeName() -> String {
        return "#text"
    }

    /**
     * Get the text content of this text node.
     * @return Unencoded, normalised text.
     * @see TextNode#getWholeText()
     */
    open func text() -> String {
        return TextNode.normaliseWhitespace(getWholeText())
    }

    /**
     * Set the text content of this text node.
     * @param text unencoded text
     * @return this, for chaining
     */
    @discardableResult
    public func text(_ text: String) -> TextNode {
        self._text = text
        guard let attributes = attributes else {
            return self
        }
        do {
            try attributes.put(TextNode.TEXT_KEY, text)
        } catch {

        }
        return self
    }

    /**
     Get the (unencoded) text of this text node, including any newlines and spaces present in the original.
     @return text
     */
    open func getWholeText() -> String {
		return attributes == nil ? _text : attributes!.get(key: TextNode.TEXT_KEY)
    }

    /**
     Test if this text node is blank -- that is, empty or only whitespace (including newlines).
     @return true if this document is empty or only whitespace, false if it contains any text content.
     */
    open func isBlank() -> Bool {
        return StringUtil.isBlank(getWholeText())
    }

    /**
     * Split this text node into two nodes at the specified string offset. After splitting, this node will contain the
     * original text up to the offset, and will have a new text node sibling containing the text after the offset.
     * @param offset string offset point to split node at.
     * @return the newly created text node containing the text after the offset.
     */
    open func splitText(_ offset: Int)throws->TextNode {
        try Validate.isTrue(val: offset >= 0, msg: "Split offset must be not be negative")
        try Validate.isTrue(val: offset < _text.count, msg: "Split offset must not be greater than current text length")

        let head: String = getWholeText().substring(0, offset)
        let tail: String = getWholeText().substring(offset)
        text(head)
        let tailNode: TextNode = TextNode(tail, self.getBaseUri())
        if (parent() != nil) {
            try parent()?.addChildren(siblingIndex+1, tailNode)
        }
        return tailNode
    }

    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings)throws {
		if (out.prettyPrint() &&
			((siblingIndex == 0 && (parentNode as? Element) != nil &&  (parentNode as! Element).tag().formatAsBlock() && !isBlank()) ||
				(out.outline() && siblingNodes().count > 0 && !isBlank()) )) {
            indent(accum, depth, out)
		}

        let par: Element? = parent() as? Element
        let normaliseWhite = out.prettyPrint() && par != nil && !Element.preserveWhitespace(par!)

        Entities.escape(accum, getWholeText(), out, false, normaliseWhite, false)
    }

    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
    }

    /**
     * Create a new TextNode from HTML encoded (aka escaped) data.
     * @param encodedText Text containing encoded HTML (e.g. &amp;lt;)
     * @param baseUri Base uri
     * @return TextNode containing unencoded data (e.g. &lt;)
     */
    public static func createFromEncoded(_ encodedText: String, _ baseUri: String)throws->TextNode {
        let text: String = try Entities.unescape(encodedText)
        return TextNode(text, baseUri)
    }

    static public func normaliseWhitespace(_ text: String) -> String {
        let _text = StringUtil.normaliseWhitespace(text)
        return _text
    }

    static public func stripLeadingWhitespace(_ text: String) -> String {
        return text.replaceFirst(of: "^\\s+", with: "")
        //return text.replaceFirst("^\\s+", "")
    }

    static public func lastCharIsWhitespace(_ sb: StringBuilder) -> Bool {
        return sb.toString().last == " "
    }

    // attribute fiddling. create on first access.
    private func ensureAttributes() {
        if (attributes == nil) {
            attributes = Attributes()
            do {
                try attributes?.put(TextNode.TEXT_KEY, _text)
            } catch {}
        }
    }

    open override func attr(_ attributeKey: String)throws->String {
        ensureAttributes()
        return try super.attr(attributeKey)
    }

    open override func getAttributes() -> Attributes {
        ensureAttributes()
        return super.getAttributes()!
    }

    open override func attr(_ attributeKey: String, _ attributeValue: String)throws->Node {
        ensureAttributes()
        return try super.attr(attributeKey, attributeValue)
    }

    open override func hasAttr(_ attributeKey: String) -> Bool {
        ensureAttributes()
        return super.hasAttr(attributeKey)
    }

    open override func removeAttr(_ attributeKey: String)throws->Node {
        ensureAttributes()
        return try super.removeAttr(attributeKey)
    }

    open override func absUrl(_ attributeKey: String)throws->String {
        ensureAttributes()
        return try super.absUrl(attributeKey)
    }

	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = TextNode(_text, baseUri)
		return super.copy(clone: clone)
	}

	public override func copy(parent: Node?) -> Node {
		let clone = TextNode(_text, baseUri)
		return super.copy(clone: clone, parent: parent)
	}

	public override func copy(clone: Node, parent: Node?) -> Node {
		return super.copy(clone: clone, parent: parent)
	}
}
