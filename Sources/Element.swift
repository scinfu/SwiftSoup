//
//  Element.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

open class Element: Node {
    var _tag: Tag
    
    private static let classString = "class".utf8Array
    private static let emptyString = "".utf8Array
    @usableFromInline
    internal static let idString = "id".utf8Array
    private static let rootString = "#root".utf8Array
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
    
    /// Cached normalized text (UTF‑8) for trim+normalize path.
    @usableFromInline
    internal var cachedTextUTF8: [UInt8]? = nil
    @usableFromInline
    internal var cachedTextVersion: Int = -1
    
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
        super.init(baseUri, attributes, skipChildReserve: skipChildReserve)
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
        super.init(baseUri, Attributes(), skipChildReserve: skipChildReserve)
        attributes?.ownerElement = self
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
    
    // attribute fiddling. create on first access.
    @inline(__always)
    private func ensureAttributes() {
        if (attributes == nil) {
            attributes = Attributes()
        }
    }
    
    /**
     Set an attribute value on this element. If this element already has an attribute with the
     key, its value is updated; otherwise, a new attribute is added.
     
     - returns: this element
     */
    @discardableResult
    @inline(__always)
    open override func attr(_ attributeKey: [UInt8], _ attributeValue: [UInt8]) throws -> Element {
        ensureAttributes()
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
        ensureAttributes()
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
        ensureAttributes()
        try attributes?.put(attributeKey, attributeValue)
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
        ensureAttributes()
        try attributes?.put(attributeKey.utf8Array, attributeValue)
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
        return attributes!.dataset()
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
        // was - Node#addChildren(child). short-circuits an array create and a loop.
        try reparentChild(child)
        childNodes.append(child)
        child.setSiblingIndex(childNodes.count - 1)
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
        childNodes.removeAll()
        bumpTextMutationVersion()
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
        let x = try Element.indexInList(self, parent()?.children().array())
        return x == nil ? 0 : x!
    }
    
    /**
     Gets the last element sibling of this element
     - returns: the last sibling that is an element (aka the parent's last element child)
     */
    @inline(__always)
    public func lastElementSibling() -> Element? {
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
        let normalizedTagName = tagName.lowercased().trim()
        
        if isTagQueryIndexDirty || normalizedTagNameIndex == nil {
            rebuildQueryIndexesForAllTags()
            isTagQueryIndexDirty = false
        }
        
        let weakElements = normalizedTagNameIndex?[normalizedTagName] ?? []
        return Elements(weakElements.compactMap { $0.value })
    }
    
