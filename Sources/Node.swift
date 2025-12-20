//
//  Node.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//

import Foundation

fileprivate let childNodesDiffAlgorithmThreshold: Int = 10

@usableFromInline
internal final class Weak<T: AnyObject> {
    @usableFromInline
    weak var value: T?
    
    @usableFromInline
    init(_ value: T) {
        self.value = value
    }
}

open class Node: Equatable, Hashable {
    var baseUri: [UInt8]?
    var attributes: Attributes?
    
    @usableFromInline
    weak var parentNode: Node? {
        @inline(__always)
        didSet {
            guard let element = self as? Element, oldValue !== parentNode else { return }
            element.markQueryIndexesDirty()
        }
    }
    
    /// Text cache versioning for the root of a tree (Document or standalone root Element).
    @usableFromInline
    internal var textMutationVersion: Int = 0
    
    /// Reference back to the parser that built this node (for bulk-build flag checks)
    @usableFromInline
    weak var treeBuilder: TreeBuilder?
    
    @usableFromInline
    var childNodes: [Node]
    
    /**
     Get the list index of this node in its node sibling list. I.e. if this is the first node
     sibling, returns 0.
     - returns: position in node sibling list
     - seealso: ``Element/elementSiblingIndex()``
     */
    public private(set) var siblingIndex: Int = 0
    
    private static let abs = "abs:".utf8Array
    private static let absCount = abs.count
    fileprivate static let empty = "".utf8Array
    
    /**
     Create a new Node.
     - parameter baseUri: base URI
     - parameter attributes: attributes (not `nil`, but may be empty)
     - parameter skipChildReserve: Whether to skip reserving space for children in advance.
     */
    public init(
        _ baseUri: [UInt8],
        _ attributes: Attributes,
        skipChildReserve: Bool = false
    ) {
        childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        
        self.baseUri = baseUri.trim()
        self.attributes = attributes
    }
    
    public init(
        _ baseUri: [UInt8],
        skipChildReserve: Bool = false
    ) {
        childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        
        self.baseUri = baseUri.trim()
        self.attributes = Attributes()
    }
    
    /**
     Default constructor. Doesn't setup base uri, children, or attributes; use with caution.
     */
    public init(
        skipChildReserve: Bool = false
    ) {
        self.childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        
        self.attributes = nil
        self.baseUri = nil
    }
    
    /**
     Get the node name of this node. Use for debugging purposes and not logic switching (for that, use instanceof).
     - returns: node name
     */
    public func nodeName() -> String {
        preconditionFailure("This method must be overridden")
    }
    
    public func nodeNameUTF8() -> [UInt8] {
        preconditionFailure("This method must be overridden")
    }
    
    /**
     Get an attribute's value by its key. **Case insensitive.**
     
     To get an absolute URL from an attribute that may be a relative URL, prefix the key with `abs`,
     which is a shortcut to the ``absUrl(_:)-(String)`` method.
     
     E.g.:
     ```swift
     let urlString = a.attr("abs:href")
     ```
     
     - parameter attributeKey: The attribute key.
     - returns: The attribute, or empty string if not present (to avoid `nil`s).
     - seealso: ``getAttributes()``, ``hasAttr(_:)-(String)``, ``absUrl(_:)-(String)``
     */
    open func attr(_ attributeKey: [UInt8]) throws -> [UInt8] {
        let val: [UInt8] = try attributes!.getIgnoreCase(key: attributeKey)
        if !val.isEmpty {
            return val
        } else if (attributeKey.lowercased().starts(with: Node.abs)) {
            return try absUrl(attributeKey.substring(Node.abs.count))
        } else {
            return Node.empty
        }
    }
    
    open func attr(_ attributeKey: String) throws -> String {
        return try String(decoding: attr(attributeKey.utf8Array), as: UTF8.self)
    }
    
    /**
     Get all of the element's attributes.
     - returns: attributes (which implements iterable, in same order as presented in original HTML).
     */
    open func getAttributes() -> Attributes? {
        return attributes
    }
    
