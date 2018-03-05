//
//  Node.swift
//  SwifSoup
//
//  Created by Nabil Chatbi on 29/09/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

open class Node: Equatable, Hashable {
    private static let abs = "abs:"
    fileprivate static let empty = ""
    private static let EMPTY_NODES: Array<Node>  = Array<Node>()
    weak var parentNode: Node?
    var childNodes: Array <Node>
    var attributes: Attributes?
    var baseUri: String?

	/**
	* Get the list index of this node in its node sibling list. I.e. if this is the first node
	* sibling, returns 0.
	* @return position in node sibling list
	* @see org.jsoup.nodes.Element#elementSiblingIndex()
	*/
    public private(set) var siblingIndex: Int = 0

    /**
     Create a new Node.
     @param baseUri base URI
     @param attributes attributes (not null, but may be empty)
     */
    public init(_ baseUri: String, _ attributes: Attributes) {
        self.childNodes = Node.EMPTY_NODES
        self.baseUri = baseUri.trim()
        self.attributes = attributes
    }

    public init(_ baseUri: String) {
        childNodes = Node.EMPTY_NODES
        self.baseUri = baseUri.trim()
        self.attributes = Attributes()
    }

    /**
     * Default constructor. Doesn't setup base uri, children, or attributes; use with caution.
     */
    public init() {
        self.childNodes = Node.EMPTY_NODES
        self.attributes = nil
        self.baseUri = nil
    }

    /**
     Get the node name of this node. Use for debugging purposes and not logic switching (for that, use instanceof).
     @return node name
     */
    public func nodeName() -> String {
        preconditionFailure("This method must be overridden")
    }

    /**
     * Get an attribute's value by its key. <b>Case insensitive</b>
     * <p>
     * To get an absolute URL from an attribute that may be a relative URL, prefix the key with <code><b>abs</b></code>,
     * which is a shortcut to the {@link #absUrl} method.
     * </p>
     * E.g.:
     * <blockquote><code>String url = a.attr("abs:href");</code></blockquote>
     *
     * @param attributeKey The attribute key.
     * @return The attribute, or empty string if not present (to avoid nulls).
     * @see #attributes()
     * @see #hasAttr(String)
     * @see #absUrl(String)
     */
    open func attr(_ attributeKey: String)throws ->String {
        let val: String = try attributes!.getIgnoreCase(key: attributeKey)
        if (val.count > 0) {
            return val
        } else if (attributeKey.lowercased().startsWith(Node.abs)) {
            return try absUrl(attributeKey.substring(Node.abs.count))
        } else {return Node.empty}
    }

    /**
     * Get all of the element's attributes.
     * @return attributes (which implements iterable, in same order as presented in original HTML).
     */
    open func getAttributes() -> Attributes? {
        return attributes
    }

    /**
     * Set an attribute (key=value). If the attribute already exists, it is replaced.
     * @param attributeKey The attribute key.
     * @param attributeValue The attribute value.
     * @return this (for chaining)
     */
    @discardableResult
    open func attr(_ attributeKey: String, _ attributeValue: String)throws->Node {
        try attributes?.put(attributeKey, attributeValue)
        return self
    }

    /**
     * Test if this element has an attribute. <b>Case insensitive</b>
     * @param attributeKey The attribute key to check.
     * @return true if the attribute exists, false if not.
     */
    open func hasAttr(_ attributeKey: String) -> Bool {
		guard let attributes = attributes else {
			return false
		}
        if (attributeKey.startsWith(Node.abs)) {
            let key: String = attributeKey.substring(Node.abs.count)
            do {
                let abs = try absUrl(key)
                if (attributes.hasKeyIgnoreCase(key: key) &&  !Node.empty.equals(abs)) {
                    return true
                }
            } catch {
                return false
            }

        }
        return attributes.hasKeyIgnoreCase(key: attributeKey)
    }

    /**
     * Remove an attribute from this element.
     * @param attributeKey The attribute to remove.
     * @return this (for chaining)
     */
    @discardableResult
    open func removeAttr(_ attributeKey: String)throws->Node {
        try attributes?.removeIgnoreCase(key: attributeKey)
        return self
    }

    /**
     Get the base URI of this node.
     @return base URI
     */
    open func getBaseUri() -> String {
        return baseUri!
    }

