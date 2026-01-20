//
//  Element.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

#if canImport(CLibxml2) || canImport(libxml2)
#if canImport(CLibxml2)
@preconcurrency import CLibxml2
#elseif canImport(libxml2)
@preconcurrency import libxml2
#endif
#endif

open class Element: Node {
    var _tag: Tag
    
    private static let classString = "class".utf8Array
    private static let emptyString = "".utf8Array
    @usableFromInline
    internal static let idString = "id".utf8Array
    private static let rootString = "#root".utf8Array
    /// Build per-key attribute value indexes on-demand to accelerate repeated attribute selectors.
    @usableFromInline
    internal static let dynamicAttributeValueIndexMaxKeys: Int = 8
    @usableFromInline
    internal static let hotAttributeIndexKeys: Set<[UInt8]> = Set([
        "href".utf8Array,
        "src".utf8Array,
        "srcset".utf8Array,
        "data-src".utf8Array,
        "data-srcset".utf8Array,
        "data-original".utf8Array,
        "data-lazy-src".utf8Array,
        "data-lazy-srcset".utf8Array,
        "rel".utf8Array,
        "itemtype".utf8Array,
        "itemprop".utf8Array,
        "property".utf8Array,
        "name".utf8Array,
        "content".utf8Array,
        "role".utf8Array,
        "aria-hidden".utf8Array,
        "type".utf8Array,
        "charset".utf8Array
    ].map { $0.lowercased() })


    /// Lazily-built tag → elements index (normalized lowercase UTF‑8 keys), invalidated on mutations.
    /// Optimizes hot tag selectors while preserving document order.
    @usableFromInline
    internal var normalizedTagNameIndex: [[UInt8]: [Weak<Element>]]? = nil
    @usableFromInline
    internal var isTagQueryIndexDirty: Bool = false
    
    /// Lazily-built class → elements index (normalized lowercase UTF‑8 keys).
    /// Rebuilt on class/DOM mutations to avoid stale results.
    @usableFromInline
    internal var normalizedClassNameIndex: [[UInt8]: [Weak<Element>]]? = nil
    @usableFromInline
    internal var isClassQueryIndexDirty: Bool = false
    
    /// Lazily-built id → elements index (id is case‑insensitive per HTML matching).
    /// Multiple matches are preserved for non‑unique IDs; order is document order.
    @usableFromInline
    internal var normalizedIdIndex: [[UInt8]: [Weak<Element>]]? = nil
    @usableFromInline
    internal var isIdQueryIndexDirty: Bool = false
    
    /// Lazily-built attribute-name → elements index (normalized lowercase UTF‑8 keys).
    /// Keeps full scan out of attribute‑heavy selectors like [href], [data-*].
    @usableFromInline
    internal var normalizedAttributeNameIndex: [[UInt8]: [Weak<Element>]]? = nil
    @usableFromInline
    internal var isAttributeQueryIndexDirty: Bool = false

    
    /// Lazily-built attribute-name → (value → elements) index for a curated hot list.
    /// Focused to avoid index build cost dwarfing selector savings.
    @usableFromInline
    internal var normalizedAttributeValueIndex: [[UInt8]: [[UInt8]: [Weak<Element>]]]? = nil
    @usableFromInline
    internal var isAttributeValueQueryIndexDirty: Bool = false
    /// Tracks dynamically indexed attribute keys (in insertion order) for bounded caching.
    @usableFromInline
    internal var dynamicAttributeValueIndexKeySet: Set<[UInt8]>? = nil
    @usableFromInline
    internal var dynamicAttributeValueIndexKeyOrder: [[UInt8]]? = nil
    @usableFromInline
    internal var suppressQueryIndexDirty: Bool = false

    /// Small LRU cache for selector results on this root, invalidated on mutations.
    @usableFromInline
    internal static let selectorResultCacheCapacity: Int = 32
    @usableFromInline
    internal let selectorResultCacheLock = Mutex()
    @usableFromInline
    internal var selectorResultCache: [String: Elements]? = nil
    @usableFromInline
    internal var selectorResultCacheOrder: [String] = []
    @usableFromInline
    internal var selectorResultTextVersion: Int = 0
    @usableFromInline
    internal var selectorResultCacheRoot: Node? = nil
    
    /// Cached normalized text (UTF‑8) for trim+normalize path.
    /// NOTE: Removed text cache; keep no per-node cache state here.
    
    
    /**
     Create a new, standalone Element. (Standalone in that is has no parent.)
     
     - parameter tag: tag of this element
     - parameter baseUri: the base URI
     - parameter attributes: initial attributes
     - parameter skipChildReserve: Whether to skip reserving space for children in advance.
     - seealso: ``appendChild(_:)``, ``appendElement(_:)``
     */
    public convenience init(_ tag: Tag, _ baseUri: String, _ attributes: Attributes, skipChildReserve: Bool = false) {
        self.init(tag, baseUri.utf8Array, attributes, skipChildReserve: skipChildReserve)
        attributes.ownerElement = self
    }
    
    public init(_ tag: Tag, _ baseUri: [UInt8], _ attributes: Attributes, skipChildReserve: Bool = false) {
        self._tag = tag
        super.init(baseUri, attributes: attributes, skipChildReserve: skipChildReserve)
        attributes.ownerElement = self
    }
    /**
     Create a new Element from a tag and a base URI.
     
     - parameter tag: element tag
     - parameter baseUri: the base URI of this element. It is acceptable for the base URI to be an empty
       string, but not `nil`.
     - parameter skipChildReserve: Whether to skip reserving space for children in advance.
     - seealso: ``Tag/valueOf(_:_:)-(String,ParseSettings)``
     */
    public convenience init(_ tag: Tag, _ baseUri: String, skipChildReserve: Bool = false) {
        self.init(tag, baseUri.utf8Array, skipChildReserve: skipChildReserve)
        attributes?.ownerElement = self
    }
    
    public init(_ tag: Tag, _ baseUri: [UInt8], skipChildReserve: Bool = false) {
        self._tag = tag
        super.init(baseUri, attributes: nil, skipChildReserve: skipChildReserve)
    }
    
    public override func nodeNameUTF8() -> [UInt8] {
        return _tag.getNameUTF8()
    }
    
    public override func nodeName() -> String {
        return _tag.getName()
    }
    /**
     Get the name of the tag for this element. E.g. `div`.
     
     - returns: the tag name
     */
    open func tagNameUTF8() -> [UInt8] {
        return _tag.getNameUTF8()
    }
    open func tagNameNormalUTF8() -> [UInt8] {
        return _tag.getNameNormalUTF8()
    }
    open func tagName() -> String {
        return _tag.getName()
    }
    open func tagNameNormal() -> String {
        return _tag.getNameNormal()
    }
    
    /**
     Change the tag of this element. For example, convert a `<span>` to a `<div>` with
     `el.tagName("div")`.
     
     - parameter tagName: new tag name for this element
     - returns: this element, for chaining
     */
    @discardableResult
    public func tagName(_ tagName: [UInt8]) throws -> Element {
        try Validate.notEmpty(string: tagName, msg: "Tag name must not be empty.")
        _tag = try Tag.valueOf(tagName, ParseSettings.preserveCase) // preserve the requested tag case
        markTagQueryIndexDirty()
        bumpTextMutationVersion()
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           doc.isLibxml2Backend,
           let nodePtr = libxml2NodePtr,
           doc.libxml2DocPtr != nil {
            var nameTerm = tagName
            nameTerm.append(0)
            nameTerm.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return }
                base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                    xmlNodeSetName(nodePtr, ptr)
                }
            }
            if doc.libxml2TagNameOverrides != nil {
                doc.libxml2TagNameOverrides?[UnsafeMutableRawPointer(nodePtr)] = tagName
            }
        }
#endif
        markSourceDirty()
        return self
    }
    
    @discardableResult
    public func tagName(_ tagName: String) throws -> Element {
        return try self.tagName(tagName.utf8Array)
    }
    
    /**
     Get the Tag for this element.
     
     - returns: the tag object
     */
    open func tag() -> Tag {
        return _tag
    }

    
    /**
     Test if this element is a block-level element. (E.g. `<div> == true` or an inline element
     `<p> == false`).
     
     - returns: true if block, false if not (and thus inline)
     */
    open func isBlock() -> Bool {
        return _tag.isBlock()
    }
    
    /// Test if this element has child nodes.
    open func isEmpty() -> Bool {
        return childNodes.isEmpty
    }
    
    /**
     Get the `id` attribute of this element.
     
     - returns: The id attribute, if present, or an empty string if not.
     */
    open func id() -> String {
        guard let attributes else { return "" }
        do {
            return try String(decoding: attributes.getIgnoreCase(key: Element.idString), as: UTF8.self)
        } catch {}
        return ""
    }

    @inline(__always)
    open func idUTF8() -> [UInt8] {
        guard let attributes else { return [] }
        do {
            return try attributes.getIgnoreCase(key: Element.idString)
        } catch {}
        return []
    }
    
    // attribute fiddling. create on first access.
    @inline(__always)
    private func ensureAttributes() -> Attributes {
        #if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.isLibxml2Backend {
            Libxml2Backend.hydrateAttributesIfNeeded(self)
        } else if libxml2Context != nil {
            Libxml2Backend.hydrateAttributesIfNeeded(self)
        }
        #endif
        if let attributes {
            return attributes
        }
        let created = Attributes()
        created.ownerElement = self
        attributes = created
        return created
    }

    @inline(__always)
    open override func getAttributes() -> Attributes? {
        return ensureAttributes()
    }

    @inline(__always)
    open override func attr(_ attributeKey: [UInt8]) throws -> [UInt8] {
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           doc.libxml2Only,
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr {
            if attributeKey.count >= UTF8Arrays.absPrefix.count {
                @inline(__always)
                func lowerAscii(_ b: UInt8) -> UInt8 {
                    return (b >= 65 && b <= 90) ? (b &+ 32) : b
                }
                if lowerAscii(attributeKey[0]) == UTF8Arrays.absPrefix[0] &&
                    lowerAscii(attributeKey[1]) == UTF8Arrays.absPrefix[1] &&
                    lowerAscii(attributeKey[2]) == UTF8Arrays.absPrefix[2] &&
                    attributeKey[3] == UTF8Arrays.absPrefix[3] {
                    return try absUrl(attributeKey.substring(UTF8Arrays.absPrefix.count))
                }
            }
            let needsTrim = (attributeKey.first?.isWhitespace ?? false)
                || (attributeKey.last?.isWhitespace ?? false)
            let trimmedKey = needsTrim ? attributeKey.trim() : attributeKey
            if trimmedKey.isEmpty { return [] }
            let settings = doc.treeBuilder?.settings ?? doc.libxml2Context?.settings ?? ParseSettings.htmlDefault
            let normalizedKey: [UInt8]
            if settings.preservesAttributeCase() || !Attributes.containsAsciiUppercase(trimmedKey) {
                normalizedKey = trimmedKey
            } else {
                normalizedKey = trimmedKey.lowercased()
            }
            if let overrides = doc.libxml2AttributeOverrides,
               let override = overrides[UnsafeMutableRawPointer(nodePtr)] {
                if override.hasKeyIgnoreCase(key: normalizedKey) {
                    return (try? override.getIgnoreCase(key: normalizedKey)) ?? []
                }
            }
            if let value = Libxml2Backend.attributeValueFromLibxml2Node(nodePtr, key: normalizedKey) {
                return value
            }
            return []
        }
#endif
        guard attributes != nil else {
            if attributeKey.count >= UTF8Arrays.absPrefix.count {
                @inline(__always)
                func lowerAscii(_ b: UInt8) -> UInt8 {
                    return (b >= 65 && b <= 90) ? (b &+ 32) : b
                }
                if lowerAscii(attributeKey[0]) == UTF8Arrays.absPrefix[0] &&
                    lowerAscii(attributeKey[1]) == UTF8Arrays.absPrefix[1] &&
                    lowerAscii(attributeKey[2]) == UTF8Arrays.absPrefix[2] &&
                    attributeKey[3] == UTF8Arrays.absPrefix[3] {
                    return try absUrl(attributeKey.substring(UTF8Arrays.absPrefix.count))
                }
            }
            return []
        }
        return try super.attr(attributeKey)
    }

    @inline(__always)
    open override func attr(_ attributeKey: String) throws -> String {
        return try String(decoding: attr(attributeKey.utf8Array), as: UTF8.self)
    }
    
    /**
     Set an attribute value on this element. If this element already has an attribute with the
     key, its value is updated; otherwise, a new attribute is added.
     
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    open override func attr(_ attributeKey: [UInt8], _ attributeValue: [UInt8]) throws -> Element {
        _ = ensureAttributes()
        try super.attr(attributeKey, attributeValue)
        return self
    }
    
    /**
     Set an attribute value on this element. If this element already has an attribute with the
     key, its value is updated; otherwise, a new attribute is added.
     
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    open override func attr(_ attributeKey: String, _ attributeValue: String) throws -> Element {
        _ = ensureAttributes()
        try super.attr(attributeKey.utf8Array, attributeValue.utf8Array)
        return self
    }
    
    /**
     Set a boolean attribute value on this element. Setting to `e` sets the attribute value to "" and
     marks the attribute as boolean so no value is written out. Setting to `e` removes the attribute
     with the same key if it exists.
     
     - parameter attributeKey: the attribute key
     - parameter attributeValue: the attribute value
     
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    open func attr(_ attributeKey: [UInt8], _ attributeValue: Bool) throws -> Element {
        _ = ensureAttributes()
        try attributes?.put(attributeKey, attributeValue)
        markSourceDirty()
        return self
    }
    
    /**
     Set a boolean attribute value on this element. Setting to `e` sets the attribute value to "" and
     marks the attribute as boolean so no value is written out. Setting to `e` removes the attribute
     with the same key if it exists.
     
     - parameter attributeKey: the attribute key
     - parameter attributeValue: the attribute value
     
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    open func attr(_ attributeKey: String, _ attributeValue: Bool) throws -> Element {
        _ = ensureAttributes()
        try attributes?.put(attributeKey.utf8Array, attributeValue)
        markSourceDirty()
        return self
    }
    
    /**
     Get this element's HTML5 custom data attributes. Each attribute in the element that has a key
     starting with "data-" is included the dataset.
     
     E.g., the element `<div data-package="SwiftSoup" data-language="Java" class="group">...` has the dataset
     `package=SwiftSoup, language=java`.
     
     This map is a filtered view of the element's attribute map. Changes to one map (add, remove, update) are reflected
     in the other map.
     
     You can find elements that have data attributes using the `[^data-]` attribute key prefix selector.
     
     - returns: a map of `key=value` custom data attributes.
     */
    @inline(__always)
    open func dataset() -> Dictionary<String, String> {
        return ensureAttributes().dataset()
    }
    
    @inline(__always)
    open override func parent() -> Element? {
        return parentNode as? Element
    }
    
    /**
     Get this element's parent and ancestors, up to the document root.
     - returns: this element's stack of parents, closest first.
     */
    @inline(__always)
    open func parents() -> Elements {
        let parents: Elements = Elements()
        Element.accumulateParents(self, parents)
        return parents
    }
    
    @inline(__always)
    private static func accumulateParents(_ el: Element, _ parents: Elements) {
        let parent: Element? = el.parent()
        if (parent != nil && !(parent!.tagNameUTF8() == Element.rootString)) {
            parents.add(parent!)
            accumulateParents(parent!, parents)
        }
    }
    
    /**
     Get a child element of this element, by its 0-based index number.
     
     Note that an element can have both mixed Nodes and Elements as children. This method inspects
     a filtered list of children that are elements, and the index is based on that filtered list.
     
     - parameter index: the index number of the element to retrieve
     - returns: the child element
     - seealso: ``Node/childNode(_:)``
     - warning: Crashes if the index is out of bounds!
     */
    @inline(__always)
    open func child(_ index: Int) -> Element {
        return children().get(index)
    }
    
    /**
     Get this element's child elements.
     
     This is effectively a filter on `childNodes` to get Element nodes.
     
     - returns: child elements. If this element has no children, returns an
       empty list.
     */
    @inline(__always)
    open func children() -> Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty {
            return Elements(childNodes.lazy.compactMap { $0 as? Element })
        }
