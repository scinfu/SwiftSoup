//
//  Tag.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 15/10/16.
//

import Foundation

open class Tag: Hashable, @unchecked Sendable {
    // Removed duplicate == and hash(into:) to fix redeclaration errors
    // Singleton for thread-safe tag map
    private final class TagRegistry: @unchecked Sendable {
        static let shared = TagRegistry()
        let tagsLock = NSLock()
        var tags: Dictionary<[UInt8], Tag>
        private init() {
            do {
                self.tags = try Tag.initializeMaps()
            } catch {
                preconditionFailure("This method must be overridden")
            }
        }
    }

    // Helper to access the singleton
    private static var tagsLock: NSLock { TagRegistry.shared.tagsLock }
    private static var tags: Dictionary<[UInt8], Tag> {
        get { TagRegistry.shared.tags }
        set { TagRegistry.shared.tags = newValue }
    }

    fileprivate var _tagName: [UInt8]
    fileprivate var _tagNameNormal: [UInt8]
    fileprivate var _isBlock: Bool = true // block or inline
    fileprivate var _formatAsBlock: Bool = true // should be formatted as a block
    fileprivate var _canContainBlock: Bool = true // Can this tag hold block level tags?
    fileprivate var _canContainInline: Bool = true // only pcdata if not
    fileprivate var _empty: Bool = false // can hold nothing e.g. img
    fileprivate var _selfClosing: Bool = false // can self close (<foo />). used for unknown tags that self close, without forcing them as empty.
    fileprivate var _preserveWhitespace: Bool = false // for pre, textarea, script etc
    fileprivate var _formList: Bool = false // a control that appears in forms: input, textarea, output etc
    fileprivate var _formSubmit: Bool = false // a control that can be submitted in a form: input etc

    public init(_ tagName: [UInt8]) {
        self._tagName = tagName
        self._tagNameNormal = tagName.lowercased()
    }
    
    public convenience init(_ tagName: String) {
        self.init(tagName.utf8Array)
    }

    /**
     * Get this tag's name.
     *
     * @return the tag's name
     */
    open func getName() -> String {
        return String(decoding: self._tagName, as: UTF8.self)
    }
    open func getNameNormal() -> String {
        return String(decoding: self._tagNameNormal, as: UTF8.self)
    }
    open func getNameUTF8() -> [UInt8] {
        return self._tagName
    }
    open func getNameNormalUTF8() -> [UInt8] {
        return self._tagNameNormal
    }

    /**
     * Get a Tag by name. If not previously defined (unknown), returns a new generic tag, that can do anything.
     * <p>
     * Pre-defined tags (P, DIV etc) will be ==, but unknown tags are not registered and will only .equals().
     * </p>
     *
     * @param tagName Name of tag, e.g. "p". Case insensitive.
     * @param settings used to control tag name sensitivity
     * @return The tag, either defined or new generic.
     */
    public static func valueOf(_ tagName: String, _ settings: ParseSettings) throws -> Tag {
        return try valueOf(tagName.utf8Array, settings)
    }
    
    public static func valueOf(_ tagName: [UInt8], _ settings: ParseSettings) throws -> Tag {
        var tagName = tagName
        var tag: Tag?
        Tag.tagsLock.lock()
        tag = Tag.tags[tagName]
        Tag.tagsLock.unlock()

        if (tag == nil) {
            tagName = settings.normalizeTag(tagName)
            try Validate.notEmpty(string: tagName)
            Tag.tagsLock.lock()
            tag = Tag.tags[tagName]
            Tag.tagsLock.unlock()

            if (tag == nil) {
                // not defined: create default; go anywhere, do anything! (incl be inside a <p>)
                tag = Tag(tagName)
                tag!._isBlock = false
                tag!._canContainBlock = true
            }
        }
        return tag!
    }

    /**
     * Get a Tag by name. If not previously defined (unknown), returns a new generic tag, that can do anything.
     * <p>
     * Pre-defined tags (P, DIV etc) will be ==, but unknown tags are not registered and will only .equals().
     * </p>
     *
     * @param tagName Name of tag, e.g. "p". <b>Case sensitive</b>.
     * @return The tag, either defined or new generic.
     */
    @inline(__always)
    public static func valueOf(_ tagName: String) throws -> Tag {
        return try valueOf(tagName.utf8Array)
    }
    