    /**
     Set an attribute (key=value). If the attribute already exists, it is replaced.
     - parameter attributeKey: The attribute key.
     - parameter attributeValue: The attribute value.
     - returns: this (for chaining)
     */
    @discardableResult
    open func attr(_ attributeKey: [UInt8], _ attributeValue: [UInt8]) throws -> Node {
        try attributes?.put(attributeKey, attributeValue)
        return self
    }
    
    @discardableResult
    open func attr(_ attributeKey: String, _ attributeValue: String) throws -> Node {
        try attributes?.put(attributeKey, attributeValue)
        return self
    }
    
    /**
     Test if this element has an attribute. **Case insensitive.**
     - parameter attributeKey: The attribute key to check.
     - returns: true if the attribute exists, false if not.
     */
    open func hasAttr(_ attributeKey: String) -> Bool {
        return hasAttr(attributeKey.utf8Array)
    }
    
    /**
     Test if this element has an attribute. **Case insensitive.**
     - parameter attributeKey: The attribute key to check.
     - returns: true if the attribute exists, false if not.
     */
    open func hasAttr(_ attributeKey: [UInt8]) -> Bool {
        guard let attributes = attributes else {
            return false
        }
        if attributeKey.starts(with: Node.abs) {
            let key = ArraySlice(attributeKey.dropFirst(Node.absCount))
            do {
                let abs = try absUrl(key)
                if (attributes.hasKeyIgnoreCase(key: key) && !abs.isEmpty) {
                    return true
                }
            } catch {
                return false
            }
            
        }
        return attributes.hasKeyIgnoreCase(key: attributeKey)
    }
    
    /**
     Remove an attribute from this element.
     - parameter attributeKey: The attribute to remove.
     - returns: this (for chaining)
     */
    @discardableResult
    open func removeAttr(_ attributeKey: [UInt8]) throws -> Node {
        try attributes?.removeIgnoreCase(key: attributeKey)
        return self
    }
    
    @discardableResult
    open func removeAttr(_ attributeKey: String) throws -> Node {
        return try removeAttr(attributeKey.utf8Array)
    }
    
    /**
     Get the base URI of this node.
     - returns: base URI
     */
    open func getBaseUri() -> String {
        return String(decoding: getBaseUriUTF8(), as: UTF8.self)
    }
    
    open func getBaseUriUTF8() -> [UInt8] {
        return baseUri ?? []
    }
    
    /**
     Update the base URI of this node and all of its descendants.
     - parameter baseUri: base URI to set
     */
    open func setBaseUri(_ baseUri: String) throws {
        try setBaseUri(baseUri.utf8Array)
    }
    
    open func setBaseUri(_ baseUri: [UInt8]) throws {
        class nodeVisitor: NodeVisitor {
            private let baseUri: [UInt8]
            init(_ baseUri: [UInt8]) {
                self.baseUri = baseUri
            }
            
            func head(_ node: Node, _ depth: Int) throws {
                node.baseUri = baseUri
            }
            
            func tail(_ node: Node, _ depth: Int) throws {
            }
        }
        try traverse(nodeVisitor(baseUri))
    }
    
    /**
     Get an absolute URL from a URL attribute that may be relative (i.e. an `<a href>` or
     `<img src>`).
     
     E.g.:
     ```swift
     let absUrlString = linkEl.absUrl("href")
     ```
     
     If the attribute value is already absolute (i.e. it starts with a protocol, like
     `http://` or `https://` etc), and it successfully parses as a URL, the attribute is
     returned directly. Otherwise, it is treated as a URL relative to the element's ``Node/getBaseUri()``, and made
     absolute using that.
     
     As an alternate, you can use the ``attr(_:)-(String)`` method with the `abs:` prefix, e.g.:
     ```swift
     let absUrlString = linkEl.attr("abs:href")
     ```
     
     - parameter attributeKey: The attribute key
     - returns: An absolute URL if one could be made, or an empty string if the attribute was missing or
     could not be made successfully into a URL.
     - seealso: ``attr(_:)-(String)``
     */
    open func absUrl(_ attributeKey: String) throws -> String {
        return try String(decoding: absUrl(attributeKey.utf8Array), as: UTF8.self)
    }
    
