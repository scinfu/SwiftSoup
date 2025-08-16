//
//  Tag.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 15/10/16.
//

import Foundation

open class Tag: Hashable, @unchecked Sendable {
    // Removed duplicate == and hash(into:) to fix redeclaration errors
    
    private static let knownTags: Dictionary<[UInt8], Tag> = {
        do {
            return try initializeMaps()
        } catch {
            preconditionFailure("Cannot initialize known tags: \(error)")
        }
    }()
    
    #if DEBUG
    /// Compile-time check that the ``knownTags`` dictionary really is `Sendable`.
    private static let sendableCheck: any Sendable = knownTags
    #endif
    
    
    /// Tag traits.
    internal struct Traits: Sendable, Hashable {
        /// block or inline
        var isBlock: Bool
        /// should be formatted as a block
        var formatAsBlock: Bool
        /// Can this tag hold block level tags?
        var canContainBlock: Bool
        /// only pcdata if not
        var canContainInline: Bool
        /// can hold nothing e.g. img
        var empty: Bool
        /// can self close (<foo />). used for unknown tags that self close, without forcing them as empty.
        var selfClosing: Bool
        /// for pre, textarea, script etc
        var preserveWhitespace: Bool
        /// a control that appears in forms: input, textarea, output etc
        var formList: Bool
        /// a control that can be submitted in a form: input etc
        var formSubmit: Bool
        
        static let forBlockTag = Traits(isBlock: true, formatAsBlock: true, canContainBlock: true, canContainInline: true, empty: false, selfClosing: false, preserveWhitespace: false, formList: false, formSubmit: false)
        
        static let forInlineTag = Traits(isBlock: false, formatAsBlock: false, canContainBlock: false, canContainInline: true, empty: false, selfClosing: false, preserveWhitespace: false, formList: false, formSubmit: false)

    }

    fileprivate let tagName: [UInt8]
    fileprivate let tagNameNormal: [UInt8]
    fileprivate let traits: Traits

    public convenience init(_ tagName: [UInt8]) {
        self.init(tagName, traits: .forBlockTag)
    }
    
    public convenience init(_ tagName: String) {
        self.init(tagName.utf8Array, traits: .forBlockTag)
    }

    private init(_ tagName: [UInt8], traits: Traits) {
        self.tagName = tagName
        self.tagNameNormal = tagName.lowercased()
        self.traits = traits
    }
    
    /**
     * Get this tag's name.
     *
     * @return the tag's name
     */
    open func getName() -> String {
        return String(decoding: self.tagName, as: UTF8.self)
    }
    open func getNameNormal() -> String {
        return String(decoding: self.tagNameNormal, as: UTF8.self)
    }
    open func getNameUTF8() -> [UInt8] {
        return self.tagName
    }
    open func getNameNormalUTF8() -> [UInt8] {
        return self.tagNameNormal
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
        return try valueOf(tagName.utf8Array, settings, isSelfClosing: false)
    }
    
    public static func valueOf(_ tagName: [UInt8], _ settings: ParseSettings) throws -> Tag {
        return try valueOf(tagName, settings, isSelfClosing: false)
    }
    
    internal static func valueOf(_ tagName: [UInt8], _ settings: ParseSettings, isSelfClosing: Bool) throws -> Tag {
        if let tag = Self.knownTags[tagName] {
            return tag
        }
        
        let normalizedTagName = settings.normalizeTag(tagName)
        try Validate.notEmpty(string: normalizedTagName)
        
        if let tag = Self.knownTags[normalizedTagName] {
            return tag
        }
        
        // not defined: create default; go anywhere, do anything! (incl be inside a <p>)
        var traits = Traits.forBlockTag
        traits.isBlock = false
        traits.selfClosing = isSelfClosing
        return Tag(normalizedTagName, traits: traits)
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
        return traits.isBlock
    }

    /**
     * Gets if this tag should be formatted as a block (or as inline)
     *
     * @return if should be formatted as block or inline
     */
    @inline(__always)
    open func formatAsBlock() -> Bool {
        return traits.formatAsBlock
    }

    /**
     * Gets if this tag can contain block tags.
     *
     * @return if tag can contain block tags
     */
    @inline(__always)
    open func canContainBlock() -> Bool {
        return traits.canContainBlock
    }

    /**
     * Gets if this tag is an inline tag.
     *
     * @return if this tag is an inline tag.
     */
    @inline(__always)
    open func isInline() -> Bool {
        return !traits.isBlock
    }