    /**
     Update the base URI of this node and all of its descendants.
     @param baseUri base URI to set
     */
    open func setBaseUri(_ baseUri: String)throws {
        class nodeVisitor: NodeVisitor {
            private let baseUri: String
            init(_ baseUri: String) {
                self.baseUri = baseUri
            }

            func head(_ node: Node, _ depth: Int)throws {
                node.baseUri = baseUri
            }

            func tail(_ node: Node, _ depth: Int)throws {
            }
        }
        try traverse(nodeVisitor(baseUri))
    }

    /**
     * Get an absolute URL from a URL attribute that may be relative (i.e. an <code>&lta href&gt;</code> or
     * <code>&lt;img src&gt;</code>).
     * <p>
     * E.g.: <code>String absUrl = linkEl.absUrl("href");</code>
     * </p>
     * <p>
     * If the attribute value is already absolute (i.e. it starts with a protocol, like
     * <code>http://</code> or <code>https://</code> etc), and it successfully parses as a URL, the attribute is
     * returned directly. Otherwise, it is treated as a URL relative to the element's {@link #baseUri}, and made
     * absolute using that.
     * </p>
     * <p>
     * As an alternate, you can use the {@link #attr} method with the <code>abs:</code> prefix, e.g.:
     * <code>String absUrl = linkEl.attr("abs:href");</code>
     * </p>
     *
     * @param attributeKey The attribute key
     * @return An absolute URL if one could be made, or an empty string (not null) if the attribute was missing or
     * could not be made successfully into a URL.
     * @see #attr
     * @see java.net.URL#URL(java.net.URL, String)
     */
    open func absUrl(_ attributeKey: String)throws->String {
        try Validate.notEmpty(string: attributeKey)

        if (!hasAttr(attributeKey)) {
            return Node.empty // nothing to make absolute with
        } else {
            return StringUtil.resolve(baseUri!, relUrl: try attr(attributeKey))
        }
    }

    /**
     Get a child node by its 0-based index.
     @param index index of child node
     @return the child node at this index. Throws a {@code IndexOutOfBoundsException} if the index is out of bounds.
     */
    open func childNode(_ index: Int) -> Node {
        return childNodes[index]
    }

    /**
     Get this node's children. Presented as an unmodifiable list: new children can not be added, but the child nodes
     themselves can be manipulated.
     @return list of children. If no children, returns an empty list.
     */
    open func getChildNodes()->Array<Node> {
        return childNodes
    }

    /**
     * Returns a deep copy of this node's children. Changes made to these nodes will not be reflected in the original
     * nodes
     * @return a deep copy of this node's children
     */
    open func childNodesCopy()->Array<Node> {
		var children: Array<Node> = Array<Node>()
		for node: Node in childNodes {
			children.append(node.copy() as! Node)
		}
		return children
    }

    /**
     * Get the number of child nodes that this node holds.
     * @return the number of child nodes that this node holds.
     */
    public func childNodeSize() -> Int {
        return childNodes.count
    }

    final func childNodesAsArray() -> [Node] {
        return childNodes as Array
    }

    /**
     Gets this node's parent node.
     @return parent node or null if no parent.
     */
    open func parent() -> Node? {
        return parentNode
    }

    /**
     Gets this node's parent node. Node overridable by extending classes, so useful if you really just need the Node type.
     @return parent node or null if no parent.
     */
    final func getParentNode() -> Node? {
        return parentNode
    }

    /**
     * Gets the Document associated with this Node.
     * @return the Document associated with this Node, or null if there is no such Document.
     */
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
     * Remove (delete) this node from the DOM tree. If this node has children, they are also removed.
     */
    open func remove()throws {
        try parentNode?.removeChild(self)
    }

    /**
     * Insert the specified HTML into the DOM before this node (i.e. as a preceding sibling).
     * @param html HTML to add before this node
     * @return this node, for chaining
     * @see #after(String)
     */
    @discardableResult
    open func before(_ html: String)throws->Node {
        try addSiblingHtml(siblingIndex, html)
        return self
    }

    /**
     * Insert the specified node into the DOM before this node (i.e. as a preceding sibling).
     * @param node to add before this node
     * @return this node, for chaining
     * @see #after(Node)
     */
    @discardableResult
    open func before(_ node: Node)throws ->Node {
        try Validate.notNull(obj: node)
        try Validate.notNull(obj: parentNode)

        try parentNode?.addChildren(siblingIndex, node)
        return self
    }

    /**
     * Insert the specified HTML into the DOM after this node (i.e. as a following sibling).
     * @param html HTML to add after this node
     * @return this node, for chaining
     * @see #before(String)
     */
    @discardableResult
    open func after(_ html: String)throws ->Node {
        try addSiblingHtml(siblingIndex + 1, html)
        return self
    }