    open func absUrl<T: Collection>(_ attributeKey: T) throws -> [UInt8] where T.Element == UInt8 {
        try Validate.notEmpty(string: attributeKey)
        
        let keyStr = String(decoding: attributeKey, as: UTF8.self)
        if (!hasAttr(keyStr)) {
            return Node.empty // nothing to make absolute with
        } else {
            return StringUtil.resolve(String(decoding: baseUri!, as: UTF8.self), relUrl: try attr(keyStr)).utf8Array
        }
    }
    
    /**
     Get a child node by its 0-based index.
     - parameter index: index of child node
     - returns: the child node at this index.
     - warning: Crashes if the index is out of bounds!
     */
    @inline(__always)
    open func childNode(_ index: Int) -> Node {
        return childNodes[index]
    }
    
    /**
     Get this node's children. Presented as an unmodifiable list: new children can not be added, but the child nodes
     themselves can be manipulated.
     - returns: list of children. If no children, returns an empty list.
     */
    @inline(__always)
    open func getChildNodes() -> Array<Node> {
        return childNodes
    }
    
    /**
     Returns a deep copy of this node's children. Changes made to these nodes will not be reflected in the original
     nodes
     - returns: a deep copy of this node's children
     */
    @inline(__always)
    open func childNodesCopy() -> Array<Node> {
        return childNodes.map { $0.copy() as! Node }
    }
    
    /**
     Get the number of child nodes that this node holds.
     - returns: the number of child nodes that this node holds.
     */
    @inline(__always)
    public func childNodeSize() -> Int {
        return childNodes.count
    }
    
    @inline(__always)
    public func hasChildNodes() -> Bool {
        return !childNodes.isEmpty
    }
    
    @inline(__always)
    final func childNodesAsArray() -> [Node] {
        return childNodes as Array
    }
    
    /**
     Gets this node's parent node.
     - returns: parent node or `nil` if no parent.
     */
    @inline(__always)
    open func parent() -> Node? {
        return parentNode
    }
    
    /**
     Gets this node's parent node. Node overridable by extending classes, so useful if you really just need the Node type.
     - returns: parent node or `nil` if no parent.
     */
    @inline(__always)
    final func getParentNode() -> Node? {
        return parentNode
    }
    
    /**
     Gets the Document associated with this Node.
     - returns: the Document associated with this Node, or `nil` if there is no such Document.
     */
    @inline(__always)
    open func ownerDocument() -> Document? {
        if let this =  self as? Document {
            return this
        } else if (parentNode == nil) {
            return nil
        } else {
            return parentNode!.ownerDocument()
        }
    }
    
    /**
     Remove (delete) this node from the DOM tree. If this node has children, they are also removed.
     */
    @inline(__always)
    open func remove() throws {
        try parentNode?.removeChild(self)
    }
    
    @inline(__always)
    @usableFromInline
    internal func textMutationRoot() -> Node {
        var node: Node = self
        while let parent = node.parentNode {
            node = parent
        }
        return node
    }
    
    @inline(__always)
    @usableFromInline
    internal func bumpTextMutationVersion() {
        let root = textMutationRoot()
        root.textMutationVersion &+= 1
    }
    
    /**
     Insert the specified HTML into the DOM before this node (i.e. as a preceding sibling).
     - parameter html: HTML to add before this node
     - returns: this node, for chaining
     - seealso: ``after(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    open func before(_ html: String) throws -> Node {
        try addSiblingHtml(siblingIndex, html)
        return self
    }
    
    /**
     Insert the specified HTML into the DOM before this node (i.e. as a preceding sibling).
     - parameter html: HTML to add before this node
     - returns: this node, for chaining
     - seealso: ``after(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    open func before(_ html: [UInt8]) throws -> Node {
        try addSiblingHtml(siblingIndex, html)
        return self
    }
    
    /**
     Insert the specified node into the DOM before this node (i.e. as a preceding sibling).
     - parameter node: to add before this node
     - returns: this node, for chaining
     - seealso: ``after(_:)-(Node)``
     */
    @discardableResult
    @inline(__always)
    open func before(_ node: Node) throws -> Node {
        try Validate.notNull(obj: node)
        try Validate.notNull(obj: parentNode)
        
        try parentNode?.addChildren(siblingIndex, node)
        return self
    }
    