#endif
        // create on the fly rather than maintaining two lists. if gets slow, memoize, and mark dirty on change
        return Elements(childNodes.lazy.compactMap { $0 as? Element })
    }
    
    /**
     Get this element's child text nodes. The list is unmodifiable but the text nodes may be manipulated.
     
     This is effectively a filter on `childNodes` to get Text nodes.
     
     For example, with the input HTML: `<p>One <span>Two</span> Three <br> Four</p>` with the `p` element selected:
     * `p.text()` = `"One Two Three Four"`
     * `p.ownText()` = `"One Three Four"`
     * `p.children()` = `Elements[<span>, <br>]`
     * `p.childNodes()` = `List<Node>["One ", <span>, " Three ", <br>, " Four"]`
     * `p.textNodes()` = `List<TextNode>["One ", " Three ", " Four"]`
     
     - returns: child text nodes. If this element has no text nodes, returns an
       empty list.
     */
    @inline(__always)
    open func textNodes() -> Array<TextNode> {
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = doc.libxml2DocPtr.flatMap { xmlDocGetRootElement($0) }
            } else {
                startNode = libxml2NodePtr?.pointee.children
            }
            if let startNode {
                var output: [TextNode] = []
                var cursor: xmlNodePtr? = startNode
                while let node = cursor {
                    if node.pointee.type == XML_TEXT_NODE,
                       let text = Libxml2Backend.wrapNodeForSelectionFast(node, doc: doc) as? TextNode {
                        output.append(text)
                    }
                    cursor = node.pointee.next
                }
                return output
            }
        }
#endif
        return childNodes.compactMap { $0 as? TextNode }
    }
    
    /**
     Get this element's child data nodes. The list is unmodifiable but the data nodes may be manipulated.
     
     This is effectively a filter on `childNodes` to get Data nodes.
     
     - returns: child data nodes. If this element has no data nodes, returns an
       empty list.
     - seealso: ``data()``
     */
    @inline(__always)
    open func dataNodes() -> Array<DataNode> {
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = doc.libxml2DocPtr.flatMap { xmlDocGetRootElement($0) }
            } else {
                startNode = libxml2NodePtr?.pointee.children
            }
            if let startNode {
                var output: [DataNode] = []
                var cursor: xmlNodePtr? = startNode
                while let node = cursor {
                    if node.pointee.type == XML_TEXT_NODE,
                       let data = Libxml2Backend.wrapNodeForSelectionFast(node, doc: doc) as? DataNode {
                        output.append(data)
                    } else if node.pointee.type == XML_CDATA_SECTION_NODE,
                              let data = Libxml2Backend.wrapNodeForSelectionFast(node, doc: doc) as? DataNode {
                        output.append(data)
                    }
                    cursor = node.pointee.next
                }
                return output
            }
        }
#endif
        return childNodes.compactMap { $0 as? DataNode }
    }
    
    /**
     Find elements that match the ``CssSelector`` CSS query, with this element as the starting context. Matched elements
     may include this element, or any of its children.
     
     This method is generally more powerful to use than the DOM-type `getElementBy*` methods, because
     multiple filters can be combined, e.g.:
     
     * `el.select("a[href]")` - finds links (`a` tags with `href` attributes)
     * `el.select("a[href*=example.com]")` - finds links pointing to example.com (loosely)
     
     See the query syntax documentation in ``CssSelector``.
     
     - parameter cssQuery: a ``CssSelector`` CSS-like query
     - returns: elements that match the query (empty if none match)
     - throws ``Exception`` with ``ExceptionType/SelectorParseException`` (unchecked) on an invalid CSS query.
     */
    @inline(__always)
    public func select(_ cssQuery: String)throws->Elements {
        return try CssSelector.select(cssQuery, self)
    }
    
    /**
     Find elements that match the ``Evaluator`` with a ``CssSelector`` query, with this element as the starting context.
     Matched elements may include this element, or any of its children.
     
     This method is more efficient for repeated queries since it avoids repeated query parsing.
     
     - parameter evaluator: a ``Evaluator`` to use for the query
     - returns: elements that match the query (empty if none match)
     - seealso: ``QueryParser``
     */
    @inline(__always)
    public func select(_ evaluator: Evaluator)throws->Elements {
        return try CssSelector.select(evaluator, self)
    }
    
    /**
     Check if this element matches the given ``CssSelector`` CSS query.
     - parameter cssQuery: a ``CssSelector`` CSS query
     - returns: if this element matches the query
     */
    @inline(__always)
    public func iS(_ cssQuery: String)throws->Bool {
        return try iS(QueryParser.parse(cssQuery))
    }
    
    /**
     Check if this element matches the given ``Evaluator``.
     - parameter evaluator: a query evaluator
     - returns: if this element matches the query
     - seealso: ``QueryParser``
     */
    @inline(__always)
    public func iS(_ evaluator: Evaluator)throws->Bool {
        guard let od = self.ownerDocument() else {
            return false
        }
        return try evaluator.matches(od, self)
    }
    
    /**
     Add a node child node to this element.
     
     - parameter child: node to add.
     - returns: this element, so that you can add more child nodes or elements.
     */
    @discardableResult
    @inline(__always)
    public func appendChild(_ child: Node) throws -> Element {
        #if PROFILE
        let _p = Profiler.start("Element.appendChild")
        defer { Profiler.end("Element.appendChild", _p) }
        #endif
        // was - Node#addChildren(child). short-circuits an array create and a loop.
        let isBulkBuilding = treeBuilder?.isBulkBuilding == true
        if isBulkBuilding, child.parentNode == nil {
            // Fast path for parser-owned nodes during bulk build.
            child.treeBuilder = treeBuilder
            child.parentNode = self
        } else {
            try reparentChild(child)
        }
#if canImport(CLibxml2) || canImport(libxml2)
        var didSyncLibxml2 = false
        if !isBulkBuilding,
           let doc = ownerDocument(),
           doc.isLibxml2Backend,
           doc.libxml2DocPtr != nil,
           !libxml2ChildrenHydrated {
            Libxml2Backend.hydrateChildrenIfNeeded(self)
        }
        if !isBulkBuilding,
           let parentPtr = libxml2NodePtr,
           let doc = ownerDocument(),
           doc.libxml2DocPtr != nil,
           child.ownerDocument() === doc {
            let childPtr = child.libxml2NodePtr ?? child.libxml2EnsureNode(in: doc)
            if let childPtr {
                if child.libxml2NodePtr != nil {
                    xmlUnlinkNode(childPtr)
                }
                xmlAddChild(parentPtr, childPtr)
                didSyncLibxml2 = true
            }
        }
#endif
        if let existingIndex = childNodes.firstIndex(where: { $0 === child }) {
            if existingIndex == childNodes.count - 1 {
                child.setSiblingIndex(existingIndex)
            } else {
                childNodes.remove(at: existingIndex)
                reindexChildren(existingIndex)
                childNodes.append(child)
                child.setSiblingIndex(childNodes.count - 1)
            }
        } else {
            childNodes.append(child)
            child.setSiblingIndex(childNodes.count - 1)
        }
        if !isBulkBuilding {
#if canImport(CLibxml2) || canImport(libxml2)
            if didSyncLibxml2 {
                withLibxml2DirtySuppressed {
                    child.withLibxml2DirtySuppressed {
                        child.markSourceDirty()
                        markSourceDirty()
                    }
                }
            } else {
                child.markSourceDirty()
                markSourceDirty()
            }
#else
            child.markSourceDirty()
            markSourceDirty()
#endif
        }
        return self
    }
    
    /**
     Add a node to the start of this element's children.
     
     - parameter child: node to add.
     - returns: this element, so that you can add more child nodes or elements.
     */
    @discardableResult
    @inline(__always)
    public func prependChild(_ child: Node)throws->Element {
        try addChildren(0, child)
        return self
    }
    
    /**
     Inserts the given child nodes into this element at the specified index. Current nodes will be shifted to the
     right. The inserted nodes will be moved from their current parent. To prevent moving, copy the nodes first.
     
     - parameter index: 0-based index to insert children at. Specify `0` to insert at the start, `-1` at the
       end
     - parameter children: child nodes to insert
     - returns: this element, for chaining.
     */
    @discardableResult
    @inline(__always)
    public func insertChildren(_ index: Int, _ children: Array<Node>)throws->Element {
        //Validate.notNull(children, "Children collection to be inserted must not be null.")
        var index = index
        let currentSize: Int = childNodeSize()
        if (index < 0) { index += currentSize + 1} // roll around
        try Validate.isTrue(val: index >= 0 && index <= currentSize, msg: "Insert position out of bounds.")
        
        try addChildren(index, children)
        return self
    }
    
    /**
     Create a new element by tag name, and add it as the last child.
     
     - parameter tagName: the name of the tag (e.g. `div`).
     - returns: the new element, to allow you to add content to it, e.g.:
       `parent.appendElement("h1").attr("id", "header").text("Welcome")`
     */
    @discardableResult
    @inline(__always)
    public func appendElement(_ tagName: String) throws -> Element {
        return try appendElement(tagName.utf8Array)
    }
    
    @discardableResult
    @inline(__always)
    internal func appendElement(_ tagName: [UInt8]) throws -> Element {
        let child: Element = Element(try Tag.valueOf(tagName), getBaseUriUTF8())
        if let treeBuilder {
            child.treeBuilder = treeBuilder
        }
        try appendChild(child)
        return child
    }
    
    /**
     Create a new element by tag name, and add it as the first child.
     
     - parameter tagName: the name of the tag (e.g. `div`).
     - returns: the new element, to allow you to add content to it, e.g.:
       `parent.prependElement("h1").attr("id", "header").text("Welcome")`
     */
    @discardableResult
    @inline(__always)
    public func prependElement(_ tagName: String) throws -> Element {
        return try prependElement(tagName.utf8Array)
    }
    
    @discardableResult
    @inline(__always)
    internal func prependElement(_ tagName: [UInt8]) throws -> Element {
        let child: Element = Element(try Tag.valueOf(tagName), getBaseUriUTF8())
        if let treeBuilder {
            child.treeBuilder = treeBuilder
        }
        try prependChild(child)
        return child
    }
    
    /**
     Create and append a new TextNode to this element.
     
     - parameter text: the unencoded text to add
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    public func appendText(_ text: String) throws -> Element {
        let node: TextNode = TextNode(text.utf8Array, getBaseUriUTF8())
        try appendChild(node)
        return self
    }
    
    /**
     Create and prepend a new TextNode to this element.
     
     - parameter text: the unencoded text to add
     - returns: this element
     */
    @discardableResult
    public func prependText(_ text: String) throws -> Element {
        let node: TextNode = TextNode(text.utf8Array, getBaseUriUTF8())
        try prependChild(node)
        return self
    }
    
    /**
     Add inner HTML to this element. The supplied HTML will be parsed, and each node appended to the end of the children.
     - parameter html: HTML to add inside this element, after the existing HTML
     - returns: this element
     - seealso: ``html(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    public func append(_ html: String) throws -> Element {
        let nodes: Array<Node> = try Parser.parseFragment(html.utf8Array, self, getBaseUriUTF8())
        try addChildren(nodes)
        return self
    }
    
    /**
     Add inner HTML into this element. The supplied HTML will be parsed, and each node prepended to the start of the element's children.
     - parameter html: HTML to add inside this element, before the existing HTML
     - returns: this element
     - seealso: ``html(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    public func prepend(_ html: String)throws->Element {
        let nodes: Array<Node> = try Parser.parseFragment(html.utf8Array, self, getBaseUriUTF8())
        try addChildren(0, nodes)
        return self
    }
    
    /**
     Insert the specified HTML into the DOM before this element (as a preceding sibling).
     
     - parameter html: HTML to add before this element
     - returns: this element, for chaining
     - seealso: ``after(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    open override func before(_ html: String)throws->Element {
        return try super.before(html) as! Element
    }
    
    /**
     Insert the specified node into the DOM before this node (as a preceding sibling).
     - parameter node: to add before this element
     - returns: this Element, for chaining
     - seealso: ``after(_:)-(Node)``
     */
    @discardableResult
    @inline(__always)
    open override func before(_ node: Node)throws->Element {
        return try super.before(node) as! Element
    }
    
    /**
     Insert the specified HTML into the DOM after this element (as a following sibling).
     
     - parameter html: HTML to add after this element
     - returns: this element, for chaining
     - seealso: ``before(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    open override func after(_ html: String) throws -> Element {
        return try super.after(html) as! Element
    }
    
    /**
     Insert the specified node into the DOM after this node (as a following sibling).
     - parameter node: to add after this element
     - returns: this element, for chaining
     - seealso: ``before(_:)-(Node)``
     */
    @inline(__always)
    open override func after(_ node: Node) throws -> Element {
        return try super.after(node) as! Element
    }
    
    /**
     Remove all of the element's child nodes. Any attributes are left as-is.
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    public func empty() -> Element {
        markQueryIndexesDirty()
#if canImport(CLibxml2) || canImport(libxml2)
        var didSyncLibxml2 = false
        if let doc = ownerDocument(),
           doc.libxml2DocPtr != nil,
           libxml2NodePtr != nil {
            for child in childNodes {
                _ = child.libxml2DetachAndFreeIfPossible()
            }
            didSyncLibxml2 = true
        }
#endif
        childNodes.removeAll()
        bumpTextMutationVersion()
#if canImport(CLibxml2) || canImport(libxml2)
        if didSyncLibxml2 {
            withLibxml2DirtySuppressed {
                markSourceDirty()
            }
        } else {
            markSourceDirty()
        }
#else
        markSourceDirty()
#endif
        return self
    }
    
    /**
     Wrap the supplied HTML around this element.
     
     - parameter html: HTML to wrap around this element, e.g. `<div class="head"></div>`. Can be arbitrarily deep.
     - returns: this element, for chaining.
     */
    @discardableResult
    @inline(__always)
    open override func wrap(_ html: String) throws -> Element {
        return try super.wrap(html) as! Element
    }
    
    /**
     Get a CSS selector that will uniquely select this element.
     
     If the element has an ID, returns #id;
     otherwise returns the parent (if any) CSS selector, followed by `>`,
     followed by a unique selector for the element (tag.class.class:nth-child(n)).
     
     - returns: the CSS Path that can be used to retrieve the element in a selector.
     */
    public func cssSelector() throws -> String {
        let elementId = id()
        if !elementId.isEmpty {
            return "#" + elementId
        }
        
        // Translate HTML namespace ns:tag to CSS namespace syntax ns|tag
        let tagName: String = self.tagName().replacingOccurrences(of: ":", with: "|")
        var selector: String = tagName
        let cl = try classNames()
        let classes: String = cl.joined(separator: ".")
        if !classes.isEmpty {
            selector.append(".")
            selector.append(classes)
        }
        
        if (parent() == nil || ((parent() as? Document) != nil)) // don't add Document to selector, as will always have a html node
        {
            return selector
        }
        
        selector.insert(contentsOf: " > ", at: selector.startIndex)
        if (try parent()!.select(selector).array().count > 1) {
            selector.append(":nth-child(\(try elementSiblingIndex() + 1))")
        }
        
        return try parent()!.cssSelector() + (selector)
    }
    
    /**
     Get sibling elements. If the element has no sibling elements, returns an empty list. An element is not a sibling
     of itself, so will not be included in the returned list.
     - returns: sibling elements
     */
    public func siblingElements() -> Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        if parentNode == nil,
           let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr,
           let parentPtr = nodePtr.pointee.parent {
            let siblings = Elements()
            var cursor: xmlNodePtr? = parentPtr.pointee.children
            while let current = cursor {
                if current != nodePtr,
                   current.pointee.type == XML_ELEMENT_NODE,
                   let wrapped = Libxml2Backend.wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    siblings.add(wrapped)
                }
                cursor = current.pointee.next
            }
            return siblings
        }
