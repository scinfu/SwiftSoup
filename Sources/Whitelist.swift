//
//  Whitelist.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 14/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

/*
 Thank you to Ryan Grove (wonko.com) for the Ruby HTML cleaner http://github.com/rgrove/sanitize/, which inspired
 this whitelist configuration, and the initial defaults.
 */

/**
 Whitelists define what HTML (elements and attributes) to allow through the cleaner. Everything else is removed.
 <p>
 Start with one of the defaults:
 </p>
 <ul>
 <li>{@link #none}
 <li>{@link #simpleText}
 <li>{@link #basic}
 <li>{@link #basicWithImages}
 <li>{@link #relaxed}
 </ul>
 <p>
 If you need to allow more through (please be careful!), tweak a base whitelist with:
 </p>
 <ul>
 <li>{@link #addTags}
 <li>{@link #addAttributes}
 <li>{@link #addEnforcedAttribute}
 <li>{@link #addProtocols}
 </ul>
 <p>
 You can remove any setting from an existing whitelist with:
 </p>
 <ul>
 <li>{@link #removeTags}
 <li>{@link #removeAttributes}
 <li>{@link #removeEnforcedAttribute}
 <li>{@link #removeProtocols}
 </ul>
 
 <p>
 The cleaner and these whitelists assume that you want to clean a <code>body</code> fragment of HTML (to add user
 supplied HTML into a templated page), and not to clean a full HTML document. If the latter is the case, either wrap the
 document HTML around the cleaned body HTML, or create a whitelist that allows <code>html</code> and <code>head</code>
 elements as appropriate.
 </p>
 <p>
 If you are going to extend a whitelist, please be very careful. Make sure you understand what attributes may lead to
 XSS attack vectors. URL attributes are particularly vulnerable and require careful validation. See
 http://ha.ckers.org/xss.html for some XSS attack examples.
 </p>
 */

import Foundation

public class Whitelist {
    private var tagNames: Set<TagName> // tags allowed, lower case. e.g. [p, br, span]
    private var attributes: Dictionary<TagName, Set<AttributeKey>> // tag -> attribute[]. allowed attributes [href] for a tag.
    private var enforcedAttributes: Dictionary<TagName, Dictionary<AttributeKey, AttributeValue>> // always set these attribute values
    private var protocols: Dictionary<TagName, Dictionary<AttributeKey, Set<Protocol>>> // allowed URL protocols for attributes
    private var preserveRelativeLinks: Bool  // option to preserve relative links

    /**
     This whitelist allows only text nodes: all HTML will be stripped.
     
     @return whitelist
     */
    public static func none() -> Whitelist {
        return Whitelist()
    }

    /**
     This whitelist allows only simple text formatting: <code>b, em, i, strong, u</code>. All other HTML (tags and
     attributes) will be removed.
     
     @return whitelist
     */
    public static func simpleText()throws ->Whitelist {
        return try Whitelist().addTags("b", "em", "i", "strong", "u")
    }

    /**
     <p>
     This whitelist allows a fuller range of text nodes: <code>a, b, blockquote, br, cite, code, dd, dl, dt, em, i, li,
     ol, p, pre, q, small, span, strike, strong, sub, sup, u, ul</code>, and appropriate attributes.
     </p>
     <p>
     Links (<code>a</code> elements) can point to <code>http, https, ftp, mailto</code>, and have an enforced
     <code>rel=nofollow</code> attribute.
     </p>
     <p>
     Does not allow images.
     </p>
     
     @return whitelist
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
     This whitelist allows the same text tags as {@link #basic}, and also allows <code>img</code> tags, with appropriate
     attributes, with <code>src</code> pointing to <code>http</code> or <code>https</code>.
     
     @return whitelist
     */
    public static func basicWithImages()throws->Whitelist {
        return try basic()
            .addTags("img")
            .addAttributes("img", "align", "alt", "height", "src", "title", "width")
            .addProtocols("img", "src", "http", "https")

    }

