//
//  Whitelist.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//

/*
 Thank you to Ryan Grove (wonko.com) for the Ruby HTML cleaner http://github.com/rgrove/sanitize/, which inspired
 this whitelist configuration, and the initial defaults.
 */


import Foundation

/**
 Whitelists define what HTML (elements and attributes) to allow through the cleaner. Everything else is removed.
 
 Start with one of the defaults:
 
 * ``none()``
 * ``simpleText()``
 * ``basic()``
 * ``basicWithImages()``
 * ``relaxed()``
 
 If you need to allow more through (please be careful!), tweak a base whitelist with:
 
 * ``addTags(_:)``
 * ``addAttributes(_:_:)``
 * ``addCSSProperties(_:_:)``
 * ``addEnforcedAttribute(_:_:_:)``
 * ``addProtocols(_:_:_:)``
 
 You can remove any setting from an existing whitelist with:
 
 * ``removeTags(_:)``
 * ``removeAttributes(_:_:)``
 * ``removeCSSProperties(_:_:)``
 * ``removeEnforcedAttribute(_:_:)``
 * ``removeProtocols(_:_:_:)``
 
 The cleaner and these whitelists assume that you want to clean a `body` fragment of HTML (to add user
 supplied HTML into a templated page), and not to clean a full HTML document. If the latter is the case, either wrap the
 document HTML around the cleaned body HTML, or create a whitelist that allows `html` and `head`
 elements as appropriate.
 
 If you are going to extend a whitelist, please be very careful. Make sure you understand what attributes may lead to
 XSS attack vectors. URL attributes are particularly vulnerable and require careful validation. See
 http://ha.ckers.org/xss.html for some XSS attack examples.
 */
 public class Whitelist {

    /// Controls how whitespace in URL attributes is handled during sanitization.
    public enum URLWhitespaceMode {
        /// No trimming; URL attributes with leading/trailing whitespace will have those attributes removed.
        case strict
        /// Trim whitespace for both validation and output.
        case trim
        /// Trim whitespace for validation, but preserve original whitespace in output. This is the default.
        case allow

        func prepareForValidation(_ value: [UInt8]) -> [UInt8] {
            switch self {
            case .strict: value
            case .trim, .allow: value.trim()
            }
        }

        func prepareForOutput(_ value: [UInt8]) -> [UInt8] {
            switch self {
            case .trim: value.trim()
            case .strict, .allow: value
            }
        }
    }

    private var tagNames: Set<TagName> // tags allowed, lower case. e.g. [p, br, span]
    private var attributes: Dictionary<TagName, Set<AttributeKey>> // tag -> attribute[]. allowed attributes [href] for a tag.
    private var cssProperties: Dictionary<TagName, Set<CSSPropertyName>> // tag -> allowed CSS properties for inline style attributes.
    private var enforcedAttributes: Dictionary<TagName, Dictionary<AttributeKey, AttributeValue>> // always set these attribute values
    private var protocols: Dictionary<TagName, Dictionary<AttributeKey, Set<Protocol>>> // allowed URL protocols for attributes
    private var preserveRelativeLinks: Bool  // option to preserve relative links
    private var urlWhitespaceMode: URLWhitespaceMode

    /**
     This whitelist allows only text nodes: all HTML will be stripped.
     
     - returns: whitelist
     */
    public static func none() -> Whitelist {
        return Whitelist()
    }

    /**
     This whitelist allows only simple text formatting: `b, em, i, strong, u`. All other HTML (tags and
     attributes) will be removed.
     
     - returns: whitelist
     */
    public static func simpleText()throws ->Whitelist {
        return try Whitelist().addTags("b", "em", "i", "strong", "u")
    }

    /**
     This whitelist allows a fuller range of text nodes: `a, b, blockquote, br, cite, code, dd, dl, dt, em, i, li,
     ol, p, pre, q, small, span, strike, strong, sub, sup, u, ul`, and appropriate attributes.
     
     Links (`a` elements) can point to `http, https, ftp, mailto`, and have an enforced
     `rel=nofollow` attribute.
     
     Does not allow images.
     
     - returns: whitelist
     */
    public static func basic()throws->Whitelist {
        return try Whitelist()
            .addTags(
                "a", "b", "blockquote", "br", "cite", "code", "dd", "dl", "dt", "em",
                "i", "li", "ol", "p", "pre", "q", "small", "span", "strike", "strong", "sub",
                "sup", "u", "ul")

            .addAttributes("a", "href")
            .addAttributes("blockquote", "cite")
            .addAttributes("q", "cite")

            .addProtocols("a", "href", "ftp", "http", "https", "mailto")
            .addProtocols("blockquote", "cite", "http", "https")
            .addProtocols("cite", "cite", "http", "https")

            .addEnforcedAttribute("a", "rel", "nofollow")
    }

    /**
     This whitelist allows the same text tags as ``basic()``, and also allows `img` tags, with appropriate
     attributes, with `src` pointing to `http` or `https`.
     
     - returns: whitelist
     */
    public static func basicWithImages()throws->Whitelist {
        return try basic()
            .addTags("img")
            .addAttributes("img", "align", "alt", "height", "src", "title", "width")
            .addProtocols("img", "src", "http", "https")

    }

    /**
     This whitelist allows a full range of text and structural body HTML: `a, b, blockquote, br, caption, cite,
     code, col, colgroup, dd, div, dl, dt, em, h1, h2, h3, h4, h5, h6, i, img, li, ol, p, pre, q, small, span, strike, strong, sub,
     sup, table, tbody, td, tfoot, th, thead, tr, u, ul`
     
     Links do not have an enforced `rel=nofollow` attribute, but you can add that if desired.
     
     - returns: whitelist
     */
    public static func relaxed()throws->Whitelist {
        return try Whitelist()
            .addTags(
                "a", "b", "blockquote", "br", "caption", "cite", "code", "col",
                "colgroup", "dd", "div", "dl", "dt", "em", "h1", "h2", "h3", "h4", "h5", "h6",
                "i", "img", "li", "ol", "p", "pre", "q", "small", "span", "strike", "strong",
                "sub", "sup", "table", "tbody", "td", "tfoot", "th", "thead", "tr", "u",
                "ul")

            .addAttributes("a", "href", "title")
            .addAttributes("blockquote", "cite")
            .addAttributes("col", "span", "width")
            .addAttributes("colgroup", "span", "width")
            .addAttributes("img", "align", "alt", "height", "src", "title", "width")
            .addAttributes("ol", "start", "type")
            .addAttributes("q", "cite")
            .addAttributes("table", "summary", "width")
            .addAttributes("td", "abbr", "axis", "colspan", "rowspan", "width")
            .addAttributes(
                "th", "abbr", "axis", "colspan", "rowspan", "scope",
                "width")
            .addAttributes("ul", "type")

            .addProtocols("a", "href", "ftp", "http", "https", "mailto")
            .addProtocols("blockquote", "cite", "http", "https")
            .addProtocols("cite", "cite", "http", "https")
            .addProtocols("img", "src", "http", "https")
            .addProtocols("q", "cite", "http", "https")
    }

    /**
     Create a new, empty whitelist. Generally it will be better to start with a default prepared whitelist instead.
     
     - seealso: ``basic()``, ``basicWithImages()``, ``simpleText()``, ``relaxed()``
     */
    init() {
        tagNames = Set<TagName>()
        attributes = Dictionary<TagName, Set<AttributeKey>>()
        cssProperties = Dictionary<TagName, Set<CSSPropertyName>>()
        enforcedAttributes = Dictionary<TagName, Dictionary<AttributeKey, AttributeValue>>()
        protocols = Dictionary<TagName, Dictionary<AttributeKey, Set<Protocol>>>()
        preserveRelativeLinks = false
        urlWhitespaceMode = .allow
    }

    /**
     Add a list of allowed elements to a whitelist. (If a tag is not allowed, it will be removed from the HTML.)
     
     - parameter tags: tag names to allow
     - returns: this (for chaining)
     */
    @discardableResult
    open func addTags(_ tags: String...) throws -> Whitelist {
        for tagName in tags {
            try Validate.notEmpty(string: tagName)
            tagNames.insert(TagName.valueOf(tagName))
        }
        return self
    }

    /**
     Remove a list of allowed elements from a whitelist. (If a tag is not allowed, it will be removed from the HTML.)
     
     - parameter tags: tag names to disallow
     - returns: this (for chaining)
     */
    @discardableResult
    open func removeTags(_ tags: String...) throws -> Whitelist {
        try Validate.notNull(obj: tags)

        for tag in tags {
            try Validate.notEmpty(string: tag)
            let tagName: TagName = TagName.valueOf(tag)

            if(tagNames.contains(tagName)) { // Only look in sub-maps if tag was allowed
                tagNames.remove(tagName)
                attributes.removeValue(forKey: tagName)
                cssProperties.removeValue(forKey: tagName)
                enforcedAttributes.removeValue(forKey: tagName)
                protocols.removeValue(forKey: tagName)
            }
        }
        return self
    }

    /**
     Add a list of allowed CSS properties to the `style` attribute for a tag.

     To make CSS properties valid for <b>all tags</b>, use the pseudo tag `:all`.

     - parameter tag: The tag the CSS properties are for. The tag will be added to the allowed tag list if necessary.
     - parameter properties: List of valid CSS properties for inline styles on the tag
     - returns: this (for chaining)
     */
    @discardableResult
    open func addCSSProperties(_ tag: String, _ properties: String...) throws -> Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.isTrue(val: !properties.isEmpty, msg: "No CSS properties supplied.")

        let tagName = TagName.valueOf(tag)
        if !tagNames.contains(tagName) {
            tagNames.insert(tagName)
        }

        var propertySet = cssProperties[tagName] ?? Set<CSSPropertyName>()
        for property in properties {
            try Validate.notEmpty(string: property)
            propertySet.insert(CSSPropertyName.valueOf(property))
        }
        cssProperties[tagName] = propertySet

        return self
    }

    /**
     Remove a list of allowed CSS properties from the `style` attribute for a tag.

     To make CSS properties invalid for <b>all tags</b>, use the pseudo tag `:all`.

     - parameter tag: The tag the CSS properties are for.
     - parameter properties: List of invalid CSS properties for inline styles on the tag
     - returns: this (for chaining)
     */
    @discardableResult
    open func removeCSSProperties(_ tag: String, _ properties: String...) throws -> Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.isTrue(val: !properties.isEmpty, msg: "No CSS properties supplied.")

        let tagName = TagName.valueOf(tag)
        var propertySet = Set<CSSPropertyName>()
        for property in properties {
            try Validate.notEmpty(string: property)
            propertySet.insert(CSSPropertyName.valueOf(property))
        }

        if tagNames.contains(tagName), var currentSet = cssProperties[tagName] {
            for property in propertySet {
                currentSet.remove(property)
            }
            if currentSet.isEmpty {
                cssProperties.removeValue(forKey: tagName)
            } else {
                cssProperties[tagName] = currentSet
            }
        }

        if tag == ":all" {
            for name in cssProperties.keys {
                var currentSet = cssProperties[name]!
                for property in propertySet {
                    currentSet.remove(property)
                }
                if currentSet.isEmpty {
                    cssProperties.removeValue(forKey: name)
                } else {
                    cssProperties[name] = currentSet
                }
            }
        }

        return self
    }

    /**
     Add a list of allowed attributes to a tag. (If an attribute is not allowed on an element, it will be removed.)
     
     E.g.: `addAttributes("a", "href", "class")` allows `href` and `class` attributes
     on `a` tags.
     
     To make an attribute valid for <b>all tags</b>, use the pseudo tag `:all`, e.g.
     `addAttributes(":all", "class")`.
     
     - parameter tag:  The tag the attributes are for. The tag will be added to the allowed tag list if necessary.
     - parameter keys: List of valid attributes for the tag
     - returns: this (for chaining)
     */
    @discardableResult
    open func addAttributes(_ tag: String, _ keys: String...)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.isTrue(val: !keys.isEmpty, msg: "No attributes supplied.")

        let tagName = TagName.valueOf(tag)
        if (!tagNames.contains(tagName)) {
            tagNames.insert(tagName)
        }
        var attributeSet = Set<AttributeKey>()
        for key in keys {
            try Validate.notEmpty(string: key)
            attributeSet.insert(AttributeKey.valueOf(key))
        }

        if var currentSet = attributes[tagName] {
            for at in attributeSet {
                currentSet.insert(at)
            }
            attributes[tagName] = currentSet
        } else {
            attributes[tagName] = attributeSet
        }

        return self
    }

    /**
     Remove a list of allowed attributes from a tag. (If an attribute is not allowed on an element, it will be removed.)
     
     E.g.: `removeAttributes("a", "href", "class")` disallows `href` and `class`
     attributes on `a` tags.
     
     To make an attribute invalid for <b>all tags</b>, use the pseudo tag `:all`, e.g.
     `removeAttributes(":all", "class")`.
     
     - parameter tag:  The tag the attributes are for.
     - parameter keys: List of invalid attributes for the tag
     - returns: this (for chaining)
     */
    @discardableResult
    open func removeAttributes(_ tag: String, _ keys: String...)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.isTrue(val: !keys.isEmpty, msg: "No attributes supplied.")

        let tagName: TagName = TagName.valueOf(tag)
        var attributeSet = Set<AttributeKey>()
        for key in keys {
            try Validate.notEmpty(string: key)
            attributeSet.insert(AttributeKey.valueOf(key))
        }

        if(tagNames.contains(tagName)) { // Only look in sub-maps if tag was allowed
            if var currentSet = attributes[tagName] {
                for l in attributeSet {
                    currentSet.remove(l)
                }
                attributes[tagName] = currentSet
                if(currentSet.isEmpty) { // Remove tag from attribute map if no attributes are allowed for tag
                    attributes.removeValue(forKey: tagName)
                }
            }

        }

        if(tag == ":all") { // Attribute needs to be removed from all individually set tags
            for name in attributes.keys {
                var currentSet: Set<AttributeKey> = attributes[name]!
                for l in attributeSet {
                    currentSet.remove(l)
                }
                attributes[name] = currentSet
                if(currentSet.isEmpty) { // Remove tag from attribute map if no attributes are allowed for tag
                    attributes.removeValue(forKey: name)
                }
            }
        }
        return self
    }

    /**
     Add an enforced attribute to a tag. An enforced attribute will always be added to the element. If the element
     already has the attribute set, it will be overridden.
     
     E.g.: `addEnforcedAttribute("a", "rel", "nofollow")` will make all `a` tags output as
     `<a href="..." rel="nofollow">`
     
     - parameter tag:   The tag the enforced attribute is for. The tag will be added to the allowed tag list if necessary.
     - parameter key:   The attribute key
     - parameter value: The enforced attribute value
     - returns: this (for chaining)
     */
    @discardableResult
    open func addEnforcedAttribute(_ tag: String, _ key: String, _ value: String)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.notEmpty(string: key)
        try Validate.notEmpty(string: value)

        let tagName: TagName = TagName.valueOf(tag)
        if (!tagNames.contains(tagName)) {
            tagNames.insert(tagName)
        }
        let attrKey: AttributeKey = AttributeKey.valueOf(key)
        let attrVal: AttributeValue = AttributeValue.valueOf(value)

        if (enforcedAttributes[tagName] != nil) {
            enforcedAttributes[tagName]?[attrKey] = attrVal
        } else {
            var attrMap: Dictionary<AttributeKey, AttributeValue> = Dictionary<AttributeKey, AttributeValue>()
            attrMap[attrKey] = attrVal
            enforcedAttributes[tagName] = attrMap
        }
        return self
    }

    /**
     Remove a previously configured enforced attribute from a tag.
     
     - parameter tag:   The tag the enforced attribute is for.
     - parameter key:   The attribute key
     - returns: this (for chaining)
     */
    @discardableResult
    open func removeEnforcedAttribute(_ tag: String, _ key: String)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.notEmpty(string: key)

        let tagName: TagName = TagName.valueOf(tag)
        if(tagNames.contains(tagName) && (enforcedAttributes[tagName] != nil)) {
            let attrKey: AttributeKey = AttributeKey.valueOf(key)
            var attrMap: Dictionary<AttributeKey, AttributeValue> = enforcedAttributes[tagName]!
            attrMap.removeValue(forKey: attrKey)
            enforcedAttributes[tagName] = attrMap

            if(attrMap.isEmpty) { // Remove tag from enforced attribute map if no enforced attributes are present
                enforcedAttributes.removeValue(forKey: tagName)
            }
        }
        return self
    }

    /**
     Configure this Whitelist to preserve relative links in an element's URL attribute, or convert them to absolute
     links. By default, this is _false_: URLs will be  made absolute (e.g. start with an allowed protocol, like
     e.g. `http://`.
     
     Note that when handling relative links, the input document must have an appropriate `base URI` set when
     parsing, so that the link's protocol can be confirmed. Regardless of the setting of the `preserve relative
     links` option, the link must be resolvable against the base URI to an allowed protocol; otherwise the attribute
     will be removed.
     
     - parameter preserve: `true` to allow relative links, `false` (default) to deny
     - returns: this Whitelist, for chaining.
     - seealso: ``addProtocols(_:_:_:)``
     */
    @discardableResult
    open func preserveRelativeLinks(_ preserve: Bool) -> Whitelist {
        preserveRelativeLinks = preserve
        return self
    }

    /**
     Configure how whitespace in URL attributes is handled during sanitization.

     - `.strict`: No trimming. URL attributes with leading/trailing whitespace will be removed.
     - `.trim`: Trims whitespace for both protocol validation and output.
     - `.allow` (default): Trims whitespace for protocol validation but preserves original whitespace in output.

     - parameter mode: The whitespace handling mode
     - returns: this Whitelist, for chaining.
     */
    @discardableResult
    open func urlWhitespace(_ mode: URLWhitespaceMode) -> Whitelist {
        urlWhitespaceMode = mode
        return self
    }

    /**
     Add allowed URL protocols for an element's URL attribute. This restricts the possible values of the attribute to
     URLs with the defined protocol.
     
     E.g.: `addProtocols("a", "href", "ftp", "http", "https")`
     
     To allow a link to an in-page URL anchor (i.e. `<a href="#anchor">`, add a `#`:
     E.g.: `addProtocols("a", "href", "#")`
     
     - parameter tag:       Tag the URL protocol is for
     - parameter key:       Attribute key
     - parameter protocols: List of valid protocols
     - returns: this, for chaining
     */
    @discardableResult
    open func addProtocols(_ tag: String, _ key: String, _ protocols: String...)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.notEmpty(string: key)

        let tagName: TagName = TagName.valueOf(tag)
        let attrKey: AttributeKey = AttributeKey.valueOf(key)
        var attrMap: Dictionary<AttributeKey, Set<Protocol>>
        var protSet: Set<Protocol>

        if (self.protocols[tagName] != nil) {
            attrMap = self.protocols[tagName]!
        } else {
            attrMap =  Dictionary<AttributeKey, Set<Protocol>>()
            self.protocols[tagName] = attrMap
        }

        if (attrMap[attrKey] != nil) {
            protSet = attrMap[attrKey]!
        } else {
            protSet = Set<Protocol>()
            attrMap[attrKey] = protSet
            self.protocols[tagName] = attrMap
        }
        for ptl in protocols {
            try Validate.notEmpty(string: ptl)
            let prot: Protocol = Protocol.valueOf(ptl)
            protSet.insert(prot)
        }
        attrMap[attrKey] = protSet
        self.protocols[tagName] = attrMap

        return self
    }

    /**
     Remove allowed URL protocols for an element's URL attribute.
     
     E.g.: `removeProtocols("a", "href", "ftp")`
     
     - parameter tag:       Tag the URL protocol is for
     - parameter key:       Attribute key
     - parameter protocols: List of invalid protocols
     - returns: this, for chaining
     */
    @discardableResult
    open func removeProtocols(_ tag: String, _ key: String, _ protocols: String...)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.notEmpty(string: key)

        let tagName: TagName = TagName.valueOf(tag)
        let attrKey: AttributeKey = AttributeKey.valueOf(key)

        if(self.protocols[tagName] != nil) {
            var attrMap: Dictionary<AttributeKey, Set<Protocol>> = self.protocols[tagName]!
            if(attrMap[attrKey] != nil) {
                var protSet: Set<Protocol> = attrMap[attrKey]!
                for ptl in protocols {
                    try Validate.notEmpty(string: ptl)
                    let prot: Protocol = Protocol.valueOf(ptl)
                    protSet.remove(prot)
                }
                attrMap[attrKey] = protSet

                if(protSet.isEmpty) { // Remove protocol set if empty
                    attrMap.removeValue(forKey: attrKey)
                    if(attrMap.isEmpty) { // Remove entry for tag if empty
                        self.protocols.removeValue(forKey: tagName)
                    }

                }
            }
            self.protocols[tagName] = attrMap
        }
        return self
    }

    /**
     Test if the supplied tag is allowed by this whitelist
     - parameter tag: test tag
     - returns: true if allowed
     */
    public func isSafeTag(_ tag: [UInt8]) -> Bool {
        return tagNames.contains(TagName.valueOf(tag))
    }

    /**
     Test if the supplied attribute is allowed by this whitelist for this tag
     - parameter tagName: tag to consider allowing the attribute in
     - parameter el: element under test, to confirm protocol
     - parameter attr: attribute under test
     - returns: true if allowed
     */
    public func isSafeAttribute(_ tagName: String, _ el: Element, _ attr: Attribute)throws -> Bool {
        let tag: TagName = TagName.valueOf(tagName)
        let key: AttributeKey = AttributeKey.valueOf(attr.getKey())

        if attributes[tag]?.contains(key) ?? false {
            if let attrProts = protocols[tag] {
                if let protocols = attrProts[key] {
                    // test
                    return try testValidProtocol(el, attr, protocols)
                } else {
                    // ok if not defined protocol
                    return true
                }
            } else { // attribute found, no protocols defined, so OK
                return true
            }
        }
        // no attributes defined for tag, try :all tag
        return try (tagName != ":all") && isSafeAttribute(":all", el, attr)
    }
    
    /**
     Test if the supplied attribute is allowed by this whitelist for this tag
     - parameter tagName: tag to consider allowing the attribute in
     - parameter el: element under test, to confirm protocol
     - parameter attr: attribute under test
     - returns: A clone of the passed attribute if it's allowed. The clone may have its value altered depending
       on whitelist settings like ``preserveRelativeLinks(_:)``.
     */
    public func safeAttribute(_ tagName: String, _ el: Element, _ attr: Attribute)throws -> Attribute? {
        guard try isSafeAttribute(tagName, el, attr) else {
            return nil
        }

        let clonedAttr = attr.clone()

        if isStyleAttribute(attr), let allowedCSSProperties = configuredCSSProperties(for: tagName) {
            guard let sanitizedStyle = sanitizeStyleAttribute(attr.getValue(), allowedProperties: allowedCSSProperties) else {
                return nil
            }
            if sanitizedStyle != attr.getValue() {
                clonedAttr.setValue(value: sanitizedStyle.utf8Array)
            }
            return clonedAttr
        }

        // Only apply URL resolution and whitespace handling to attributes that
        // have protocols defined (i.e., URL attributes like href, src). Applying
        // URL resolution to non-URL attributes like `style` corrupts values
        // containing `#` (e.g., CSS colors) by percent-encoding them to `%23`.
        guard isURLAttribute(tagName, attr) else {
            return clonedAttr
        }

        let resolutionCandidate = resolutionCandidateValue(el, attr)
        if !preserveRelativeLinks && shouldResolveURLAttribute(resolutionCandidate) {
            let resolved = resolveURL(el, resolutionCandidate)
            if !resolved.isEmpty {
                clonedAttr.setValue(value: resolved)
                return clonedAttr
            }
        }

        // No resolution — apply whitespace mode to the original value
        let originalValue = attr.getValueUTF8()
        let outputValue = urlWhitespaceMode.prepareForOutput(originalValue)
        if outputValue != originalValue {
            clonedAttr.setValue(value: outputValue)
        }

        return clonedAttr
    }

    /// Check if the attribute has protocols defined in the whitelist, indicating it's a URL attribute.
    private func isURLAttribute(_ tagName: String, _ attr: Attribute) -> Bool {
        let tag = TagName.valueOf(tagName)
        let key = AttributeKey.valueOf(attr.getKey())
        if protocols[tag]?[key] != nil {
            return true
        }
        return tagName != ":all" && isURLAttribute(":all", attr)
    }

    /// Only absolutize values that already look root-relative or protocol-relative.
    /// Other relative paths stay unchanged in the cleaned output.
    private func shouldResolveURLAttribute(_ normalizedValue: [UInt8]) -> Bool {
        if normalizedValue.first?.isWhitespace == true || normalizedValue.last?.isWhitespace == true {
            return false
        }
        if normalizedValue.first == TokeniserStateVars.slashByte {
            return true
        }
        let value = String(decoding: normalizedValue, as: UTF8.self)
        return URL(string: value)?.scheme?.isEmpty == false
    }

    /// Prepare the value used for URL-resolution decisions. When a base URI is
    /// available we trim first so existing base-resolution behavior is preserved.
    private func resolutionCandidateValue(_ el: Element, _ attr: Attribute) -> [UInt8] {
        let rawValue = attr.getValueUTF8()
        let baseUri = el.getBaseUri()
        if baseUri.isEmpty {
            return rawValue
        }
        return rawValue.trim()
    }

    /// Resolve a URL attribute, trimming whitespace before resolution when a base URI
    /// is present to avoid percent-encoding of leading/trailing spaces. Without a base
    /// URI, the raw value is passed through for Foundation normalization only.
    private func resolveWithTrimmedURL(_ el: Element, _ attr: Attribute) -> [UInt8] {
        resolveURL(el, resolutionCandidateValue(el, attr))
    }

    private func resolveURL(_ el: Element, _ normalizedValue: [UInt8]) -> [UInt8] {
        let baseUri = el.getBaseUri()
        let relUrl = String(decoding: normalizedValue, as: UTF8.self)
        let resolved = StringUtil.resolve(baseUri, relUrl: relUrl)
        return resolved.utf8Array
    }

    private func isStyleAttribute(_ attr: Attribute) -> Bool {
        AttributeKey.valueOf(attr.getKey()) == AttributeKey.valueOf("style")
    }

    private func configuredCSSProperties(for tagName: String) -> Set<CSSPropertyName>? {
        let tag = TagName.valueOf(tagName)
        let allTag = TagName.valueOf(":all")
        let tagProperties = cssProperties[tag]
        let allProperties = tagName == ":all" ? nil : cssProperties[allTag]

        guard tagProperties != nil || allProperties != nil else {
            return nil
        }

        var allowedProperties = Set<CSSPropertyName>()
        if let tagProperties {
            allowedProperties.formUnion(tagProperties)
        }
        if let allProperties {
            allowedProperties.formUnion(allProperties)
        }
        return allowedProperties
    }

    // Inline CSS is filtered conservatively: only whitelisted properties survive,
    // comments are stripped, and declarations using common XSS vectors are dropped.
    private func sanitizeStyleAttribute(_ style: String, allowedProperties: Set<CSSPropertyName>) -> String? {
        let safeDeclarations = parseStyleDeclarations(style).compactMap { declaration -> String? in
            let propertyName = declaration.name.lowercased()
            guard allowedProperties.contains(CSSPropertyName.valueOf(propertyName)) else {
                return nil
            }
            guard !isAlwaysUnsafeCSSProperty(propertyName),
                  isSafeCSSValue(declaration.value) else {
                return nil
            }
            return "\(propertyName):\(declaration.value)"
        }

        guard !safeDeclarations.isEmpty else {
            return nil
        }

        return safeDeclarations.joined(separator: "; ")
    }

    private func parseStyleDeclarations(_ style: String) -> [CSSDeclaration] {
        let styleWithoutComments = stripCSSComments(style)
        var declarations = [CSSDeclaration]()
        var buffer = ""
        var quote: Character?
        var isEscaped = false
        var parenthesisDepth = 0

        for character in styleWithoutComments {
            if let activeQuote = quote {
                buffer.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                continue
            }

            switch character {
            case "\"", "'":
                quote = character
                buffer.append(character)
            case "(":
                parenthesisDepth += 1
                buffer.append(character)
            case ")":
                parenthesisDepth = max(0, parenthesisDepth - 1)
                buffer.append(character)
            case ";" where parenthesisDepth == 0:
                if let declaration = parseStyleDeclaration(buffer) {
                    declarations.append(declaration)
                }
                buffer.removeAll(keepingCapacity: true)
            default:
                buffer.append(character)
            }
        }

        if let declaration = parseStyleDeclaration(buffer) {
            declarations.append(declaration)
        }

        return declarations
    }

    private func stripCSSComments(_ style: String) -> String {
        var result = ""
        var quote: Character?
        var isEscaped = false
        var index = style.startIndex

        while index < style.endIndex {
            let character = style[index]

            if let activeQuote = quote {
                result.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
                index = style.index(after: index)
                continue
            }

            if character == "\"" || character == "'" {
                quote = character
                result.append(character)
                index = style.index(after: index)
                continue
            }

            if character == "/", style.index(after: index) < style.endIndex, style[style.index(after: index)] == "*" {
                index = style.index(index, offsetBy: 2)
                while index < style.endIndex {
                    if style[index] == "*",
                       style.index(after: index) < style.endIndex,
                       style[style.index(after: index)] == "/" {
                        index = style.index(index, offsetBy: 2)
                        break
                    }
                    index = style.index(after: index)
                }
                continue
            }

            result.append(character)
            index = style.index(after: index)
        }

        return result
    }

    private func isAlwaysUnsafeCSSProperty(_ propertyName: String) -> Bool {
        switch propertyName {
        case "behavior", "-moz-binding":
            return true
        default:
            return false
        }
    }

    private func isSafeCSSValue(_ value: String) -> Bool {
        let sanitized = stripCSSComments(value)
        let normalized = sanitized.lowercased()
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)

        return !normalized.contains("expression(")
            && !normalized.contains("@import")
            && !normalized.contains("url(")
    }

    private func parseStyleDeclaration(_ declaration: String) -> CSSDeclaration? {
        let trimmedDeclaration = declaration.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDeclaration.isEmpty else {
            return nil
        }

        var quote: Character?
        var isEscaped = false
        var parenthesisDepth = 0
        var colonIndex: String.Index?
        var index = trimmedDeclaration.startIndex

        while index < trimmedDeclaration.endIndex {
            let character = trimmedDeclaration[index]

            if let activeQuote = quote {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == activeQuote {
                    quote = nil
                }
            } else {
                switch character {
                case "\"", "'":
                    quote = character
                case "(":
                    parenthesisDepth += 1
                case ")":
                    parenthesisDepth = max(0, parenthesisDepth - 1)
                case ":" where parenthesisDepth == 0:
                    colonIndex = index
                    index = trimmedDeclaration.endIndex
                    continue
                default:
                    break
                }
            }

            index = trimmedDeclaration.index(after: index)
        }

        guard let colonIndex else {
            return nil
        }

        let name = trimmedDeclaration[..<colonIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let valueStart = trimmedDeclaration.index(after: colonIndex)
        let value = trimmedDeclaration[valueStart...].trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !value.isEmpty else {
            return nil
        }

        return CSSDeclaration(name: name, value: value)
    }

    private func testValidProtocol(_ el: Element, _ attr: Attribute, _ protocols: Set<Protocol>) throws -> Bool {
        // try to resolve relative urls to abs, and optionally update the attribute so output html has abs.
        // rels without a baseuri get removed
        var checkedValue = resolveWithTrimmedURL(el, attr)
        if checkedValue.isEmpty {
            checkedValue = urlWhitespaceMode.prepareForValidation(attr.getValueUTF8())
        }

        for ptl in protocols {
            var prot: String = ptl.toString()

            if prot == "#" { // allows anchor links
                if isValidAnchor(checkedValue) {
                    return true
                } else {
                    continue
                }
            }

            prot += ":"

            if checkedValue.lowercased().hasPrefix(prot.utf8Array) {
                return true
            }

        }

        return false
    }

    private func isValidAnchor(_ value: [UInt8]) -> Bool {
        return value.starts(with: "#".utf8Array) && Pattern(".*\\s.*").matcher(in: String(decoding: value, as: UTF8.self)).count == 0
    }

    public func getEnforcedAttributes(_ tagName: String)throws->Attributes {
        let attrs: Attributes = Attributes()
        let tag: TagName = TagName.valueOf(tagName)
        if let keyVals: Dictionary<AttributeKey, AttributeValue> = enforcedAttributes[tag] {
            for entry in keyVals {
                try attrs.put(entry.key.toString(), entry.value.toString())
            }
        }
        return attrs
    }

    func isTextOnly() -> Bool {
        tagNames.isEmpty
    }

}