    /**
     Insert the specified HTML into the DOM after this node (i.e. as a following sibling).
     - parameter html: HTML to add after this node
     - returns: this node, for chaining
     - seealso: ``before(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    open func after(_ html: String) throws -> Node {
        try addSiblingHtml(siblingIndex + 1, html)
        return self
    }
    
    /**
     Insert the specified node into the DOM after this node (i.e. as a following sibling).
     - parameter node: to add after this node
     - returns: this node, for chaining
     - seealso: ``before(_:)-(Node)``
     */
    @discardableResult
    @inline(__always)
    open func after(_ node: Node) throws -> Node {
        try Validate.notNull(obj: node)
        try Validate.notNull(obj: parentNode)
        
        try parentNode?.addChildren(siblingIndex+1, node)
        return self
    }
    
    private func addSiblingHtml(_ index: Int, _ html: String) throws {
        try Validate.notNull(obj: parentNode)
        
        let context: Element? = parent() as? Element
        
        let nodes: Array<Node> = try Parser.parseFragment(html, context, getBaseUriUTF8())
        try parentNode?.addChildren(index, nodes)
    }
    
    private func addSiblingHtml(_ index: Int, _ html: [UInt8]) throws {
        try Validate.notNull(obj: parentNode)
        
        let context: Element? = parent() as? Element
        
        let nodes: Array<Node> = try Parser.parseFragment(html, context, getBaseUriUTF8())
        try parentNode?.addChildren(index, nodes)
    }
    
    /**
     Insert the specified HTML into the DOM after this node (i.e. as a following sibling).
     - parameter html: HTML to add after this node
     - returns: this node, for chaining
     - seealso: ``before(_:)-(String)``
     */
    @discardableResult
    @inline(__always)
    open func after(html: String) throws -> Node {
        try addSiblingHtml(siblingIndex + 1, html)
        return self
    }
    
    /**
     Insert the specified node into the DOM after this node (i.e. as a following sibling).
     - parameter node: to add after this node
     - returns: this node, for chaining
     - seealso: ``before(_:)-(Node)``
     */
    @discardableResult
    @inline(__always)
    open func after(node: Node) throws -> Node {
        try Validate.notNull(obj: node)
        try Validate.notNull(obj: parentNode)
        
        try parentNode?.addChildren(siblingIndex + 1, node)
        return self
    }
    
    @inline(__always)
    open func addSiblingHtml(index: Int, _ html: String)throws {
        try Validate.notNull(obj: html)
        try Validate.notNull(obj: parentNode)
        
        let context: Element? = parent() as? Element
        let nodes: Array<Node> = try Parser.parseFragment(html, context, getBaseUriUTF8())
        try parentNode?.addChildren(index, nodes)
    }
    
    /**
     Wrap the supplied HTML around this node.
     - parameter html: HTML to wrap around this element, e.g. `<div class="head"></div>`. Can be arbitrarily deep.
     - returns: this node, for chaining.
     */
    @discardableResult
    open func wrap(_ html: String) throws -> Node? {
        try Validate.notEmpty(string: html.utf8Array)
        
        let context: Element? = parent() as? Element
        var wrapChildren: Array<Node> = try Parser.parseFragment(html, context, getBaseUriUTF8())
        let wrapNode: Node? = !wrapChildren.isEmpty ? wrapChildren[0] : nil
        if (wrapNode == nil || !(((wrapNode as? Element) != nil))) { // nothing to wrap with; noop
            return nil
        }
        
        let wrap: Element = wrapNode as! Element
        let deepest: Element = getDeepChild(el: wrap)
        try parentNode?.replaceChild(self, wrap)
        wrapChildren = wrapChildren.filter { $0 != wrap}
        try deepest.addChildren(self)
        
        // remainder (unbalanced wrap, like <div></div><p></p> -- The <p> is remainder
        if !wrapChildren.isEmpty {
            for i in  0..<wrapChildren.count {
                let remainder: Node = wrapChildren[i]
                try remainder.parentNode?.removeChild(remainder)
                try wrap.appendChild(remainder)
            }
        }
        return self
    }
    