    /**
     This whitelist allows a full range of text and structural body HTML: <code>a, b, blockquote, br, caption, cite,
     code, col, colgroup, dd, div, dl, dt, em, h1, h2, h3, h4, h5, h6, i, img, li, ol, p, pre, q, small, span, strike, strong, sub,
     sup, table, tbody, td, tfoot, th, thead, tr, u, ul</code>
     <p>
     Links do not have an enforced <code>rel=nofollow</code> attribute, but you can add that if desired.
     </p>
     
     @return whitelist
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
     
     @see #basic()
     @see #basicWithImages()
     @see #simpleText()
     @see #relaxed()
     */
    init() {
        tagNames = Set<TagName>()
        attributes = Dictionary<TagName, Set<AttributeKey>>()
        enforcedAttributes = Dictionary<TagName, Dictionary<AttributeKey, AttributeValue>>()
        protocols = Dictionary<TagName, Dictionary<AttributeKey, Set<Protocol>>>()
        preserveRelativeLinks = false
    }

    /**
     Add a list of allowed elements to a whitelist. (If a tag is not allowed, it will be removed from the HTML.)
     
     @param tags tag names to allow
     @return this (for chaining)
     */
    @discardableResult
    open func addTags(_ tags: String...)throws ->Whitelist {
        for tagName in tags {
            try Validate.notEmpty(string: tagName)
            tagNames.insert(TagName.valueOf(tagName))
        }
        return self
    }

    /**
     Remove a list of allowed elements from a whitelist. (If a tag is not allowed, it will be removed from the HTML.)
     
     @param tags tag names to disallow
     @return this (for chaining)
     */
    @discardableResult
    open func removeTags(_ tags: String...)throws ->Whitelist {
        try Validate.notNull(obj: tags)

        for tag in tags {
            try Validate.notEmpty(string: tag)
            let tagName: TagName = TagName.valueOf(tag)

            if(tagNames.contains(tagName)) { // Only look in sub-maps if tag was allowed
                tagNames.remove(tagName)
                attributes.removeValue(forKey: tagName)
                enforcedAttributes.removeValue(forKey: tagName)
                protocols.removeValue(forKey: tagName)
            }
        }
        return self
    }

    /**
     Add a list of allowed attributes to a tag. (If an attribute is not allowed on an element, it will be removed.)
     <p>
     E.g.: <code>addAttributes("a", "href", "class")</code> allows <code>href</code> and <code>class</code> attributes
     on <code>a</code> tags.
     </p>
     <p>
     To make an attribute valid for <b>all tags</b>, use the pseudo tag <code>:all</code>, e.g.
     <code>addAttributes(":all", "class")</code>.
     </p>
     
     @param tag  The tag the attributes are for. The tag will be added to the allowed tag list if necessary.
     @param keys List of valid attributes for the tag
     @return this (for chaining)
     */
    @discardableResult
    open func addAttributes(_ tag: String, _ keys: String...)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.isTrue(val: keys.count > 0, msg: "No attributes supplied.")

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
     <p>
     E.g.: <code>removeAttributes("a", "href", "class")</code> disallows <code>href</code> and <code>class</code>
     attributes on <code>a</code> tags.
     </p>
     <p>
     To make an attribute invalid for <b>all tags</b>, use the pseudo tag <code>:all</code>, e.g.
     <code>removeAttributes(":all", "class")</code>.
     </p>
     
