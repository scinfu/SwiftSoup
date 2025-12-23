//
//  Document.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

@usableFromInline
internal final class SourceBuffer {
    @usableFromInline
    let bytes: [UInt8]
    
    @usableFromInline
    init(_ bytes: [UInt8]) {
        self.bytes = bytes
    }
}

open class Document: Element {
    public enum QuirksMode {
        case noQuirks, quirks, limitedQuirks
    }

    private var _outputSettings: OutputSettings  = OutputSettings()
    private var _quirksMode: Document.QuirksMode = QuirksMode.noQuirks
    private let _location: [UInt8]
    private var updateMetaCharset: Bool = false
    
    @usableFromInline
    internal var parsedAsXml: Bool = false


    /**
     Create a new, empty Document.
     - parameter baseUri: base URI of document
     - seealso: ``SwiftSoup/parse(_:)-(Data)``, ``createShell(_:)-([UInt8])``
     */
    public init(_ baseUri: [UInt8]) {
        _location = baseUri
        super.init(try! Tag.valueOf(UTF8Arrays.hashRoot, ParseSettings.htmlDefault), baseUri)
    }
    
    public init(_ baseUri: String) {
        _location = baseUri.utf8Array
        super.init(try! Tag.valueOf(UTF8Arrays.hashRoot, ParseSettings.htmlDefault), _location)
    }

    /**
     Create a valid, empty shell of a document, suitable for adding more elements to.
     - parameter baseUri: baseUri of document
     - returns: document with html, head, and body elements.
     */
    static public func createShell(_ baseUri: String) -> Document {
        createShell(baseUri.utf8Array)
    }
    
    static public func createShell(_ baseUri: [UInt8]) -> Document {
        let doc: Document = Document(baseUri)
        let html: Element = try! doc.appendElement("html")
        try! html.appendElement("head")
        try! html.appendElement("body")
        
        return doc
    }

    /**
     Get the URL this Document was parsed from. If the starting URL is a redirect,
     this will return the final URL from which the document was served from.
     - returns: location
     */
    public func location() -> String {
        return String(decoding: _location, as: UTF8.self)
    }

    /**
     Accessor to the document's `head` element.
     - returns: `head`
     */
    public func head() -> Element? {
        return findFirstElementByTagName(UTF8Arrays.head, self)
    }

    /**
     Accessor to the document's `body` element.
     - returns: `body`
     */
    public func body() -> Element? {
        return findFirstElementByTagName(UTF8Arrays.body, self)
    }

    /**
     Get the string contents of the document's `title` element.
     - returns: Trimmed title, or empty string if none set.
     */
    public func title()throws->String {
        // title is a preserve whitespace tag (for document output), but normalised here
        let titleEl: Element? = try getElementsByTag("title").first()
        return titleEl != nil ? try StringUtil.normaliseWhitespace(titleEl!.text()).trim() : ""
    }

    /**
     Set the document's `title` element. Updates the existing element, or adds `title` to `head` if
     not present
     - parameter title: string to set as title
     */
    public func title(_ title: String)throws {
        let titleEl: Element? = try getElementsByTag("title").first()
        if (titleEl == nil) { // add to head
            try head()?.appendElement("title").text(title)
        } else {
            try titleEl?.text(title)
        }
    }

    /**
     Create a new Element, with this document's base uri. Does not make the new element a child of this document.
     - parameter tagName: element tag name (e.g. `a`)
     - returns: new element
     */
    public func createElement(_ tagName: String) throws -> Element {
        let el = try Element(Tag.valueOf(tagName.utf8Array, ParseSettings.preserveCase), self.getBaseUriUTF8())
        el.ownerDocumentOverride = self
        if let treeBuilder {
            el.treeBuilder = treeBuilder
        }
        return el
    }