    /**
     Find elements by ID, including or under this element.
     
     - parameter id: The ID to search for.
     - returns: Elements matching the ID, empty if none.
     */
    @usableFromInline
    func getElementsById(_ id: [UInt8]) -> Elements {
        let key = id.trim()
        if key.isEmpty {
            return Elements()
        }
        
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
        try Validate.notEmpty(string: id.utf8Array)
        let elements = getElementsById(id.utf8Array)
        return elements.array().isEmpty ? nil : elements.get(0)
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
        let key = className.utf8Array
        if isClassQueryIndexDirty || normalizedClassNameIndex == nil {
            rebuildQueryIndexesForAllClasses()
            isClassQueryIndexDirty = false
        }
        let results = normalizedClassNameIndex?[key.lowercased()]?.compactMap { $0.value } ?? []
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
        let key = key.trim()
        if key.lowercased().hasPrefix("abs:") {
            return try Collector.collect(Evaluator.Attribute(key), self)
        }
        let normalizedKey = key.utf8Array.lowercased().trim()
        
        if isAttributeQueryIndexDirty || normalizedAttributeNameIndex == nil {
            rebuildQueryIndexesForAllAttributes()
            isAttributeQueryIndexDirty = false
        }
        
        let results = normalizedAttributeNameIndex?[normalizedKey]?.compactMap { $0.value } ?? []
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
        if key.lowercased().hasPrefix("abs:") {
            return try Collector.collect(Evaluator.AttributeWithValue(key, value), self)
        }
        let normalizedKey = key.utf8Array.lowercased().trim()
        if Element.isHotAttributeKey(normalizedKey) {
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
    
    /**
     Find elements that either do not have this attribute, or have it with a different value. Case insensitive.
     
     - parameter key: name of the attribute
     - parameter value: value of the attribute
     - returns: elements that do not have a matching attribute
     */
    @inline(__always)
    public func getElementsByAttributeValueNot(_ key: String, _ value: String)throws->Elements {
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
    
    public func text(trimAndNormaliseWhitespace: Bool = true) throws -> String {
        if trimAndNormaliseWhitespace {
            let version = textMutationRoot().textMutationVersion
            if cachedTextVersion == version, let cachedTextUTF8 {
                return String(decoding: cachedTextUTF8, as: UTF8.self)
            }
            let accum: StringBuilder = StringBuilder()
            try NodeTraversor(TextNodeVisitor(accum, trimAndNormaliseWhitespace: true)).traverse(self)
            let text = accum.toString().trim()
            let textUTF8 = text.utf8Array
            cachedTextUTF8 = textUTF8
            cachedTextVersion = version
            return text
        }
        let accum: StringBuilder = StringBuilder()
        try NodeTraversor(TextNodeVisitor(accum, trimAndNormaliseWhitespace: trimAndNormaliseWhitespace)).traverse(self)
        let text = accum.toString()
        if trimAndNormaliseWhitespace {
            return text.trim()
        }
        return text
    }
    
    public func textUTF8(trimAndNormaliseWhitespace: Bool = true) throws -> [UInt8] {
        let accum: StringBuilder = StringBuilder()
        try NodeTraversor(TextNodeVisitor(accum, trimAndNormaliseWhitespace: trimAndNormaliseWhitespace)).traverse(self)
        let text = accum.buffer
        if trimAndNormaliseWhitespace {
            return Array(text.trim())
        }
        return Array(text)
    }
    
    public func textUTF8Slice(trimAndNormaliseWhitespace: Bool = true) throws -> ArraySlice<UInt8> {
        let accum: StringBuilder = StringBuilder()
        try NodeTraversor(TextNodeVisitor(accum, trimAndNormaliseWhitespace: trimAndNormaliseWhitespace)).traverse(self)
        let text = accum.buffer
        if trimAndNormaliseWhitespace {
            return text.trim()
        }
        return text
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
        let sb: StringBuilder = StringBuilder()
        ownText(sb)
        return Array(sb.buffer.trim())
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
        let text = textNode.getWholeTextUTF8()
        
        if (Element.preserveWhitespace(textNode.parentNode)) {
            accum.append(text)
        } else {
            StringUtil.appendNormalisedWhitespace(accum, string: text, stripLeading: TextNode.lastCharIsWhitespace(accum))
        }
    }
    
    private static func appendWhitespaceIfBr(_ element: Element, _ accum: StringBuilder) {
        if (element._tag.getNameUTF8() == UTF8Arrays.br && !TextNode.lastCharIsWhitespace(accum)) {
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
        let classAttr: [UInt8]? = attributes?.get(key: Element.classString)
        let len: Int = (classAttr != nil) ? classAttr!.count : 0
        let wantLen: Int = className.count
        
        if (len == 0 || len < wantLen) {
            return false
        }
        
        // if both lengths are equal, only need compare the className with the attribute
        if (len == wantLen) {
            return className.equalsIgnoreCase(string: classAttr)
        }
        
        // otherwise, scan for whitespace and compare regions (with no string or arraylist allocations)
        var inClass: Bool = false
        var start = [].startIndex
        if let classAttr {
            let startIdx = classAttr.startIndex
            start = startIdx
            let endIdx = classAttr.endIndex
            
            for i in startIdx..<endIdx {
                if classAttr[i].isWhitespace {
                    if inClass {
                        // white space ends a class name, compare it with the requested one, ignore case
                        if (
                            i - start == wantLen && classAttr.regionMatches(
                                ignoreCase: true,
                                selfOffset: start,
                                other: className,
                                otherOffset: 0,
                                targetLength: wantLen
                            )
                        ) {
                            return true
                        }
                        inClass = false
                    }
                } else {
                    if (!inClass) {
                        // we're in a class name : keep the start of the substring
                        inClass = true
                        start = i
                    }
                }
            }
        }
        
        // check the last entry
        if inClass && len - start == wantLen {
            return classAttr?.regionMatches(
                ignoreCase: true,
                selfOffset: start,
                other: className,
                otherOffset: 0,
                targetLength: wantLen
            ) ?? false
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
    
    @inline(__always)
    open override func html(_ appendable: StringBuilder) throws -> StringBuilder {
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
        return copy(clone: clone, parent: parent, copyChildren: false, rebuildIndexes: false)
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
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isTagQueryIndexDirty = true
                el.isClassQueryIndexDirty = true
                el.isIdQueryIndexDirty = true
                el.isAttributeQueryIndexDirty = true
                el.isAttributeValueQueryIndexDirty = true
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markTagQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isTagQueryIndexDirty = true
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markClassQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isClassQueryIndexDirty = true
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markIdQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isIdQueryIndexDirty = true
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markAttributeQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isAttributeQueryIndexDirty = true
            }
            current = node.parentNode
        }
    }
    
    @usableFromInline
    @inline(__always)
    func markAttributeValueQueryIndexDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isAttributeValueQueryIndexDirty = true
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
    
    @usableFromInline
    @inline(__always)
    static func isHotAttributeKey(_ normalizedKey: [UInt8]) -> Bool {
        return hotAttributeIndexKeys.contains(normalizedKey)
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllTags() {
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        
        try? NodeTraversor(IndexBuilderVisitor { element in
            let key = element.tagNameNormalUTF8()
            newIndex[key, default: []].append(Weak(element))
        }).traverse(self)
        
        normalizedTagNameIndex = newIndex
        isTagQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllClasses() {
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        
        try? NodeTraversor(IndexBuilderVisitor { element in
            if let classNames = try? element.unorderedClassNamesUTF8() {
                for className in classNames {
                    newIndex[Array(className.lowercased()), default: []].append(Weak(element))
                }
            }
        }).traverse(self)
        normalizedClassNameIndex = newIndex
        isClassQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllIds() {
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount)
        
        try? NodeTraversor(IndexBuilderVisitor { element in
            if let attrs = element.getAttributes() {
                if let idValue = try? attrs.getIgnoreCase(key: Element.idString), !idValue.isEmpty {
                    newIndex[idValue, default: []].append(Weak(element))
                }
            }
        }).traverse(self)
        
        normalizedIdIndex = newIndex
        isIdQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllAttributes() {
        /// Index build is depth‑first to preserve document order.
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        
        try? NodeTraversor(IndexBuilderVisitor { element in
            if let attrs = element.getAttributes() {
                attrs.ensureMaterialized()
                for attr in attrs.attributes {
                    let key = attr.getKeyUTF8().lowercased()
                    newIndex[key, default: []].append(Weak(element))
                }
            }
        }).traverse(self)
        
        normalizedAttributeNameIndex = newIndex
        isAttributeQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForHotAttributes() {
        /// Index build is depth‑first to preserve document order for stable selector results.
        var newIndex: [[UInt8]: [[UInt8]: [Weak<Element>]]] = [:]
        
        newIndex.reserveCapacity(Element.hotAttributeIndexKeys.count)
        
        try? NodeTraversor(IndexBuilderVisitor { element in
            if let attrs = element.getAttributes() {
                attrs.ensureMaterialized()
                for attr in attrs.attributes {
                    let key = attr.getKeyUTF8().lowercased()
                    guard Element.isHotAttributeKey(key) else { continue }
                    let value = attr.getValueUTF8().trim().lowercased()
                    var valueIndex = newIndex[key] ?? [:]
                    valueIndex[value, default: []].append(Weak(element))
                    newIndex[key] = valueIndex
                }
            }
        }).traverse(self)
        
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