#endif
        if (parentNode == nil) {return Elements()}
        
        let elements: Array<Element>? = parent()?.children().array()
        let siblings: Elements = Elements()
        if let elements = elements {
            for el: Element in elements {
                if (el != self) {
                    siblings.add(el)
                }
            }
        }
        return siblings
    }
    
    /**
     Gets the next sibling element of this element. E.g., if a `div` contains two `p`s,
     the `nextElementSibling` of the first `p` is the second `p`.
     
     This is similar to ``Node/nextSibling()``, but specifically finds only Elements.
     
     - returns: the next element, or `nil` if there is no next element
     - seealso: ``previousElementSibling()``
     */
    public func nextElementSibling()throws->Element? {
#if canImport(CLibxml2) || canImport(libxml2)
        if parentNode == nil,
           let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr {
            var cursor = nodePtr.pointee.next
            while let current = cursor {
                if current.pointee.type == XML_ELEMENT_NODE,
                   let wrapped = Libxml2Backend.wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    return wrapped
                }
                cursor = current.pointee.next
            }
            return nil
        }
#endif
        if (parentNode == nil) {return nil}
        let siblings: Array<Element>? = parent()?.children().array()
        let index: Int? = try Element.indexInList(self, siblings)
        try Validate.notNull(obj: index)
        if let siblings = siblings {
            if (siblings.count > index!+1) {
                return siblings[index!+1]
            } else {
                return nil
            }
        }
        return nil
    }
    
    /**
     Gets the previous element sibling of this element.
     - returns: the previous element, or `nil` if there is no previous element
     - seealso: ``nextElementSibling()``
     */
    public func previousElementSibling()throws->Element? {
#if canImport(CLibxml2) || canImport(libxml2)
        if parentNode == nil,
           let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr {
            var cursor = nodePtr.pointee.prev
            while let current = cursor {
                if current.pointee.type == XML_ELEMENT_NODE,
                   let wrapped = Libxml2Backend.wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    return wrapped
                }
                cursor = current.pointee.prev
            }
            return nil
        }
#endif
        if (parentNode == nil) {return nil}
        let siblings: Array<Element>? = parent()?.children().array()
        let index: Int? = try Element.indexInList(self, siblings)
        try Validate.notNull(obj: index)
        if (index! > 0) {
            return siblings?[index!-1]
        } else {
            return nil
        }
    }
    
    /**
     Gets the first element sibling of this element.
     - returns: the first sibling that is an element (aka the parent's first element child)
     */
    public func firstElementSibling() -> Element? {
        // todo: should firstSibling() exclude this?
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr,
           let parentPtr = nodePtr.pointee.parent {
            var cursor: xmlNodePtr? = parentPtr.pointee.children
            var first: Element? = nil
            var count = 0
            while let current = cursor {
                if current.pointee.type == XML_ELEMENT_NODE,
                   let wrapped = Libxml2Backend.wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    if first == nil { first = wrapped }
                    count += 1
                    if count > 1 {
                        break
                    }
                }
                cursor = current.pointee.next
            }
            return count > 1 ? first : nil
        }
#endif
        let siblings: Array<Element>? = parent()?.children().array()
        return (siblings != nil && siblings!.count > 1) ? siblings![0] : nil
    }
    
    /**
     Get the list index of this element in its element sibling list. I.e. if this is the first element
     sibling, returns 0.
     
     - returns: position in element sibling list
     */
    public func elementSiblingIndex()throws->Int {
        if (parent() == nil) {return 0}
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr,
           let parentPtr = nodePtr.pointee.parent {
            var cursor: xmlNodePtr? = parentPtr.pointee.children
            var index = 0
            while let current = cursor {
                if current.pointee.type == XML_ELEMENT_NODE {
                    if current == nodePtr {
                        return index
                    }
                    index += 1
                }
                cursor = current.pointee.next
            }
            return 0
        }
#endif
        let x = try Element.indexInList(self, parent()?.children().array())
        return x == nil ? 0 : x!
    }
    
    /**
     Gets the last element sibling of this element
     - returns: the last sibling that is an element (aka the parent's last element child)
     */
    @inline(__always)
    public func lastElementSibling() -> Element? {
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let nodePtr = libxml2NodePtr,
           let parentPtr = nodePtr.pointee.parent {
            var cursor: xmlNodePtr? = parentPtr.pointee.children
            var last: Element? = nil
            var count = 0
            while let current = cursor {
                if current.pointee.type == XML_ELEMENT_NODE,
                   let wrapped = Libxml2Backend.wrapNodeForSelectionFast(current, doc: doc) as? Element {
                    last = wrapped
                    count += 1
                }
                cursor = current.pointee.next
            }
            return count > 1 ? last : nil
        }
#endif
        let siblings: Array<Element>? = parent()?.children().array()
        return (siblings != nil && siblings!.count > 1) ? siblings![siblings!.count - 1] : nil
    }
    
    private static func indexInList(_ search: Element, _ elements: Array<Element>?)throws->Int? {
        try Validate.notNull(obj: elements)
        return elements?.firstIndex(of: search)
    }
    
    
    // MARK: DOM type methods

    /**
     Finds elements, including and recursively under this element, with the specified tag name.
     - parameter tagName: The tag name to search for (case insensitively).
     - returns: a matching unmodifiable list of elements. Will be empty if this element and none of its children match.
     */
    @inline(__always)
    public func getElementsByTag(_ tagName: String) throws -> Elements {
        return try getElementsByTag(tagName.utf8Array)
    }
    
    /**
     Finds elements, including and recursively under this element, with the specified tag name.
     - parameter tagName: The tag name to search for (case insensitively).
     - returns: a matching unmodifiable list of elements. Will be empty if this element and none of its children match.
     */
    @inline(__always)
    public func getElementsByTag(_ tagName: [UInt8]) throws -> Elements {
        try Validate.notEmpty(string: tagName)
        let trimmed = tagName.trim()
        if trimmed.isEmpty {
            return Elements()
        }
        if !Attributes.containsAsciiUppercase(trimmed) {
            return try getElementsByTagNormalized(trimmed)
        }
        let normalizedTagName = trimmed.lowercased()
        let weakElements = tagQueryIndexForKey(normalizedTagName)
        return Elements(weakElements.compactMap { $0.value })
    }

    /**
     Finds elements by a normalized (trimmed, lowercase) tag name.
     - parameter normalizedTagName: The already-normalized tag name.
     - returns: a matching unmodifiable list of elements.
     */
    @inline(__always)
    public func getElementsByTagNormalized(_ normalizedTagName: [UInt8]) throws -> Elements {
        try Validate.notEmpty(string: normalizedTagName)
        let needsTrim = (normalizedTagName.first?.isWhitespace ?? false) || (normalizedTagName.last?.isWhitespace ?? false)
        let key = needsTrim ? normalizedTagName.trim() : normalizedTagName
        if key.isEmpty {
            return Elements()
        }
        if key.count == 1, key[0] == UInt8(ascii: "*") {
            return try getAllElements()
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr,
           doc.libxml2TagNameOverrides?.isEmpty != false {
            let settings = doc.treeBuilder?.settings ?? ParseSettings.htmlDefault
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                if self is Document, let cached = doc.libxml2SkipFallbackTagCacheGet(key) {
                    return cached
                }
                let elements = Libxml2Backend.collectElementsByTagName(
                    start: startNode,
                    tag: key,
                    settings: settings,
                    doc: doc
                )
                if self is Document {
                    doc.libxml2SkipFallbackTagCachePut(key, elements)
                }
                return elements
            }
        }
#endif
        let weakElements = tagQueryIndexForKey(key)
        let elements = weakElements.compactMap { $0.value }
        #if canImport(CLibxml2) || canImport(libxml2)
        if ownerDocument()?.isLibxml2Backend == true, elements.count > 1 {
            var seen = Set<ObjectIdentifier>()
            seen.reserveCapacity(elements.count)
            var unique: [Element] = []
            unique.reserveCapacity(elements.count)
            for element in elements {
                let id = ObjectIdentifier(element)
                if seen.contains(id) { continue }
                seen.insert(id)
                unique.append(element)
            }
            return Elements(unique)
        }
        #endif
        return Elements(elements)
    }
    
    /**
     Find elements by ID, including or under this element.
     
     - parameter id: The ID to search for.
     - returns: Elements matching the ID, empty if none.
     */
    @usableFromInline
    func getElementsById(_ id: [UInt8]) -> Elements {
        let needsTrim = (id.first?.isWhitespace ?? false) || (id.last?.isWhitespace ?? false)
        let key = needsTrim ? id.trim() : id
        if key.isEmpty {
            return Elements()
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                return collectElementsByAttributePredicate { element in
                    element.idUTF8() == key
                }
            }
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                let idKey = "id".utf8Array
                if self is Document {
                    let cacheKey = Document.AttributeValueCacheKey(key: idKey, value: key)
                    if let cached = doc.libxml2SkipFallbackAttrValueCacheGet(cacheKey) {
                        return cached
                    }
                    let elements = Libxml2Backend.collectElementsByAttributeValue(
                        start: startNode,
                        key: idKey,
                        value: key,
                        doc: doc
                    )
                    doc.libxml2SkipFallbackAttrValueCachePut(cacheKey, elements)
                    return elements
                }
                return Libxml2Backend.collectElementsByAttributeValue(
                    start: startNode,
                    key: idKey,
                    value: key,
                    doc: doc
                )
            }
        }
#endif
        if isIdQueryIndexDirty || normalizedIdIndex == nil {
            rebuildQueryIndexesForAllIds()
            isIdQueryIndexDirty = false
        }
        
        let results = normalizedIdIndex?[key]?.compactMap { $0.value } ?? []
        return Elements(results)
    }
    
    /**
     Find an element by ID, including or under this element.
     
     Note that this finds the first matching ID, starting with this element. If you search down from a different
     starting point, it is possible to find a different element by ID. For unique element by ID within a Document,
     use ``Element/getElementById(_:)`` on a ``Document``.
     - parameter id: The ID to search for.
     - returns: The first matching element by ID, starting with this element, or `nil` if none found.
     */
    @inline(__always)
    public func getElementById(_ id: String) throws -> Element? {
        let idBytes = id.utf8Array
        try Validate.notEmpty(string: idBytes)
        let needsTrim = (idBytes.first?.isWhitespace ?? false) || (idBytes.last?.isWhitespace ?? false)
        let key = needsTrim ? idBytes.trim() : idBytes
        if key.isEmpty {
            return nil
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = doc.libxml2DocPtr.flatMap { xmlDocGetRootElement($0) }
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                if let match = Libxml2Backend.findFirstElementById(start: startNode, id: key, doc: doc) {
                    return match
                }
            }
        }
#endif
        if isIdQueryIndexDirty || normalizedIdIndex == nil {
            rebuildQueryIndexesForAllIds()
            isIdQueryIndexDirty = false
        }
        
        if let weakElements = normalizedIdIndex?[key] {
            for weak in weakElements {
                if let element = weak.value {
                    return element
                }
            }
        }
        return nil
    }
    
    /**
     * Find elements that have this class, including or under this element. Case insensitive.
     *
     * Elements can have multiple classes (e.g. `<div class="header round first">`. This method
     * checks each class, so you can find the above with `el.getElementsByClass("header")`.
     *
     * - parameter className: the name of the class to search for.
     * - returns: elements with the supplied class name, empty if none
     * - seealso: ``hasClass(_:)-(String)``, ``classNames()``
     */
    @inline(__always)
    public func getElementsByClass(_ className: String) throws -> Elements {
        DebugTrace.log("Element.getElementsByClass: \(className)")
        let key = className.utf8Array
        if isClassQueryIndexDirty || normalizedClassNameIndex == nil {
            DebugTrace.log("Element.getElementsByClass: rebuilding class index")
            rebuildQueryIndexesForAllClasses()
            isClassQueryIndexDirty = false
        }
        let normalizedKey: [UInt8]
        if !Attributes.containsAsciiUppercase(key) {
            normalizedKey = key
        } else {
            normalizedKey = key.lowercased()
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           !doc.libxml2Only,
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                return Libxml2Backend.collectElementsByClassName(
                    start: startNode,
                    className: normalizedKey,
                    doc: doc
                )
            }
        }
#endif
        let results = normalizedClassNameIndex?[normalizedKey]?.compactMap { $0.value } ?? []
        if results.count <= 1 {
            return Elements(results)
        }
        var seen = Set<ObjectIdentifier>()
        seen.reserveCapacity(results.count)
        var unique: [Element] = []
        unique.reserveCapacity(results.count)
        for el in results {
            let id = ObjectIdentifier(el)
            if seen.contains(id) { continue }
            seen.insert(id)
            unique.append(el)
        }
        return Elements(unique)
    }

    @inline(__always)
    @usableFromInline
    internal func getElementsByClassNormalizedBytes(_ normalizedClassName: [UInt8]) -> Elements {
        if normalizedClassName.isEmpty {
            return Elements()
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           !doc.libxml2Only,
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                if self is Document, let cached = doc.libxml2SkipFallbackClassCacheGet(normalizedClassName) {
                    return cached
                }
                let elements = Libxml2Backend.collectElementsByClassName(
                    start: startNode,
                    className: normalizedClassName,
                    doc: doc
                )
                if self is Document {
                    doc.libxml2SkipFallbackClassCachePut(normalizedClassName, elements)
                }
                return elements
            }
        }
#endif
        if isClassQueryIndexDirty || normalizedClassNameIndex == nil {
            rebuildQueryIndexesForAllClasses()
            isClassQueryIndexDirty = false
        }
        let results = normalizedClassNameIndex?[normalizedClassName]?.compactMap { $0.value } ?? []
        return Elements(results)
    }
    
    /**
     Find elements that have a named attribute set. Case insensitive.
     
     - parameter key: name of the attribute, e.g. `href`
     - returns: elements that have this attribute, empty if none
     */
    @inline(__always)
    public func getElementsByAttribute(_ key: String) throws -> Elements {
        try Validate.notEmpty(string: key.utf8Array)
        let keyBytes = key.utf8Array
        @inline(__always)
        func hasAbsPrefix(_ bytes: [UInt8]) -> Bool {
            if bytes.count < UTF8Arrays.absPrefix.count { return false }
            @inline(__always)
            func lowerAscii(_ b: UInt8) -> UInt8 {
                return (b >= 65 && b <= 90) ? b &+ 32 : b
            }
            return lowerAscii(bytes[0]) == UTF8Arrays.absPrefix[0] &&
                lowerAscii(bytes[1]) == UTF8Arrays.absPrefix[1] &&
                lowerAscii(bytes[2]) == UTF8Arrays.absPrefix[2] &&
                bytes[3] == UTF8Arrays.absPrefix[3]
        }
        let needsTrim = (keyBytes.first?.isWhitespace ?? false) || (keyBytes.last?.isWhitespace ?? false)
        let keyForPrefix = needsTrim ? keyBytes.trim() : keyBytes
        if hasAbsPrefix(keyForPrefix) {
            return try Collector.collect(Evaluator.Attribute(key), self)
        }
        let normalizedKey: [UInt8]
        if needsTrim {
            let trimmed = keyForPrefix
            normalizedKey = Attributes.containsAsciiUppercase(trimmed) ? trimmed.lowercased() : trimmed
        } else if Attributes.containsAsciiUppercase(keyBytes) {
            normalizedKey = keyBytes.lowercased()
        } else {
            normalizedKey = keyBytes
        }
        if isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil {
            rebuildQueryIndexesForAllAttributes()
            isAttributeQueryIndexDirty = false
        }
        
        let results = normalizedAttributeNameIndex?[normalizedKey]?.compactMap { $0.value } ?? []
        return Elements(results)
    }

    /**
     Find elements that have a named attribute set with a normalized (trimmed, lowercase) key.
     - parameter normalizedKey: The already-normalized attribute key.
     - returns: elements that have this attribute, empty if none
     */
    @inline(__always)
    public func getElementsByAttributeNormalized(_ normalizedKey: [UInt8]) -> Elements {
        let needsTrim = (normalizedKey.first?.isWhitespace ?? false) || (normalizedKey.last?.isWhitespace ?? false)
        let key = needsTrim ? normalizedKey.trim() : normalizedKey
        if key.isEmpty {
            return Elements()
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                return collectElementsByAttributePredicate { element in
                    element.hasAttr(key)
                }
            }
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                if self is Document, let cached = doc.libxml2SkipFallbackAttrCacheGet(key) {
                    return cached
                }
                let elements = Libxml2Backend.collectElementsByAttributeName(
                    start: startNode,
                    key: key,
                    doc: doc
                )
                if self is Document {
                    doc.libxml2SkipFallbackAttrCachePut(key, elements)
                }
                return elements
            }
        }