    /**
     Normalise the document. This happens after the parse phase so generally does not need to be called.
     Moves any text content that is not in the body element into the body.
     - returns: this document after normalisation
     */
    @discardableResult
    public func normalise() throws -> Document {
        var htmlE: Element? = findFirstElementByTagName(UTF8Arrays.html, self)
        if (htmlE == nil) {
            htmlE = try appendElement(UTF8Arrays.html)
        }
        let htmlEl: Element = htmlE!

        if (head() == nil) {
            try htmlEl.prependElement(UTF8Arrays.head)
        }
        if (body() == nil) {
            try htmlEl.appendElement(UTF8Arrays.body)
        }

        // pull text nodes out of root, html, and head els, and push into body. non-text nodes are already taken care
        // of. do in inverse order to maintain text order.
        try normaliseTextNodes(head()!)
        try normaliseTextNodes(htmlEl)
        try normaliseTextNodes(self)

        try normaliseStructure(UTF8Arrays.head, htmlEl)
        try normaliseStructure(UTF8Arrays.body, htmlEl)

        try ensureMetaCharsetElement()

        return self
    }

    // does not recurse.
    private func normaliseTextNodes(_ element: Element) throws {
        var toMove: Array<Node> =  Array<Node>()
        for node: Node in element.childNodes {
            if let tn = (node as? TextNode) {
                if (!tn.isBlank()) {
                toMove.append(tn)
                }
            }
        }

        for i in (0..<toMove.count).reversed() {
            let node: Node = toMove[i]
            try element.removeChild(node)
            try body()?.prependChild(TextNode(UTF8Arrays.whitespace, []))
            try body()?.prependChild(node)
        }
    }

    // merge multiple <head> or <body> contents into one, delete the remainder, and ensure they are owned by <html>
    private func normaliseStructure(_ tag: [UInt8], _ htmlEl: Element) throws {
        let elements: Elements = try self.getElementsByTag(tag)
        let master: Element? = elements.first() // will always be available as created above if not existent
        if (elements.size() > 1) { // dupes, move contents to master
            var toMove: Array<Node> = Array<Node>()
            for i in 1..<elements.size() {
                let dupe: Node = elements.get(i)
                for node: Node in dupe.childNodes {
                    toMove.append(node)
                }
                try dupe.remove()
            }

            for dupe: Node in toMove {
                try master?.appendChild(dupe)
            }
        }
        // ensure parented by <html>
        if (!(master != nil && master!.parent() != nil && master!.parent()!.equals(htmlEl))) {
            try htmlEl.appendChild(master!) // includes remove()
        }
    }

    // fast method to get first by tag name, used for html, head, body finders
    private func findFirstElementByTagName(_ tag: [UInt8], _ node: Node) -> Element? {
        if (node.nodeNameUTF8() == tag) {
            return node as? Element
        } else {
            for child: Node in node.childNodes {
                let found: Element? = findFirstElementByTagName(tag, child)
                if (found != nil) {
                    return found
                }
            }
        }
        return nil
    }

    @inline(__always)
    open override func outerHtml() throws -> String {
        return try super.html() // no outer wrapper tag
    }
    
    @inline(__always)
    open func outerHtmlUTF8() throws -> [UInt8] {
        return try super.htmlUTF8() // no outer wrapper tag
    }

    /**
     Set the text of the `body` of this document. Any existing nodes within the body will be cleared.
     - parameter text: unencoded text
     - returns: this document
     */
    @discardableResult
    @inline(__always)
    public override func text(_ text: String) throws -> Element {
        try body()?.text(text) // overridden to not nuke doc structure
        return self
    }

    @inline(__always)
    public override func nodeNameUTF8() -> [UInt8] {
        return nodeName().utf8Array
    }
    
    @inline(__always)
    public override func nodeName() -> String {
        return "#document"
    }