     @param tag  The tag the attributes are for.
     @param keys List of invalid attributes for the tag
     @return this (for chaining)
     */
    @discardableResult
    open func removeAttributes(_ tag: String, _ keys: String...)throws->Whitelist {
        try Validate.notEmpty(string: tag)
        try Validate.isTrue(val: keys.count > 0, msg: "No attributes supplied.")

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
     <p>
     E.g.: <code>addEnforcedAttribute("a", "rel", "nofollow")</code> will make all <code>a</code> tags output as
     <code>&lt;a href="..." rel="nofollow"&gt;</code>
     </p>
     
     @param tag   The tag the enforced attribute is for. The tag will be added to the allowed tag list if necessary.
     @param key   The attribute key
     @param value The enforced attribute value
     @return this (for chaining)
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
     
     @param tag   The tag the enforced attribute is for.
     @param key   The attribute key
     @return this (for chaining)
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
     * Configure this Whitelist to preserve relative links in an element's URL attribute, or convert them to absolute
     * links. By default, this is <b>false</b>: URLs will be  made absolute (e.g. start with an allowed protocol, like
     * e.g. {@code http://}.
     * <p>
     * Note that when handling relative links, the input document must have an appropriate {@code base URI} set when
     * parsing, so that the link's protocol can be confirmed. Regardless of the setting of the {@code preserve relative
     * links} option, the link must be resolvable against the base URI to an allowed protocol; otherwise the attribute
     * will be removed.
     * </p>
     *
     * @param preserve {@code true} to allow relative links, {@code false} (default) to deny
     * @return this Whitelist, for chaining.
     * @see #addProtocols
     */
    @discardableResult
    open func preserveRelativeLinks(_ preserve: Bool) -> Whitelist {
        preserveRelativeLinks = preserve
        return self
    }

    /**
     Add allowed URL protocols for an element's URL attribute. This restricts the possible values of the attribute to
     URLs with the defined protocol.
     <p>
     E.g.: <code>addProtocols("a", "href", "ftp", "http", "https")</code>
     </p>
     <p>
     To allow a link to an in-page URL anchor (i.e. <code>&lt;a href="#anchor"&gt;</code>, add a <code>#</code>:<br>
     E.g.: <code>addProtocols("a", "href", "#")</code>
     </p>
     
     @param tag       Tag the URL protocol is for
     @param key       Attribute key
     @param protocols List of valid protocols
     @return this, for chaining
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
     <p>
     E.g.: <code>removeProtocols("a", "href", "ftp")</code>
     </p>
     
     @param tag       Tag the URL protocol is for
     @param key       Attribute key
     @param protocols List of invalid protocols
     @return this, for chaining
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
     * Test if the supplied tag is allowed by this whitelist
     * @param tag test tag
     * @return true if allowed
     */
    public func isSafeTag(_ tag: String) -> Bool {
        return tagNames.contains(TagName.valueOf(tag))
    }

    /**
     * Test if the supplied attribute is allowed by this whitelist for this tag
     * @param tagName tag to consider allowing the attribute in
     * @param el element under test, to confirm protocol
     * @param attr attribute under test
     * @return true if allowed
     */
    public func isSafeAttribute(_ tagName: String, _ el: Element, _ attr: Attribute)throws -> Bool {
        let tag: TagName = TagName.valueOf(tagName)
        let key: AttributeKey = AttributeKey.valueOf(attr.getKey())

        if (attributes[tag] != nil) {
            if (attributes[tag]?.contains(key))! {
                if (protocols[tag] != nil) {
                    let attrProts: Dictionary<AttributeKey, Set<Protocol>> = protocols[tag]!
                    // ok if not defined protocol; otherwise test
                    return try (attrProts[key] == nil) || testValidProtocol(el, attr, attrProts[key]!)
                } else { // attribute found, no protocols defined, so OK
                    return true
                }
            }
        }
        // no attributes defined for tag, try :all tag
        return try !(tagName == ":all") && isSafeAttribute(":all", el, attr)
    }

    private func testValidProtocol(_ el: Element, _ attr: Attribute, _ protocols: Set<Protocol>)throws->Bool {
        // try to resolve relative urls to abs, and optionally update the attribute so output html has abs.
        // rels without a baseuri get removed
        var value: String = try el.absUrl(attr.getKey())
        if (value.count == 0) {
            value = attr.getValue()
        }// if it could not be made abs, run as-is to allow custom unknown protocols
        if (!preserveRelativeLinks) {
            attr.setValue(value: value)
        }

        for  ptl in protocols {
            var prot: String = ptl.toString()

            if (prot=="#") { // allows anchor links
                if (isValidAnchor(value)) {
                    return true
                } else {
                    continue
                }
            }

            prot += ":"

            if (value.lowercased().hasPrefix(prot)) {
                return true
            }

        }

        return false
    }

    private func isValidAnchor(_ value: String) -> Bool {
        return value.startsWith("#") && !(Pattern(".*\\s.*").matcher(in: value).count > 0)
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

}

// named types for config. All just hold strings, but here for my sanity.

open class TagName: TypedValue {
    override init(_ value: String) {
        super.init(value)
    }

    static func valueOf(_ value: String) -> TagName {
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
    public var hashValue: Int {
        return value.hashValue
    }
}

public func == (lhs: TypedValue, rhs: TypedValue) -> Bool {
    if(lhs === rhs) {return true}
    return lhs.value == rhs.value
}