#endif
        if isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil {
            rebuildQueryIndexesForAllAttributes()
            isAttributeQueryIndexDirty = false
        }
        let results = normalizedAttributeNameIndex?[key]?.compactMap { $0.value } ?? []
        return Elements(results)
    }
    
    /**
     Find elements that have an attribute name starting with the supplied prefix. Use `data-` to find elements
     that have HTML5 datasets.
     - parameter keyPrefix: name prefix of the attribute e.g. `data-`
     - returns: elements that have attribute names that start with with the prefix, empty if none.
     */
    @inline(__always)
    public func getElementsByAttributeStarting(_ keyPrefix: String) throws -> Elements {
        try Validate.notEmpty(string: keyPrefix.utf8Array)
        let keyPrefix = keyPrefix.trim()
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                let normalizedPrefix = keyPrefix.lowercased().utf8Array
                return try collectElementsByAttributeNamePrefix(normalizedPrefix)
            }
            let normalizedPrefix = keyPrefix.lowercased().utf8Array
            if !normalizedPrefix.isEmpty {
                let startNode: xmlNodePtr?
                if self is Document {
                    startNode = xmlDocGetRootElement(docPtr)
                } else {
                    startNode = libxml2NodePtr
                }
                if let startNode {
                    return Libxml2Backend.collectElementsByAttributeNamePrefix(
                        start: startNode,
                        keyPrefix: normalizedPrefix,
                        doc: doc
                    )
                }
            }
        }
#endif
        return try Collector.collect(Evaluator.AttributeStarting(keyPrefix.utf8Array), self)
    }
    
    /**
     Find elements that have an attribute with the specific value. Case insensitive.
     
     - parameter key: name of the attribute
     - parameter value: value of the attribute
     - returns: elements that have this attribute with this value, empty if none
     */
    @inline(__always)
    public func getElementsByAttributeValue(_ key: String, _ value: String)throws->Elements {
        let keyBytes = key.utf8Array
        @inline(__always)
        func hasAbsPrefix(_ bytes: [UInt8]) -> Bool {
            if bytes.count < UTF8Arrays.absPrefix.count { return false }
            @inline(__always)
            func lowerAscii(_ b: UInt8) -> UInt8 {
                return (b >= 65 && b <= 90) ? b &+ 32 : b
            }
            return lowerAscii(bytes[0]) == UTF8Arrays.absPrefix[0] &&
                lowerAscii(bytes[1]) == UTF8Arrays.absPrefix[1] &&
                lowerAscii(bytes[2]) == UTF8Arrays.absPrefix[2] &&
                bytes[3] == UTF8Arrays.absPrefix[3]
        }
        if hasAbsPrefix(keyBytes) {
            return try Collector.collect(Evaluator.AttributeWithValue(key, value), self)
        }
        let needsTrim = (keyBytes.first?.isWhitespace ?? false) || (keyBytes.last?.isWhitespace ?? false)
        let normalizedKey: [UInt8]
        if needsTrim {
            let trimmed = keyBytes.trim()
            normalizedKey = Attributes.containsAsciiUppercase(trimmed) ? trimmed.lowercased() : trimmed
        } else if Attributes.containsAsciiUppercase(keyBytes) {
            normalizedKey = keyBytes.lowercased()
        } else {
            normalizedKey = keyBytes
        }
        let isHotKey = Element.isHotAttributeKey(normalizedKey)
        if Element.dynamicAttributeValueIndexMaxKeys > 0,
           !isHotKey {
            ensureDynamicAttributeValueIndexKey(normalizedKey)
        }
        if isHotKey || (dynamicAttributeValueIndexKeySet?.contains(normalizedKey) ?? false) {
            if isAttributeValueQueryIndexDirty || normalizedAttributeValueIndex == nil {
                rebuildQueryIndexesForHotAttributes()
                isAttributeValueQueryIndexDirty = false
            }
            let normalizedValue = value.utf8Array.trim().lowercased()
            let results = normalizedAttributeValueIndex?[normalizedKey]?[normalizedValue]?.compactMap { $0.value } ?? []
            return Elements(results)
        }
        return try Collector.collect(Evaluator.AttributeWithValue(key, value), self)
    }

    @inline(__always)
    func getElementsByAttributeValueNormalized(
        _ keyBytes: [UInt8],
        _ valueBytes: [UInt8],
        _ key: String,
        _ value: String
    ) throws -> Elements {
        if keyBytes.starts(with: UTF8Arrays.absPrefix) {
            return try Collector.collect(Evaluator.AttributeWithValue(key, value), self)
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                if self is Document {
                    let cacheKey = Document.AttributeValueCacheKey(key: keyBytes, value: valueBytes)
                    if let cached = doc.libxml2SkipFallbackAttrValueCacheGet(cacheKey) {
                        return cached
                    }
                    let elements = Libxml2Backend.collectElementsByAttributeValue(
                        start: startNode,
                        key: keyBytes,
                        value: valueBytes,
                        doc: doc
                    )
                    doc.libxml2SkipFallbackAttrValueCachePut(cacheKey, elements)
                    return elements
                }
                return Libxml2Backend.collectElementsByAttributeValue(
                    start: startNode,
                    key: keyBytes,
                    value: valueBytes,
                    doc: doc
                )
            }
        }
#endif
        let isHotKey = Element.isHotAttributeKey(keyBytes)
        if Element.dynamicAttributeValueIndexMaxKeys > 0,
           !isHotKey {
            ensureDynamicAttributeValueIndexKey(keyBytes)
        }
        if isHotKey || (dynamicAttributeValueIndexKeySet?.contains(keyBytes) ?? false) {
            if isAttributeValueQueryIndexDirty || normalizedAttributeValueIndex == nil {
                rebuildQueryIndexesForHotAttributes()
                isAttributeValueQueryIndexDirty = false
            }
            let results = normalizedAttributeValueIndex?[keyBytes]?[valueBytes]?.compactMap { $0.value } ?? []
            return Elements(results)
        }
        return try Collector.collect(Evaluator.AttributeWithValue(key, value), self)
    }
    
    /**
     Find elements that either do not have this attribute, or have it with a different value. Case insensitive.
     
     - parameter key: name of the attribute
     - parameter value: value of the attribute
     - returns: elements that do not have a matching attribute
     */
    @inline(__always)
    public func getElementsByAttributeValueNot(_ key: String, _ value: String)throws->Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        let (_, keyBytes, _, valueBytes) = try Element.normalizeAttributeKeyValue(key, value)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                return try collectElementsByAttributePredicate { element in
                    if !element.hasAttr(keyBytes) {
                        return true
                    }
                    let elementValue = try element.attr(keyBytes)
                    return !elementValue.equalsIgnoreCase(string: valueBytes)
                }
            }
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                return Libxml2Backend.collectElementsByAttributeValueNot(
                    start: startNode,
                    key: keyBytes,
                    value: valueBytes,
                    doc: doc
                )
            }
        }
#endif
        return try Collector.collect(Evaluator.AttributeWithValueNot(key, value), self)
    }
    
    /**
     Find elements that have attributes that start with the value prefix. Case insensitive.
     
     - parameter key: name of the attribute
     - parameter valuePrefix: start of attribute value
     - returns: elements that have attributes that start with the value prefix
     */
    @inline(__always)
    public func getElementsByAttributeValueStarting(_ key: String, _ valuePrefix: String)throws->Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        let (_, keyBytes, normalizedValue, valueBytes) = try Element.normalizeAttributeKeyValue(key, valuePrefix)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                return try collectElementsByAttributePredicate { element in
                    guard element.hasAttr(keyBytes) else { return false }
                    let elementValue = try element.attr(keyBytes)
                    let normalizedElementValue = Attributes.containsAsciiUppercase(elementValue)
                        ? elementValue.lowercased()
                        : elementValue
                    return Element.bytesStartsWith(normalizedElementValue, valueBytes)
                }
            }
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                return Libxml2Backend.collectElementsByAttributeValueStarting(
                    start: startNode,
                    key: keyBytes,
                    value: valueBytes,
                    valueLower: normalizedValue,
                    doc: doc
                )
            }
        }
#endif
        return try Collector.collect(Evaluator.AttributeWithValueStarting(key, valuePrefix), self)
    }
    
    /**
     Find elements that have attributes that end with the value suffix. Case insensitive.
     
     - parameter key: name of the attribute
     - parameter valueSuffix: end of the attribute value
     - returns: elements that have attributes that end with the value suffix
     */
    @inline(__always)
    public func getElementsByAttributeValueEnding(_ key: String, _ valueSuffix: String)throws->Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        let (_, keyBytes, normalizedValue, valueBytes) = try Element.normalizeAttributeKeyValue(key, valueSuffix)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                return try collectElementsByAttributePredicate { element in
                    guard element.hasAttr(keyBytes) else { return false }
                    let elementValue = try element.attr(keyBytes)
                    let normalizedElementValue = Attributes.containsAsciiUppercase(elementValue)
                        ? elementValue.lowercased()
                        : elementValue
                    return Element.bytesEndsWith(normalizedElementValue, valueBytes)
                }
            }
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                return Libxml2Backend.collectElementsByAttributeValueEnding(
                    start: startNode,
                    key: keyBytes,
                    value: valueBytes,
                    valueLower: normalizedValue,
                    doc: doc
                )
            }
        }
#endif
        return try Collector.collect(Evaluator.AttributeWithValueEnding(key, valueSuffix), self)
    }
    
    /**
     Find elements that have attributes whose value contains the match string. Case insensitive.
     
     - parameter key: name of the attribute
     - parameter match: substring of value to search for
     - returns: elements that have attributes containing this text
     */
    @inline(__always)
    public func getElementsByAttributeValueContaining(_ key: String, _ match: String)throws->Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        let (_, keyBytes, normalizedValue, valueBytes) = try Element.normalizeAttributeKeyValue(key, match)
        if let doc = ownerDocument(),
           (doc.libxml2Only),
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            if doc.libxml2AttributeOverrides?.isEmpty == false {
                return try collectElementsByAttributePredicate { element in
                    guard element.hasAttr(keyBytes) else { return false }
                    let elementValue = try element.attr(keyBytes)
                    let normalizedElementValue = Attributes.containsAsciiUppercase(elementValue)
                        ? elementValue.lowercased()
                        : elementValue
                    return Element.bytesContains(normalizedElementValue, valueBytes)
                }
            }
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            if let startNode {
                return Libxml2Backend.collectElementsByAttributeValueContaining(
                    start: startNode,
                    key: keyBytes,
                    value: valueBytes,
                    valueLower: normalizedValue,
                    doc: doc
                )
            }
        }