    /**
     Sets the charset used in this document. This method is equivalent
     to ``OutputSettings/charset(_:)`` but in addition it updates the
     charset / encoding element within the document.
     
     This enables ``updateMetaCharsetElement(_:)`` meta charset update.
     
     If there's no element with charset / encoding information yet it will
     be created. Obsolete charset / encoding definitions are removed!
     
     **Elements used:**
     
     * **HTML:** `<meta charset="CHARSET">`
     * **XML:**: `<?xml version="1.0" encoding="CHARSET">`
     
     - parameter charset: Charset
     - seealso: ``updateMetaCharsetElement(_:)``, ``OutputSettings/charset(_:)``
     */
    public func charset(_ charset: String.Encoding)throws {
        updateMetaCharsetElement(true)
        _outputSettings.charset(charset)
        try ensureMetaCharsetElement()
    }

    /**
     Returns the charset used in this document. This method is equivalent
     to ``OutputSettings/charset()``.
     
     - returns: Current Charset
     */
    @inline(__always)
    public func charset() -> String.Encoding {
        return _outputSettings.charset()
    }

    /**
     Sets whether the element with charset information in this document is
     updated on changes through ``charset(_:)`` or not.
     
     If set to `false` (default) there are no elements modified.
     
     - parameter update: If `true` the element updated on charset
     changes, `false` if not
     */
    @inline(__always)
    public func updateMetaCharsetElement(_ update: Bool) {
        self.updateMetaCharset = update
    }

    /**
     Returns whether the element with charset information in this document is
     updated on changes through ``charset(_:)`` or not.
     
     - returns: Returns `e` if the element is updated on charset
     changes, `e` if not
     */
    @inline(__always)
    public func updateMetaCharsetElement() -> Bool {
        return updateMetaCharset
    }

    /**
     Ensures a meta charset (HTML) or XML declaration (XML) with the current
     encoding used. This only applies with ``updateMetaCharsetElement(_:)``
     set to `e`, otherwise this method does nothing.
     
     An existing element gets updated with the current charset.
     If there's no element yet it will be inserted.
     Obsolete elements are removed.
     
     **Elements used:**
     
     * **HTML:** `<meta charset="CHARSET">`
     * **XML:** `<?xml version="1.0" encoding="CHARSET">`
     */
    private func ensureMetaCharsetElement() throws {
        if (updateMetaCharset) {
            let syntax: OutputSettings.Syntax = outputSettings().syntax()

            if (syntax == OutputSettings.Syntax.html) {
                let metaCharset: Element? = try select("meta[charset]").first()

                if (metaCharset != nil) {
                    try metaCharset?.attr("charset", charset().displayName())
                } else {
                    let head: Element? = self.head()

                    if (head != nil) {
                        try head?.appendElement("meta").attr("charset", charset().displayName())
                    }
                }

                // Remove obsolete elements
				let s = try select("meta[name=charset]")
				try s.remove()

            } else if (syntax == OutputSettings.Syntax.xml) {
                let node: Node = getChildNodes()[0]

                if let decl = (node as? XmlDeclaration) {

                    if (decl.name()=="xml") {
                        try decl.attr("encoding".utf8Array, charset().displayName().utf8Array)

                        _ = try  decl.attr("version".utf8Array)
                        try decl.attr("version".utf8Array, "1.0".utf8Array)
                    } else {
                        try Validate.notNull(obj: baseUri)
                        let decl = XmlDeclaration("xml".utf8Array, baseUri!, false)
                        try decl.attr("version".utf8Array, "1.0".utf8Array)
                        try decl.attr("encoding".utf8Array, charset().displayName().utf8Array)

                        try prependChild(decl)
                    }
                } else {
                    try Validate.notNull(obj: baseUri)
                    let decl = XmlDeclaration("xml".utf8Array, baseUri!, false)
                    try decl.attr("version".utf8Array, "1.0".utf8Array)
                    try decl.attr("encoding".utf8Array, charset().displayName().utf8Array)

                    try prependChild(decl)
                }
            }
        }
    }

    /**
     Get the document's current output settings.
     - returns: the document's current output settings.
     */
    @inline(__always)
    public func outputSettings() -> OutputSettings {
    return _outputSettings
    }

