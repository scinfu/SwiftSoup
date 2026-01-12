//
//  Node.swift
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
    @usableFromInline
    internal var _attributes: Attributes?

#if canImport(CLibxml2) || canImport(libxml2)
    @usableFromInline
    internal var libxml2NodePtr: xmlNodePtr? = nil
    @usableFromInline
    internal var libxml2DirtySuppressionCount: Int = 0
    @usableFromInline
    internal var libxml2ChildrenHydrated: Bool = false
    @usableFromInline
    internal var libxml2AttributesHydrated: Bool = false
    @usableFromInline
    internal var libxml2Context: Libxml2DocumentContext? = nil
#endif

    @inline(__always)
    internal func ensureAttributesForWrite() -> Attributes {
#if canImport(CLibxml2) || canImport(libxml2)
        if let element = self as? Element,
           let doc = ownerDocument(),
           doc.libxml2Only {
            Libxml2Backend.hydrateAttributesIfNeeded(element)
        }
#endif
        if let attributes {
            return attributes
        }
        let created = Attributes()
        if let element = self as? Element {
            created.ownerElement = element
        }
        attributes = created
        return created
    }
    
    @usableFromInline
    internal var sourceRange: SourceRange? = nil
    
    @usableFromInline
    internal var sourceRangeIsComplete: Bool = false
    
    @usableFromInline
    internal var sourceRangeDirty: Bool = false
    
    @usableFromInline
    internal var sourceBuffer: SourceBuffer? = nil
    
    @usableFromInline
    weak var parentNode: Node? {
        @inline(__always)
        didSet {
            guard let element = self as? Element, oldValue !== parentNode else { return }
            if element.suppressQueryIndexDirty {
                return
            }
            if element.treeBuilder?.isBulkBuilding == true {
                return
            }
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
    internal var _childNodes: [Node]

    @inline(__always)
    @usableFromInline
    internal var attributes: Attributes? {
        get {
#if canImport(CLibxml2) || canImport(libxml2)
            if let doc = ownerDocument(), doc.libxml2Only {
                if let element = self as? Element {
                    Libxml2Backend.hydrateAttributesIfNeeded(element)
                }
            } else if libxml2Context != nil {
                if let element = self as? Element {
                    Libxml2Backend.hydrateAttributesIfNeeded(element)
                }
            } else {
                ensureLibxml2TreeIfNeeded()
            }
#endif
            return _attributes
        }
        set {
            _attributes = newValue
#if canImport(CLibxml2) || canImport(libxml2)
            if newValue != nil {
                libxml2AttributesHydrated = true
            }
#endif
        }
    }

    @inline(__always)
    @usableFromInline
    internal var childNodes: [Node] {
        get {
#if canImport(CLibxml2) || canImport(libxml2)
            if let doc = ownerDocument(), doc.libxml2Only {
                Libxml2Backend.hydrateChildrenIfNeeded(self)
            } else if libxml2Context != nil {
                Libxml2Backend.hydrateChildrenIfNeeded(self)
            } else {
                ensureLibxml2TreeIfNeeded()
            }
#endif
            return _childNodes
        }
        set {
            _childNodes = newValue
#if canImport(CLibxml2) || canImport(libxml2)
            libxml2ChildrenHydrated = true
#endif
        }
    }
    
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
    
    @inline(__always)
    private static func hasAbsPrefix(_ key: [UInt8]) -> Bool {
        if key.count < absCount { return false }
        for i in 0..<absCount {
            let b = key[i]
            let lower = (b >= 65 && b <= 90) ? b + 32 : b
            if lower != abs[i] {
                return false
            }
        }
        return true
    }
    
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
        self._childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        self.baseUri = baseUri.trim()
        self._attributes = attributes
    }

    public init(
        _ baseUri: [UInt8],
        attributes: Attributes?,
        skipChildReserve: Bool = false
    ) {
        _childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        self.baseUri = baseUri.trim()
        self._attributes = attributes
    }
    
    public init(
        _ baseUri: [UInt8],
        skipChildReserve: Bool = false
    ) {
        _childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        self.baseUri = baseUri.trim()
        self._attributes = nil
    }
    
    /**
     Default constructor. Doesn't setup base uri, children, or attributes; use with caution.
     */
    public init(
        skipChildReserve: Bool = false
    ) {
        self._childNodes = []
        if !skipChildReserve && self is Element || self is DocumentType {
            childNodes.reserveCapacity(32)
        }
        
        self._attributes = nil
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
        guard let attributes = attributes else {
            if Node.hasAbsPrefix(attributeKey) {
                return try absUrl(attributeKey.substring(Node.abs.count))
            }
            return Node.empty
        }
        let val: [UInt8] = try attributes.getIgnoreCase(key: attributeKey)
        if !val.isEmpty {
            return val
        } else if Node.hasAbsPrefix(attributeKey) {
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
        try ensureAttributesForWrite().put(attributeKey, attributeValue)
        markSourceDirty()
        return self
    }
    
    @discardableResult
    open func attr(_ attributeKey: String, _ attributeValue: String) throws -> Node {
        try ensureAttributesForWrite().put(attributeKey, attributeValue)
        markSourceDirty()
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
        markSourceDirty()
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
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = ownerDocument(), !doc.libxml2Only {
            ensureLibxml2TreeIfNeeded()
        }
#endif
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
        if let this = self as? Document {
            return this
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if let doc = libxml2Context?.document {
            return doc
        }
#endif
        var current = parentNode
        var seen = Set<ObjectIdentifier>()
        while let node = current {
            if let doc = node as? Document {
                return doc
            }
            let id = ObjectIdentifier(node)
            if seen.contains(id) {
                return nil
            }
            seen.insert(id)
            current = node.parentNode
        }
        return nil
    }

    /// A token that changes when text content in this node's tree mutates.
    /// Use this to invalidate external caches that depend on text content.
    @inline(__always)
    public func textMutationVersionToken() -> Int {
        var node: Node = self
        while let parent = node.parentNode {
            node = parent
        }
        return node.textMutationVersion
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

    @inline(__always)
    @usableFromInline
    internal func markSourceDirty(force: Bool = false) {
#if canImport(CLibxml2) || canImport(libxml2)
        markLibxml2Dirty()
#endif
        if sourceRangeDirty {
            return
        }
        if !force, treeBuilder?.isBulkBuilding == true {
            return
        }
        sourceRangeDirty = true
        parentNode?.markSourceDirty(force: force)
    }

#if canImport(CLibxml2) || canImport(libxml2)
    @inline(__always)
    @usableFromInline
    internal func ensureLibxml2TreeIfNeeded() {
        guard let doc = ownerDocument(), doc.libxml2LazyState != nil else { return }
        doc.ensureLibxml2TreeIfNeeded()
    }

    @inline(__always)
    @usableFromInline
    internal func markLibxml2Dirty() {
        if treeBuilder?.isBulkBuilding == true {
            return
        }
        if libxml2DirtySuppressionCount > 0 {
            return
        }
        guard let doc = ownerDocument(), doc.libxml2DocPtr != nil else { return }
        doc.libxml2BackedDirty = true
    }

    @inline(__always)
    private func linkFormControlsIfNeeded(_ node: Node) {
        guard let doc = ownerDocument(), doc.libxml2Preferred else { return }
        var cursor: Node? = self
        var form: FormElement? = nil
        while let current = cursor {
            if let found = current as? FormElement {
                form = found
                break
            }
            cursor = current.parentNode
        }
        guard let form else { return }
        addFormControls(from: node, to: form)
    }

    private func addFormControls(from node: Node, to form: FormElement) {
        if let element = node as? Element, element.tag().isFormListed() {
            let existing = form.elements().array()
            if !existing.contains(element) {
                _ = form.addElement(element)
            }
        }
        let children = node._childNodes
        if !children.isEmpty {
            for child in children {
                addFormControls(from: child, to: form)
            }
        }
    }

    @inline(__always)
    @usableFromInline
    internal func withLibxml2DirtySuppressed<T>(_ body: () throws -> T) rethrows -> T {
        libxml2DirtySuppressionCount += 1
        defer { libxml2DirtySuppressionCount -= 1 }
        return try body()
    }

    @inline(__always)
    @usableFromInline
    internal func libxml2CanSyncContent() -> Bool {
        return libxml2NodePtr != nil && ownerDocument()?.libxml2DocPtr != nil
    }

    @inline(__always)
    @usableFromInline
    internal func libxml2SetNodeContent(_ bytes: [UInt8]) {
        guard let nodePtr = libxml2NodePtr else { return }
        guard ownerDocument()?.libxml2DocPtr != nil else { return }
        var content = bytes
        content.append(0)
        content.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return }
            base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                xmlNodeSetContent(nodePtr, ptr)
            }
        }
    }

    @inline(__always)
    @usableFromInline
    internal func libxml2ClearNodePtrRecursive() {
        libxml2NodePtr = nil
        for child in childNodes {
            child.libxml2ClearNodePtrRecursive()
        }
    }

#if canImport(CLibxml2) || canImport(libxml2)
    @inline(__always)
    @usableFromInline
    internal func removeLibxml2OverridesRecursive(in doc: Document) {
        if let nodePtr = libxml2NodePtr {
            let key = UnsafeMutableRawPointer(nodePtr)
            doc.libxml2AttributeOverrides?[key] = nil
            doc.libxml2TagNameOverrides?[key] = nil
            doc.libxml2Context?.attributeOverrides?[key] = nil
            doc.libxml2Context?.tagNameOverrides?[key] = nil
        }
        for child in childNodes {
            child.removeLibxml2OverridesRecursive(in: doc)
        }
    }
#endif

    @inline(__always)
    @discardableResult
    @usableFromInline
    internal func libxml2DetachAndFreeIfPossible() -> Bool {
        guard let nodePtr = libxml2NodePtr else { return false }
        guard let doc = ownerDocument(), doc.libxml2DocPtr != nil else { return false }
        removeLibxml2OverridesRecursive(in: doc)
        xmlUnlinkNode(nodePtr)
        xmlFreeNode(nodePtr)
        libxml2ClearNodePtrRecursive()
        return true
    }

    @inline(__always)
    @usableFromInline
    internal func libxml2EnsureNode(in doc: Document) -> xmlNodePtr? {
        if let existing = libxml2NodePtr {
            return existing
        }
        guard doc.libxml2DocPtr != nil else { return nil }
        if let element = self as? Element {
            guard let nodePtr = element.libxml2CreateNode() else { return nil }
            element.libxml2NodePtr = nodePtr
            if let attrs = element.attributes {
                for attr in attrs.asList() {
                    let key = attr.getKeyUTF8()
                    let value = attr.getValueUTF8()
                    let isBoolean = attr.isBooleanAttribute()
                    element.libxml2SyncAttribute(key: key, value: value, isBoolean: isBoolean)
                }
            }
            for child in element.childNodes {
                if let childPtr = child.libxml2EnsureNode(in: doc) {
                    xmlAddChild(nodePtr, childPtr)
                }
            }
            return nodePtr
        }
        if let text = self as? TextNode {
            let bytes = text.getWholeTextUTF8()
            return bytes.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return nil }
                return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                    let nodePtr = xmlNewTextLen(ptr, Int32(buf.count))
                    text.libxml2NodePtr = nodePtr
                    if let nodePtr {
                        nodePtr.pointee._private = Unmanaged.passUnretained(text).toOpaque()
                    }
                    return nodePtr
                }
            }
        }
        if let data = self as? DataNode {
            let bytes = data.getWholeDataUTF8()
            return bytes.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return nil }
                return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                    let nodePtr = xmlNewTextLen(ptr, Int32(buf.count))
                    data.libxml2NodePtr = nodePtr
                    if let nodePtr {
                        nodePtr.pointee._private = Unmanaged.passUnretained(data).toOpaque()
                    }
                    return nodePtr
                }
            }
        }
        if let comment = self as? Comment {
            var bytes = comment.getDataUTF8()
            bytes.append(0)
            return bytes.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return nil }
                return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                    let nodePtr = xmlNewComment(ptr)
                    comment.libxml2NodePtr = nodePtr
                    if let nodePtr {
                        nodePtr.pointee._private = Unmanaged.passUnretained(comment).toOpaque()
                    }
                    return nodePtr
                }
            }
        }
        if let decl = self as? XmlDeclaration {
            var nameBytes = decl.name().utf8Array
            nameBytes.append(0)
            let nodePtr: xmlNodePtr? = nameBytes.withUnsafeBufferPointer { buf in
                guard let base = buf.baseAddress else { return nil }
                return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                    xmlNewPI(ptr, nil)
                }
            }
            if let nodePtr, let attrs = decl.attributes {
                decl.libxml2NodePtr = nodePtr
                nodePtr.pointee._private = Unmanaged.passUnretained(decl).toOpaque()
                let attribs = attrs.asList()
                if !attribs.isEmpty {
                    var pairs: [String] = []
                    pairs.reserveCapacity(attribs.count)
                    for attr in attribs {
                        let key = String(decoding: attr.getKeyUTF8(), as: UTF8.self)
                        let value = String(decoding: attr.getValueUTF8(), as: UTF8.self)
                        pairs.append("\(key)=\"\(value)\"")
                    }
                    let joined = pairs.joined(separator: " ")
                    var content = joined.utf8Array
                    content.append(0)
                    content.withUnsafeBufferPointer { buf in
                        guard let base = buf.baseAddress else { return }
                        base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                            xmlNodeSetContent(nodePtr, ptr)
                        }
                    }
                }
            }
            return nodePtr
        }
        // DocumentType is backed by xmlDtd (xmlDtdPtr), not xmlNodePtr. Skip for now.
        return nil
    }