#endif
        return try Collector.collect(Evaluator.AttributeWithValueContaining(key, match), self)
    }
    
    /**
     Find elements that have attributes whose values match the supplied regular expression.
     - parameter key: name of the attribute
     - parameter pattern: compiled regular expression to match against attribute values
     - returns: elements that have attributes matching this regular expression
     */
    public func getElementsByAttributeValueMatching(_ key: String, _ pattern: Pattern)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValueMatching(key, pattern), self)
        
    }
    
    /**
     Find elements that have attributes whose values match the supplied regular expression.
     - parameter key: name of the attribute
     - parameter regex: regular expression to match against attribute values. You can use [embedded flags](https://developer.apple.com/documentation/foundation/nsregularexpression#Flag-Options) (such as `(?i)` and `(?m)`) to control regex options.
     - returns: elements that have attributes matching this regular expression
     */
    public func getElementsByAttributeValueMatching(_ key: String, _ regex: String)throws->Elements {
        var pattern: Pattern
        do {
            pattern = Pattern.compile(regex)
            try pattern.validate()
        } catch {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Pattern syntax error: \(regex)")
        }
        return try getElementsByAttributeValueMatching(key, pattern)
    }
    
    /**
     Find elements whose sibling index is less than the supplied index.
     - parameter index: 0-based index
     - returns: elements less than index
     */
    public func getElementsByIndexLessThan(_ index: Int)throws->Elements {
        return try Collector.collect(Evaluator.IndexLessThan(index), self)
    }
    
    /**
     Find elements whose sibling index is greater than the supplied index.
     - parameter index: 0-based index
     - returns: elements greater than index
     */
    public func getElementsByIndexGreaterThan(_ index: Int)throws->Elements {
        return try Collector.collect(Evaluator.IndexGreaterThan(index), self)
    }
    
    /**
     Find elements whose sibling index is equal to the supplied index.
     - parameter index: 0-based index
     - returns: elements equal to index
     */
    public func getElementsByIndexEquals(_ index: Int)throws->Elements {
        return try Collector.collect(Evaluator.IndexEquals(index), self)
    }
    
    /**
     Find elements that contain the specified string. The search is case insensitive. The text may appear directly
     in the element, or in any of its descendants.
     - parameter searchText: to look for in the element's text
     - returns: elements that contain the string, case insensitive.
     - seealso: ``text(_:)``
     */
    public func getElementsContainingText(_ searchText: String)throws->Elements {
        return try Collector.collect(Evaluator.ContainsText(searchText), self)
    }
    
    /**
     Find elements that directly contain the specified string. The search is case insensitive. The text must appear directly
     in the element, not in any of its descendants.
     - parameter searchText: to look for in the element's own text
     - returns: elements that contain the string, case insensitive.
     - seealso: ``ownText()``
     */
    public func getElementsContainingOwnText(_ searchText: String)throws->Elements {
        return try Collector.collect(Evaluator.ContainsOwnText(searchText), self)
    }
    
    /**
     Find elements whose text matches the supplied regular expression.
     - parameter pattern: regular expression to match text against
     - returns: elements matching the supplied regular expression.
     - seealso: ``text(_:)``
     */
    public func getElementsMatchingText(_ pattern: Pattern)throws->Elements {
        return try Collector.collect(Evaluator.Matches(pattern), self)
    }
    
    /**
     Find elements whose text matches the supplied regular expression.
     - parameter regex: regular expression to match text against. You can use [embedded flags](https://developer.apple.com/documentation/foundation/nsregularexpression#Flag-Options) (such as `(?i)` and `(?m)`) to control regex options.
     - returns: elements matching the supplied regular expression.
     - seealso: ``text(_:)``
     */
    public func getElementsMatchingText(_ regex: String)throws->Elements {
        let pattern: Pattern
        do {
            pattern = Pattern.compile(regex)
            try pattern.validate()
        } catch {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Pattern syntax error: \(regex)")
        }
        return try getElementsMatchingText(pattern)
    }
    
    /**
     Find elements whose own text matches the supplied regular expression.
     - parameter pattern: regular expression to match text against
     - returns: elements matching the supplied regular expression.
     - seealso: ``ownText()``
     */
    public func getElementsMatchingOwnText(_ pattern: Pattern)throws->Elements {
        return try Collector.collect(Evaluator.MatchesOwn(pattern), self)
    }
    
    /**
     Find elements whose text matches the supplied regular expression.
     - parameter regex: regular expression to match text against. You can use [embedded flags](https://developer.apple.com/documentation/foundation/nsregularexpression#Flag-Options) (such as `(?i)` and `(?m)`) to control regex options.
     - returns: elements matching the supplied regular expression.
     - seealso: ``ownText()``
     */
    public func getElementsMatchingOwnText(_ regex: String)throws->Elements {
        let pattern: Pattern
        do {
            pattern = Pattern.compile(regex)
            try pattern.validate()
        } catch {
            throw Exception.Error(type: ExceptionType.IllegalArgumentException, Message: "Pattern syntax error: \(regex)")
        }
        return try getElementsMatchingOwnText(pattern)
    }
    
    /**
     Find all elements under this element (including self, and children of children).
     
     - returns: all elements
     */
    public func getAllElements()throws->Elements {
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(),
           doc.libxml2Only,
           !doc.libxml2BackedDirty,
           let docPtr = doc.libxml2DocPtr {
            let startNode: xmlNodePtr?
            if self is Document {
                startNode = xmlDocGetRootElement(docPtr)
            } else {
                startNode = libxml2NodePtr
            }
            return Libxml2Backend.collectAllElements(
                start: startNode,
                doc: doc,
                includeSelf: !(self is Document)
            )
        }
#endif
        return try Collector.collect(Evaluator.AllElements(), self)
    }
    
    /**
     Gets the combined text of this element and all its children. Whitespace is normalized and trimmed.
     
     For example, given HTML `<p>Hello  <b>there</b> now! </p>`, `p.text()` returns `"Hello there now!"`
     
     - returns: unencoded text, or empty string if none.
     - seealso: ``ownText()``, ``textNodes()``
     */
    class TextNodeVisitor: NodeVisitor {
        let accum: StringBuilder
        let trimAndNormaliseWhitespace: Bool
        init(_ accum: StringBuilder, trimAndNormaliseWhitespace: Bool) {
            self.accum = accum
            self.trimAndNormaliseWhitespace = trimAndNormaliseWhitespace
        }
        public func head(_ node: Node, _ depth: Int) {
            if let textNode = (node as? TextNode) {
                if trimAndNormaliseWhitespace {
                    Element.appendNormalisedText(accum, textNode)
                } else {
                    accum.append(textNode.getWholeTextUTF8())
                }
            } else if let element = (node as? Element) {
                if !accum.isEmpty &&
                    (element.isBlock() || element._tag.getNameUTF8() == UTF8Arrays.br) &&
                    !TextNode.lastCharIsWhitespace(accum) {
                    accum.append(UTF8Arrays.whitespace)
                }
            }
        }
        
        public func tail(_ node: Node, _ depth: Int) {
        }
    }

    @inline(__always)
    private func collectTextFast(_ accum: StringBuilder, trimAndNormaliseWhitespace: Bool) {
        var stack: ContiguousArray<Node> = []
        stack.reserveCapacity(childNodes.count + 1)
        stack.append(self)
        var lastWasWhite = false
        while let node = stack.popLast() {
            if let textNode = node as? TextNode {
                if trimAndNormaliseWhitespace {
                    Element.appendNormalisedTextTracking(accum, textNode, lastWasWhite: &lastWasWhite)
                } else {
                    let slice = textNode.wholeTextSlice()
                    accum.append(slice)
                    if let last = slice.last {
                        lastWasWhite = (last == TokeniserStateVars.spaceByte)
                    }
                }
                continue
            }
            if let element = node as? Element {
                if !accum.isEmpty &&
                    (element.isBlock() || Tag.isBr(element._tag)) &&
                    !lastWasWhite {
                    accum.append(UTF8Arrays.whitespace)
                    lastWasWhite = true
                }
            }
            let children = node.childNodes
            if !children.isEmpty {
                var i = children.count - 1
                while i >= 0 {
                    stack.append(children[i])
                    i -= 1
                }
            }
        }
    }

    @inline(__always)
    private func collectTextFastTrimmed(_ accum: StringBuilder) -> (Bool, Bool) {
        var stack: ContiguousArray<Node> = []
        stack.reserveCapacity(childNodes.count + 1)
        stack.append(self)
        var lastWasWhite = false
        var sawWhitespace = false
        while let node = stack.popLast() {
            if let textNode = node as? TextNode {
                Element.appendNormalisedTextTracking(
                    accum,
                    textNode,
                    lastWasWhite: &lastWasWhite,
                    sawWhitespace: &sawWhitespace
                )
                continue
            }
            if let element = node as? Element {
                if !accum.isEmpty &&
                    (element.isBlock() || Tag.isBr(element._tag)) &&
                    !lastWasWhite {
                    accum.append(UTF8Arrays.whitespace)
                    lastWasWhite = true
                    sawWhitespace = true
                }
            }
            let children = node.childNodes
            if !children.isEmpty {
                var i = children.count - 1
                while i >= 0 {
                    stack.append(children[i])
                    i -= 1
                }
            }
        }
        return (lastWasWhite, sawWhitespace)
    }

    @inline(__always)
    private func collectTextFastRaw(_ accum: StringBuilder) {
        var stack: ContiguousArray<Node> = []
        stack.reserveCapacity(childNodes.count + 1)
        stack.append(self)
        var lastWasWhite = false
        while let node = stack.popLast() {
            if let textNode = node as? TextNode {
                let slice = textNode.wholeTextSlice()
                accum.append(slice)
                if let last = slice.last {
                    lastWasWhite = (last == TokeniserStateVars.spaceByte)
                }
                continue
            }
            if let element = node as? Element {
                if !accum.isEmpty &&
                    (element.isBlock() || Tag.isBr(element._tag)) &&
                    !lastWasWhite {
                    accum.append(UTF8Arrays.whitespace)
                    lastWasWhite = true
                }
            }
            let children = node.childNodes
            if !children.isEmpty {
                var i = children.count - 1
                while i >= 0 {
                    stack.append(children[i])
                    i -= 1
                }
            }
        }
    }
    
    public func text(trimAndNormaliseWhitespace: Bool = true) throws -> String {
#if canImport(CLibxml2) || canImport(libxml2)
        if ownerDocument()?.libxml2Only == true,
           let bytes = Libxml2Backend.textFromLibxml2Node(self, trim: trimAndNormaliseWhitespace) {
            return String(decoding: bytes, as: UTF8.self)
        }
#endif
        if trimAndNormaliseWhitespace {
            if let slice = singleTextNoWhitespaceSlice() {
                return String(decoding: slice, as: UTF8.self)
            }
            if childNodes.count == 1, let textNode = childNodes.first as? TextNode {
                let accum = StringBuilder()
                Element.appendNormalisedText(accum, textNode)
                if let first = accum.buffer.first, first.isWhitespace {
                    let trimmed = accum.buffer.trim()
                    return String(decoding: trimmed, as: UTF8.self)
                }
                accum.trimTrailingWhitespace()
                let text = String(decoding: accum.buffer, as: UTF8.self)
                return text
            }
            let accum: StringBuilder = StringBuilder(max(64, childNodes.count * 8))
            #if PROFILE
            let _p = Profiler.start("Element.text.traverse")
            defer { Profiler.end("Element.text.traverse", _p) }
            #endif
            let (lastWasWhite, sawWhitespace) = collectTextFastTrimmed(accum)
            if sawWhitespace, let first = accum.buffer.first, first.isWhitespace {
                let trimmed = accum.buffer.trim()
                return String(decoding: trimmed, as: UTF8.self)
            }
            if sawWhitespace, lastWasWhite {
                accum.trimTrailingWhitespace()
            }
            return String(decoding: accum.buffer, as: UTF8.self)
        }
        let accum: StringBuilder = StringBuilder(max(64, childNodes.count * 8))
        collectTextFastRaw(accum)
        return accum.toString()
    }
    
    public func textUTF8(trimAndNormaliseWhitespace: Bool = true) throws -> [UInt8] {
#if canImport(CLibxml2) || canImport(libxml2)
        if ownerDocument()?.libxml2Only == true,
           let bytes = Libxml2Backend.textFromLibxml2Node(self, trim: trimAndNormaliseWhitespace) {
            return bytes
        }
#endif
        if trimAndNormaliseWhitespace, let slice = singleTextNoWhitespaceSlice() {
            return Array(slice)
        }
        let accum: StringBuilder = StringBuilder(max(64, childNodes.count * 8))
        if trimAndNormaliseWhitespace {
            let (lastWasWhite, sawWhitespace) = collectTextFastTrimmed(accum)
            if sawWhitespace, let first = accum.buffer.first, first.isWhitespace {
                return Array(accum.buffer.trim())
            }
            if sawWhitespace, lastWasWhite {
                accum.trimTrailingWhitespace()
            }
            return Array(accum.buffer)
        }
        collectTextFastRaw(accum)
        return Array(accum.buffer)
    }
    
    public func textUTF8Slice(trimAndNormaliseWhitespace: Bool = true) throws -> ArraySlice<UInt8> {
        if trimAndNormaliseWhitespace, let slice = singleTextNoWhitespaceSlice() {
            return slice
        }
        let accum: StringBuilder = StringBuilder(max(64, childNodes.count * 8))
        if trimAndNormaliseWhitespace {
            let (lastWasWhite, sawWhitespace) = collectTextFastTrimmed(accum)
            if sawWhitespace, let first = accum.buffer.first, first.isWhitespace {
                return accum.buffer.trim()
            }
            if sawWhitespace, lastWasWhite {
                accum.trimTrailingWhitespace()
            }
            return accum.buffer
        }
        collectTextFastRaw(accum)
        return accum.buffer
    }

    @inline(__always)
    private func singleTextNoWhitespaceSlice() -> ArraySlice<UInt8>? {
        guard childNodes.count == 1, let textNode = childNodes.first as? TextNode else {
            return nil
        }
        let slice = textNode.wholeTextSlice()
        if slice.isEmpty {
            return slice
        }
        for b in slice {
            if StringUtil.isAsciiWhitespaceByte(b) ||
                b == StringUtil.utf8NBSPLead ||
                b == StringUtil.utf8NBSPTrail {
                return nil
            }
        }
        return slice
    }

    /**
     Gets the text owned by this element only; does not get the combined text of all children.
     
     For example, given HTML `<p>Hello <b>there</b> now!</p>`, `p.ownText()` returns `"Hello now!"`,
     whereas `p.text()` returns `"Hello there now!"`.
     Note that the text within the `b` element is not returned, as it is not a direct child of the `p` element.
     
     - returns: unencoded text, or empty string if none.
     - seealso: ``text(_:)``, ``textNodes()``
     */
    public func ownText() -> String {
#if canImport(CLibxml2) || canImport(libxml2)
        if let bytes = Libxml2Backend.ownTextFromLibxml2Node(self) {
            return String(decoding: bytes, as: UTF8.self)
        }
#endif
        let sb: StringBuilder = StringBuilder()
        ownText(sb)
        return sb.toString().trim()
    }
    
    /**
     Gets the text owned by this element only; does not get the combined text of all children.
     
     For example, given HTML `<p>Hello <b>there</b> now!</p>`, `p.ownText()` returns `"Hello now!"`,
     whereas `p.text()` returns `"Hello there now!"`.
     Note that the text within the `b` element is not returned, as it is not a direct child of the `p` element.
     
     - returns: unencoded text, or empty string if none.
     - seealso: ``text(_:)``, ``textNodes()``
     */
    public func ownTextUTF8() -> [UInt8] {
#if canImport(CLibxml2) || canImport(libxml2)
        if let bytes = Libxml2Backend.ownTextFromLibxml2Node(self) {
            return bytes
        }
#endif
        let sb: StringBuilder = StringBuilder()
        ownText(sb)
        if let first = sb.buffer.first, first.isWhitespace {
            return Array(sb.buffer.trim())
        }
        sb.trimTrailingWhitespace()
        return Array(sb.buffer)
    }
    
    private func ownText(_ accum: StringBuilder) {
        for child: Node in childNodes {
            if let textNode = (child as? TextNode) {
                Element.appendNormalisedText(accum, textNode)
            } else if let child =  (child as? Element) {
                Element.appendWhitespaceIfBr(child, accum)
            }
        }
    }
    
    private static func appendNormalisedText(_ accum: StringBuilder, _ textNode: TextNode) {
        let text = textNode.wholeTextSlice()
        if Element.preserveWhitespace(textNode.parentNode) {
            accum.append(text)
            return
        }
        StringUtil.appendNormalisedWhitespace(
            accum,
            string: text,
            stripLeading: accum.isEmpty || TextNode.lastCharIsWhitespace(accum)
        )
    }

    @inline(__always)
    private static func appendNormalisedTextTracking(_ accum: StringBuilder,
                                                     _ textNode: TextNode,
                                                     lastWasWhite: inout Bool) {
        let text = textNode.wholeTextSlice()
        if Element.preserveWhitespace(textNode.parentNode) {
            accum.append(text)
            if let last = text.last {
                lastWasWhite = (last == TokeniserStateVars.spaceByte)
            }
            return
        }
        StringUtil.appendNormalisedWhitespace(
            accum,
            string: text,
            stripLeading: accum.isEmpty || lastWasWhite,
            lastWasWhite: &lastWasWhite
        )
    }

    @inline(__always)
    private static func appendNormalisedTextTracking(_ accum: StringBuilder,
                                                     _ textNode: TextNode,
                                                     lastWasWhite: inout Bool,
                                                     sawWhitespace: inout Bool) {
        let text = textNode.wholeTextSlice()
        if Element.preserveWhitespace(textNode.parentNode) {
            accum.append(text)
            if let last = text.last {
                lastWasWhite = (last == TokeniserStateVars.spaceByte)
            }
            sawWhitespace = true
            return
        }
        StringUtil.appendNormalisedWhitespace(
            accum,
            string: text,
            stripLeading: accum.isEmpty || lastWasWhite,
            lastWasWhite: &lastWasWhite,
            sawWhitespace: &sawWhitespace
        )
    }

    @inline(__always)
    private static func lowerAscii(_ byte: UInt8) -> UInt8 {
        if byte >= 65 && byte <= 90 {
            return byte &+ 32
        }
        return byte
    }

    private struct AsciiKMPMatcher {
        let needle: [UInt8]
        let lps: [Int]
        var j: Int = 0

        init(_ needle: [UInt8]) {
            self.needle = needle
            var lps = [Int](repeating: 0, count: needle.count)
            var length = 0
            var i = 1
            while i < needle.count {
                if needle[i] == needle[length] {
                    length += 1
                    lps[i] = length
                    i += 1
                } else if length != 0 {
                    length = lps[length - 1]
                } else {
                    lps[i] = 0
                    i += 1
                }
            }
            self.lps = lps
        }

        @inline(__always)
        mutating func feed(_ byte: UInt8) -> Bool {
            let c = Element.lowerAscii(byte)
            while j > 0 && c != needle[j] {
                j = lps[j - 1]
            }
            if c == needle[j] {
                j += 1
                if j == needle.count {
                    return true
                }
            }
            return false
        }
    }

    @inline(__always)
    private static func emitNormalizedSlice(_ slice: ArraySlice<UInt8>,
                                            stripLeading: Bool,
                                            emittedAny: inout Bool,
                                            lastWasWhite: inout Bool,
                                            matcher: inout AsciiKMPMatcher) -> Bool {
        var reachedNonWhite = false
        var i = slice.startIndex
        let end = slice.endIndex
        while i < end {
            let firstByte = slice[i]
            if firstByte < TokeniserStateVars.asciiUpperLimitByte {
                if StringUtil.isAsciiWhitespaceByte(firstByte) {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i = slice.index(after: i)
                        continue
                    }
                    if matcher.feed(TokeniserStateVars.spaceByte) { return true }
                    lastWasWhite = true
                    emittedAny = true
                    i = slice.index(after: i)
                    continue
                }
                var j = i
                while j < end {
                    let b = slice[j]
                    if b >= TokeniserStateVars.asciiUpperLimitByte || StringUtil.isAsciiWhitespaceByte(b) {
                        break
                    }
                    if matcher.feed(b) { return true }
                    j = slice.index(after: j)
                }
                if i != j {
                    emittedAny = true
                    lastWasWhite = false
                    reachedNonWhite = true
                    i = j
                    continue
                }
                i = slice.index(after: i)
                continue
            }
            if firstByte == StringUtil.utf8NBSPLead {
                let next = slice.index(after: i)
                if next < end, slice[next] == StringUtil.utf8NBSPTrail {
                    if (stripLeading && !reachedNonWhite) || lastWasWhite {
                        i = slice.index(after: next)
                        continue
                    }
                    if matcher.feed(TokeniserStateVars.spaceByte) { return true }
                    lastWasWhite = true
                    emittedAny = true
                    reachedNonWhite = true
                    i = slice.index(after: next)
                    continue
                }
            }
            let scalarByteCount: Int
            if firstByte < StringUtil.utf8Lead3Min {
                scalarByteCount = 2
            } else if firstByte < StringUtil.utf8Lead4Min {
                scalarByteCount = 3
            } else {
                scalarByteCount = 4
            }
            var next = i
            for _ in 0..<scalarByteCount {
                if next == end { return false }
                let b = slice[next]
                if matcher.feed(b) { return true }
                next = slice.index(after: next)
            }
            emittedAny = true
            lastWasWhite = false
            reachedNonWhite = true
            i = next
        }
        return false
    }

    @inline(__always)
    internal func containsNormalizedTextASCII(_ needleLower: [UInt8]) -> Bool {
        if needleLower.isEmpty {
            return true
        }
        var matcher = AsciiKMPMatcher(needleLower)
        var stack: ContiguousArray<Node> = []
        stack.reserveCapacity(childNodes.count + 1)
        stack.append(self)
        var lastWasWhite = false
        var emittedAny = false
        while let node = stack.popLast() {
            if let textNode = node as? TextNode {
                let slice = textNode.wholeTextSlice()
                let stripLeading = !emittedAny || lastWasWhite
                if Element.emitNormalizedSlice(slice,
                                               stripLeading: stripLeading,
                                               emittedAny: &emittedAny,
                                               lastWasWhite: &lastWasWhite,
                                               matcher: &matcher) {
                    return true
                }
                continue
            }
            if let element = node as? Element {
                if emittedAny,
                   (element.isBlock() || Tag.isBr(element._tag)),
                   !lastWasWhite {
                    if matcher.feed(TokeniserStateVars.spaceByte) { return true }
                    emittedAny = true
                    lastWasWhite = true
                }
            }
            let children = node.childNodes
            if !children.isEmpty {
                var i = children.count - 1
                while i >= 0 {
                    stack.append(children[i])
                    i -= 1
                }
            }
        }
        return false
    }

    @inline(__always)
    internal func containsOwnTextASCII(_ needleLower: [UInt8]) -> Bool {
        if needleLower.isEmpty {
            return true
        }
        var matcher = AsciiKMPMatcher(needleLower)
        var lastWasWhite = false
        var emittedAny = false
        let children = childNodes
        for child in children {
            if let textNode = child as? TextNode {
                let slice = textNode.wholeTextSlice()
                let stripLeading = !emittedAny || lastWasWhite
                if Element.emitNormalizedSlice(slice,
                                               stripLeading: stripLeading,
                                               emittedAny: &emittedAny,
                                               lastWasWhite: &lastWasWhite,
                                               matcher: &matcher) {
                    return true
                }
            } else if let element = child as? Element {
                if emittedAny, Tag.isBr(element._tag), !lastWasWhite {
                    if matcher.feed(TokeniserStateVars.spaceByte) { return true }
                    emittedAny = true
                    lastWasWhite = true
                }
            }
        }
        return false
    }
    
    private static func appendWhitespaceIfBr(_ element: Element, _ accum: StringBuilder) {
        if (Tag.isBr(element._tag) && !TextNode.lastCharIsWhitespace(accum)) {
            accum.append(UTF8Arrays.whitespace)
        }
    }
    
    static func preserveWhitespace(_ node: Node?) -> Bool {
        // looks only at this element and one level up, to prevent recursion & needless stack searches
        if let element = (node as? Element) {
            return element._tag.preserveWhitespace() || element.parent() != nil && element.parent()!._tag.preserveWhitespace()
        }
        return false
    }
    
    /**
     Set the text of this element. Any existing contents (text or elements) will be cleared
     - parameter text: unencoded text
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    public func text(_ text: String) throws -> Element {
        empty()
        let textNode: TextNode = TextNode(text.utf8Array, baseUri)
        try appendChild(textNode)
        return self
    }
    
    /**
     Test if this element has any text content (that is not just whitespace).
     - returns: true if element has non-blank text content.
     */
    public func hasText() -> Bool {
        for child: Node in childNodes {
            if let textNode = (child as? TextNode) {
                if (!textNode.isBlank()) {
                    return true
                }
            } else if let el = (child as? Element) {
                if (el.hasText()) {
                    return true
                }
            }
        }
        return false
    }
    
    /**
     Get the combined data of this element. Data is e.g. the inside of a `script` tag.
     - returns: the data, or empty string if none
     - seealso: ``dataNodes()``
     */
    public func data() -> String {
        let sb: StringBuilder = StringBuilder()
        
        for childNode: Node in childNodes {
            if let data = (childNode as? DataNode) {
                sb.append(data.getWholeDataUTF8())
            } else if let element = (childNode as? Element) {
                let elementData: String = element.data()
                sb.append(elementData)
            }
        }
        return sb.toString()
    }
    
    /**
     Gets the literal value of this element's "class" attribute, which may include multiple class names, space
     separated. (E.g. on `;` returns, "`y`")
     - returns: The literal class attribute, or an empty string if no class attribute set.
     */
    public func className() throws -> String {
        return try String(decoding: attr(Element.classString).trim(), as: UTF8.self)
    }
    
    /**
     Gets the literal value of this element's "class" attribute, which may include multiple class names, space
     separated. (E.g. on `;` returns, "`y`")
     - returns: The literal class attribute, or an empty array if no class attribute set.
     */
    public func classNameUTF8() throws -> [UInt8] {
        return try attr(Element.classString).trim()
    }
    
    /**
     Get all of the element's class names. E.g. on element `<div class="header gray">`,
     returns a set of two elements `"header", "gray"`. Note that modifications to this set are not pushed to
     the backing `class` attribute; use the ``classNames(_:)`` method to persist them.
     - returns: set of classnames, empty if no class attribute
     */
    @inlinable
    public func unorderedClassNamesUTF8() throws -> [ArraySlice<UInt8>] {
        let input = try classNameUTF8()
        var result = [ArraySlice<UInt8>]()
        result.reserveCapacity(Int(ceil(CGFloat(input.underestimatedCount) / 10)))
        var i = 0
        let len = input.count
        
        while i < len {
            // Skip any leading whitespace
            while i < len && input[i].isWhitespace {
                i += 1
            }
            let start = i
            
            // Find the end of the class name
            while i < len && !input[i].isWhitespace {
                i += 1
            }
            
            if start < i {
                result.append(input[start..<i])
            }
        }
        
        return result
    }
    
    /**
     Get all of the element's class names. E.g. on element `<div class="header gray">`,
     returns a set of two elements `"header", "gray"`. Note that modifications to this set are not pushed to
     the backing `class` attribute; use the ``classNames(_:)`` method to persist them.
     - returns: set of classnames, empty if no class attribute
     */
    @inlinable
    public func classNamesUTF8() throws -> OrderedSet<[UInt8]> {
        let input = try classNameUTF8()
        let set = OrderedSet<[UInt8]>()
        var i = 0
        let len = input.count
        
        while i < len {
            // Skip any leading whitespace
            while i < len && input[i].isWhitespace {
                i += 1
            }
            let start = i
            
            // Find the end of the class name
            while i < len && !input[i].isWhitespace {
                i += 1
            }
            
            if start < i {
                set.append(Array(input[start..<i]))
            }
        }
        
        return set
    }
    
    /**
     Get all of the element's class names. E.g. on element `<div class="header gray">`,
     returns a set of two elements `"header", "gray"`. Note that modifications to this set are not pushed to
     the backing `class` attribute; use the ``classNames(_:)`` method to persist them.
     - returns: set of classnames, empty if no class attribute
     */
    public func classNames() throws -> OrderedSet<String> {
        let utf8ClassName = try classNameUTF8()
        let classNames = OrderedSet<String>()
        var currentStartIndex: Int? = nil
        
        for (i, byte) in utf8ClassName.enumerated() {
            if byte.isWhitespace {
                if let start = currentStartIndex {
                    let classBytes = utf8ClassName[start..<i]
                    if !classBytes.isEmpty {
                        classNames.append(String(decoding: classBytes, as: UTF8.self))
                    }
                    currentStartIndex = nil
                }
            } else {
                if currentStartIndex == nil {
                    currentStartIndex = i
                }
            }
        }
        
        if let start = currentStartIndex {
            let classBytes = utf8ClassName[start..<utf8ClassName.count]
            if !classBytes.isEmpty {
                classNames.append(String(decoding: classBytes, as: UTF8.self))
            }
        }
        
        return classNames
    }
    
    /**
     Set the element's `class` attribute to the supplied class names.
     - parameter classNames: set of classes
     - returns: this element, for chaining
     */
    @discardableResult
    public func classNames(_ classNames: OrderedSet<String>) throws -> Element {
        _ = ensureAttributes()
        try attributes?.put(Element.classString, StringUtil.join(classNames, sep: " ").utf8Array)
        return self
    }
    
    /**
     Tests if this element has a class. Case insensitive.
     - parameter className: name of class to check for
     - returns: true if it does, false if not
     */
    // performance sensitive
    @inline(__always)
    public func hasClass(_ className: String) -> Bool {
        hasClass(className.utf8Array)
    }
    
    /**
     Tests if this element has a class. Case insensitive.
     - parameter className: name of class to check for
     - returns: true if it does, false if not
     */
    // performance sensitive
    public func hasClass(_ className: [UInt8]) -> Bool {
        DebugTrace.log("Element.hasClass(bytes): \(String(decoding: className, as: UTF8.self))")
        guard let classAttr = attributes?.get(key: Element.classString) else {
            DebugTrace.log("Element.hasClass: no class attr")
            return false
        }
        let len = classAttr.count
        let wantLen = className.count
        if len == 0 || len < wantLen || wantLen == 0 {
            DebugTrace.log("Element.hasClass: len mismatch")
            return false
        }
        if len == wantLen {
            return className.equalsIgnoreCase(string: classAttr)
        }

        @inline(__always)
        func equalsIgnoreCaseSlice(_ bytes: [UInt8], _ start: Int, _ length: Int, _ other: [UInt8]) -> Bool {
            if length != other.count { return false }
            var i = 0
            while i < length {
                let b = bytes[start + i]
                let o = other[i]
                let lowerB = (b >= 65 && b <= 90) ? (b &+ 32) : b
                let lowerO = (o >= 65 && o <= 90) ? (o &+ 32) : o
                if lowerB != lowerO {
                    return false
                }
                i &+= 1
            }
            return true
        }

        var i = 0
        var tokenStart = 0
        var inToken = false
        while i < len {
            let b = classAttr[i]
            if b.isWhitespace {
                if inToken {
                    let tokenLen = i - tokenStart
                    if tokenLen == wantLen && equalsIgnoreCaseSlice(classAttr, tokenStart, tokenLen, className) {
                        return true
                    }
                    inToken = false
                }
            } else if !inToken {
                inToken = true
                tokenStart = i
            }
            i &+= 1
        }
        if inToken {
            let tokenLen = len - tokenStart
            if tokenLen == wantLen && equalsIgnoreCaseSlice(classAttr, tokenStart, tokenLen, className) {
                return true
            }
        }
        return false
    }
    
    /**
     Add a class name to this element's `class` attribute.
     - parameter className: class name to add
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    public func addClass(_ className: String) throws -> Element {
        let classes: OrderedSet<String> = try classNames()
        classes.append(className)
        try classNames(classes)
        return self
    }
    
    /**
     Remove a class name from this element's `class` attribute.
     - parameter className: class name to remove
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    public func removeClass(_ className: String) throws -> Element {
        let classes: OrderedSet<String> = try classNames()
        classes.remove(className)
        try classNames(classes)
        return self
    }
    
    /**
     Toggle a class name on this element's `class` attribute: if present, remove it; otherwise add it.
     - parameter className: class name to toggle
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    public func toggleClass(_ className: String) throws -> Element {
        let classes: OrderedSet<String> = try classNames()
        if (classes.contains(className)) {classes.remove(className)
        } else {
            classes.append(className)
        }
        try classNames(classes)
        
        return self
    }
    
    /**
     Get the value of a form element (input, textarea, etc).
     - returns: the value of the form element, or empty string if not set.
     */
    @inline(__always)
    public func val() throws -> String {
        if (tagName() == "textarea") {
            return try text()
        } else {
            return try attr("value")
        }
    }
    
    /**
     Set the value of a form element (input, textarea, etc).
     - parameter value: value to set
     - returns: this element (for chaining)
     */
    @discardableResult
    @inline(__always)
    public func val(_ value: String) throws -> Element {
        if (tagName() == "textarea") {
            try text(value)
        } else {
            try attr("value", value)
        }
        return self
    }
    
    @inline(__always)
    override func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
        if (out.prettyPrint() && (_tag.formatAsBlock() || (parent() != nil && parent()!.tag().formatAsBlock()) || out.outline())) {
            if !accum.isEmpty {
                indent(accum, depth, out)
            }
        }
        accum
            .append(UTF8Arrays.tagStart)
            .append(tagNameUTF8())
        try attributes?.html(accum: accum, out: out)
        
        // selfclosing includes unknown tags, isEmpty defines tags that are always empty
        if (childNodes.isEmpty && _tag.isSelfClosing()) {
            if (out.syntax() == OutputSettings.Syntax.html && _tag.isEmpty()) {
                accum.append(UTF8Arrays.selfClosingTagEnd) // <img /> for "always empty" tags. selfclosing is ignored but retained for xml/xhtml compatibility
            } else {
                accum.append(UTF8Arrays.selfClosingTagEnd) // <img /> in xml
            }
        } else {
            accum.append(UTF8Arrays.tagEnd)
        }
    }
    
    @inline(__always)
    override func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        if (!(childNodes.isEmpty && _tag.isSelfClosing())) {
            if (out.prettyPrint() && (!childNodes.isEmpty && (
                _tag.formatAsBlock() || (out.outline() && (childNodes.count > 1 || (childNodes.count == 1 && !(((childNodes[0] as? TextNode) != nil)))))
            ))) {
                indent(accum, depth, out)
            }
            accum.append(UTF8Arrays.endTagStart).append(tagNameUTF8()).append(UTF8Arrays.tagEnd)
        }
    }
    
    /**
     Retrieves the element's inner HTML. E.g. on a `<div>` with one empty `<p>`, would return
     `<p></p>`. (Whereas ``Node/outerHtml()`` would return `<div><p></p></div>`.)
     
     - returns: String of HTML.
     - seealso: ``Node/outerHtml()``
     */
    @inline(__always)
    public func html() throws -> String {
#if canImport(CLibxml2) || canImport(libxml2)
        let out = getOutputSettings()
        let doc = ownerDocument()
        let hasOverrides = (doc?.libxml2AttributeOverrides?.isEmpty == false)
           
        if Libxml2Serialization.enabled,
           let doc,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
            out.syntax() == .html,
           !out.prettyPrint(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr,
           let dumped = Libxml2Serialization.htmlDumpChildren(node: nodePtr, doc: docPtr) {
#if DEBUG && SWIFTSOUP_LIBXML2_DEBUG_OVERRIDES
            if String(decoding: tagNameUTF8(), as: UTF8.self) == "body" {
                print("Libxml2 html() using libxml2 serialization")
            }
#endif
            return String(decoding: dumped, as: UTF8.self)
        }
        let allowFastSerialize = Libxml2Serialization.enabled
        if allowFastSerialize,
           let doc,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
           out.syntax() == .html,
           !out.prettyPrint(),
           !out.outline(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr {
            if let dumped = Libxml2Serialization.htmlDumpChildren(node: nodePtr, doc: docPtr) {
                return String(decoding: dumped, as: UTF8.self)
            }
        }
        if let doc,
           doc.libxml2Only,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
           out.syntax() == .html,
           !out.outline(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr,
           let dumped = Libxml2Serialization.htmlDumpChildrenFormat(
            node: nodePtr,
            doc: docPtr,
            prettyPrint: out.prettyPrint()
           ) {
            if dumped.isEmpty, nodePtr.pointee.children != nil,
               let outer = Libxml2Serialization.htmlDumpFormat(node: nodePtr, doc: docPtr, prettyPrint: out.prettyPrint()),
               let inner = Element.stripOuterTag(from: outer, tagName: tagNameUTF8()) {
                return String(decoding: inner, as: UTF8.self)
            }
            return String(decoding: dumped, as: UTF8.self)
        }
#endif
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.ensureLibxml2TreeIfNeeded()
        }
#endif
        let accum: StringBuilder = StringBuilder()
        try html2(accum)
        return getOutputSettings().prettyPrint() ? accum.toString().trim() : accum.toString()
    }
    
    /**
     Retrieves the element's inner HTML. E.g. on a `<div>` with one empty `<p>`, would return
     `<p></p>`. (Whereas ``Node/outerHtml()`` would return `<div><p></p></div>`.)
     
     - returns: String of HTML.
     - seealso: ``Node/outerHtml()``
     */
    @inline(__always)
    public func htmlUTF8() throws -> [UInt8] {
#if canImport(CLibxml2) || canImport(libxml2)
        let out = getOutputSettings()
        let doc = ownerDocument()
        let hasOverrides = (doc?.libxml2AttributeOverrides?.isEmpty == false)
           
        if Libxml2Serialization.enabled,
           let doc,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
            out.syntax() == .html,
           !out.prettyPrint(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr,
           let dumped = Libxml2Serialization.htmlDumpChildren(node: nodePtr, doc: docPtr) {
            return dumped
        }
        let allowFastSerialize = Libxml2Serialization.enabled
        if allowFastSerialize,
           let doc,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
           out.syntax() == .html,
           !out.prettyPrint(),
           !out.outline(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr {
            if let dumped = Libxml2Serialization.htmlDumpChildren(node: nodePtr, doc: docPtr) {
                return dumped
            }
        }
        if let doc,
           doc.libxml2Only,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
           out.syntax() == .html,
           !out.outline(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr,
           let dumped = Libxml2Serialization.htmlDumpChildrenFormat(
            node: nodePtr,
            doc: docPtr,
            prettyPrint: out.prettyPrint()
           ) {
            if dumped.isEmpty, nodePtr.pointee.children != nil,
               let outer = Libxml2Serialization.htmlDumpFormat(node: nodePtr, doc: docPtr, prettyPrint: out.prettyPrint()),
               let inner = Element.stripOuterTag(from: outer, tagName: tagNameUTF8()) {
                return inner
            }
            return dumped
        }
#endif
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.ensureLibxml2TreeIfNeeded()
        }
#endif
        let accum: StringBuilder = StringBuilder()
        try html2(accum)
        return Array(getOutputSettings().prettyPrint() ? accum.buffer.trim() : accum.buffer)
    }
    
    @inline(__always)
    private func html2(_ accum: StringBuilder) throws {
        for node in childNodes {
            try node.outerHtml(accum)
        }
    }

    #if canImport(CLibxml2) || canImport(libxml2)
    @inline(__always)
    private static func stripOuterTag(from bytes: [UInt8], tagName: [UInt8]) -> [UInt8]? {
        guard !bytes.isEmpty else { return nil }
        var i = 0
        while i < bytes.count, bytes[i] != UTF8Arrays.tagStart.first! { i += 1 }
        if i >= bytes.count { return nil }
        var j = i + 1
        while j < bytes.count, isWhitespaceByte(bytes[j]) { j += 1 }
        guard matchTag(bytes, start: j, tag: tagName) else { return nil }
        var inSingleQuote = false
        var inDoubleQuote = false
        var k = j
        while k < bytes.count {
            let c = bytes[k]
            if c == 34 && !inSingleQuote { inDoubleQuote.toggle() }
            else if c == 39 && !inDoubleQuote { inSingleQuote.toggle() }
            else if c == UTF8Arrays.tagEnd.first! && !inSingleQuote && !inDoubleQuote { break }
            k += 1
        }
        if k >= bytes.count { return nil }
        let startTagEnd = k
        var endStart: Int? = nil
        var idx = bytes.count - 2
        while idx >= 1 {
            if bytes[idx - 1] == UTF8Arrays.tagStart.first!,
               bytes[idx] == UTF8Arrays.forwardSlash.first! {
                var t = idx + 1
                while t < bytes.count, isWhitespaceByte(bytes[t]) { t += 1 }
                if matchTag(bytes, start: t, tag: tagName) {
                    endStart = idx - 1
                    break
                }
            }
            idx -= 1
        }
        guard let endStart else { return nil }
        let innerStart = startTagEnd + 1
        if innerStart > endStart { return [] }
        return Array(bytes[innerStart..<endStart])
    }

    @inline(__always)
    private static func matchTag(_ bytes: [UInt8], start: Int, tag: [UInt8]) -> Bool {
        if start < 0 || start + tag.count > bytes.count { return false }
        for k in 0..<tag.count {
            if asciiLower(bytes[start + k]) != asciiLower(tag[k]) { return false }
        }
        return true
    }

    @inline(__always)
    private static func asciiLower(_ byte: UInt8) -> UInt8 {
        if byte >= 65 && byte <= 90 { return byte &+ 32 }
        return byte
    }

    @inline(__always)
    private static func isWhitespaceByte(_ byte: UInt8) -> Bool {
        return byte == UTF8Arrays.whitespace.first!
            || byte == UTF8Arrays.tab.first!
            || byte == UTF8Arrays.newline.first!
            || byte == UTF8Arrays.carriageReturn.first!
    }
    #endif
    
    @inline(__always)
    open override func html(_ appendable: StringBuilder) throws -> StringBuilder {
#if canImport(CLibxml2) || canImport(libxml2)
        let out = getOutputSettings()
        let doc = ownerDocument()
        let hasOverrides = (doc?.libxml2AttributeOverrides?.isEmpty == false)
           
        if Libxml2Serialization.enabled,
           let doc,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
            out.syntax() == .html,
           !out.prettyPrint(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr,
           let dumped = Libxml2Serialization.htmlDumpChildren(node: nodePtr, doc: docPtr) {
            appendable.append(dumped)
            return appendable
        }
        let allowFastSerialize = Libxml2Serialization.enabled
           
        if allowFastSerialize,
           let doc,
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           !doc.libxml2TextNodesDirty,
           out.syntax() == .html,
           !out.prettyPrint(),
           !out.outline(),
           !hasOverrides,
           let nodePtr = libxml2NodePtr {
            if let dumped = Libxml2Serialization.htmlDumpChildren(node: nodePtr, doc: docPtr) {
                appendable.append(dumped)
                return appendable
            }
        }
#endif
        for node in childNodes {
            try node.outerHtml(appendable)
        }
        return appendable
    }
    
    /**
     * Set this element's inner HTML. Clears the existing HTML first.
     * - parameter html: HTML to parse and set into this element
     * - returns: this element
     * - seealso: ``append(_:)``
     */
    @discardableResult
    @inline(__always)
    public func html(_ html: String) throws -> Element {
        empty()
        try append(html)
        return self
    }
    
    @inline(__always)
    public override func copy(with zone: NSZone? = nil) -> Any {
        let clone = Element(_tag, baseUri!, skipChildReserve: true)
        if let treeBuilder {
            clone.treeBuilder = treeBuilder
        }
        return copy(clone: clone)
    }
    
    @inline(__always)
    public override func copy(parent: Node?) -> Node {
        let clone = Element(_tag, baseUri!, skipChildReserve: true)
        if let treeBuilder {
            clone.treeBuilder = treeBuilder
        }
        return copy(clone: clone, parent: parent)
    }

    @inline(__always)
    override func copyForDeepClone(parent: Node?) -> Node {
        let clone = Element(_tag, baseUri!, skipChildReserve: true)
        if let treeBuilder {
            clone.treeBuilder = treeBuilder
        }
        return copy(
            clone: clone,
            parent: parent,
            copyChildren: false,
            rebuildIndexes: false,
            suppressQueryIndexDirty: true
        )
    }
    
    @inline(__always)
    public override func copy(clone: Node, parent: Node?) -> Node {
        return super.copy(clone: clone, parent: parent)
    }
    
    public static func ==(lhs: Element, rhs: Element) -> Bool {
        guard lhs as Node == rhs as Node else {
            return false
        }
        
        return lhs._tag == rhs._tag
    }
    
    override public func hash(into hasher: inout Hasher) {
        super.hash(into: &hasher)
        hasher.combine(_tag)
    }
}

internal extension Element {
    final class IndexBuilderVisitor: NodeVisitor {
        private let handler: (Element) -> Void
        
        init(_ handler: @escaping (Element) -> Void) {
            self.handler = handler
        }
        
        func head(_ node: Node, _ depth: Int) {
            if let element = node as? Element {
                handler(element)
            }
        }
        
        func tail(_ node: Node, _ depth: Int) {
            // void
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markQueryIndexesDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.libxml2SkipFallbackClearAllCaches()
        }
#endif
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isTagQueryIndexDirty = true
                el.isClassQueryIndexDirty = true
                el.isIdQueryIndexDirty = true
                el.isAttributeQueryIndexDirty = true
                el.isAttributeValueQueryIndexDirty = true
                el.invalidateSelectorResultCache()
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markTagQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.libxml2SkipFallbackClearAllCaches()
        }
#endif
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isTagQueryIndexDirty = true
                el.invalidateSelectorResultCache()
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markClassQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.libxml2SkipFallbackClearAllCaches()
        }
#endif
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isClassQueryIndexDirty = true
                el.invalidateSelectorResultCache()
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markIdQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.libxml2SkipFallbackClearAllCaches()
        }
#endif
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isIdQueryIndexDirty = true
                el.invalidateSelectorResultCache()
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markAttributeQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.libxml2SkipFallbackClearAllCaches()
        }
#endif
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isAttributeQueryIndexDirty = true
                el.invalidateSelectorResultCache()
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markAttributeValueQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), doc.libxml2Only {
            doc.libxml2SkipFallbackClearAllCaches()
        }
#endif
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isAttributeValueQueryIndexDirty = true
                el.invalidateSelectorResultCache()
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markAttributeValueQueryIndexDirty(for key: [UInt8]) {
        let normalizedKey = key.lowercased()
        if Element.isHotAttributeKey(normalizedKey) {
            markAttributeValueQueryIndexDirty()
        }
    }

#if canImport(CLibxml2) || canImport(libxml2)
    @inline(__always)
    @usableFromInline
    func libxml2SyncAttribute(key: [UInt8], value: [UInt8], isBoolean: Bool) {
        guard !key.isEmpty else { return }
        guard let nodePtr = libxml2NodePtr else { return }
        guard let doc = ownerDocument(), doc.libxml2DocPtr != nil else { return }
        var keyTerm = key
        keyTerm.append(0)
        let rawValue: [UInt8]
        if value.isEmpty && isBoolean {
            rawValue = key
        } else {
            rawValue = value
        }
        var valueTerm = rawValue
        valueTerm.append(0)
        keyTerm.withUnsafeBufferPointer { keyBuf in
            guard let keyBase = keyBuf.baseAddress else { return }
            keyBase.withMemoryRebound(to: xmlChar.self, capacity: keyBuf.count) { keyPtr in
                valueTerm.withUnsafeBufferPointer { valueBuf in
                    guard let valueBase = valueBuf.baseAddress else { return }
                    valueBase.withMemoryRebound(to: xmlChar.self, capacity: valueBuf.count) { valuePtr in
                        _ = xmlSetProp(nodePtr, keyPtr, valuePtr)
                    }
                }
            }
        }
    }

    @inline(__always)
    @usableFromInline
    func libxml2SyncAttributeRemoved(key: [UInt8]) {
        guard !key.isEmpty else { return }
        guard let nodePtr = libxml2NodePtr else { return }
        guard let doc = ownerDocument(), doc.libxml2DocPtr != nil else { return }
        var keyTerm = key
        keyTerm.append(0)
        keyTerm.withUnsafeBufferPointer { keyBuf in
            guard let keyBase = keyBuf.baseAddress else { return }
            keyBase.withMemoryRebound(to: xmlChar.self, capacity: keyBuf.count) { keyPtr in
                _ = xmlUnsetProp(nodePtr, keyPtr)
            }
        }
    }

    @inline(__always)
    @usableFromInline
    func libxml2CreateNode(docPtr: xmlDocPtr) -> xmlNodePtr? {
        let name = tagNameNormalUTF8()
        guard !name.isEmpty else { return nil }
        var nameTerm = name
        nameTerm.append(0)
        return nameTerm.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return nil }
            return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                let nodePtr = xmlNewDocNode(docPtr, nil, ptr, nil)
                if let nodePtr {
                    nodePtr.pointee._private = Unmanaged.passUnretained(self).toOpaque()
                }
                return nodePtr
            }
        }
    }