    /**
     Set the document's output settings.
     - parameter outputSettings: new output settings.
     - returns: this document, for chaining.
     */
    @discardableResult
    @inline(__always)
    public func outputSettings(_ outputSettings: OutputSettings) -> Document {
        self._outputSettings = outputSettings
        return self
    }

    @usableFromInline
    internal func sourcePatches() throws -> [SourcePatch] {
        guard sourceBuffer != nil else { return [] }
        let out = (_outputSettings.copy() as! OutputSettings).prettyPrint(pretty: false)
        var patches: [SourcePatch] = []

        func collect(_ node: Node, _ ancestorDirty: Bool) {
            let nodeDirty = node.sourceRangeDirty
            if nodeDirty && !ancestorDirty,
               node.sourceRangeIsComplete,
               let range = node.sourceRange,
               range.isValid,
               let source = sourceBuffer?.bytes,
               range.end <= source.count {
                if let replacement = try? node.outerHtmlUTF8Internal(out, allowRawSource: false) {
                    patches.append(SourcePatch(range: range, replacement: replacement))
                    return
                }
            }
            let hasOwnRange = node.sourceRangeIsComplete && node.sourceRange != nil
            let childAncestorDirty = ancestorDirty || (nodeDirty && hasOwnRange)
            if node.hasChildNodes() {
                for child in node.childNodes {
                    collect(child, childAncestorDirty)
                }
            }
        }

        collect(self, false)
        if patches.count > 1 {
            patches.sort { $0.range.start < $1.range.start }
        }
        return patches
    }

    @inline(__always)
    public func quirksMode()->Document.QuirksMode {
        return _quirksMode
    }

    @discardableResult
    @inline(__always)
    public func quirksMode(_ quirksMode: Document.QuirksMode) -> Document {
        self._quirksMode = quirksMode
        return self
    }

    @inline(__always)
	public override func copy(with zone: NSZone? = nil) -> Any {
		let clone = Document(_location)
		return copy(clone: clone)
	}

    @inline(__always)
	public override func copy(parent: Node?) -> Node {
		let clone = Document(_location)
		return copy(clone: clone, parent: parent)
	}

    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = Document(_location)
        clone._outputSettings = _outputSettings.copy() as! OutputSettings
        clone._quirksMode = _quirksMode
        clone.updateMetaCharset = updateMetaCharset
        clone.sourceBuffer = nil
        clone.parsedAsXml = parsedAsXml
        return copy(clone: clone, parent: parent, copyChildren: false, rebuildIndexes: false)
    }

    @inline(__always)
    public override func copy(clone: Node, parent: Node?) -> Node {
        let clone = clone as! Document
        clone._outputSettings = _outputSettings.copy() as! OutputSettings
        clone._quirksMode = _quirksMode
        clone.updateMetaCharset = updateMetaCharset
        clone.sourceBuffer = nil
        clone.parsedAsXml = parsedAsXml
        return super.copy(clone: clone, parent: parent)
    }

}

public class OutputSettings: NSCopying {
    /**
     * The output serialization syntax.
     */
    public enum Syntax {case html, xml}

    @usableFromInline
    internal var _escapeMode: Entities.EscapeMode  = Entities.EscapeMode.base
    @usableFromInline
    internal var _encoder: String.Encoding = String.Encoding.utf8 // Charset.forName("UTF-8")
    private var _prettyPrint: Bool = true
    private var _outline: Bool = false
    private var _indentAmount: UInt  = 1
    private var _syntax = Syntax.html

    public init() {}

    /**
     Get the document's current HTML escape mode: `e`, which provides a limited set of named HTML
     entities and escapes other characters as numbered entities for maximum compatibility; or `d`,
     which uses the complete set of HTML named entities.
     
     The default escape mode is `e`.
     - returns: the document's current escape mode
     */
    @inline(__always)
    public func escapeMode() -> Entities.EscapeMode {
        return _escapeMode
    }

