//
//  Tag.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 15/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class Tag: Hashable {
    // map of known tags
    static var tags: Dictionary<String, Tag> = {
        do {
            return try Tag.initializeMaps()
        } catch {
            preconditionFailure("This method must be overridden")
        }
        return Dictionary<String, Tag>()
    }()

    fileprivate var _tagName: String
    fileprivate var _tagNameNormal: String
    fileprivate var _isBlock: Bool = true // block or inline
    fileprivate var _formatAsBlock: Bool = true // should be formatted as a block
    fileprivate var _canContainBlock: Bool = true // Can this tag hold block level tags?
    fileprivate var _canContainInline: Bool = true // only pcdata if not
    fileprivate var _empty: Bool = false // can hold nothing e.g. img
    fileprivate var _selfClosing: Bool = false // can self close (<foo />). used for unknown tags that self close, without forcing them as empty.
    fileprivate var _preserveWhitespace: Bool = false // for pre, textarea, script etc
    fileprivate var _formList: Bool = false // a control that appears in forms: input, textarea, output etc
    fileprivate var _formSubmit: Bool = false // a control that can be submitted in a form: input etc

    public init(_ tagName: String) {
        self._tagName = tagName
        self._tagNameNormal = tagName.lowercased()
    }

    /**
     * Get this tag's name.
     *
     * @return the tag's name
     */
    open func getName() -> String {
        return self._tagName
    }
    open func getNameNormal() -> String {
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
    public static func valueOf(_ tagName: String, _ settings: ParseSettings)throws->Tag {
        var tagName = tagName
        var tag: Tag? = Tag.tags[tagName]

        if (tag == nil) {
            tagName = settings.normalizeTag(tagName)
            try Validate.notEmpty(string: tagName)
            tag = Tag.tags[tagName]

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
    public static func valueOf(_ tagName: String)throws->Tag {
        return try valueOf(tagName, ParseSettings.preserveCase)
    }

    /**
     * Gets if this is a block tag.
     *
     * @return if block tag
     */
    open func isBlock() -> Bool {
        return _isBlock
    }

    /**
     * Gets if this tag should be formatted as a block (or as inline)
     *
     * @return if should be formatted as block or inline
     */
    open func formatAsBlock() -> Bool {
        return _formatAsBlock
    }

    /**
     * Gets if this tag can contain block tags.
     *
     * @return if tag can contain block tags
     */
    open func canContainBlock() -> Bool {
        return _canContainBlock
    }

    /**
     * Gets if this tag is an inline tag.
     *
     * @return if this tag is an inline tag.
     */
    open func isInline() -> Bool {
        return !_isBlock
    }

    /**
     * Gets if this tag is a data only tag.
     *
     * @return if this tag is a data only tag
     */
    open func isData() -> Bool {
        return !_canContainInline && !isEmpty()
    }

    /**
     * Get if this is an empty tag
     *
     * @return if this is an empty tag
     */
    open func isEmpty() -> Bool {
        return _empty
    }

    /**
     * Get if this tag is self closing.
     *
     * @return if this tag should be output as self closing.
     */
    open func isSelfClosing() -> Bool {
        return _empty || _selfClosing
    }

    /**
     * Get if this is a pre-defined tag, or was auto created on parsing.
     *
     * @return if a known tag
     */
    open func isKnownTag() -> Bool {
        return Tag.tags[_tagName] != nil
    }

    /**
     * Check if this tagname is a known tag.
     *
     * @param tagName name of tag
     * @return if known HTML tag
     */
    public static func isKnownTag(_ tagName: String) -> Bool {
        return Tag.tags[tagName] != nil
    }

    /**
     * Get if this tag should preserve whitespace within child text nodes.
     *
     * @return if preserve whitepace
     */
    public func preserveWhitespace() -> Bool {
        return _preserveWhitespace
    }

    /**
     * Get if this tag represents a control associated with a form. E.g. input, textarea, output
     * @return if associated with a form
     */
    public func isFormListed() -> Bool {
        return _formList
    }

    /**
     * Get if this tag represents an element that should be submitted with a form. E.g. input, option
     * @return if submittable with a form
     */
    public func isFormSubmittable() -> Bool {
        return _formSubmit
    }

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

    open func toString() -> String {
        return _tagName
    }

    // internal static initialisers:
    // prepped from http://www.w3.org/TR/REC-html40/sgml/dtd.html and other sources
    private static let blockTags: [String] = [
        "html", "head", "body", "frameset", "script", "noscript", "style", "meta", "link", "title", "frame",
        "noframes", "section", "nav", "aside", "hgroup", "header", "footer", "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "pre", "div", "blockquote", "hr", "address", "figure", "figcaption", "form", "fieldset", "ins",
        "del", "s", "dl", "dt", "dd", "li", "table", "caption", "thead", "tfoot", "tbody", "colgroup", "col", "tr", "th",
        "td", "video", "audio", "canvas", "details", "menu", "plaintext", "template", "article", "main",
        "svg", "math"
    ]
    private static let inlineTags: [String] = [
        "object", "base", "font", "tt", "i", "b", "u", "big", "small", "em", "strong", "dfn", "code", "samp", "kbd",
        "var", "cite", "abbr", "time", "acronym", "mark", "ruby", "rt", "rp", "a", "img", "br", "wbr", "map", "q",
        "sub", "sup", "bdo", "iframe", "embed", "span", "input", "select", "textarea", "label", "button", "optgroup",
        "option", "legend", "datalist", "keygen", "output", "progress", "meter", "area", "param", "source", "track",
        "summary", "command", "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track",
        "data", "bdi"
    ]
    private static let emptyTags: [String] = [
        "meta", "link", "base", "frame", "img", "br", "wbr", "embed", "hr", "input", "keygen", "col", "command",
        "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track"
    ]
    private static let formatAsInlineTags: [String] = [
        "title", "a", "p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "address", "li", "th", "td", "script", "style",
        "ins", "del", "s"
    ]
    private static let preserveWhitespaceTags: [String] = [
        "pre", "plaintext", "title", "textarea"
        // script is not here as it is a data node, which always preserve whitespace
    ]
    // todo: I think we just need submit tags, and can scrub listed
    private static let formListedTags: [String] = [
        "button", "fieldset", "input", "keygen", "object", "output", "select", "textarea"
    ]
    private static let formSubmitTags: [String] = [
        "input", "keygen", "object", "select", "textarea"
    ]

    static private func initializeMaps()throws->Dictionary<String, Tag> {
        var dict = Dictionary<String, Tag>()

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