#endif

    @usableFromInline
    @inline(__always)
    func cachedSelectorResult(_ query: String) -> Elements? {
        selectorResultCacheLock.lock()
        defer { selectorResultCacheLock.unlock() }
        guard let cache = selectorResultCache else { return nil }
        let root: Node
        if let cachedRoot = selectorResultCacheRoot, cachedRoot.parentNode == nil {
            root = cachedRoot
        } else {
            root = textMutationRoot()
            selectorResultCacheRoot = root
        }
        let currentTextVersion = root.textMutationVersion
        if currentTextVersion != selectorResultTextVersion {
            invalidateSelectorResultCacheUnlocked()
            selectorResultTextVersion = currentTextVersion
            return nil
        }
        return cache[query]
    }

    @usableFromInline
    @inline(__always)
    func storeSelectorResult(_ query: String, _ result: Elements) {
        selectorResultCacheLock.lock()
        defer { selectorResultCacheLock.unlock() }
        if selectorResultCache == nil {
            selectorResultCache = [:]
            selectorResultCacheOrder = []
        }
        if selectorResultCacheRoot == nil || selectorResultCacheRoot?.parentNode != nil {
            selectorResultCacheRoot = textMutationRoot()
        }
        if let root = selectorResultCacheRoot {
            selectorResultTextVersion = root.textMutationVersion
        } else {
            selectorResultTextVersion = textMutationVersionToken()
        }
        if selectorResultCache![query] != nil {
            return
        }
        selectorResultCache![query] = result
        selectorResultCacheOrder.append(query)
        let capacity = Element.selectorResultCacheCapacity
        if selectorResultCacheOrder.count > capacity {
            let overflow = selectorResultCacheOrder.count - capacity
            if overflow > 0 {
                for _ in 0..<overflow {
                    let removedKey = selectorResultCacheOrder.removeFirst()
                    selectorResultCache?.removeValue(forKey: removedKey)
                }
            }
        }
    }

    @usableFromInline
    @inline(__always)
    func invalidateSelectorResultCache() {
        selectorResultCacheLock.lock()
        defer { selectorResultCacheLock.unlock() }
        invalidateSelectorResultCacheUnlocked()
    }

    @inline(__always)
    private func invalidateSelectorResultCacheUnlocked() {
        if selectorResultCache != nil {
            selectorResultCache = nil
            selectorResultCacheOrder.removeAll(keepingCapacity: true)
            selectorResultCacheRoot = nil
        }
    }
    
    @usableFromInline
    @inline(__always)
    static func isHotAttributeKey(_ normalizedKey: [UInt8]) -> Bool {
        return hotAttributeIndexKeys.contains(normalizedKey)
    }

    @inline(__always)
    private static func normalizeAttributeKeyValue(
        _ key: String,
        _ value: String
    ) throws -> (String, [UInt8], String, [UInt8]) {
        var value = value
        try Validate.notEmpty(string: key)
        try Validate.notEmpty(string: value)
        let normalizedKey = key.trim().lowercased()
        if (value.startsWith("\"") && value.hasSuffix("\"")) || (value.startsWith("'") && value.hasSuffix("'")) {
            value = value.substring(1, value.count - 2)
        }
        let normalizedValue = value.trim().lowercased()
        return (normalizedKey, normalizedKey.utf8Array, normalizedValue, normalizedValue.utf8Array)
    }

    @inline(__always)
    private func traverseElementsDepthFirst(_ visitor: (Element) -> Void) {
        var stack: [Element] = []
        stack.reserveCapacity(childNodes.count + 1)
        stack.append(self)
        while let element = stack.popLast() {
            visitor(element)
            let children = element.childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    if let childElement = child as? Element {
                        stack.append(childElement)
                    }
                }
            }
        }
    }

    @inline(__always)
    private func collectElementsByAttributePredicate(
        _ predicate: (Element) throws -> Bool
    ) rethrows -> Elements {
        var matches: [Element] = []
        matches.reserveCapacity(16)
        var stack: [Element] = []
        stack.reserveCapacity(childNodes.count + 1)
        stack.append(self)
        while let element = stack.popLast() {
            if try predicate(element) {
                matches.append(element)
            }
            let children = element.childNodes
            if !children.isEmpty {
                for child in children.reversed() {
                    if let childElement = child as? Element {
                        stack.append(childElement)
                    }
                }
            }
        }
        return Elements(matches)
    }

    @inline(__always)
    private func collectElementsByAttributeNamePrefix(
        _ keyPrefixLower: [UInt8]
    ) throws -> Elements {
        collectElementsByAttributePredicate { element in
            guard let attributes = element.getAttributes(), attributes.size() > 0 else {
                return false
            }
            for attr in attributes.asList() {
                let keyBytes = attr.getKeyUTF8()
                let normalizedKey = Attributes.containsAsciiUppercase(keyBytes)
                    ? keyBytes.lowercased()
                    : keyBytes
                if normalizedKey.starts(with: keyPrefixLower) {
                    return true
                }
            }
            return false
        }
    }

    @inline(__always)
    private static func bytesStartsWith(_ value: [UInt8], _ prefix: [UInt8]) -> Bool {
        return value.starts(with: prefix)
    }

    @inline(__always)
    private static func bytesEndsWith(_ value: [UInt8], _ suffix: [UInt8]) -> Bool {
        guard value.count >= suffix.count else { return false }
        return value.suffix(suffix.count).elementsEqual(suffix)
    }

    @inline(__always)
    private static func bytesContains(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        if needle.isEmpty { return true }
        if needle.count > haystack.count { return false }
        let lastStart = haystack.count - needle.count
        var i = 0
        while i <= lastStart {
            if haystack[i] == needle[0] {
                var j = 1
                while j < needle.count && haystack[i + j] == needle[j] {
                    j += 1
                }
                if j == needle.count {
                    return true
                }
            }
            i += 1
        }
        return false
    }

    @usableFromInline
    @inline(__always)
    func materializeAttributesRecursively() {
        traverseElementsDepthFirst { element in
            element.attributes?.ensureMaterialized()
        }
    }

    @inline(__always)
    private static func forEachClassName(in bytes: [UInt8], _ visitor: (ArraySlice<UInt8>) -> Void) {
        var i = 0
        let len = bytes.count
        while i < len {
            while i < len && bytes[i].isWhitespace {
                i &+= 1
            }
            let start = i
            while i < len && !bytes[i].isWhitespace {
                i &+= 1
            }
            if start < i {
                visitor(bytes[start..<i])
            }
        }
    }

    @inline(__always)
    private static func forEachClassNameWithUppercase(in bytes: [UInt8], _ visitor: (ArraySlice<UInt8>, Bool) -> Void) {
        var i = 0
        let len = bytes.count
        while i < len {
            while i < len && bytes[i].isWhitespace {
                i &+= 1
            }
            let start = i
            var hasUppercase = false
            while i < len && !bytes[i].isWhitespace {
                let b = bytes[i]
                if !hasUppercase && b >= 65 && b <= 90 {
                    hasUppercase = true
                }
                i &+= 1
            }
            if start < i {
                visitor(bytes[start..<i], hasUppercase)
            }
        }
    }

    @inline(__always)
    private func ensureDynamicAttributeValueIndexKey(_ key: [UInt8]) {
        guard Element.dynamicAttributeValueIndexMaxKeys > 0,
              !Element.isHotAttributeKey(key) else {
            return
        }
        if dynamicAttributeValueIndexKeySet?.contains(key) == true {
            return
        }
        if dynamicAttributeValueIndexKeySet == nil {
            dynamicAttributeValueIndexKeySet = Set<[UInt8]>()
            dynamicAttributeValueIndexKeyOrder = []
        }
        dynamicAttributeValueIndexKeySet?.insert(key)
        dynamicAttributeValueIndexKeyOrder?.append(key)
        if let maxKeys = dynamicAttributeValueIndexKeyOrder?.count,
           maxKeys > Element.dynamicAttributeValueIndexMaxKeys {
            let overflow = maxKeys - Element.dynamicAttributeValueIndexMaxKeys
            if overflow > 0 {
                for _ in 0..<overflow {
                    if let removed = dynamicAttributeValueIndexKeyOrder?.removeFirst() {
                        dynamicAttributeValueIndexKeySet?.remove(removed)
                        normalizedAttributeValueIndex?.removeValue(forKey: removed)
                    }
                }
            }
        }
        isAttributeValueQueryIndexDirty = true
    }

    @inline(__always)
    private func rebuildQueryIndexesCombined(
        needsTags: Bool,
        needsClasses: Bool,
        needsIds: Bool,
        needsAttributes: Bool,
        needsHotAttributes: Bool
    ) {
        DebugTrace.log("Element.rebuildQueryIndexesCombined: tags=\(needsTags) classes=\(needsClasses) ids=\(needsIds) attrs=\(needsAttributes) hot=\(needsHotAttributes)")
        var tagIndex: [[UInt8]: [Weak<Element>]] = [:]
        var classIndex: [[UInt8]: [Weak<Element>]] = [:]
        var idIndex: [[UInt8]: [Weak<Element>]] = [:]
        var attributeIndex: [[UInt8]: [Weak<Element>]] = [:]
        var hotAttributeIndex: [[UInt8]: [[UInt8]: [Weak<Element>]]] = [:]
        let dynamicKeys = dynamicAttributeValueIndexKeySet

        let childNodeCount = childNodeSize()
        if needsTags {
            tagIndex.reserveCapacity(childNodeCount * 4)
        }
        if needsClasses {
            classIndex.reserveCapacity(childNodeCount * 4)
        }
        if needsIds {
            idIndex.reserveCapacity(childNodeCount)
        }
        if needsAttributes {
            attributeIndex.reserveCapacity(childNodeCount * 4)
        }
        if needsHotAttributes {
            hotAttributeIndex.reserveCapacity(Element.hotAttributeIndexKeys.count + (dynamicKeys?.count ?? 0))
        }

        traverseElementsDepthFirst { element in
            DebugTrace.log("rebuildQueryIndexesCombined: visiting \(element.tagName())")
            if needsTags {
                let key = element.tagNameNormalUTF8()
                tagIndex[key, default: []].append(Weak(element))
            }
            if needsClasses {
                DebugTrace.log("rebuildQueryIndexesCombined: classes for \(element.tagName())")
                if let attrs = element.attributes,
                   let classValue = try? attrs.getIgnoreCase(key: Element.classString),
                   !classValue.isEmpty {
                    let trimmed = classValue.trim()
                    if !trimmed.isEmpty {
                        Element.forEachClassNameWithUppercase(in: trimmed) { className, hasUppercase in
                            let key = hasUppercase ? Array(className.lowercased()) : Array(className)
                            classIndex[key, default: []].append(Weak(element))
                        }
                    }
                }
            }
            if needsIds {
                DebugTrace.log("rebuildQueryIndexesCombined: ids for \(element.tagName())")
                if let attrs = element.attributes,
                   let idValue = try? attrs.getIgnoreCase(key: Element.idString),
                   !idValue.isEmpty {
                    idIndex[idValue, default: []].append(Weak(element))
                }
            }
            if needsAttributes || needsHotAttributes {
                DebugTrace.log("rebuildQueryIndexesCombined: attrs for \(element.tagName())")
                if let attrs = element.attributes {
                    attrs.ensureMaterialized()
                    let lowerKeys = attrs.hasUppercaseKeys
                    for attr in attrs.attributes {
                        DebugTrace.log("rebuildQueryIndexesCombined: attr key \(String(decoding: attr.getKeyUTF8(), as: UTF8.self))")
                        let keyBytes = attr.getKeyUTF8()
                        let key = lowerKeys ? keyBytes.lowercased() : keyBytes
                        if needsAttributes {
                            attributeIndex[key, default: []].append(Weak(element))
                        }
                        if needsHotAttributes,
                           (Element.isHotAttributeKey(key) || (dynamicKeys?.contains(key) ?? false)) {
                            let value = attr.getValueUTF8().trim().lowercased()
                            var valueIndex = hotAttributeIndex[key] ?? [:]
                            valueIndex[value, default: []].append(Weak(element))
                            hotAttributeIndex[key] = valueIndex
                        }
                    }
                }
            }
        }

        if needsTags {
            normalizedTagNameIndex = tagIndex
            isTagQueryIndexDirty = false
        }
        if needsClasses {
            normalizedClassNameIndex = classIndex
            isClassQueryIndexDirty = false
        }
        if needsIds {
            normalizedIdIndex = idIndex
            isIdQueryIndexDirty = false
        }
        if needsAttributes {
            normalizedAttributeNameIndex = attributeIndex
            isAttributeQueryIndexDirty = false
        }
        if needsHotAttributes {
            normalizedAttributeValueIndex = hotAttributeIndex
            isAttributeValueQueryIndexDirty = false
        }
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllTags() {
        let needsClasses = isClassQueryIndexDirty || normalizedClassNameIndex == nil
        let needsIds = isIdQueryIndexDirty || normalizedIdIndex == nil
        let needsAttributes = isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil
        let needsHotAttributes = isAttributeValueQueryIndexDirty || normalizedAttributeValueIndex == nil
        let combinedCount = 1 +
            (needsClasses ? 1 : 0) +
            (needsIds ? 1 : 0) +
            (needsAttributes ? 1 : 0) +
            (needsHotAttributes ? 1 : 0)
        if combinedCount > 1 {
            rebuildQueryIndexesCombined(
                needsTags: true,
                needsClasses: needsClasses,
                needsIds: needsIds,
                needsAttributes: needsAttributes,
                needsHotAttributes: needsHotAttributes
            )
            return
        }
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        
        traverseElementsDepthFirst { element in
            let key = element.tagNameNormalUTF8()
            newIndex[key, default: []].append(Weak(element))
        }
        
        normalizedTagNameIndex = newIndex
        isTagQueryIndexDirty = false
    }

    @usableFromInline
    @inline(__always)
    func tagQueryIndexForKey(_ key: [UInt8]) -> [Weak<Element>] {
        if isTagQueryIndexDirty {
            normalizedTagNameIndex = nil
            isTagQueryIndexDirty = false
        }
        if normalizedTagNameIndex == nil {
            normalizedTagNameIndex = [:]
        }
        if let existing = normalizedTagNameIndex?[key] {
            return existing
        }
        var matches: [Weak<Element>] = []
        let childNodeCount = childNodeSize()
        matches.reserveCapacity(max(4, childNodeCount / 8))
        traverseElementsDepthFirst { element in
            if element.tagNameNormalUTF8() == key {
                matches.append(Weak(element))
            }
        }
        normalizedTagNameIndex?[key] = matches
        return matches
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllClasses() {
        let needsIds = isIdQueryIndexDirty || normalizedIdIndex == nil
        let needsAttributes = isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil
        let needsHotAttributes = isAttributeValueQueryIndexDirty || normalizedAttributeValueIndex == nil
        let combinedCount = 1 +
            (needsIds ? 1 : 0) +
            (needsAttributes ? 1 : 0) +
            (needsHotAttributes ? 1 : 0)
        if combinedCount > 1 {
            DebugTrace.log("Element.rebuildQueryIndexesForAllClasses: combined rebuild")
            rebuildQueryIndexesCombined(
                needsTags: false,
                needsClasses: true,
                needsIds: needsIds,
                needsAttributes: needsAttributes,
                needsHotAttributes: needsHotAttributes
            )
            return
        }
        DebugTrace.log("Element.rebuildQueryIndexesForAllClasses: solo rebuild")
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)

        traverseElementsDepthFirst { element in
            if let attrs = element.attributes,
               let classValue = try? attrs.getIgnoreCase(key: Element.classString),
               !classValue.isEmpty {
                let trimmed = classValue.trim()
                if !trimmed.isEmpty {
                    Element.forEachClassNameWithUppercase(in: trimmed) { className, hasUppercase in
                        let key = hasUppercase ? Array(className.lowercased()) : Array(className)
                        newIndex[key, default: []].append(Weak(element))
                    }
                }
            }
        }
        normalizedClassNameIndex = newIndex
        isClassQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllIds() {
        let needsClasses = isClassQueryIndexDirty || normalizedClassNameIndex == nil
        let needsAttributes = isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil
        let needsHotAttributes = isAttributeValueQueryIndexDirty || normalizedAttributeValueIndex == nil
        let combinedCount = 1 +
            (needsClasses ? 1 : 0) +
            (needsAttributes ? 1 : 0) +
            (needsHotAttributes ? 1 : 0)
        if combinedCount > 1 {
            rebuildQueryIndexesCombined(
                needsTags: false,
                needsClasses: needsClasses,
                needsIds: true,
                needsAttributes: needsAttributes,
                needsHotAttributes: needsHotAttributes
            )
            return
        }
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount)
        
        traverseElementsDepthFirst { element in
            if let attrs = element.attributes {
                if let idValue = try? attrs.getIgnoreCase(key: Element.idString), !idValue.isEmpty {
                    newIndex[idValue, default: []].append(Weak(element))
                }
            }
        }
        
        normalizedIdIndex = newIndex
        isIdQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllAttributes() {
        let needsClasses = isClassQueryIndexDirty || normalizedClassNameIndex == nil
        let needsIds = isIdQueryIndexDirty || normalizedIdIndex == nil
        let needsHotAttributes = isAttributeValueQueryIndexDirty || normalizedAttributeValueIndex == nil
        let combinedCount = 1 +
            (needsClasses ? 1 : 0) +
            (needsIds ? 1 : 0) +
            (needsHotAttributes ? 1 : 0)
        if combinedCount > 1 {
            rebuildQueryIndexesCombined(
                needsTags: false,
                needsClasses: needsClasses,
                needsIds: needsIds,
                needsAttributes: true,
                needsHotAttributes: needsHotAttributes
            )
            return
        }
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        
        traverseElementsDepthFirst { element in
            if let attrs = element.attributes {
                attrs.ensureMaterialized()
                let lowerKeys = attrs.hasUppercaseKeys
                for attr in attrs.attributes {
                    let keyBytes = attr.getKeyUTF8()
                    let key = lowerKeys ? keyBytes.lowercased() : keyBytes
                    newIndex[key, default: []].append(Weak(element))
                }
            }
        }
        
        normalizedAttributeNameIndex = newIndex
        isAttributeQueryIndexDirty = false
    }

    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForHotAttributes() {
        let needsClasses = isClassQueryIndexDirty || normalizedClassNameIndex == nil
        let needsIds = isIdQueryIndexDirty || normalizedIdIndex == nil
        let needsAttributes = isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil
        let combinedCount = 1 +
            (needsClasses ? 1 : 0) +
            (needsIds ? 1 : 0) +
            (needsAttributes ? 1 : 0)
        if combinedCount > 1 {
            rebuildQueryIndexesCombined(
                needsTags: false,
                needsClasses: needsClasses,
                needsIds: needsIds,
                needsAttributes: needsAttributes,
                needsHotAttributes: true
            )
            return
        }
        /// Index build is depth‑first to preserve document order for stable selector results.
        var newIndex: [[UInt8]: [[UInt8]: [Weak<Element>]]] = [:]
        let dynamicKeys = dynamicAttributeValueIndexKeySet
        newIndex.reserveCapacity(Element.hotAttributeIndexKeys.count + (dynamicKeys?.count ?? 0))
        traverseElementsDepthFirst { element in
            if let attrs = element.getAttributes() {
                attrs.ensureMaterialized()
                let lowerKeys = attrs.hasUppercaseKeys
                for attr in attrs.attributes {
                    let keyBytes = attr.getKeyUTF8()
                    let key = lowerKeys ? keyBytes.lowercased() : keyBytes
                    guard Element.isHotAttributeKey(key) || (dynamicKeys?.contains(key) ?? false) else { continue }
                    let value = attr.getValueUTF8().trim().lowercased()
                    var valueIndex = newIndex[key] ?? [:]
                    valueIndex[value, default: []].append(Weak(element))
                    newIndex[key] = valueIndex
                }
            }
        }
        
        normalizedAttributeValueIndex = newIndex
        isAttributeValueQueryIndexDirty = false
    }
    
    @inlinable
    func rebuildQueryIndexesForThisNodeOnly() {
        normalizedTagNameIndex = nil
        normalizedClassNameIndex = nil
        normalizedIdIndex = nil
        normalizedAttributeNameIndex = nil
        normalizedAttributeValueIndex = nil
        markTagQueryIndexDirty()
        markClassQueryIndexDirty()
        markIdQueryIndexDirty()
        markAttributeQueryIndexDirty()
        markAttributeValueQueryIndexDirty()
    }
}