    /**
     Set the document's escape mode, which determines how characters are escaped when the output character set
     does not support a given character:- using either a named or a numbered escape.
     - parameter escapeMode: the new escape mode to use
     - returns: the document's output settings, for chaining
     */
    @discardableResult
    @inline(__always)
    public func escapeMode(_ escapeMode: Entities.EscapeMode) -> OutputSettings {
        self._escapeMode = escapeMode
        return self
    }

    /**
     Get the document's current output charset, which is used to control which characters are escaped when
     generating HTML (via the `)` methods), and which are kept intact.
     
     Where possible (when parsing from a URL or File), the document's output charset is automatically set to the
     input charset. Otherwise, it defaults to UTF-8.
     
     - returns: the document's current charset.
     */
    @inline(__always)
    public func encoder() -> String.Encoding {
        return _encoder
    }
    
    @inline(__always)
    public func charset() -> String.Encoding {
        return _encoder
    }

    /**
     Update the document's output charset.
     - parameter encoder: the new charset to use.
     - returns: the document's output settings, for chaining
     */
    @discardableResult
    @inline(__always)
    public func encoder(_ encoder: String.Encoding) -> OutputSettings {
        self._encoder = encoder
        return self
    }

    @discardableResult
    @inline(__always)
    public func charset(_ e: String.Encoding) -> OutputSettings {
        return encoder(e)
    }

    /**
     Get the document's current output syntax.
     - returns: current syntax
     */
    @inline(__always)
    public func syntax() -> Syntax {
        return _syntax
    }

    /**
     Set the document's output syntax. Either `html`, with empty tags and boolean attributes (etc), or
     `xml`, with self-closing tags.
     
     - parameter syntax: serialization syntax
     - returns: the document's output settings, for chaining
     */
    @discardableResult
    @inline(__always)
    public func syntax(syntax: Syntax) -> OutputSettings {
        _syntax = syntax
        return self
    }

    /**
     Get if pretty printing is enabled. Default is true. If disabled, the HTML output methods will not re-format
     the output, and the output will generally look like the input.
     - returns: if pretty printing is enabled.
     */
    @inline(__always)
    public func prettyPrint() -> Bool {
        return _prettyPrint
    }

    /**
     Enable or disable pretty printing.
     - parameter pretty: new pretty print setting
     - returns: this, for chaining
     */
    @discardableResult
    @inline(__always)
    public func prettyPrint(pretty: Bool) -> OutputSettings {
        _prettyPrint = pretty
        return self
    }

    /**
     Get if outline mode is enabled. Default is false. If enabled, the HTML output methods will consider
     all tags as block.
     - returns: if outline mode is enabled.
     */
    @inline(__always)
    public func outline() -> Bool {
        return _outline
    }

    /**
     Enable or disable HTML outline mode.
     - parameter outlineMode: new outline setting
     - returns: this, for chaining
     */
    @discardableResult
    @inline(__always)
    public func outline(outlineMode: Bool) -> OutputSettings {
        _outline = outlineMode
        return self
    }

    /**
     Get the current tag indent amount, used when pretty printing.
     - returns: the current indent amount
     */
    @inline(__always)
    public func indentAmount() -> UInt {
        return _indentAmount
    }

    /**
     Set the indent amount for pretty printing
     - parameter indentAmount: number of spaces to use for indenting each level. Must be >= 0.
     - returns: this, for chaining
     */
    @discardableResult
    @inline(__always)
    public func indentAmount(indentAmount: UInt) -> OutputSettings {
        _indentAmount = indentAmount
        return self
    }

    @inline(__always)
    public func copy(with zone: NSZone? = nil) -> Any {
        let clone: OutputSettings = OutputSettings()
        clone.charset(_encoder) // new charset and charset encoder
        clone._escapeMode = _escapeMode//Entities.EscapeMode.valueOf(escapeMode.name())
        clone._prettyPrint = _prettyPrint
        clone._outline = _outline
        clone._indentAmount = _indentAmount
        clone._syntax = _syntax
        // indentAmount, prettyPrint are primitives so object.clone() will handle
        return clone
    }

}
