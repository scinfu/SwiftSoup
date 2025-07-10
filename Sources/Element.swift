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
    private static let idString = "id".utf8Array
    private static let rootString = "#root".utf8Array
    
    @usableFromInline
    internal var normalizedTagNameIndex: [[UInt8]: [Weak<Element>]]? = nil
    @usableFromInline
    internal var isTagQueryIndexDirty: Bool = false
    
    @usableFromInline
    internal var normalizedClassNameIndex: [[UInt8]: [Weak<Element>]]? = nil
    @usableFromInline
    internal var isClassQueryIndexDirty: Bool = false
    
    /**
     * Create a new, standalone Element. (Standalone in that is has no parent.)
     *
     * @param tag tag of this element
     * @param baseUri the base URI
     * @param attributes initial attributes
     * @see #appendChild(Node)
     * @see #appendElement(String)
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
     * Create a new Element from a tag and a base URI.
     *
     * @param tag element tag
     * @param baseUri the base URI of this element. It is acceptable for the base URI to be an empty
     *            string, but not null.
     * @see Tag#valueOf(String, ParseSettings)
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
     * Get the name of the tag for this element. E.g. {@code div}
     *
     * @return the tag name
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
     * Change the tag of this element. For example, convert a {@code <span>} to a {@code <div>} with
     * {@code el.tagName("div")}.
     *
     * @param tagName new tag name for this element
     * @return this element, for chaining
     */
    @discardableResult
    public func tagName(_ tagName: [UInt8]) throws -> Element {
        try Validate.notEmpty(string: tagName, msg: "Tag name must not be empty.")
        _tag = try Tag.valueOf(tagName, ParseSettings.preserveCase) // preserve the requested tag case
        return self
    }
    
    @discardableResult
    public func tagName(_ tagName: String) throws -> Element {
        return try self.tagName(tagName.utf8Array)
    }
    
    /**
     * Get the Tag for this element.
     *
     * @return the tag object
     */
    open func tag() -> Tag {
        return _tag
    }
    
    /**
     * Test if this element is a block-level element. (E.g. {@code <div> == true} or an inline element
     * {@code <p> == false}).
     *
     * @return true if block, false if not (and thus inline)
     */
    open func isBlock() -> Bool {
        return _tag.isBlock()
    }
    
    /// Test if this element has child nodes.
    open func isEmpty() -> Bool {
        return childNodes.isEmpty
    }
    
    /**
     * Get the {@code id} attribute of this element.
     *
     * @return The id attribute, if present, or an empty string if not.
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
     * Set an attribute value on this element. If this element already has an attribute with the
     * key, its value is updated; otherwise, a new attribute is added.
     *
     * @return this element
     */
    @discardableResult
    @inline(__always)
    open override func attr(_ attributeKey: [UInt8], _ attributeValue: [UInt8]) throws -> Element {
        ensureAttributes()
        try super.attr(attributeKey, attributeValue)
        return self
    }
    
    /**
     * Set an attribute value on this element. If this element already has an attribute with the
     * key, its value is updated; otherwise, a new attribute is added.
     *
     * @return this element
     */
    @discardableResult
    @inline(__always)
    open override func attr(_ attributeKey: String, _ attributeValue: String) throws -> Element {
        ensureAttributes()
        try super.attr(attributeKey.utf8Array, attributeValue.utf8Array)
        return self
    }
    
    /**
     * Set a boolean attribute value on this element. Setting to <code>true</code> sets the attribute value to "" and
     * marks the attribute as boolean so no value is written out. Setting to <code>false</code> removes the attribute
     * with the same key if it exists.
     *
     * @param attributeKey the attribute key
     * @param attributeValue the attribute value
     *
     * @return this element
     */
    @discardableResult
    @inline(__always)
    open func attr(_ attributeKey: [UInt8], _ attributeValue: Bool) throws -> Element {
        ensureAttributes()
        try attributes?.put(attributeKey, attributeValue)
        return self
    }
    
    /**
     * Set a boolean attribute value on this element. Setting to <code>true</code> sets the attribute value to "" and
     * marks the attribute as boolean so no value is written out. Setting to <code>false</code> removes the attribute
     * with the same key if it exists.
     *
     * @param attributeKey the attribute key
     * @param attributeValue the attribute value
     *
     * @return this element
     */
    @discardableResult
    @inline(__always)
    open func attr(_ attributeKey: String, _ attributeValue: Bool) throws -> Element {
        ensureAttributes()
        try attributes?.put(attributeKey.utf8Array, attributeValue)
        return self
    }
    
    /**
     * Get this element's HTML5 custom data attributes. Each attribute in the element that has a key
     * starting with "data-" is included the dataset.
     * <p>
     * E.g., the element {@code <div data-package="SwiftSoup" data-language="Java" class="group">...} has the dataset
     * {@code package=SwiftSoup, language=java}.
     * <p>
     * This map is a filtered view of the element's attribute map. Changes to one map (add, remove, update) are reflected
     * in the other map.
     * <p>
     * You can find elements that have data attributes using the {@code [^data-]} attribute key prefix selector.
     * @return a map of {@code key=value} custom data attributes.
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
     * Get this element's parent and ancestors, up to the document root.
     * @return this element's stack of parents, closest first.
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
     * Get a child element of this element, by its 0-based index number.
     * <p>
     * Note that an element can have both mixed Nodes and Elements as children. This method inspects
     * a filtered list of children that are elements, and the index is based on that filtered list.
     * </p>
     *
     * @param index the index number of the element to retrieve
     * @return the child element, if it exists, otherwise throws an {@code IndexOutOfBoundsException}
     * @see #childNode(int)
     */
    @inline(__always)
    open func child(_ index: Int) -> Element {
        return children().get(index)
    }
    
    /**
     * Get this element's child elements.
     * <p>
     * This is effectively a filter on {@link #childNodes()} to get Element nodes.
     * </p>
     * @return child elements. If this element has no children, returns an
     * empty list.
     * @see #childNodes()
     */
    @inline(__always)
    open func children() -> Elements {
        // create on the fly rather than maintaining two lists. if gets slow, memoize, and mark dirty on change
        return Elements(childNodes.lazy.compactMap { $0 as? Element })
    }
    
    /**
     * Get this element's child text nodes. The list is unmodifiable but the text nodes may be manipulated.
     * <p>
     * This is effectively a filter on {@link #childNodes()} to get Text nodes.
     * @return child text nodes. If this element has no text nodes, returns an
     * empty list.
     * </p>
     * For example, with the input HTML: {@code <p>One <span>Two</span> Three <br> Four</p>} with the {@code p} element selected:
     * <ul>
     *     <li>{@code p.text()} = {@code "One Two Three Four"}</li>
     *     <li>{@code p.ownText()} = {@code "One Three Four"}</li>
     *     <li>{@code p.children()} = {@code Elements[<span>, <br>]}</li>
     *     <li>{@code p.childNodes()} = {@code List<Node>["One ", <span>, " Three ", <br>, " Four"]}</li>
     *     <li>{@code p.textNodes()} = {@code List<TextNode>["One ", " Three ", " Four"]}</li>
     * </ul>
     */
    @inline(__always)
    open func textNodes() -> Array<TextNode> {
        return childNodes.compactMap { $0 as? TextNode }
    }
    
    /**
     * Get this element's child data nodes. The list is unmodifiable but the data nodes may be manipulated.
     * <p>
     * This is effectively a filter on {@link #childNodes()} to get Data nodes.
     * </p>
     * @return child data nodes. If this element has no data nodes, returns an
     * empty list.
     * @see #data()
     */
    @inline(__always)
    open func dataNodes() -> Array<DataNode> {
        return childNodes.compactMap { $0 as? DataNode }
    }
    
    /**
     * Find elements that match the {@link CssSelector} CSS query, with this element as the starting context. Matched elements
     * may include this element, or any of its children.
     * <p>
     * This method is generally more powerful to use than the DOM-type {@code getElementBy*} methods, because
     * multiple filters can be combined, e.g.:
     * </p>
     * <ul>
     * <li>{@code el.select("a[href]")} - finds links ({@code a} tags with {@code href} attributes)
     * <li>{@code el.select("a[href*=example.com]")} - finds links pointing to example.com (loosely)
     * </ul>
     * <p>
     * See the query syntax documentation in {@link CssSelector}.
     * </p>
     *
     * @param cssQuery a {@link CssSelector} CSS-like query
     * @return elements that match the query (empty if none match)
     * @see CssSelector
     * @throws CssSelector.SelectorParseException (unchecked) on an invalid CSS query.
     */
    @inline(__always)
    public func select(_ cssQuery: String)throws->Elements {
        return try CssSelector.select(cssQuery, self)
    }
    
    /**
     * Check if this element matches the given {@link CssSelector} CSS query.
     * @param cssQuery a {@link CssSelector} CSS query
     * @return if this element matches the query
     */
    @inline(__always)
    public func iS(_ cssQuery: String)throws->Bool {
        return try iS(QueryParser.parse(cssQuery))
    }
    
    /**
     * Check if this element matches the given {@link CssSelector} CSS query.
     * @param cssQuery a {@link CssSelector} CSS query
     * @return if this element matches the query
     */
    @inline(__always)
    public func iS(_ evaluator: Evaluator)throws->Bool {
        guard let od = self.ownerDocument() else {
            return false
        }
        return try evaluator.matches(od, self)
    }
    
    /**
     * Add a node child node to this element.
     *
     * @param child node to add.
     * @return this element, so that you can add more child nodes or elements.
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
     * Add a node to the start of this element's children.
     *
     * @param child node to add.
     * @return this element, so that you can add more child nodes or elements.
     */
    @discardableResult
    @inline(__always)
    public func prependChild(_ child: Node)throws->Element {
        try addChildren(0, child)
        return self
    }
    
    /**
     * Inserts the given child nodes into this element at the specified index. Current nodes will be shifted to the
     * right. The inserted nodes will be moved from their current parent. To prevent moving, copy the nodes first.
     *
     * @param index 0-based index to insert children at. Specify {@code 0} to insert at the start, {@code -1} at the
     * end
     * @param children child nodes to insert
     * @return this element, for chaining.
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
     * Create a new element by tag name, and add it as the last child.
     *
     * @param tagName the name of the tag (e.g. {@code div}).
     * @return the new element, to allow you to add content to it, e.g.:
     *  {@code parent.appendElement("h1").attr("id", "header").text("Welcome")}
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
        try appendChild(child)
        return child
    }
    
    /**
     * Create a new element by tag name, and add it as the first child.
     *
     * @param tagName the name of the tag (e.g. {@code div}).
     * @return the new element, to allow you to add content to it, e.g.:
     *  {@code parent.prependElement("h1").attr("id", "header").text("Welcome")}
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
        try prependChild(child)
        return child
    }
    
    /**
     * Create and append a new TextNode to this element.
     *
     * @param text the unencoded text to add
     * @return this element
     */
    @discardableResult
    @inline(__always)
    public func appendText(_ text: String) throws -> Element {
        let node: TextNode = TextNode(text.utf8Array, getBaseUriUTF8())
        try appendChild(node)
        return self
    }
    
    /**
     * Create and prepend a new TextNode to this element.
     *
     * @param text the unencoded text to add
     * @return this element
     */
    @discardableResult
    public func prependText(_ text: String) throws -> Element {
        let node: TextNode = TextNode(text.utf8Array, getBaseUriUTF8())
        try prependChild(node)
        return self
    }
    
    /**
     * Add inner HTML to this element. The supplied HTML will be parsed, and each node appended to the end of the children.
     * @param html HTML to add inside this element, after the existing HTML
     * @return this element
     * @see #html(String)
     */
    @discardableResult
    @inline(__always)
    public func append(_ html: String) throws -> Element {
        let nodes: Array<Node> = try Parser.parseFragment(html.utf8Array, self, getBaseUriUTF8())
        try addChildren(nodes)
        return self
    }
    
    /**
     * Add inner HTML into this element. The supplied HTML will be parsed, and each node prepended to the start of the element's children.
     * @param html HTML to add inside this element, before the existing HTML
     * @return this element
     * @see #html(String)
     */
    @discardableResult
    @inline(__always)
    public func prepend(_ html: String)throws->Element {
        let nodes: Array<Node> = try Parser.parseFragment(html.utf8Array, self, getBaseUriUTF8())
        try addChildren(0, nodes)
        return self
    }
    
    /**
     * Insert the specified HTML into the DOM before this element (as a preceding sibling).
     *
     * @param html HTML to add before this element
     * @return this element, for chaining
     * @see #after(String)
     */
    @discardableResult
    @inline(__always)
    open override func before(_ html: String)throws->Element {
        return try super.before(html) as! Element
    }
    
    /**
     * Insert the specified node into the DOM before this node (as a preceding sibling).
     * @param node to add before this element
     * @return this Element, for chaining
     * @see #after(Node)
     */
    @discardableResult
    @inline(__always)
    open override func before(_ node: Node)throws->Element {
        return try super.before(node) as! Element
    }
    
    /**
     * Insert the specified HTML into the DOM after this element (as a following sibling).
     *
     * @param html HTML to add after this element
     * @return this element, for chaining
     * @see #before(String)
     */
    @discardableResult
    @inline(__always)
    open override func after(_ html: String) throws -> Element {
        return try super.after(html) as! Element
    }
    
    /**
     * Insert the specified node into the DOM after this node (as a following sibling).
     * @param node to add after this element
     * @return this element, for chaining
     * @see #before(Node)
     */
    @inline(__always)
    open override func after(_ node: Node) throws -> Element {
        return try super.after(node) as! Element
    }
    
    /**
     * Remove all of the element's child nodes. Any attributes are left as-is.
     * @return this element
     */
    @discardableResult
    @inline(__always)
    public func empty() -> Element {
        markQueryIndexesDirty()
        childNodes.removeAll()
        return self
    }
    
    /**
     * Wrap the supplied HTML around this element.
     *
     * @param html HTML to wrap around this element, e.g. {@code <div class="head"></div>}. Can be arbitrarily deep.
     * @return this element, for chaining.
     */
    @discardableResult
    @inline(__always)
    open override func wrap(_ html: String) throws -> Element {
        return try super.wrap(html) as! Element
    }
    
    /**
     * Get a CSS selector that will uniquely select this element.
     * <p>
     * If the element has an ID, returns #id;
     * otherwise returns the parent (if any) CSS selector, followed by {@literal '>'},
     * followed by a unique selector for the element (tag.class.class:nth-child(n)).
     * </p>
     *
     * @return the CSS Path that can be used to retrieve the element in a selector.
     */
    public func cssSelector() throws -> String {
        let elementId = id()
        if (elementId.count > 0) {
            return "#" + elementId
        }
        
        // Translate HTML namespace ns:tag to CSS namespace syntax ns|tag
        let tagName: String = self.tagName().replacingOccurrences(of: ":", with: "|")
        var selector: String = tagName
        let cl = try classNames()
        let classes: String = cl.joined(separator: ".")
        if (classes.count > 0) {
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
     * Get sibling elements. If the element has no sibling elements, returns an empty list. An element is not a sibling
     * of itself, so will not be included in the returned list.
     * @return sibling elements
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
     * Gets the next sibling element of this element. E.g., if a {@code div} contains two {@code p}s,
     * the {@code nextElementSibling} of the first {@code p} is the second {@code p}.
     * <p>
     * This is similar to {@link #nextSibling()}, but specifically finds only Elements
     * </p>
     * @return the next element, or null if there is no next element
     * @see #previousElementSibling()
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
                return nil}
        }
        return nil
    }
    
    /**
     * Gets the previous element sibling of this element.
     * @return the previous element, or null if there is no previous element
     * @see #nextElementSibling()
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
     * Gets the first element sibling of this element.
     * @return the first sibling that is an element (aka the parent's first element child)
     */
    public func firstElementSibling() -> Element? {
        // todo: should firstSibling() exclude this?
        let siblings: Array<Element>? = parent()?.children().array()
        return (siblings != nil && siblings!.count > 1) ? siblings![0] : nil
    }
    
    /*
     * Get the list index of this element in its element sibling list. I.e. if this is the first element
     * sibling, returns 0.
     * @return position in element sibling list
     */
    public func elementSiblingIndex()throws->Int {
        if (parent() == nil) {return 0}
        let x = try Element.indexInList(self, parent()?.children().array())
        return x == nil ? 0 : x!
    }
    
    /**
     * Gets the last element sibling of this element
     * @return the last sibling that is an element (aka the parent's last element child)
     */
    @inline(__always)
    public func lastElementSibling() -> Element? {
        let siblings: Array<Element>? = parent()?.children().array()
        return (siblings != nil && siblings!.count > 1) ? siblings![siblings!.count - 1] : nil
    }
    
    private static func indexInList(_ search: Element, _ elements: Array<Element>?)throws->Int? {
        try Validate.notNull(obj: elements)
        if let elements = elements {
            for i in  0..<elements.count {
                let element: Element = elements[i]
                if (element == search) {
                    return i
                }
            }
        }
        return nil
    }
    
    // DOM type methods
    
    /**
     * Finds elements, including and recursively under this element, with the specified tag name.
     * @param tagName The tag name to search for (case insensitively).
     * @return a matching unmodifiable list of elements. Will be empty if this element and none of its children match.
     */
    @inline(__always)
    public func getElementsByTag(_ tagName: String) throws -> Elements {
        return try getElementsByTag(tagName.utf8Array)
    }
    
    /**
     * Finds elements, including and recursively under this element, with the specified tag name.
     * @param tagName The tag name to search for (case insensitively).
     * @return a matching unmodifiable list of elements. Will be empty if this element and none of its children match.
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
     * Find an element by ID, including or under this element.
     * <p>
     * Note that this finds the first matching ID, starting with this element. If you search down from a different
     * starting point, it is possible to find a different element by ID. For unique element by ID within a Document,
     * use {@link Document#getElementById(String)}
     * @param id The ID to search for.
     * @return The first matching element by ID, starting with this element, or null if none found.
     */
    @inline(__always)
    public func getElementById(_ id: String) throws -> Element? {
        try Validate.notEmpty(string: id.utf8Array)
        
        let elements: Elements = try Collector.collect(Evaluator.Id(id), self)
        if (elements.array().count > 0) {
            return elements.get(0)
        } else {
            return nil
        }
    }
    
    /**
     * Find elements that have this class, including or under this element. Case insensitive.
     * <p>
     * Elements can have multiple classes (e.g. {@code <div class="header round first">}. This method
     * checks each class, so you can find the above with {@code el.getElementsByClass("header")}.
     *
     * @param className the name of the class to search for.
     * @return elements with the supplied class name, empty if none
     * @see #hasClass(String)
     * @see #classNames()
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
     * Find elements that have a named attribute set. Case insensitive.
     *
     * @param key name of the attribute, e.g. {@code href}
     * @return elements that have this attribute, empty if none
     */
    @inline(__always)
    public func getElementsByAttribute(_ key: String) throws -> Elements {
        try Validate.notEmpty(string: key.utf8Array)
        let key = key.trim()
        return try Collector.collect(Evaluator.Attribute(key), self)
    }
    
    /**
     * Find elements that have an attribute name starting with the supplied prefix. Use {@code data-} to find elements
     * that have HTML5 datasets.
     * @param keyPrefix name prefix of the attribute e.g. {@code data-}
     * @return elements that have attribute names that start with with the prefix, empty if none.
     */
    @inline(__always)
    public func getElementsByAttributeStarting(_ keyPrefix: String) throws -> Elements {
        try Validate.notEmpty(string: keyPrefix.utf8Array)
        let keyPrefix = keyPrefix.trim()
        return try Collector.collect(Evaluator.AttributeStarting(keyPrefix.utf8Array), self)
    }
    
    /**
     * Find elements that have an attribute with the specific value. Case insensitive.
     *
     * @param key name of the attribute
     * @param value value of the attribute
     * @return elements that have this attribute with this value, empty if none
     */
    @inline(__always)
    public func getElementsByAttributeValue(_ key: String, _ value: String)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValue(key, value), self)
    }
    
    /**
     * Find elements that either do not have this attribute, or have it with a different value. Case insensitive.
     *
     * @param key name of the attribute
     * @param value value of the attribute
     * @return elements that do not have a matching attribute
     */
    @inline(__always)
    public func getElementsByAttributeValueNot(_ key: String, _ value: String)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValueNot(key, value), self)
    }
    
    /**
     * Find elements that have attributes that start with the value prefix. Case insensitive.
     *
     * @param key name of the attribute
     * @param valuePrefix start of attribute value
     * @return elements that have attributes that start with the value prefix
     */
    @inline(__always)
    public func getElementsByAttributeValueStarting(_ key: String, _ valuePrefix: String)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValueStarting(key, valuePrefix), self)
    }
    
    /**
     * Find elements that have attributes that end with the value suffix. Case insensitive.
     *
     * @param key name of the attribute
     * @param valueSuffix end of the attribute value
     * @return elements that have attributes that end with the value suffix
     */
    @inline(__always)
    public func getElementsByAttributeValueEnding(_ key: String, _ valueSuffix: String)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValueEnding(key, valueSuffix), self)
    }
    
    /**
     * Find elements that have attributes whose value contains the match string. Case insensitive.
     *
     * @param key name of the attribute
     * @param match substring of value to search for
     * @return elements that have attributes containing this text
     */
    @inline(__always)
    public func getElementsByAttributeValueContaining(_ key: String, _ match: String)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValueContaining(key, match), self)
    }
    
    /**
     * Find elements that have attributes whose values match the supplied regular expression.
     * @param key name of the attribute
     * @param pattern compiled regular expression to match against attribute values
     * @return elements that have attributes matching this regular expression
     */
    public func getElementsByAttributeValueMatching(_ key: String, _ pattern: Pattern)throws->Elements {
        return try Collector.collect(Evaluator.AttributeWithValueMatching(key, pattern), self)
        
    }
    
    /**
     * Find elements that have attributes whose values match the supplied regular expression.
     * @param key name of the attribute
     * @param regex regular expression to match against attribute values. You can use <a href="http://java.sun.com/docs/books/tutorial/essential/regex/pattern.html#embedded">embedded flags</a> (such as (?i) and (?m) to control regex options.
     * @return elements that have attributes matching this regular expression
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
     * Find elements whose sibling index is less than the supplied index.
     * @param index 0-based index
     * @return elements less than index
     */
    public func getElementsByIndexLessThan(_ index: Int)throws->Elements {
        return try Collector.collect(Evaluator.IndexLessThan(index), self)
    }
    
    /**
     * Find elements whose sibling index is greater than the supplied index.
     * @param index 0-based index
     * @return elements greater than index
     */
    public func getElementsByIndexGreaterThan(_ index: Int)throws->Elements {
        return try Collector.collect(Evaluator.IndexGreaterThan(index), self)
    }
    
    /**
     * Find elements whose sibling index is equal to the supplied index.
     * @param index 0-based index
     * @return elements equal to index
     */
    public func getElementsByIndexEquals(_ index: Int)throws->Elements {
        return try Collector.collect(Evaluator.IndexEquals(index), self)
    }
    
    /**
     * Find elements that contain the specified string. The search is case insensitive. The text may appear directly
     * in the element, or in any of its descendants.
     * @param searchText to look for in the element's text
     * @return elements that contain the string, case insensitive.
     * @see Element#text()
     */
    public func getElementsContainingText(_ searchText: String)throws->Elements {
        return try Collector.collect(Evaluator.ContainsText(searchText), self)
    }
    
    /**
     * Find elements that directly contain the specified string. The search is case insensitive. The text must appear directly
     * in the element, not in any of its descendants.
     * @param searchText to look for in the element's own text
     * @return elements that contain the string, case insensitive.
     * @see Element#ownText()
     */
    public func getElementsContainingOwnText(_ searchText: String)throws->Elements {
        return try Collector.collect(Evaluator.ContainsOwnText(searchText), self)
    }
    
    /**
     * Find elements whose text matches the supplied regular expression.
     * @param pattern regular expression to match text against
     * @return elements matching the supplied regular expression.
     * @see Element#text()
     */
    public func getElementsMatchingText(_ pattern: Pattern)throws->Elements {
        return try Collector.collect(Evaluator.Matches(pattern), self)
    }
    
    /**
     * Find elements whose text matches the supplied regular expression.
     * @param regex regular expression to match text against. You can use <a href="http://java.sun.com/docs/books/tutorial/essential/regex/pattern.html#embedded">embedded flags</a> (such as (?i) and (?m) to control regex options.
     * @return elements matching the supplied regular expression.
     * @see Element#text()
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
     * Find elements whose own text matches the supplied regular expression.
     * @param pattern regular expression to match text against
     * @return elements matching the supplied regular expression.
     * @see Element#ownText()
     */
    public func getElementsMatchingOwnText(_ pattern: Pattern)throws->Elements {
        return try Collector.collect(Evaluator.MatchesOwn(pattern), self)
    }
    
    /**
     * Find elements whose text matches the supplied regular expression.
     * @param regex regular expression to match text against. You can use <a href="http://java.sun.com/docs/books/tutorial/essential/regex/pattern.html#embedded">embedded flags</a> (such as (?i) and (?m) to control regex options.
     * @return elements matching the supplied regular expression.
     * @see Element#ownText()
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
     * Find all elements under this element (including self, and children of children).
     *
     * @return all elements
     */
    public func getAllElements()throws->Elements {
        return try Collector.collect(Evaluator.AllElements(), self)
    }
    
    /**
     * Gets the combined text of this element and all its children. Whitespace is normalized and trimmed.
     * <p>
     * For example, given HTML {@code <p>Hello  <b>there</b> now! </p>}, {@code p.text()} returns {@code "Hello there now!"}
     *
     * @return unencoded text, or empty string if none.
     * @see #ownText()
     * @see #textNodes()
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
    
    /**
     * Gets the text owned by this element only; does not get the combined text of all children.
     * <p>
     * For example, given HTML {@code <p>Hello <b>there</b> now!</p>}, {@code p.ownText()} returns {@code "Hello now!"},
     * whereas {@code p.text()} returns {@code "Hello there now!"}.
     * Note that the text within the {@code b} element is not returned, as it is not a direct child of the {@code p} element.
     *
     * @return unencoded text, or empty string if none.
     * @see #text()
     * @see #textNodes()
     */
    public func ownText() -> String {
        let sb: StringBuilder = StringBuilder()
        ownText(sb)
        return sb.toString().trim()
    }
    
    /**
     * Gets the text owned by this element only; does not get the combined text of all children.
     * <p>
     * For example, given HTML {@code <p>Hello <b>there</b> now!</p>}, {@code p.ownText()} returns {@code "Hello now!"},
     * whereas {@code p.text()} returns {@code "Hello there now!"}.
     * Note that the text within the {@code b} element is not returned, as it is not a direct child of the {@code p} element.
     *
     * @return unencoded text, or empty string if none.
     * @see #text()
     * @see #textNodes()
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
     * Set the text of this element. Any existing contents (text or elements) will be cleared
     * @param text unencoded text
     * @return this element
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
     @return true if element has non-blank text content.
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
     * Get the combined data of this element. Data is e.g. the inside of a {@code script} tag.
     * @return the data, or empty string if none
     *
     * @see #dataNodes()
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
     * Gets the literal value of this element's "class" attribute, which may include multiple class names, space
     * separated. (E.g. on <code>&lt;div class="header gray"&gt;</code> returns, "<code>header gray</code>")
     * @return The literal class attribute, or <b>empty string</b> if no class attribute set.
     */
    public func className() throws -> String {
        return try String(decoding: attr(Element.classString).trim(), as: UTF8.self)
    }
    
    /**
     * Gets the literal value of this element's "class" attribute, which may include multiple class names, space
     * separated. (E.g. on <code>&lt;div class="header gray"&gt;</code> returns, "<code>header gray</code>")
     * @return The literal class attribute, or <b>empty string</b> if no class attribute set.
     */
    public func classNameUTF8() throws -> [UInt8] {
        return try attr(Element.classString).trim()
    }
    
    /**
     * Get all of the element's class names. E.g. on element {@code <div class="header gray">},
     * returns a set of two elements {@code "header", "gray"}. Note that modifications to this set are not pushed to
     * the backing {@code class} attribute; use the {@link #classNames(java.util.Set)} method to persist them.
     * @return set of classnames, empty if no class attribute
     */
    @inlinable
    internal func unorderedClassNamesUTF8() throws -> [ArraySlice<UInt8>] {
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
     * Get all of the element's class names. E.g. on element {@code <div class="header gray">},
     * returns a set of two elements {@code "header", "gray"}. Note that modifications to this set are not pushed to
     * the backing {@code class} attribute; use the {@link #classNames(java.util.Set)} method to persist them.
     * @return set of classnames, empty if no class attribute
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
     * Get all of the element's class names. E.g. on element {@code <div class="header gray">},
     * returns a set of two elements {@code "header", "gray"}. Note that modifications to this set are not pushed to
     * the backing {@code class} attribute; use the {@link #classNames(java.util.Set)} method to persist them.
     * @return set of classnames, empty if no class attribute
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
     Set the element's {@code class} attribute to the supplied class names.
     @param classNames set of classes
     @return this element, for chaining
     */
    @discardableResult
    public func classNames(_ classNames: OrderedSet<String>) throws -> Element {
        try attributes?.put(Element.classString, StringUtil.join(classNames, sep: " ").utf8Array)
        return self
    }
    
    /**
     * Tests if this element has a class. Case insensitive.
     * @param className name of class to check for
     * @return true if it does, false if not
     */
    // performance sensitive
    public func hasClass(_ className: String) -> Bool {
        let classAtt: [UInt8]? = attributes?.get(key: Element.classString)
        let len: Int = (classAtt != nil) ? classAtt!.count : 0
        let wantLen: Int = className.count
        
        if (len == 0 || len < wantLen) {
            return false
        }
        let classAttr = String(decoding: classAtt!, as: UTF8.self)
        
        // if both lengths are equal, only need compare the className with the attribute
        if (len == wantLen) {
            return className.equalsIgnoreCase(string: classAttr)
        }
        
        // otherwise, scan for whitespace and compare regions (with no string or arraylist allocations)
        var inClass: Bool = false
        var start: Int = 0
        for i in 0..<len {
            if (classAttr.utf8ByteAt(i).isWhitespace) {
                if (inClass) {
                    // white space ends a class name, compare it with the requested one, ignore case
                    if (i - start == wantLen && classAttr.regionMatches(ignoreCase: true, selfOffset: start,
                                                                        other: className, otherOffset: 0,
                                                                        targetLength: wantLen)) {
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
        
        // check the last entry
        if (inClass && len - start == wantLen) {
            return classAttr.regionMatches(ignoreCase: true, selfOffset: start,
                                           other: className, otherOffset: 0, targetLength: wantLen)
        }
        
        return false
    }
    
    /**
     * Tests if this element has a class. Case insensitive.
     * @param className name of class to check for
     * @return true if it does, false if not
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
     Add a class name to this element's {@code class} attribute.
     @param className class name to add
     @return this element
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
     Remove a class name from this element's {@code class} attribute.
     @param className class name to remove
     @return this element
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
     Toggle a class name on this element's {@code class} attribute: if present, remove it; otherwise add it.
     @param className class name to toggle
     @return this element
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
     * Get the value of a form element (input, textarea, etc).
     * @return the value of the form element, or empty string if not set.
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
     * Set the value of a form element (input, textarea, etc).
     * @param value value to set
     * @return this element (for chaining)
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
     * Retrieves the element's inner HTML. E.g. on a {@code <div>} with one empty {@code <p>}, would return
     * {@code <p></p>}. (Whereas {@link #outerHtml()} would return {@code <div><p></p></div>}.)
     *
     * @return String of HTML.
     * @see #outerHtml()
     */
    @inline(__always)
    public func html() throws -> String {
        let accum: StringBuilder = StringBuilder()
        try html2(accum)
        return getOutputSettings().prettyPrint() ? accum.toString().trim() : accum.toString()
    }
    
    /**
     * Retrieves the element's inner HTML. E.g. on a {@code <div>} with one empty {@code <p>}, would return
     * {@code <p></p>}. (Whereas {@link #outerHtml()} would return {@code <div><p></p></div>}.)
     *
     * @return String of HTML.
     * @see #outerHtml()
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
    
    /**
     * {@inheritDoc}
     */
    @inline(__always)
    open override func html(_ appendable: StringBuilder) throws -> StringBuilder {
        for node in childNodes {
            try node.outerHtml(appendable)
        }
        return appendable
    }
    
    /**
     * Set this element's inner HTML. Clears the existing HTML first.
     * @param html HTML to parse and set into this element
     * @return this element
     * @see #append(String)
     */
    @discardableResult
    public func html(_ html: String) throws -> Element {
        empty()
        try append(html)
        return self
    }
    
    public override func copy(with zone: NSZone? = nil) -> Any {
        let clone = Element(_tag, baseUri!, attributes!)
        return copy(clone: clone)
    }
    
    public override func copy(parent: Node?) -> Node {
        let clone = Element(_tag, baseUri!, attributes!)
        return copy(clone: clone, parent: parent)
    }
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
    @inlinable
    func markQueryIndexesDirty() {
        guard !(treeBuilder?.isBulkBuilding ?? false) else { return }
        var current: Node? = self
        while let node = current {
            if let el = node as? Element {
                el.isTagQueryIndexDirty = true
                el.isClassQueryIndexDirty = true
            }
            current = node.parentNode
        }
    }
    
    @inlinable
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
    
    @inlinable
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
    func rebuildQueryIndexesForAllTags() {
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        var queue: [Node] = [self]
        
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        queue.reserveCapacity(childNodeCount)
        
        var index = 0
        while index < queue.count {
            let node = queue[index]
            index += 1  // Move to the next element
            
            if let element = node as? Element {
                let key = element.tagNameNormalUTF8()
                newIndex[key, default: []].append(Weak(element))
            }
            
            queue.append(contentsOf: node.childNodes)
        }
        
        normalizedTagNameIndex = newIndex
        isTagQueryIndexDirty = false
    }
    
    @usableFromInline
    @inline(__always)
    func rebuildQueryIndexesForAllClasses() {
        var newIndex: [[UInt8]: [Weak<Element>]] = [:]
        var queue: [Node] = [self]
        let childNodeCount = childNodeSize()
        newIndex.reserveCapacity(childNodeCount * 4)
        queue.reserveCapacity(childNodeCount)
        var idx = 0
        while idx < queue.count {
            let node = queue[idx]
            idx += 1
            if let element = node as? Element {
                if let classNames = try? element.unorderedClassNamesUTF8() {
                    for className in classNames {
                        newIndex[Array(className), default: []].append(Weak(element))
                    }
                }
            }
            queue.append(contentsOf: node.childNodes)
        }
        normalizedClassNameIndex = newIndex
        isClassQueryIndexDirty = false
    }
    
    @inlinable
    func rebuildQueryIndexesForThisNodeOnly() {
        normalizedTagNameIndex = nil
        markTagQueryIndexDirty()
        markClassQueryIndexDirty()
    }
}
