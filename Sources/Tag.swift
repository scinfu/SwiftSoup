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
    private static let useUnknownTagCache: Bool = true
    private static let unknownTagCacheLimit: Int = 512
    private static let unknownTagCache = UnknownTagCache()

    // Fast known-tag lookups for common tag ids to avoid dictionary hashing on hot paths.
    private static let tagA = knownTags[UTF8Arrays.a]!
    private static let tagSpan = knownTags[UTF8Arrays.span]!
    private static let tagP = knownTags[UTF8Arrays.p]!
    private static let tagDiv = knownTags[UTF8Arrays.div]!
    private static let tagEm = knownTags[UTF8Arrays.em]!
    private static let tagStrong = knownTags[UTF8Arrays.strong]!
    private static let tagB = knownTags[UTF8Arrays.b]!
    private static let tagI = knownTags[UTF8Arrays.i]!
    private static let tagSmall = knownTags[UTF8Arrays.small]!
    private static let tagLi = knownTags[UTF8Arrays.li]!
    private static let tagBody = knownTags[UTF8Arrays.body]!
    private static let tagHtml = knownTags[UTF8Arrays.html]!
    private static let tagHead = knownTags[UTF8Arrays.head]!
    private static let tagTitle = knownTags[UTF8Arrays.title]!
    private static let tagForm = knownTags[UTF8Arrays.form]!
    private static let tagBr = knownTags[UTF8Arrays.br]!
    private static let tagMeta = knownTags[UTF8Arrays.meta]!
    private static let tagImg = knownTags[UTF8Arrays.img]!
    private static let tagScript = knownTags[UTF8Arrays.script]!
    private static let tagStyle = knownTags[UTF8Arrays.style]!
    private static let tagCaption = knownTags[UTF8Arrays.caption]!
    private static let tagCol = knownTags[UTF8Arrays.col]!
    private static let tagColgroup = knownTags[UTF8Arrays.colgroup]!
    private static let tagTable = knownTags[UTF8Arrays.table]!
    private static let tagTbody = knownTags[UTF8Arrays.tbody]!
    private static let tagThead = knownTags[UTF8Arrays.thead]!
    private static let tagTfoot = knownTags[UTF8Arrays.tfoot]!
    private static let tagTr = knownTags[UTF8Arrays.tr]!
    private static let tagTd = knownTags[UTF8Arrays.td]!
    private static let tagTh = knownTags[UTF8Arrays.th]!
    private static let tagInput = knownTags[UTF8Arrays.input]!
    private static let tagHr = knownTags[UTF8Arrays.hr]!
    private static let tagSelect = knownTags[UTF8Arrays.select]!
    private static let tagOption = knownTags[UTF8Arrays.option]!
    private static let tagOptgroup = knownTags[UTF8Arrays.optgroup]!
    private static let tagTextarea = knownTags[UTF8Arrays.textarea]!
    private static let tagNoscript = knownTags[UTF8Arrays.noscript]!
    private static let tagNoframes = knownTags[UTF8Arrays.noframes]!
    private static let tagPlaintext = knownTags[UTF8Arrays.plaintext]!
    private static let tagButton = knownTags[UTF8Arrays.button]!
    private static let tagBase = knownTags[UTF8Arrays.base]!
    private static let tagFrame = knownTags[UTF8Arrays.frame]!
    private static let tagFrameset = knownTags[UTF8Arrays.frameset]!
    private static let tagIframe = knownTags[UTF8Arrays.iframe]!
    private static let tagNoembed = knownTags[UTF8Arrays.noembed]!
    private static let tagEmbed = knownTags[UTF8Arrays.embed]!
    private static let tagDd = knownTags[UTF8Arrays.dd]!
    private static let tagDt = knownTags[UTF8Arrays.dt]!
    private static let tagDl = knownTags[UTF8Arrays.dl]!
    private static let tagOl = knownTags[UTF8Arrays.ol]!
    private static let tagUl = knownTags[UTF8Arrays.ul]!
    private static let tagPre = knownTags[UTF8Arrays.pre]!
    private static let tagListing = knownTags[UTF8Arrays.listing]!
    private static let tagAddress = knownTags[UTF8Arrays.address]!
    private static let tagArticle = knownTags[UTF8Arrays.article]!
    private static let tagAside = knownTags[UTF8Arrays.aside]!
    private static let tagBlockquote = knownTags[UTF8Arrays.blockquote]!
    private static let tagCenter = knownTags[UTF8Arrays.center]!
    private static let tagDir = knownTags[UTF8Arrays.dir]!
    private static let tagFieldset = knownTags[UTF8Arrays.fieldset]!
    private static let tagFigcaption = knownTags[UTF8Arrays.figcaption]!
    private static let tagFigure = knownTags[UTF8Arrays.figure]!
    private static let tagFooter = knownTags[UTF8Arrays.footer]!
    private static let tagHeader = knownTags[UTF8Arrays.header]!
    private static let tagHgroup = knownTags[UTF8Arrays.hgroup]!
    private static let tagMenu = knownTags[UTF8Arrays.menu]!
    private static let tagNav = knownTags[UTF8Arrays.nav]!
    private static let tagSection = knownTags[UTF8Arrays.section]!
    private static let tagSummary = knownTags[UTF8Arrays.summary]!
    private static let tagH1 = knownTags[UTF8Arrays.h1]!
    private static let tagH2 = knownTags[UTF8Arrays.h2]!
    private static let tagH3 = knownTags[UTF8Arrays.h3]!
    private static let tagH4 = knownTags[UTF8Arrays.h4]!
    private static let tagH5 = knownTags[UTF8Arrays.h5]!
    private static let tagH6 = knownTags[UTF8Arrays.h6]!
    private static let tagApplet = knownTags[UTF8Arrays.applet]!
    private static let tagMarquee = knownTags[UTF8Arrays.marquee]!
    private static let tagObject = knownTags[UTF8Arrays.object]!
    private static let tagRuby = knownTags[UTF8Arrays.ruby]!
    private static let tagRp = knownTags[UTF8Arrays.rp]!
    private static let tagRt = knownTags[UTF8Arrays.rt]!

    
    #if DEBUG
    /// Compile-time check that the ``knownTags`` dictionary really is `Sendable`.
    private static let sendableCheck: any Sendable = knownTags
    #endif

    private final class UnknownTagCache: @unchecked Sendable {
        let lock = Mutex()
        var tags: [Array<UInt8>: Tag] = [:]
        var selfClosingTags: [Array<UInt8>: Tag] = [:]
    }
    
    
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
    internal let tagId: Token.Tag.TagId

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
        self.tagId = Token.Tag.tagIdForBytes(self.tagNameNormal) ?? .none
    }
    
    /**
     Get this tag's name.
     
     - returns: the tag's name
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
     Get a Tag by name. If not previously defined (unknown), returns a new generic tag, that can do anything.
     
     Pre-defined tags (P, DIV etc) will be ==, but unknown tags are not registered and will only .equals().
     
     - parameter tagName: Name of tag, e.g. "p". Case insensitive.
     - parameter settings: used to control tag name sensitivity
     - returns: The tag, either defined or new generic.
     */
    public static func valueOf(_ tagName: String, _ settings: ParseSettings) throws -> Tag {
        return try valueOf(tagName.utf8Array, settings, isSelfClosing: false)
    }
    
    public static func valueOf(_ tagName: [UInt8], _ settings: ParseSettings) throws -> Tag {
        return try valueOf(tagName, settings, isSelfClosing: false)
    }

    @inline(__always)
    internal static func valueOfNormalized(_ normalizedTagName: [UInt8], isSelfClosing: Bool = false) throws -> Tag {
        if let tag = Self.knownTags[normalizedTagName] {
            return tag
        }
        if let cached = cachedUnknownTag(normalizedTagName, isSelfClosing: isSelfClosing) {
            return cached
        }
        try Validate.notEmpty(string: normalizedTagName)
        // not defined: create default; go anywhere, do anything! (incl be inside a <p>)
        var traits = Traits.forBlockTag
        traits.isBlock = false
        traits.selfClosing = isSelfClosing
        let tag = Tag(normalizedTagName, traits: traits)
        storeUnknownTag(normalizedTagName, isSelfClosing: isSelfClosing, tag)
        return tag
    }

    @inline(__always)
    internal static func valueOfTagId(_ tagId: Token.Tag.TagId) -> Tag? {
        switch tagId {
        case .a:
            return tagA
        case .span:
            return tagSpan
        case .p:
            return tagP
        case .div:
            return tagDiv
        case .em:
            return tagEm
        case .strong:
            return tagStrong
        case .b:
            return tagB
        case .i:
            return tagI
        case .small:
            return tagSmall
        case .li:
            return tagLi
        case .body:
            return tagBody
        case .html:
            return tagHtml
        case .head:
            return tagHead
        case .title:
            return tagTitle
        case .form:
            return tagForm
        case .br:
            return tagBr
        case .meta:
            return tagMeta
        case .img:
            return tagImg
        case .script:
            return tagScript
        case .style:
            return tagStyle
        case .caption:
            return tagCaption
        case .col:
            return tagCol
        case .colgroup:
            return tagColgroup
        case .table:
            return tagTable
        case .tbody:
            return tagTbody
        case .thead:
            return tagThead
        case .tfoot:
            return tagTfoot
        case .tr:
            return tagTr
        case .td:
            return tagTd
        case .th:
            return tagTh
        case .input:
            return tagInput
        case .hr:
            return tagHr
        case .select:
            return tagSelect
        case .option:
            return tagOption
        case .optgroup:
            return tagOptgroup
        case .textarea:
            return tagTextarea
        case .noscript:
            return tagNoscript
        case .noframes:
            return tagNoframes
        case .plaintext:
            return tagPlaintext
        case .button:
            return tagButton
        case .base:
            return tagBase
        case .frame:
            return tagFrame
        case .frameset:
            return tagFrameset
        case .iframe:
            return tagIframe
        case .noembed:
            return tagNoembed
        case .embed:
            return tagEmbed
        case .dd:
            return tagDd
        case .dt:
            return tagDt
        case .dl:
            return tagDl
        case .ol:
            return tagOl
        case .ul:
            return tagUl
        case .pre:
            return tagPre
        case .listing:
            return tagListing
        case .address:
            return tagAddress
        case .article:
            return tagArticle
        case .aside:
            return tagAside
        case .blockquote:
            return tagBlockquote
        case .center:
            return tagCenter
        case .dir:
            return tagDir
        case .fieldset:
            return tagFieldset
        case .figcaption:
            return tagFigcaption
        case .figure:
            return tagFigure
        case .footer:
            return tagFooter
        case .header:
            return tagHeader
        case .hgroup:
            return tagHgroup
        case .menu:
            return tagMenu
        case .nav:
            return tagNav
        case .section:
            return tagSection
        case .summary:
            return tagSummary
        case .h1:
            return tagH1
        case .h2:
            return tagH2
        case .h3:
            return tagH3
        case .h4:
            return tagH4
        case .h5:
            return tagH5
        case .h6:
            return tagH6
        case .applet:
            return tagApplet
        case .marquee:
            return tagMarquee
        case .object:
            return tagObject
        case .ruby:
            return tagRuby
        case .rp:
            return tagRp
        case .rt:
            return tagRt
        case .none:
            return nil
        }
    }

    @inline(__always)
    internal static func isBr(_ tag: Tag) -> Bool {
        return tag === tagBr
    }

    @inline(__always)
    internal static func isScriptOrStyle(_ tag: Tag) -> Bool {
        return tag === tagScript || tag === tagStyle
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
        if let cached = cachedUnknownTag(normalizedTagName, isSelfClosing: isSelfClosing) {
            return cached
        }
        
        // not defined: create default; go anywhere, do anything! (incl be inside a <p>)
        var traits = Traits.forBlockTag
        traits.isBlock = false
        traits.selfClosing = isSelfClosing
        let tag = Tag(normalizedTagName, traits: traits)
        storeUnknownTag(normalizedTagName, isSelfClosing: isSelfClosing, tag)
        return tag
    }

    @inline(__always)
    private static func cachedUnknownTag(_ normalizedTagName: [UInt8], isSelfClosing: Bool) -> Tag? {
        guard useUnknownTagCache else { return nil }
        unknownTagCache.lock.lock()
        let tag = isSelfClosing
            ? unknownTagCache.selfClosingTags[normalizedTagName]
            : unknownTagCache.tags[normalizedTagName]
        unknownTagCache.lock.unlock()
        return tag
    }

    @inline(__always)
    private static func storeUnknownTag(_ normalizedTagName: [UInt8], isSelfClosing: Bool, _ tag: Tag) {
        guard useUnknownTagCache else { return }
        unknownTagCache.lock.lock()
        if isSelfClosing {
            if unknownTagCache.selfClosingTags.count >= unknownTagCacheLimit {
                unknownTagCache.selfClosingTags.removeAll(keepingCapacity: true)
            }
            unknownTagCache.selfClosingTags[normalizedTagName] = tag
        } else {
            if unknownTagCache.tags.count >= unknownTagCacheLimit {
                unknownTagCache.tags.removeAll(keepingCapacity: true)
            }
            unknownTagCache.tags[normalizedTagName] = tag
        }
        unknownTagCache.lock.unlock()
    }

    /**
     Get a Tag by name. If not previously defined (unknown), returns a new generic tag, that can do anything.
     
     Pre-defined tags (P, DIV etc) will be ==, but unknown tags are not registered and will only .equals().
     
     - parameter tagName: Name of tag, e.g. "p". **Case sensitive.**
     - returns: The tag, either defined or new generic.
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
     Gets if this is a block tag.
     
     - returns: if block tag
     */
    @inline(__always)
    open func isBlock() -> Bool {
        return traits.isBlock
    }

    /**
     Gets if this tag should be formatted as a block (or as inline)
     
     - returns: if should be formatted as block or inline
     */
    @inline(__always)
    open func formatAsBlock() -> Bool {
        return traits.formatAsBlock
    }

    /**
     Gets if this tag can contain block tags.
     
     - returns: if tag can contain block tags
     */
    @inline(__always)
    open func canContainBlock() -> Bool {
        return traits.canContainBlock
    }

    /**
     Gets if this tag is an inline tag.
     
     - returns: if this tag is an inline tag.
     */
    @inline(__always)
    open func isInline() -> Bool {
        return !traits.isBlock
    }

    /**
     Gets if this tag is a data only tag.
     
     - returns: if this tag is a data only tag
     */
    @inline(__always)
    open func isData() -> Bool {
        return !traits.canContainInline && !isEmpty()
    }

    /**
     Get if this is an empty tag
     
     - returns: if this is an empty tag
     */
    @inline(__always)
    open func isEmpty() -> Bool {
        return traits.empty
    }

    /**
     Get if this tag is self closing.
     
     - returns: if this tag should be output as self closing.
     */
    @inline(__always)
    open func isSelfClosing() -> Bool {
        return traits.empty || traits.selfClosing
    }

    /**
     Get if this is a pre-defined tag, or was auto created on parsing.
     
     - returns: if a known tag
     */
    @inline(__always)
    open func isKnownTag() -> Bool {
        return Self.knownTags[tagName] != nil
    }

    /**
     Check if this tagname is a known tag.
     
     - parameter tagName: name of tag
     - returns: if known HTML tag
     */
    @inline(__always)
    public static func isKnownTag(_ tagName: [UInt8]) -> Bool {
        return Self.knownTags[tagName] != nil
    }

    /**
     Get if this tag should preserve whitespace within child text nodes.
     
     - returns: if preserve whitepace
     */
    @inline(__always)
    public func preserveWhitespace() -> Bool {
        return traits.preserveWhitespace
    }

    /**
     Get if this tag represents a control associated with a form. E.g. input, textarea, output
     - returns: if associated with a form
     */
    @inline(__always)
    public func isFormListed() -> Bool {
        return traits.formList
    }

    /**
     Get if this tag represents an element that should be submitted with a form. E.g. input, option
     - returns: if submittable with a form
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
        "noframes", "noembed", "section", "nav", "aside", "hgroup", "header", "footer", "p", "h1", "h2", "h3", "h4", "h5", "h6",
        "ul", "ol", "pre", "listing", "div", "blockquote", "hr", "address", "figure", "figcaption", "form", "fieldset",
        "center", "dir", "applet", "marquee", "ins",
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