    @inline(__always)
    public static func valueOf(_ tagName: [UInt8]) throws -> Tag {
        return try valueOf(tagName, ParseSettings.preserveCase)
    }

    /**
     * Gets if this is a block tag.
     *
     * @return if block tag
     */
    @inline(__always)
    open func isBlock() -> Bool {
        return _isBlock
    }

    /**
     * Gets if this tag should be formatted as a block (or as inline)
     *
     * @return if should be formatted as block or inline
     */
    @inline(__always)
    open func formatAsBlock() -> Bool {
        return _formatAsBlock
    }

    /**
     * Gets if this tag can contain block tags.
     *
     * @return if tag can contain block tags
     */
    @inline(__always)
    open func canContainBlock() -> Bool {
        return _canContainBlock
    }

    /**
     * Gets if this tag is an inline tag.
     *
     * @return if this tag is an inline tag.
     */
    @inline(__always)
    open func isInline() -> Bool {
        return !_isBlock
    }

    /**
     * Gets if this tag is a data only tag.
     *
     * @return if this tag is a data only tag
     */
    @inline(__always)
    open func isData() -> Bool {
        return !_canContainInline && !isEmpty()
    }

    /**
     * Get if this is an empty tag
     *
     * @return if this is an empty tag
     */
    @inline(__always)
    open func isEmpty() -> Bool {
        return _empty
    }

    /**
     * Get if this tag is self closing.
     *
     * @return if this tag should be output as self closing.
     */
    @inline(__always)
    open func isSelfClosing() -> Bool {
        return _empty || _selfClosing
    }

    /**
     * Get if this is a pre-defined tag, or was auto created on parsing.
     *
     * @return if a known tag
     */
    @inline(__always)
    open func isKnownTag() -> Bool {
        Tag.tagsLock.lock()
        let result = Tag.tags[_tagName] != nil
        Tag.tagsLock.unlock()
        return result
    }

    /**
     * Check if this tagname is a known tag.
     *
     * @param tagName name of tag
     * @return if known HTML tag
     */
    @inline(__always)
    public static func isKnownTag(_ tagName: [UInt8]) -> Bool {
        Tag.tagsLock.lock()
        let result2 = Tag.tags[tagName] != nil
        Tag.tagsLock.unlock()
        return result2
    }

    /**
     * Get if this tag should preserve whitespace within child text nodes.
     *
     * @return if preserve whitepace
     */
    @inline(__always)
    public func preserveWhitespace() -> Bool {
        return _preserveWhitespace
    }

    /**
     * Get if this tag represents a control associated with a form. E.g. input, textarea, output
     * @return if associated with a form
     */
    @inline(__always)
    public func isFormListed() -> Bool {
        return _formList
    }

    /**
     * Get if this tag represents an element that should be submitted with a form. E.g. input, option
     * @return if submittable with a form
     */
    @inline(__always)
    public func isFormSubmittable() -> Bool {
        return _formSubmit
    }

    @inline(__always)
    @discardableResult
    func setSelfClosing() -> Tag {
        _selfClosing = true
        return self
    }

    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    static public func ==(lhs: Tag, rhs: Tag) -> Bool {
        let this = lhs
        let o = rhs
        if (this === o) {return true}
        if (type(of: this) != type(of: o)) {return false}

        let tag: Tag = o

        if (lhs._tagName != tag._tagName) {return false}
        if (lhs._canContainBlock != tag._canContainBlock) {return false}
        if (lhs._canContainInline != tag._canContainInline) {return false}
        if (lhs._empty != tag._empty) {return false}
        if (lhs._formatAsBlock != tag._formatAsBlock) {return false}
        if (lhs._isBlock != tag._isBlock) {return false}
        if (lhs._preserveWhitespace != tag._preserveWhitespace) {return false}
        if (lhs._selfClosing != tag._selfClosing) {return false}
        if (lhs._formList != tag._formList) {return false}
        return lhs._formSubmit == tag._formSubmit
    }

    public func equals(_ tag: Tag) -> Bool {
        return self == tag
    }