    /**
     Removes this node from the DOM, and moves its children up into the node's parent. This has the effect of dropping
     the node but keeping its children.
     
     For example, with the input HTML:
     ```html
     <div>One <span>Two <b>Three</b></span></div>
     ```
     
     Calling `element.unwrap()` on the `span` element will result in the HTML:
     ```html
     <div>One Two <b>Three</b></div>
     ```
     
     and the `"Two "` ``TextNode`` being returned.
     
     - returns: the first child of this node, after the node has been unwrapped. `nil` if the node had no children.
     - seealso: ``remove()``, ``wrap(_:)``
     */
    @discardableResult
    open func unwrap() throws ->Node? {
        try Validate.notNull(obj: parentNode)
        
        let firstChild: Node? = !childNodes.isEmpty ? childNodes[0] : nil
        try parentNode?.addChildren(siblingIndex, self.childNodesAsArray())
        try self.remove()
        
        return firstChild
    }
    
    @inline(__always)
    private func getDeepChild(el: Element) -> Element {
        let children = el.children()
        if (children.size() > 0) {
            return getDeepChild(el: children.get(0))
        } else {
            return el
        }
    }
    
    /**
     Replace this node in the DOM with the supplied node.
     - parameter input: the node that will will replace the existing node.
     */
    @inlinable
    public func replaceWith(_ input: Node) throws {
        try Validate.notNull(obj: input)
        try Validate.notNull(obj: parentNode)
        try parentNode?.replaceChild(self, input)
    }
    
    @inline(__always)
    public func setParentNode(_ parentNode: Node) throws {
        if (self.parentNode != nil) {
            try self.parentNode?.removeChild(self)
        }
        self.parentNode = parentNode
    }
    
    @inlinable
    public func replaceChild(_ out: Node, _ input: Node) throws {
        try Validate.isTrue(val: out.parentNode === self)
        try Validate.notNull(obj: input)
        if (input.parentNode != nil) {
            try input.parentNode?.removeChild(input)
        }
        
        let index: Int = out.siblingIndex
        childNodes[index] = input
        input.parentNode = self
        input.setSiblingIndex(index)
        out.parentNode = nil
        if (out is Element) || (input is Element), let element = self as? Element {
            element.markQueryIndexesDirty()
        }
        bumpTextMutationVersion()
    }
    
    @inlinable
    public func removeChild(_ out: Node) throws {
        try Validate.isTrue(val: out.parentNode === self)
        let index: Int = out.siblingIndex
        childNodes.remove(at: index)
        reindexChildren(index)
        out.parentNode = nil
        if out is Element, let element = self as? Element {
            element.markQueryIndexesDirty()
        }
        bumpTextMutationVersion()
    }
    
    @inline(__always)
    public func addChildren(_ children: Node...) throws {
        //most used. short circuit addChildren(int), which hits reindex children and array copy
        try addChildren(children)
    }
    
    @inline(__always)
    public func addChildren(_ children: [Node]) throws {
        //most used. short circuit addChildren(int), which hits reindex children and array copy
        for child in children {
            try reparentChild(child)
            childNodes.append(child)
            child.setSiblingIndex(childNodes.count - 1)
        }
        bumpTextMutationVersion()
    }
    
    @inline(__always)
    public func addChildren(_ index: Int, _ children: Node...) throws {
        try addChildren(index, children)
    }
    
    @inline(__always)
    public func addChildren(_ index: Int, _ children: [Node]) throws {
        for input in children.reversed() {
            try reparentChild(input)
            childNodes.insert(input, at: index)
            reindexChildren(index)
        }
        bumpTextMutationVersion()
    }
    
    @inline(__always)
    public func reparentChild(_ child: Node)throws {
        try child.parentNode?.removeChild(child)
        try child.setParentNode(self)
        // propagate builder reference for bulk-append checks
        child.treeBuilder = self.treeBuilder
    }
    
    @usableFromInline
    internal func reindexChildren(_ start: Int) {
        for (index, node) in childNodes[start...].enumerated() {
            node.setSiblingIndex(start + index)
        }
    }
    
    /**
     Retrieves this node's sibling nodes. Similar to `node.parent.getChildNodes()`, but does not
     include this node (a node is not a sibling of itself).
     - returns: node siblings. If the node has no parent, returns an empty list.
     */
    open func siblingNodes() -> Array<Node> {
        if (parentNode == nil) {
            return Array<Node>()
        }
        
        let nodes: Array<Node> = parentNode!.childNodes
        var siblings: Array<Node> = Array<Node>()
        siblings.reserveCapacity(nodes.count - 1)
        for node in nodes where node !== self {
            siblings.append(node)
        }
        
        return siblings
    }
    