    /**
     * Insert the specified node into the DOM after this node (i.e. as a following sibling).
     * @param node to add after this node
     * @return this node, for chaining
     * @see #before(Node)
     */
    @discardableResult
    open func after(_ node: Node)throws->Node {
        try Validate.notNull(obj: node)
        try Validate.notNull(obj: parentNode)

        try parentNode?.addChildren(siblingIndex+1, node)
        return self
    }

    private func addSiblingHtml(_ index: Int, _ html: String)throws {
        try Validate.notNull(obj: parentNode)

        let context: Element? = parent() as? Element

        let nodes: Array<Node> = try Parser.parseFragment(html, context, getBaseUri())
        try parentNode?.addChildren(index, nodes)
    }

    /**
     * Insert the specified HTML into the DOM after this node (i.e. as a following sibling).
     * @param html HTML to add after this node
     * @return this node, for chaining
     * @see #before(String)
     */
    @discardableResult
    open func after(html: String)throws->Node {
        try addSiblingHtml(siblingIndex + 1, html)
        return self
    }

    /**
     * Insert the specified node into the DOM after this node (i.e. as a following sibling).
     * @param node to add after this node
     * @return this node, for chaining
     * @see #before(Node)
     */
    @discardableResult
    open func after(node: Node)throws->Node {
        try Validate.notNull(obj: node)
        try Validate.notNull(obj: parentNode)

        try parentNode?.addChildren(siblingIndex + 1, node)
        return self
    }

    open func addSiblingHtml(index: Int, _ html: String)throws {
        try Validate.notNull(obj: html)
        try Validate.notNull(obj: parentNode)

        let context: Element? = parent() as? Element
        let nodes: Array<Node> = try Parser.parseFragment(html, context, getBaseUri())
        try parentNode?.addChildren(index, nodes)
    }

    /**
     Wrap the supplied HTML around this node.
     @param html HTML to wrap around this element, e.g. {@code <div class="head"></div>}. Can be arbitrarily deep.
     @return this node, for chaining.
     */
    @discardableResult
    open func wrap(_ html: String)throws->Node? {
        try Validate.notEmpty(string: html)

        let context: Element? = parent() as? Element
        var wrapChildren: Array<Node> = try Parser.parseFragment(html, context, getBaseUri())
        let wrapNode: Node? = wrapChildren.count > 0 ? wrapChildren[0] : nil
        if (wrapNode == nil || !(((wrapNode as? Element) != nil))) { // nothing to wrap with; noop
            return nil
        }

        let wrap: Element = wrapNode as! Element
        let deepest: Element = getDeepChild(el: wrap)
        try parentNode?.replaceChild(self, wrap)
		wrapChildren = wrapChildren.filter { $0 != wrap}
        try deepest.addChildren(self)

        // remainder (unbalanced wrap, like <div></div><p></p> -- The <p> is remainder
        if (wrapChildren.count > 0) {
            for i in  0..<wrapChildren.count {
                let remainder: Node = wrapChildren[i]
                try remainder.parentNode?.removeChild(remainder)
                try wrap.appendChild(remainder)
            }
        }
        return self
    }

    /**
     * Removes this node from the DOM, and moves its children up into the node's parent. This has the effect of dropping
     * the node but keeping its children.
     * <p>
     * For example, with the input html:
     * </p>
     * <p>{@code <div>One <span>Two <b>Three</b></span></div>}</p>
     * Calling {@code element.unwrap()} on the {@code span} element will result in the html:
     * <p>{@code <div>One Two <b>Three</b></div>}</p>
     * and the {@code "Two "} {@link TextNode} being returned.
     *
     * @return the first child of this node, after the node has been unwrapped. Null if the node had no children.
     * @see #remove()
     * @see #wrap(String)
     */
    @discardableResult
    open func unwrap()throws ->Node? {
        try Validate.notNull(obj: parentNode)

        let firstChild: Node? = childNodes.count > 0 ? childNodes[0] : nil
        try parentNode?.addChildren(siblingIndex, self.childNodesAsArray())
        try self.remove()

        return firstChild
    }

    private func getDeepChild(el: Element) -> Element {
        let children = el.children()
        if (children.size() > 0) {
            return getDeepChild(el: children.get(0))
        } else {
            return el
        }
    }

    /**
     * Replace this node in the DOM with the supplied node.
     * @param in the node that will will replace the existing node.
     */
    public func replaceWith(_ input: Node)throws {
        try Validate.notNull(obj: input)
        try Validate.notNull(obj: parentNode)
        try parentNode?.replaceChild(self, input)
    }