    /// The hash value.
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(_tagName)
        hasher.combine(_isBlock)
        hasher.combine(_formatAsBlock)
        hasher.combine(_canContainBlock)
        hasher.combine(_canContainInline)
        hasher.combine(_empty)
        hasher.combine(_selfClosing)
        hasher.combine(_preserveWhitespace)
        hasher.combine(_formList)
        hasher.combine(_formSubmit)
    }

    @inline(__always)
    open func toString() -> String {
        return String(decoding: _tagName, as: UTF8.self)
    }

    // internal static initialisers:
    // prepped from http://www.w3.org/TR/REC-html40/sgml/dtd.html and other sources
    private static let blockTags: [[UInt8]] = [
        "html", "head", "body", "frameset", "script", "noscript", "style", "meta", "link", "title", "frame",
        "noframes", "section", "nav", "aside", "hgroup", "header", "footer", "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "pre", "div", "blockquote", "hr", "address", "figure", "figcaption", "form", "fieldset", "ins",
        "del", "s", "dl", "dt", "dd", "li", "table", "caption", "thead", "tfoot", "tbody", "colgroup", "col", "tr", "th",
        "td", "video", "audio", "canvas", "details", "menu", "plaintext", "template", "article", "main",
        "svg", "math"
    ].map { $0.utf8Array }
    private static let inlineTags: [[UInt8]] = [
        "object", "base", "font", "tt", "i", "b", "u", "big", "small", "em", "strong", "dfn", "code", "samp", "kbd",
        "var", "cite", "abbr", "time", "acronym", "mark", "ruby", "rt", "rp", "a", "img", "br", "wbr", "map", "q",
        "sub", "sup", "bdo", "iframe", "embed", "span", "input", "select", "textarea", "label", "button", "optgroup",
        "option", "legend", "datalist", "keygen", "output", "progress", "meter", "area", "param", "source", "track",
        "summary", "command", "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track",
        "data", "bdi"
    ].map { $0.utf8Array }
    private static let emptyTags: [[UInt8]] = [
        "meta", "link", "base", "frame", "img", "br", "wbr", "embed", "hr", "input", "keygen", "col", "command",
        "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track"
    ].map { $0.utf8Array }
    private static let formatAsInlineTags: [[UInt8]] = [
        "title", "a", "p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "address", "li", "th", "td", "script", "style",
        "ins", "del", "s"
    ].map { $0.utf8Array }
    private static let preserveWhitespaceTags: [[UInt8]] = [
        "pre", "plaintext", "title", "textarea"
        // script is not here as it is a data node, which always preserve whitespace
    ].map { $0.utf8Array }
    // todo: I think we just need submit tags, and can scrub listed
    private static let formListedTags: [[UInt8]] = [
        "button", "fieldset", "input", "keygen", "object", "output", "select", "textarea"
    ].map { $0.utf8Array }
    private static let formSubmitTags: [[UInt8]] = [
        "input", "keygen", "object", "select", "textarea"
    ].map { $0.utf8Array }

    static private func initializeMaps() throws -> Dictionary<[UInt8], Tag> {
        var dict = Dictionary<[UInt8], Tag>()

        // creates
        for tagName in blockTags {
            let tag = Tag(tagName)
            dict[tag._tagName] = tag
        }
        for tagName in inlineTags {
            let tag = Tag(tagName)
            tag._isBlock = false
            tag._canContainBlock = false
            tag._formatAsBlock = false
            dict[tag._tagName] = tag
        }

        // mods:
        for tagName in emptyTags {
            let tag = dict[tagName]
            try Validate.notNull(obj: tag)
            tag?._canContainBlock = false
            tag?._canContainInline = false
            tag?._empty = true
        }

        for tagName in formatAsInlineTags {
            let tag = dict[tagName]
            try Validate.notNull(obj: tag)
            tag?._formatAsBlock = false
        }

        for tagName in preserveWhitespaceTags {
            let tag = dict[tagName]
            try Validate.notNull(obj: tag)
            tag?._preserveWhitespace = true
        }

        for tagName in formListedTags {
            let tag = dict[tagName]
            try Validate.notNull(obj: tag)
            tag?._formList = true
        }

        for tagName in formSubmitTags {
            let tag = dict[tagName]
            try Validate.notNull(obj: tag)
            tag?._formSubmit = true
        }
        return dict
    }
}