    /**
     Get this node's next sibling.
     - returns: next sibling, or `nil` if this is the last sibling
     */
    @inline(__always)
    open func nextSibling() -> Node? {
        guard hasNextSibling() else { return nil }
        guard let siblings: Array<Node> = parent()?.getChildNodes() else {
            return nil
        }
        return siblings[siblingIndex + 1]
    }
    
    @inline(__always)
    open func hasNextSibling() -> Bool {
        guard let parent = parent() else {
            return false
        }
        return parent.childNodeSize() > siblingIndex + 1
    }
    
    /**
     Get this node's previous sibling.
     - returns: the previous sibling, or `nil` if this is the first sibling
     */
    @inline(__always)
    open func previousSibling() -> Node? {
        if (parentNode == nil) {
            return nil // root
        }
        
        if siblingIndex > 0 {
            return parentNode?.childNodes[siblingIndex - 1]
        } else {
            return nil
        }
    }
    
    @inline(__always)
    public func setSiblingIndex(_ siblingIndex: Int) {
        self.siblingIndex = siblingIndex
    }
    
    /**
     Perform a depth-first traversal through this node and its descendants.
     - parameter nodeVisitor: the visitor callbacks to perform on each node
     - returns: this node, for chaining
     */
    @discardableResult
    @inline(__always)
    open func traverse(_ nodeVisitor: NodeVisitor) throws -> Node {
        let traversor: NodeTraversor = NodeTraversor(nodeVisitor)
        try traversor.traverse(self)
        return self
    }
    
    /**
     Get the outer HTML of this node.
     - returns: HTML
     */
    @inline(__always)
    open func outerHtml() throws -> String {
        let accum: StringBuilder = StringBuilder(128)
        try outerHtml(accum)
        return accum.toString()
    }
    
    @inline(__always)
    public func outerHtml(_ accum: StringBuilder) throws {
        try NodeTraversor(OuterHtmlVisitor(accum, getOutputSettings())).traverse(self)
    }
    
    // if this node has no document (or parent), retrieve the default output settings
    func getOutputSettings() -> OutputSettings {
        return ownerDocument() != nil ? ownerDocument()!.outputSettings() : (Document([])).outputSettings()
    }
    