    public func setParentNode(_ parentNode: Node)throws {
        if (self.parentNode != nil) {
        try self.parentNode?.removeChild(self)
        }
        self.parentNode = parentNode
    }

    public func replaceChild(_ out: Node, _ input: Node)throws {
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
    }

    public func removeChild(_ out: Node)throws {
        try Validate.isTrue(val: out.parentNode === self)
        let index: Int = out.siblingIndex
        childNodes.remove(at: index)
        reindexChildren(index)
        out.parentNode = nil
    }

    public func addChildren(_ children: Node...)throws {
        //most used. short circuit addChildren(int), which hits reindex children and array copy
        try addChildren(children)
    }

    public func addChildren(_ children: [Node])throws {
        //most used. short circuit addChildren(int), which hits reindex children and array copy
        for child in children {
            try reparentChild(child)
            ensureChildNodes()
            childNodes.append(child)
            child.setSiblingIndex(childNodes.count-1)
        }
    }

    public func addChildren(_ index: Int, _ children: Node...)throws {
        try addChildren(index, children)
    }

    public func addChildren(_ index: Int, _ children: [Node])throws {
        ensureChildNodes()
        for i in (0..<children.count).reversed() {
            let input: Node = children[i]
            try reparentChild(input)
            childNodes.insert(input, at: index)
            reindexChildren(index)
        }
    }

    public func ensureChildNodes() {
//        if (childNodes === Node.EMPTY_NODES) {
//            childNodes = Array<Node>()
//        }
    }

    public func reparentChild(_ child: Node)throws {
        if (child.parentNode != nil) {
            try child.parentNode?.removeChild(child)
        }
        try child.setParentNode(self)
    }

    private func reindexChildren(_ start: Int) {
        for i in start..<childNodes.count {
            childNodes[i].setSiblingIndex(i)
        }
    }

    /**
     Retrieves this node's sibling nodes. Similar to {@link #childNodes()  node.parent.childNodes()}, but does not
     include this node (a node is not a sibling of itself).
     @return node siblings. If the node has no parent, returns an empty list.
     */
    open func siblingNodes()->Array<Node> {
        if (parentNode == nil) {
            return Array<Node>()
        }

        let nodes: Array<Node> = parentNode!.childNodes
        var siblings: Array<Node> = Array<Node>()
        for node in nodes {
            if (node !== self) {
                siblings.append(node)
            }
        }

        return siblings
    }

    /**
     Get this node's next sibling.
     @return next sibling, or null if this is the last sibling
     */
    open func nextSibling() -> Node? {
        guard let siblings: Array<Node> =  parentNode?.childNodes else{
            return nil
        }

        let index: Int = siblingIndex+1
        if (siblings.count > index) {
            return siblings[index]
        } else {
            return nil
        }
    }

    /**
     Get this node's previous sibling.
     @return the previous sibling, or null if this is the first sibling
     */
    open func previousSibling() -> Node? {
        if (parentNode == nil) {
            return nil // root
        }

        if (siblingIndex > 0) {
            return parentNode?.childNodes[siblingIndex-1]
        } else {
            return nil
        }
    }

    public func setSiblingIndex(_ siblingIndex: Int) {
        self.siblingIndex = siblingIndex
    }

    /**
     * Perform a depth-first traversal through this node and its descendants.
     * @param nodeVisitor the visitor callbacks to perform on each node
     * @return this node, for chaining
     */
    @discardableResult
    open func traverse(_ nodeVisitor: NodeVisitor)throws->Node {
        let traversor: NodeTraversor = NodeTraversor(nodeVisitor)
        try traversor.traverse(self)
        return self
    }

    /**
     Get the outer HTML of this node.
     @return HTML
     */
    open func outerHtml()throws->String {
        let accum: StringBuilder = StringBuilder(128)
        try outerHtml(accum)
        return accum.toString()
    }

    public func outerHtml(_ accum: StringBuilder)throws {
        try NodeTraversor(OuterHtmlVisitor(accum, getOutputSettings())).traverse(self)
    }

    // if this node has no document (or parent), retrieve the default output settings
    func getOutputSettings() -> OutputSettings {
        return ownerDocument() != nil ? ownerDocument()!.outputSettings() : (Document(Node.empty)).outputSettings()
    }

    /**
     Get the outer HTML of this node.
     @param accum accumulator to place HTML into
     @throws IOException if appending to the given accumulator fails.
     */
    func outerHtmlHead(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
        preconditionFailure("This method must be overridden")
    }