    /**
     * Gets if this tag is a data only tag.
     *
     * @return if this tag is a data only tag
     */
    @inline(__always)
    open func isData() -> Bool {
        return !traits.canContainInline && !isEmpty()
    }

    /**
     * Get if this is an empty tag
     *
     * @return if this is an empty tag
     */
    @inline(__always)
    open func isEmpty() -> Bool {
        return traits.empty
    }

    /**
     * Get if this tag is self closing.
     *
     * @return if this tag should be output as self closing.
     */
    @inline(__always)
    open func isSelfClosing() -> Bool {
        return traits.empty || traits.selfClosing
    }

    /**
     * Get if this is a pre-defined tag, or was auto created on parsing.
     *
     * @return if a known tag
     */
    @inline(__always)
    open func isKnownTag() -> Bool {
        return Self.knownTags[tagName] != nil
    }

    /**
     * Check if this tagname is a known tag.
     *
     * @param tagName name of tag
     * @return if known HTML tag
     */
    @inline(__always)
    public static func isKnownTag(_ tagName: [UInt8]) -> Bool {
        return Self.knownTags[tagName] != nil
    }

    /**
     * Get if this tag should preserve whitespace within child text nodes.
     *
     * @return if preserve whitepace
     */
    @inline(__always)
    public func preserveWhitespace() -> Bool {
        return traits.preserveWhitespace
    }

    /**
     * Get if this tag represents a control associated with a form. E.g. input, textarea, output
     * @return if associated with a form
     */
    @inline(__always)
    public func isFormListed() -> Bool {
        return traits.formList
    }

    /**
     * Get if this tag represents an element that should be submitted with a form. E.g. input, option
     * @return if submittable with a form
     */
    @inline(__always)
    public func isFormSubmittable() -> Bool {
        return traits.formSubmit
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
        if lhs === rhs {
            return true
        }
        return lhs.tagName == rhs.tagName && lhs.traits == rhs.traits
    }
    
    public func equals(_ tag: Tag) -> Bool {
        return self == tag
    }

    /// The hash value.
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    public func hash(into hasher: inout Hasher) {
        hasher.combine(tagName)
        hasher.combine(traits)
    }

    @inline(__always)
    open func toString() -> String {
        return String(decoding: tagName, as: UTF8.self)
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
    private static let emptyTags: Set<[UInt8]> = Set([
        "meta", "link", "base", "frame", "img", "br", "wbr", "embed", "hr", "input", "keygen", "col", "command",
        "device", "area", "basefont", "bgsound", "menuitem", "param", "source", "track"
    ].map { $0.utf8Array })
    private static let formatAsInlineTags: Set<[UInt8]> = Set([
        "title", "a", "p", "h1", "h2", "h3", "h4", "h5", "h6", "pre", "address", "li", "th", "td", "script", "style",
        "ins", "del", "s"
    ].map { $0.utf8Array })
    private static let preserveWhitespaceTags: Set<[UInt8]> = Set([
        "pre", "plaintext", "title", "textarea"
        // script is not here as it is a data node, which always preserve whitespace
    ].map { $0.utf8Array })
    // todo: I think we just need submit tags, and can scrub listed
    private static let formListedTags: Set<[UInt8]> = Set([
        "button", "fieldset", "input", "keygen", "object", "output", "select", "textarea"
    ].map { $0.utf8Array })
    private static let formSubmitTags: Set<[UInt8]> = Set([
        "input", "keygen", "object", "select", "textarea"
    ].map { $0.utf8Array })

    static private func initializeMaps() throws -> Dictionary<[UInt8], Tag> {
        var dict = Dictionary<[UInt8], Tag>()
        
        func traits(for tagName: [UInt8], basedOn: Traits) -> Traits {
            var result = basedOn
            if emptyTags.contains(tagName) {
                result.canContainBlock = false
                result.canContainInline = false
                result.empty = true
            }
            if formatAsInlineTags.contains(tagName) {
                result.formatAsBlock = false
            }
            if preserveWhitespaceTags.contains(tagName) {
                result.preserveWhitespace = true
            }
            if formListedTags.contains(tagName) {
                result.formList = true
            }
            if formSubmitTags.contains(tagName) {
                result.formSubmit = true
            }
            return result
        }
        
        for tagName in blockTags {
            let tag = Tag(tagName, traits: traits(for: tagName, basedOn: .forBlockTag))
            dict[tag.tagName] = tag
        }
        for tagName in inlineTags {
            let tag = Tag(tagName, traits: traits(for: tagName, basedOn: .forInlineTag))
            dict[tag.tagName] = tag
        }
        
        return dict
    }
}