    /**
     Get the outer HTML of this node.
     - parameter accum: accumulator to place HTML into
     @throws IOException if appending to the given accumulator fails.
     */
    func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
        preconditionFailure("This method must be overridden")
    }
    
    func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
        preconditionFailure("This method must be overridden")
    }
    
    /**
     Write this node and its children to the given ``StringBuilder``.
     
     - parameter appendable: the ``StringBuilder`` to write to.
     - returns: the supplied StringBuilder, for chaining.
     */
    @inline(__always)
    open func html(_ appendable: StringBuilder)throws -> StringBuilder {
        try outerHtml(appendable)
        return appendable
    }
    
    @inline(__always)
    public func indent(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        accum.append(UnicodeScalar.BackslashN).append(StringUtil.padding(depth * Int(out.indentAmount())))
    }
    
    /**
     Check if this node is the same instance of another (object identity test).
     - parameter o: other object to compare to
     - returns: true if the content of this node is the same as the other
     - seealso: ``hasSameValue(_:)``
     */
    
    @inline(__always)
    open func equals(_ o: Node) -> Bool {
        // implemented just so that javadoc is clear this is an identity test
        return self === o
    }
    
    /**
     Check if this node is has the same content as another node. A node is considered the same if its name, attributes and content match the
     other node; particularly its position in the tree does not influence its similarity.
     - parameter o: other object to compare to
     - returns: true if the content of this node is the same as the other
     */
    @inline(__always)
    open func hasSameValue(_ o: Node)throws->Bool {
        if (self === o) {return true}
        //        if (type(of:self) != type(of: o))
        //        {
        //            return false
        //        }
        
        return try self.outerHtml() ==  o.outerHtml()
    }
    
    /**
     Create a stand-alone, deep copy of this node, and all of its children. The cloned node will have no siblings or
     parent node. As a stand-alone object, any changes made to the clone or any of its children will not impact the
     original node.
     
     The cloned node may be adopted into another Document or node structure using ``Element/appendChild(_:)``.
     - returns: stand-alone cloned node
     */
    @inline(__always)
    public func copy(with zone: NSZone? = nil) -> Any {
        return copy(clone: Node(skipChildReserve: !hasChildNodes()))
    }
    
    @inline(__always)
    public func copy(parent: Node?) -> Node {
        let clone = Node(skipChildReserve: !hasChildNodes())
        return copy(clone: clone, parent: parent)
    }
    
    public func copy(clone: Node) -> Node {
        let thisClone = copy(clone: clone, parent: nil) // splits for orphan
        
        // BFS clone using index-based queue
        var queue: [Node] = [thisClone]
        var idx = 0
        while idx < queue.count {
            let currParent = queue[idx]
            idx += 1
            
            let originalChildren = currParent.childNodes
            currParent.childNodes = originalChildren.map {
                $0.copy(parent: currParent)
            }
            queue.append(contentsOf: currParent.childNodes)
            if let currParentElement = currParent as? Element {
                currParentElement.rebuildQueryIndexesForThisNodeOnly()
            }
        }
        
        return thisClone
    }
    
    /**
     * Return a clone of the node using the given parent (which can be `nil`).
     * Not a deep copy of children.
     */
    public func copy(clone: Node, parent: Node?) -> Node {
        clone.parentNode = parent // can be nil, to create an orphan split
        clone.siblingIndex = parent == nil ? 0 : siblingIndex
        clone.attributes = attributes != nil ? attributes?.clone() : nil
        clone.attributes?.ownerElement = clone as? SwiftSoup.Element
        clone.baseUri = baseUri
        clone.childNodes = childNodes
        
        if let cloneElement = clone as? Element {
            cloneElement.rebuildQueryIndexesForThisNodeOnly()
        }
        
        return clone
    }
    
    private class OuterHtmlVisitor: NodeVisitor {
        private var accum: StringBuilder
        private var out: OutputSettings
        static private let text = "#text".utf8Array
        
        init(_ accum: StringBuilder, _ out: OutputSettings) {
            self.accum = accum
            self.out = out
        }
        
        @inline(__always)
        open func head(_ node: Node, _ depth: Int) throws {
            try node.outerHtmlHead(accum, depth, out)
        }
        
        @inline(__always)
        open func tail(_ node: Node, _ depth: Int) throws {
            // When compiling a release optimized swift linux 4.2 version the "saves a void hit."
            // causes a SIL error. Removing optimization on linux until a fix is found.
#if os(Linux)
            try node.outerHtmlTail(accum, depth, out)
#else
            if (!(node.nodeNameUTF8() == OuterHtmlVisitor.text)) { // saves a void hit.
                try node.outerHtmlTail(accum, depth, out)
            }
#endif
        }
    }
    
    /// Returns a Boolean value indicating whether two values are equal.
    ///
    /// Equality is the inverse of inequality. For any values `a` and `b`,
    /// `a == b` implies that `a != b` is `false`.
    ///
    /// - Parameters:
    ///   - lhs: A value to compare.
    ///   - rhs: Another value to compare.
    @inline(__always)
    public static func ==(lhs: Node, rhs: Node) -> Bool {
        return lhs === rhs
    }
    
    /// The hash value.
    ///
    /// Hash values are not guaranteed to be equal across different executions of
    /// your program. Do not save hash values to use during a future execution.
    @inline(__always)
    public func hash(into hasher: inout Hasher) {
        hasher.combine(description)
        hasher.combine(baseUri)
    }
}

extension Node: CustomStringConvertible {
    @inline(__always)
    public var description: String {
        do {
            return try outerHtml()
        } catch {
            
        }
        return ""
    }
}

extension Node: CustomDebugStringConvertible {
    private static let space = " "
    public var debugDescription: String {
        do {
            return try String(describing: type(of: self)) + Node.space + outerHtml()
        } catch {
            
        }
        return String(describing: type(of: self))
    }
}