#endif

    @inline(__always)
    @usableFromInline
    internal func setSourceRange(_ range: SourceRange, complete: Bool) {
        sourceRange = range
        sourceRangeIsComplete = complete
        sourceRangeDirty = false
    }

    @inline(__always)
    @usableFromInline
    internal func setSourceRangeEnd(_ end: Int) {
        guard var range = sourceRange else { return }
        range.end = end
        sourceRange = range
        sourceRangeIsComplete = true
        sourceRangeDirty = false
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
#if canImport(CLibxml2) || canImport(libxml2)
        var didSyncLibxml2 = false
        if let doc = ownerDocument(),
           doc.libxml2DocPtr != nil,
           let outPtr = out.libxml2NodePtr,
           out.ownerDocument() === doc,
           input.ownerDocument() === doc {
            let inputPtr = input.libxml2NodePtr ?? input.libxml2EnsureNode(in: doc)
            if let inputPtr {
                if input.libxml2NodePtr != nil {
                    xmlUnlinkNode(inputPtr)
                }
                xmlReplaceNode(outPtr, inputPtr)
                didSyncLibxml2 = true
                out.removeLibxml2OverridesRecursive(in: doc)
                xmlFreeNode(outPtr)
                out.libxml2ClearNodePtrRecursive()
            }
        }
#endif
        childNodes[index] = input
        input.parentNode = self
        input.setSiblingIndex(index)
        out.parentNode = nil
#if canImport(CLibxml2) || canImport(libxml2)
        if didSyncLibxml2 {
            withLibxml2DirtySuppressed {
                out.withLibxml2DirtySuppressed {
                    input.withLibxml2DirtySuppressed {
                        markSourceDirty()
                        out.markSourceDirty()
                        input.markSourceDirty()
                    }
                }
            }
        } else {
            markSourceDirty()
            out.markSourceDirty()
            input.markSourceDirty()
        }
#else
        markSourceDirty()
        out.markSourceDirty()
        input.markSourceDirty()
#endif
        if (out is Element) || (input is Element), let element = self as? Element {
            element.markQueryIndexesDirty()
        }
        bumpTextMutationVersion()
    }
    
    @inlinable
    public func removeChild(_ out: Node) throws {
        try Validate.isTrue(val: out.parentNode === self)
        let index: Int = out.siblingIndex
#if canImport(CLibxml2) || canImport(libxml2)
        var didSyncLibxml2 = false
        if let _ = ownerDocument()?.libxml2DocPtr,
           libxml2NodePtr != nil,
           out.ownerDocument() === ownerDocument(),
           out.libxml2DetachAndFreeIfPossible() {
            didSyncLibxml2 = true
        }
#endif
        childNodes.remove(at: index)
        reindexChildren(index)
        out.parentNode = nil
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
        #if canImport(CLibxml2) || canImport(libxml2)
        let parentPtr = libxml2NodePtr
        let doc = ownerDocument()
        let canSyncLibxml2 = parentPtr != nil && doc?.libxml2DocPtr != nil
        var didSyncAll = canSyncLibxml2
        #endif
        for child in children {
            try reparentChild(child)
#if canImport(CLibxml2) || canImport(libxml2)
            if canSyncLibxml2, let parentPtr, let doc, child.ownerDocument() === doc {
                let childPtr = child.libxml2NodePtr ?? child.libxml2EnsureNode(in: doc)
                if let childPtr {
                    if child.libxml2NodePtr != nil {
                        xmlUnlinkNode(childPtr)
                    }
                    xmlAddChild(parentPtr, childPtr)
                } else {
                    didSyncAll = false
                }
            } else {
                didSyncAll = false
            }
#endif
            childNodes.append(child)
            child.setSiblingIndex(childNodes.count - 1)
#if canImport(CLibxml2) || canImport(libxml2)
            if doc?.libxml2Preferred == true {
                linkFormControlsIfNeeded(child)
            }
#endif
#if canImport(CLibxml2) || canImport(libxml2)
            if didSyncAll {
                child.withLibxml2DirtySuppressed {
                    child.markSourceDirty()
                }
            } else {
                child.markSourceDirty()
            }
#else
            child.markSourceDirty()
#endif
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if didSyncAll {
            withLibxml2DirtySuppressed {
                markSourceDirty()
            }
        } else {
            markSourceDirty()
        }
#else
        markSourceDirty()
#endif
        bumpTextMutationVersion()
    }
    
    @inline(__always)
    public func addChildren(_ index: Int, _ children: Node...) throws {
        try addChildren(index, children)
    }
    
    @inline(__always)
    public func addChildren(_ index: Int, _ children: [Node]) throws {
        #if canImport(CLibxml2) || canImport(libxml2)
        let parentPtr = libxml2NodePtr
        let doc = ownerDocument()
        let canSyncLibxml2 = parentPtr != nil && doc?.libxml2DocPtr != nil
        let refNodePtr = (index >= 0 && index < childNodes.count) ? childNodes[index].libxml2NodePtr : nil
        var didSyncAll = canSyncLibxml2
        #endif
        for input in children.reversed() {
            try reparentChild(input)
            childNodes.insert(input, at: index)
            reindexChildren(index)
#if canImport(CLibxml2) || canImport(libxml2)
            if doc?.libxml2Preferred == true {
                linkFormControlsIfNeeded(input)
            }
#endif
#if canImport(CLibxml2) || canImport(libxml2)
            if canSyncLibxml2, let parentPtr, let doc, input.ownerDocument() === doc {
                let childPtr = input.libxml2NodePtr ?? input.libxml2EnsureNode(in: doc)
                if let childPtr {
                    if input.libxml2NodePtr != nil {
                        xmlUnlinkNode(childPtr)
                    }
                    if let refNodePtr {
                        xmlAddPrevSibling(refNodePtr, childPtr)
                    } else {
                        xmlAddChild(parentPtr, childPtr)
                    }
                } else {
                    didSyncAll = false
                }
            } else {
                didSyncAll = false
            }
            if didSyncAll {
                input.withLibxml2DirtySuppressed {
                    input.markSourceDirty()
                }
            } else {
                input.markSourceDirty()
            }
#else
            input.markSourceDirty()
#endif
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if didSyncAll {
            withLibxml2DirtySuppressed {
                markSourceDirty()
            }
        } else {
            markSourceDirty()
        }
#else
        markSourceDirty()
#endif
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
        guard let parent = parentNode else {
            return nil
        }
        let nextIndex = siblingIndex + 1
        let siblings = parent.childNodes
        guard nextIndex < siblings.count else {
            return nil
        }
        return siblings[nextIndex]
    }
    
    @inline(__always)
    open func hasNextSibling() -> Bool {
        guard let parent = parentNode else {
            return false
        }
        return parent.childNodes.count > siblingIndex + 1
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
        try outerHtmlFast(accum, 0, getOutputSettings(), allowRawSource: true)
    }

    @inline(__always)
    @usableFromInline
    internal func outerHtmlUTF8Internal() throws -> [UInt8] {
        return try outerHtmlUTF8Internal(getOutputSettings(), allowRawSource: true)
    }

    @inline(__always)
    @usableFromInline
    internal func outerHtmlUTF8Internal(_ out: OutputSettings, allowRawSource: Bool) throws -> [UInt8] {
#if canImport(CLibxml2) || canImport(libxml2)
        let hasOverrides = (ownerDocument()?.libxml2AttributeOverrides?.isEmpty == false)
        if Libxml2Serialization.enabled,
           let nodePtr = libxml2NodePtr,
           let doc = ownerDocument(),
           let docPtr = doc.libxml2DocPtr,
           !doc.libxml2BackedDirty,
           out.syntax() == .html,
           !out.prettyPrint(),
           !hasOverrides,
           let dumped = Libxml2Serialization.htmlDump(node: nodePtr, doc: docPtr) {
            return dumped
        }
#endif
        let accum = StringBuilder(128)
        try outerHtmlFast(accum, 0, out, allowRawSource: allowRawSource)
        return Array(accum.buffer)
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

    @inline(__always)
    private func rawSourceSlice(_ out: OutputSettings, allowRawSource: Bool) -> ArraySlice<UInt8>? {
        guard allowRawSource,
              !out.prettyPrint(),
              !sourceRangeDirty,
              sourceRangeIsComplete,
              let range = sourceRange,
              range.isValid,
              let doc = ownerDocument(),
              let source = sourceBuffer?.bytes ?? doc.sourceBuffer?.bytes
        else {
            return nil
        }
        let syntax = out.syntax()
        if syntax == .xml && !doc.parsedAsXml {
            return nil
        }
        if syntax == .html || syntax == .xml {
            // ok
        } else {
            return nil
        }
        if range.end > source.count {
            return nil
        }
        return source[range.start..<range.end]
    }

    @inline(__always)
    @usableFromInline
    internal func sourceSliceUTF8() -> ArraySlice<UInt8>? {
        guard let range = sourceRange,
              range.isValid,
              let source = sourceBuffer?.bytes ?? ownerDocument()?.sourceBuffer?.bytes,
              range.end <= source.count
        else {
            return nil
        }
        return source[range.start..<range.end]
    }

    @inline(__always)
    private func outerHtmlFast(_ accum: StringBuilder, _ depth: Int, _ out: OutputSettings, allowRawSource: Bool) throws {
        if let raw = rawSourceSlice(out, allowRawSource: allowRawSource) {
            accum.append(raw)
            return
        }
        try outerHtmlHead(accum, depth, out)
        if !childNodes.isEmpty {
            for child in childNodes {
                try child.outerHtmlFast(accum, depth + 1, out, allowRawSource: allowRawSource)
            }
        }
        try outerHtmlTail(accum, depth, out)
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

    /// Internal shallow clone used by deep-copy to avoid copying childNodes.
    @inline(__always)
    func copyForDeepClone(parent: Node?) -> Node {
        let clone = Node(skipChildReserve: !hasChildNodes())
        return copy(clone: clone, parent: parent, copyChildren: false, rebuildIndexes: false, suppressQueryIndexDirty: true)
    }
    
    public func copy(clone: Node) -> Node {
        let thisClone = copy(clone: clone, parent: nil, copyChildren: true, rebuildIndexes: false, suppressQueryIndexDirty: false) // splits for orphan
        
        // BFS clone using index-based queue, preserving original nodes to avoid extra array copies.
        var queue: [(Node, Node)] = [(self, thisClone)]
        queue.reserveCapacity(8)
        var idx = 0
        while idx < queue.count {
            let (originalParent, cloneParent) = queue[idx]
            idx += 1
            
            let originalChildren = originalParent.childNodes
            if !originalChildren.isEmpty {
                var newChildren: [Node] = []
                newChildren.reserveCapacity(originalChildren.count)
                for child in originalChildren {
                    let childClone = child.copyForDeepClone(parent: cloneParent)
                    newChildren.append(childClone)
                    if child.hasChildNodes() {
                        queue.append((child, childClone))
                    }
                }
                cloneParent.childNodes = newChildren
            } else {
                cloneParent.childNodes.removeAll(keepingCapacity: true)
            }
        }
        
        return thisClone
    }
    
    /**
     * Return a clone of the node using the given parent (which can be `nil`).
     * Not a deep copy of children.
     */
    public func copy(clone: Node, parent: Node?) -> Node {
        return copy(clone: clone, parent: parent, copyChildren: true, rebuildIndexes: true, suppressQueryIndexDirty: false)
    }

    @inline(__always)
    func copy(clone: Node, parent: Node?, copyChildren: Bool, rebuildIndexes: Bool) -> Node {
        return copy(clone: clone, parent: parent, copyChildren: copyChildren, rebuildIndexes: rebuildIndexes, suppressQueryIndexDirty: false)
    }

    @inline(__always)
    func copy(
        clone: Node,
        parent: Node?,
        copyChildren: Bool,
        rebuildIndexes: Bool,
        suppressQueryIndexDirty: Bool
    ) -> Node {
        if suppressQueryIndexDirty, let element = clone as? Element {
            element.suppressQueryIndexDirty = true
        }
        clone.parentNode = parent // can be nil, to create an orphan split
        if suppressQueryIndexDirty, let element = clone as? Element {
            element.suppressQueryIndexDirty = false
        }
        clone.siblingIndex = parent == nil ? 0 : siblingIndex
        if let attrs = attributes {
            if attrs.size() == 0 {
                clone.attributes = Attributes()
            } else {
                clone.attributes = attrs.clone()
            }
            clone.attributes?.ownerElement = clone as? SwiftSoup.Element
        } else {
            clone.attributes = nil
        }
        clone.baseUri = baseUri
        if copyChildren {
            clone.childNodes = childNodes
        } else {
            clone.childNodes.removeAll(keepingCapacity: true)
        }
        clone.sourceRange = nil
        clone.sourceRangeIsComplete = false
        clone.sourceRangeDirty = true
        clone.sourceBuffer = nil

        if rebuildIndexes, let cloneElement = clone as? Element {
            cloneElement.rebuildQueryIndexesForThisNodeOnly()
        }

        return clone
    }

    @inline(__always)
    func copy(clone: Node, parent: Node?, copyChildren: Bool) -> Node {
        return copy(clone: clone, parent: parent, copyChildren: copyChildren, rebuildIndexes: true, suppressQueryIndexDirty: false)
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