    func outerHtmlTail(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) throws {
        preconditionFailure("This method must be overridden")
    }

    /**
     * Write this node and its children to the given {@link Appendable}.
     *
     * @param appendable the {@link Appendable} to write to.
     * @return the supplied {@link Appendable}, for chaining.
     */
    open func html(_ appendable: StringBuilder)throws -> StringBuilder {
        try outerHtml(appendable)
        return appendable
    }

    public func indent(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings) {
        accum.append(UnicodeScalar.BackslashN).append(StringUtil.padding(depth * Int(out.indentAmount())))
    }

    /**
     * Check if this node is the same instance of another (object identity test).
     * @param o other object to compare to
     * @return true if the content of this node is the same as the other
     * @see Node#hasSameValue(Object) to compare nodes by their value
     */

    open func equals(_ o: Node) -> Bool {
    // implemented just so that javadoc is clear this is an identity test
        return self === o
    }

    /**
     * Check if this node is has the same content as another node. A node is considered the same if its name, attributes and content match the
     * other node; particularly its position in the tree does not influence its similarity.
     * @param o other object to compare to
     * @return true if the content of this node is the same as the other
     */

    open func hasSameValue(_ o: Node)throws->Bool {
        if (self === o) {return true}
//        if (type(of:self) != type(of: o))
//        {
//            return false
//        }

        return try self.outerHtml() ==  o.outerHtml()
    }

    /**
     * Create a stand-alone, deep copy of this node, and all of its children. The cloned node will have no siblings or
     * parent node. As a stand-alone object, any changes made to the clone or any of its children will not impact the
     * original node.
     * <p>
     * The cloned node may be adopted into another Document or node structure using {@link Element#appendChild(Node)}.
     * @return stand-alone cloned node
     */
    public func copy(with zone: NSZone? = nil) -> Any {
		return copy(clone: Node())
    }

	public func copy(parent: Node?) -> Node {
		let clone = Node()
		return copy(clone: clone, parent: parent)
	}

	public func copy(clone: Node) -> Node {
		let thisClone: Node = copy(clone: clone, parent: nil) // splits for orphan

		// Queue up nodes that need their children cloned (BFS).
		var nodesToProcess: Array<Node> = Array<Node>()
		nodesToProcess.append(thisClone)

		while (!nodesToProcess.isEmpty) {
			let currParent: Node = nodesToProcess.removeFirst()

			for i in 0..<currParent.childNodes.count {
				let childClone: Node = currParent.childNodes[i].copy(parent:currParent)
				currParent.childNodes[i] = childClone
				nodesToProcess.append(childClone)
			}
		}
		return thisClone
	}

	/*
	* Return a clone of the node using the given parent (which can be null).
	* Not a deep copy of children.
	*/
	public func copy(clone: Node, parent: Node?) -> Node {
		clone.parentNode = parent // can be null, to create an orphan split
		clone.siblingIndex = parent == nil ? 0 : siblingIndex
		clone.attributes = attributes != nil ? attributes?.clone() : nil
		clone.baseUri = baseUri
		clone.childNodes = Array<Node>()

		for  child in childNodes {
			clone.childNodes.append(child)
		}

		return clone
	}

    private class OuterHtmlVisitor: NodeVisitor {
        private var accum: StringBuilder
        private var out: OutputSettings
        static private let  text = "#text"

        init(_ accum: StringBuilder, _ out: OutputSettings) {
            self.accum = accum
            self.out = out
        }

        open func head(_ node: Node, _ depth: Int)throws {

            try node.outerHtmlHead(accum, depth, out)
        }

        open func tail(_ node: Node, _ depth: Int)throws {
            if (!(node.nodeName() == OuterHtmlVisitor.text)) { // saves a void hit.
                try node.outerHtmlTail(accum, depth, out)
            }
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
    public static func ==(lhs: Node, rhs: Node) -> Bool {
        return lhs === rhs
    }

	/// The hash value.
	///
	/// Hash values are not guaranteed to be equal across different executions of
	/// your program. Do not save hash values to use during a future execution.
	public var hashValue: Int {
		return description.hashValue ^ (baseUri?.hashValue ?? 31)
	}

}

extension Node : CustomStringConvertible {
	public var description: String {
		do {
			return try outerHtml()
		} catch {

		}
		return Node.empty
	}
}

extension Node : CustomDebugStringConvertible {
    private static let space = " "
	public var debugDescription: String {
		do {
            return try String(describing: type(of: self)) + Node.space + outerHtml()
		} catch {

		}
		return String(describing: type(of: self))
	}
}