// named types for config. All just hold strings, but here for my sanity.

open class TagName: TypedValue {
    override init(_ value: String) {
        super.init(value)
    }
    
    init(_ value: [UInt8]) {
        super.init(String(decoding: value.lowercased(), as: UTF8.self))
    }

    static func valueOf(_ value: String) -> TagName {
        return TagName(value)
    }
    
    static func valueOf(_ value: [UInt8]) -> TagName {
        return TagName(value)
    }
}

open class  AttributeKey: TypedValue {
    override init(_ value: String) {
        super.init(value)
    }

    static func valueOf(_ value: String) -> AttributeKey {
        return AttributeKey(value)
    }
    
    static func valueOf(_ value: [UInt8]) -> AttributeKey {
        return AttributeKey(String(decoding: value, as: UTF8.self))
    }
}

open class CSSPropertyName: TypedValue {
    override init(_ value: String) {
        super.init(value.lowercased())
    }

    static func valueOf(_ value: String) -> CSSPropertyName {
        return CSSPropertyName(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

open class AttributeValue: TypedValue {
    override init(_ value: String) {
        super.init(value)
    }

    static func valueOf(_ value: String) -> AttributeValue {
        return AttributeValue(value)
    }
}

open class Protocol: TypedValue {
    override init(_ value: String) {
        super.init(value)
    }

    static func valueOf(_ value: String) -> Protocol {
        return Protocol(value)
    }
}

open class TypedValue {
    fileprivate let value: String

    init(_ value: String) {
        self.value = value
    }

    public func toString() -> String {
        return value
    }
}

extension TypedValue: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(value)
    }
}

public func == (lhs: TypedValue, rhs: TypedValue) -> Bool {
    if(lhs === rhs) {return true}
    return lhs.value == rhs.value
}

private struct CSSDeclaration {
    let name: String
    let value: String
}
