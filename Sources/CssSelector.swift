//
//  CssSelector.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 21/10/16.
//

import Foundation
#if canImport(CLibxml2) || canImport(libxml2)
#if canImport(CLibxml2)
@preconcurrency import CLibxml2
#elseif canImport(libxml2)
@preconcurrency import libxml2
#endif
#endif


@available(*, deprecated, renamed: "CssSelector")
typealias Selector = CssSelector

/**
 CSS-like element selector, that finds elements matching a query.
 
 # CssSelector syntax
 
 A selector is a chain of simple selectors, separated by combinators. Selectors are **case insensitive** (including against
 elements, attributes, and attribute values).
 
 The universal selector (`*`) is implicit when no element selector is supplied (i.e. `*.header` and `.header`
 are equivalent).
 
 Pattern | Matches | Example
 --------|---------|---------
 `*`     | any element | `*`
 `tag`   | elements with the given tag name | `div`
 `*\|E`  | elements of type E in any namespace _ns_ | `*\|name` finds `<fb:name>` elements
 `#id`   | elements with attribute ID of "id" | `div#wrap`, `#logo`
 `.class` | elements with a class name of "class" | `div.left`, `.result`
 `.class` | elements with a class name of "class" | `div.left`, `.result`
 `[attr]` | elements with an attribute named "attr" (with any value) | `a[href]`, `[title]`
 `[^attrPrefix]` | elements with an attribute name starting with "attrPrefix". Use to find elements with HTML5 datasets | `[^data-]`, `div[^data-]`
 `[attr=val]` | elements with an attribute named "attr", and value equal to "val" | `img[width=500]`, `a[rel=nofollow]`
 `[attr="val"]` | elements with an attribute named "attr", and value equal to "val" | `span[hello="Cleveland"][goodbye="Columbus"]`, `a[rel="nofollow"]`
 `[attr^=valPrefix]` | elements with an attribute named "attr", and value starting with "valPrefix" | `a[href^=http:]`
 `[attr$=valSuffix]` | elements with an attribute named "attr", and value ending with "valSuffix" | `img[src$=.png]`
 `[attr*=valContaining]` | elements with an attribute named "attr", and value containing "valContaining" | `a[href*=/search/]`
 `[attr~=regex]` | elements with an attribute named "attr", and value matching the regular expression | `img[src~=(?i)\\.(png|jpe?g)]`
 | | The above may be combined in any order | `div.header[title]`
 **Combinators** |||
 `E F`   | an F element descended from an E element | `div a`, `.logo h1`
 `E > F` | an F direct child of E | `ol > li`
 `E + F` | an F element immediately preceded by sibling E | `li + li`, `div.head + div`
 `E ~ F` | an F element preceded by sibling E | `h1 ~ p`
 `E, F, G` | all matching elements E, F, or G | `a[href], div, h3`
 **Pseudo selectors** |||
 `:lt(n)` | elements whose sibling index is less than _n_ | `td:lt(3)` finds the first 3 cells of each row
 `:gt(n)` | elements whose sibling index is greater than _n_ | `td:gt(1)` finds cells after skipping the first two
 `:eq(n)` | elements whose sibling index is equal to _n_ | `td:eq(0)` finds the first cell of each row
 `:has(selector)` | elements that contains at least one element matching the _selector_ | `div:has(p)` finds divs that contain p elements
 `:not(selector)` | elements that do not match the _selector_. See also ``Elements/not(_:)-(String)`` | `div:not(.logo)` finds all divs that do not have the "logo" class. `div:not(:has(div))` finds divs that do not contain divs.
 `:contains(text)` | elements that contains the specified text. The search is case insensitive. The text may appear in the found element, or any of its descendants. | `p:contains(SwiftSoup)` finds p elements containing the text "SwiftSoup".
 `:matches(regex)` | elements whose text matches the specified regular expression. The text may appear in the found element, or any of its descendants. | `td:matches(\\d+)` finds table cells containing digits. `div:matches((?i)login)` finds divs containing the text, case insensitively.
 `:containsOwn(text)` | elements that directly contain the specified text. The search is case insensitive. The text must appear in the found element, not any of its descendants. | `p:containsOwn(SwiftSoup)` finds p elements with own text "SwiftSoup".
 `:matchesOwn(regex)` | elements whose own text matches the specified regular expression. The text must appear in the found element, not any of its descendants. | `td:matchesOwn(\\d+)` finds table cells directly containing digits. `div:matchesOwn((?i)login)` finds divs containing the text, case insensitively.
 | | The above may be combined in any order and with other selectors | `.light:contains(name):eq(0)`
 **Structural pseudo selectors** |||
 `:root` | The element that is the root of the document. In HTML, this is the `html` element | `:root`
 `:nth-child(An+B)` | elements that have _A_ n + _B_ - 1 siblings _before_ it in the document tree, for any positive integer or zero value of `n`, and has a parent element. For values of `A` and `B` greater than zero, this effectively divides the element's children into groups of a elements (the last group taking the remainder), and selecting the _b_ th element of each group. For example, this allows the selectors to address every other row in a table, and could be used to alternate the color of paragraph text in a cycle of four. The `A` and `B` values must be integers (positive, negative, or zero). The index of the first child of an element is 1. In addition to this, `:nth-child()` can take `odd` and `even` as arguments instead. `odd` has the same signification as `2n+1`, and `even` has the same signification as `2n`. | `tr:nth-child(2n+1)` finds every odd row of a table. `:nth-child(10n-1)` the 9th, 19th, 29th, etc, element. `li:nth-child(5)` the 5th `li`
 `:nth-last-child(An+B)` | elements that have _A_ n + _B_ - 1 siblings _after_ it in the document tree. Otherwise like `:nth-child()` | `tr:nth-last-child(-n+2)` the last two rows of a table
 `:nth-of-type(An+B)` | pseudo-class notation represents an element that has _A_ n + _B_ - 1 siblings with the same expanded element name _before_ it in the document tree, for any zero or positive integer value of n, and has a parent element | `img:nth-of-type(2n+1)`
 `:nth-last-of-type(An+B)` | pseudo-class notation represents an element that has _A_ n + _B_ - 1 siblings with the same expanded element name _after_ it in the document tree, for any zero or positive integer value of n, and has a parent element | `img:nth-last-of-type(2n+1)`
 `:first-child` | elements that are the first child of some other element. | `div > p:first-child`
 `:last-child` | elements that are the last child of some other element. | `ol > li:last-child`
 `:first-of-type` | elements that are the first sibling of its type in the list of children of its parent element | `dl dt:first-of-type`
 `:last-of-type` | elements that are the last sibling of its type in the list of children of its parent element | `tr > td:last-of-type`
 `:only-child` | elements that have a parent element and whose parent element hasve no other element children | 
 `:only-of-type` |  an element that has a parent element and whose parent element has no other element children with the same expanded element name | 
 `:empty` | elements that have no children at all | 
 
 - seealso: ``Element/select(_:)-(String)``
 */
open class CssSelector {
    private let evaluator: Evaluator
    private let root: Element
    
    private static let selectorCacheCapacity: Int = 128
    private final class SelectorCache: @unchecked Sendable {
        var items: [String: Evaluator] = [:]
        var order: [String] = []
        var orderHead: Int = 0
        let lock = NSLock()

        @inline(__always)
        func record(_ key: String, capacity: Int) {
            order.append(key)
            let liveCount = order.count - orderHead
            if liveCount > capacity {
                let overflow = liveCount - capacity
                if overflow > 0 {
                    for _ in 0..<overflow {
                        let removedKey = order[orderHead]
                        orderHead += 1
                        items.removeValue(forKey: removedKey)
                    }
                }
                if orderHead > 64 && orderHead > order.count / 2 {
                    order.removeFirst(orderHead)
                    orderHead = 0
                }
            }
        }
    }
    private static let selectorCache = SelectorCache()
    private static let fastQueryCacheCapacity: Int = selectorCacheCapacity
    private final class FastQueryCache: @unchecked Sendable {
        var items: [String: FastQueryPlan] = [:]
        var order: [String] = []
        var orderHead: Int = 0
        let lock = NSLock()

        @inline(__always)
        func record(_ key: String, capacity: Int) {
            order.append(key)
            let liveCount = order.count - orderHead
            if liveCount > capacity {
                let overflow = liveCount - capacity
                if overflow > 0 {
                    for _ in 0..<overflow {
                        let removedKey = order[orderHead]
                        orderHead += 1
                        items.removeValue(forKey: removedKey)
                    }
                }
                if orderHead > 64 && orderHead > order.count / 2 {
                    order.removeFirst(orderHead)
                    orderHead = 0
                }
            }
        }
    }
    private static let fastQueryCache = FastQueryCache()

    private init(_ query: String, _ root: Element)throws {
        let query = query.trim()
        try Validate.notEmpty(string: query.utf8Array)

        self.evaluator = try CssSelector.cachedEvaluatorTrimmed(query)

        self.root = root
    }

    private init(_ evaluator: Evaluator, _ root: Element) {
        self.evaluator = evaluator
        self.root = root
    }

    /**
     Find elements matching selector.
     
     - parameter query: CSS selector
     - parameter root:  root element to descend into
     - returns: matching elements, empty if none
     - throws ``Exception`` with ``ExceptionType/SelectorParseException`` (unchecked) on an invalid CSS query.
     */
    public static func select(_ query: String, _ root: Element)throws->Elements {
        let query = query.trim()
        try Validate.notEmpty(string: query.utf8Array)
        DebugTrace.log("CssSelector.select(query): \(query)")
        if let cached = root.cachedSelectorResult(query) {
            DebugTrace.log("CssSelector.select(query): selector cache hit")
            return cached
        }
        let skipFallbackFastPath = root.ownerDocument()?.libxml2Only == true
#if canImport(CLibxml2) || canImport(libxml2)
        if skipFallbackFastPath {
            if let tagBytes = simpleTagQueryBytes(query) {
                DebugTrace.log("CssSelector.select(query): simple tag fast path")
                let result = try root.getElementsByTagNormalized(tagBytes)
                root.storeSelectorResult(query, result)
                return result
            }
            if let fast = try fastSelectQuery(query, root, query) {
                DebugTrace.log("CssSelector.select(query): fast path hit")
                root.storeSelectorResult(query, fast)
                return fast
            }
            if root.ownerDocument()?.isLibxml2Backend == true,
               let libxml2 = try libxml2Select(query, root) {
                DebugTrace.log("CssSelector.select(query): libxml2 xpath fast path hit")
                root.storeSelectorResult(query, libxml2)
                return libxml2
            }
        }
#endif
#if canImport(CLibxml2) || canImport(libxml2)
        if root.ownerDocument()?.libxml2Only == true,
           let libxml2 = try libxml2Select(query, root) {
            DebugTrace.log("CssSelector.select(query): libxml2 xpath fast path hit")
            root.storeSelectorResult(query, libxml2)
            return libxml2
        }
#endif
        if !skipFallbackFastPath, let tagBytes = simpleTagQueryBytes(query) {
            DebugTrace.log("CssSelector.select(query): simple tag fast path")
            let result = try root.getElementsByTagNormalized(tagBytes)
            root.storeSelectorResult(query, result)
            return result
        }
        if !skipFallbackFastPath, let fast = try fastSelectQuery(query, root, query) {
            DebugTrace.log("CssSelector.select(query): fast path hit")
            root.storeSelectorResult(query, fast)
            return fast
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if root.ownerDocument()?.libxml2Only == true,
           let libxml2 = try libxml2Select(query, root) {
            DebugTrace.log("CssSelector.select(query): libxml2 xpath fast path hit")
            root.storeSelectorResult(query, libxml2)
            return libxml2
        }
#endif
        DebugTrace.log("CssSelector.select(query): slow path")
        let evaluator = try cachedEvaluatorTrimmed(query)
        let result = try select(evaluator, root)
        root.storeSelectorResult(query, result)
        return result
    }

    /**
     Find elements matching selector.
     
     - parameter evaluator: CSS selector
     - parameter root: root element to descend into
     - returns: matching elements, empty if none
     */
    public static func select(_ evaluator: Evaluator, _ root: Element)throws->Elements {
        return try CssSelector(evaluator, root).select()
    }

    /**
     Find elements matching selector.
     
     - parameter query: CSS selector
     - parameter roots: root elements to descend into
     - returns: matching elements, empty if none
     */
    public static func select(_ query: String, _ roots: Array<Element>)throws->Elements {
        let query = query.trim()
        try Validate.notEmpty(string: query.utf8Array)
        if roots.count == 1, let root = roots.first {
            if let cached = root.cachedSelectorResult(query) {
                return cached
            }
        }
        let skipFallbackFastPath = roots.count == 1 && roots.first?.ownerDocument()?.libxml2Only == true
#if canImport(CLibxml2) || canImport(libxml2)
        if skipFallbackFastPath, let root = roots.first {
            if let tagBytes = simpleTagQueryBytes(query) {
                let result = try root.getElementsByTagNormalized(tagBytes)
                root.storeSelectorResult(query, result)
                return result
            }
            if root.ownerDocument()?.libxml2Only == true,
               let libxml2 = try libxml2Select(query, root) {
                root.storeSelectorResult(query, libxml2)
                return libxml2
            }
            if let fast = try fastSelectQuery(query, root, query) {
                root.storeSelectorResult(query, fast)
                return fast
            }
        }
#endif
        if !skipFallbackFastPath, let tagBytes = simpleTagQueryBytes(query) {
            if roots.count == 1, let root = roots.first {
                let result = try root.getElementsByTagNormalized(tagBytes)
                root.storeSelectorResult(query, result)
                return result
            }
            var elements: Array<Element> = []
            var seenIds = Set<ObjectIdentifier>()
            seenIds.reserveCapacity(roots.count * 8)
            for root in roots {
                let found = try root.getElementsByTagNormalized(tagBytes)
                for el in found.array() {
                    let id = ObjectIdentifier(el)
                    if seenIds.contains(id) {
                        continue
                    }
                    seenIds.insert(id)
                    elements.append(el)
                }
            }
            return Elements(elements)
        }
        if !skipFallbackFastPath, let fast = try fastSelectQuery(query, roots, query) {
            if roots.count == 1, let root = roots.first {
                root.storeSelectorResult(query, fast)
            }
            return fast
        }
#if canImport(CLibxml2) || canImport(libxml2)
        if roots.count == 1,
           let root = roots.first,
           root.ownerDocument()?.libxml2Only == true,
           let libxml2 = try libxml2Select(query, root) {
            root.storeSelectorResult(query, libxml2)
            return libxml2
        }
#endif
        let evaluator: Evaluator = try cachedEvaluatorTrimmed(query)
        let result = try self.select(evaluator, roots)
        if roots.count == 1, let root = roots.first {
            root.storeSelectorResult(query, result)
        }
        return result
    }

    /**
     Find elements matching an evaluator.
     
     - parameter evaluator: Query evaluator
     - parameter roots: root elements to descend into
     - seealso: ``QueryParser``
     - returns: matching elements, empty if none
     */
    public static func select(_ evaluator: Evaluator, _ roots: Array<Element>)throws->Elements {
        if roots.count == 1, let root = roots.first {
            return try select(evaluator, root)
        }
        var elements: Array<Element> = []
        var seenIds = Set<ObjectIdentifier>()
        seenIds.reserveCapacity(roots.count * 8)
        // dedupe elements by identity, not equality
        for root: Element in roots {
            let found: Elements = try select(evaluator, root)
            for el: Element in found.array() {
                let id = ObjectIdentifier(el)
                if !seenIds.contains(id) {
                    seenIds.insert(id)
                    elements.append(el)
                }
            }
        }
        return Elements(elements)
    }

    private func select()throws->Elements {
        #if PROFILE
        let _p = Profiler.start("CssSelector.select")
        defer { Profiler.end("CssSelector.select", _p) }
        #endif
        DebugTrace.log("CssSelector.select(evaluator): \(evaluator)")
        if let fast = try CssSelector.fastSelect(evaluator, root) {
            DebugTrace.log("CssSelector.select(evaluator): fast path hit")
            return fast
        }
        DebugTrace.log("CssSelector.select(evaluator): collector path")
        return try Collector.collect(evaluator, root)
    }
    
    private static func cachedEvaluatorTrimmed(_ key: String) throws -> Evaluator {
        selectorCache.lock.lock()
        if let cached = selectorCache.items[key] {
            selectorCache.lock.unlock()
            return cached
        }
        selectorCache.lock.unlock()
        
        let parsed = try QueryParser.parse(key)
        
        selectorCache.lock.lock()
        if selectorCache.items[key] == nil {
            selectorCache.items[key] = parsed
            selectorCache.record(key, capacity: selectorCacheCapacity)
        }
        selectorCache.lock.unlock()
        return parsed
    }

    private indirect enum FastQueryPlan: Sendable {
        case none
        case all
        case group([FastQueryPlan])
        case id([UInt8])
        case className([UInt8])
        case classes([UInt8], [[UInt8]])
        case tag([UInt8], Token.Tag.TagId?)
        case tagClass([UInt8], Token.Tag.TagId?, [UInt8])
        case tagClasses([UInt8], Token.Tag.TagId?, [UInt8], [[UInt8]])
        case tagId([UInt8], Token.Tag.TagId?, [UInt8])
        case attr([UInt8])
        case tagAttr([UInt8], Token.Tag.TagId?, [UInt8])
        case attrValue([UInt8], [UInt8], String, String)
        case tagAttrValue([UInt8], Token.Tag.TagId?, [UInt8], [UInt8], String, String)
        case descendant(FastQueryPlan, FastQueryPlan)
        
        func apply(_ root: Element) throws -> Elements? {
            DebugTrace.log("FastQueryPlan.apply: \(self)")
            switch self {
            case .none:
                return nil
            case .all:
                return try root.getAllElements()
            case .group(let plans):
                guard !plans.isEmpty else { return nil }
                if plans.count == 1 {
                    return try plans[0].apply(root)
                }
#if canImport(CLibxml2) || canImport(libxml2)
                if let doc = root.ownerDocument(),
                   doc.libxml2Only,
                   !doc.libxml2BackedDirty,
                   let docPtr = doc.libxml2DocPtr {
                    var tags: [[UInt8]] = []
                    tags.reserveCapacity(plans.count)
                    for plan in plans {
                        guard case .tag(let tagBytes, _) = plan else {
                            tags.removeAll()
                            break
                        }
                        if tagBytes.contains(0x3A) {
                            tags.removeAll()
                            break
                        }
                        tags.append(tagBytes)
                    }
                    if !tags.isEmpty {
                        let startNode: xmlNodePtr?
                        if root is Document {
                            startNode = xmlDocGetRootElement(docPtr)
                        } else {
                            startNode = root.libxml2NodePtr
                        }
                        if let startNode {
                            return Libxml2Backend.collectElementsByTagNames(
                                start: startNode,
                                tags: tags,
                                doc: doc
                            )
                        }
                    }
                }
#endif
                var seen = Set<ObjectIdentifier>()
                seen.reserveCapacity(16)
                for plan in plans {
                    guard let elements = try plan.apply(root) else {
                        return nil
                    }
                    for el in elements.array() {
                        let id = ObjectIdentifier(el)
                        if seen.contains(id) { continue }
                        seen.insert(id)
                    }
                }
                let output = Elements()
                output.reserveCapacity(seen.count)
                let ordered = try root.getAllElements()
                for el in ordered.array() {
                    if seen.contains(ObjectIdentifier(el)) {
                        output.add(el)
                    }
                }
                return output
            case .id(let idBytes):
                return root.getElementsById(idBytes)
            case .className(let className):
                return root.getElementsByClassNormalizedBytes(className)
            case .classes(let firstClass, let otherClasses):
                let classElements = root.getElementsByClassNormalizedBytes(firstClass)
                if classElements.isEmpty { return classElements }
                if otherClasses.isEmpty { return classElements }
                let output = Elements()
                output.reserveCapacity(classElements.size())
                for el in classElements.array() {
                    var matchesAll = true
                    for className in otherClasses where !el.hasClass(className) {
                        matchesAll = false
                        break
                    }
                    if matchesAll {
                        output.add(el)
                    }
                }
                return output
            case .tag(let tagBytes, _):
                return try root.getElementsByTagNormalized(tagBytes)
            case .tagClass(let tagBytes, let tagId, let className):
                let classElements = root.getElementsByClassNormalizedBytes(className)
                if classElements.isEmpty { return classElements }
                let output = Elements()
                output.reserveCapacity(classElements.size())
                for el in classElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                    output.add(el)
                }
                return output
            case .tagClasses(let tagBytes, let tagId, let firstClass, let otherClasses):
                let classElements = root.getElementsByClassNormalizedBytes(firstClass)
                if classElements.isEmpty { return classElements }
                let output = Elements()
                output.reserveCapacity(classElements.size())
                for el in classElements.array() {
                    if !CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                        continue
                    }
                    var matchesAll = true
                    for className in otherClasses where !el.hasClass(className) {
                        matchesAll = false
                        break
                    }
                    if matchesAll {
                        output.add(el)
                    }
                }
                return output
            case .tagId(let tagBytes, let tagId, let idBytes):
                let idElements = root.getElementsById(idBytes)
                if idElements.isEmpty { return idElements }
                let output = Elements()
                output.reserveCapacity(idElements.size())
                for el in idElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                    output.add(el)
                }
                return output
            case .attr(let attrBytes):
                if let doc = root.ownerDocument(),
                   doc.libxml2Only,
                   doc.libxml2AttributeOverrides?.isEmpty == false {
                    return nil
                }
                return root.getElementsByAttributeNormalized(attrBytes)
            case .tagAttr(let tagBytes, let tagId, let attrBytes):
                if let doc = root.ownerDocument(),
                   doc.libxml2Only,
                   doc.libxml2AttributeOverrides?.isEmpty == false {
                    return nil
                }
                let attrElements = root.getElementsByAttributeNormalized(attrBytes)
                if attrElements.isEmpty { return attrElements }
                let output = Elements()
                output.reserveCapacity(attrElements.size())
                for el in attrElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                    output.add(el)
                }
                return output
            case .attrValue(let keyBytes, let valueBytes, let key, let value):
                if let doc = root.ownerDocument(),
                   doc.libxml2Only,
                   doc.libxml2AttributeOverrides?.isEmpty == false {
                    return nil
                }
                return try root.getElementsByAttributeValueNormalized(keyBytes, valueBytes, key, value)
            case .tagAttrValue(let tagBytes, let tagId, let keyBytes, let valueBytes, let key, let value):
                if let doc = root.ownerDocument(),
                   doc.libxml2Only,
                   doc.libxml2AttributeOverrides?.isEmpty == false {
                    return nil
                }
                let attrElements = try root.getElementsByAttributeValueNormalized(keyBytes, valueBytes, key, value)
                if attrElements.isEmpty { return attrElements }
                let output = Elements()
                output.reserveCapacity(attrElements.size())
                for el in attrElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                    output.add(el)
                }
                return output
            case .descendant(let left, let right):
                guard CssSelector.isSimplePlan(left), CssSelector.isSimplePlan(right) else {
                    return nil
                }
                guard let candidates = try right.apply(root) else {
                    return nil
                }
                if candidates.isEmpty {
                    return candidates
                }
                guard let leftElements = try left.apply(root) else {
                    return nil
                }
                if leftElements.isEmpty {
                    return Elements()
                }
                let leftCount = leftElements.size()
                if leftCount == 1 {
                    let target = leftElements.get(0)
                    if case .all = right {
                        let output = Elements()
                        let children = target.childNodes
                        if !children.isEmpty {
                            var stack: ContiguousArray<Element> = []
                            stack.reserveCapacity(children.count)
                            var i = children.count
                            while i > 0 {
                                i &-= 1
                                if let childEl = children[i] as? Element {
                                    stack.append(childEl)
                                }
                            }
                            while let el = stack.popLast() {
                                output.add(el)
                                let children = el.childNodes
                                var j = children.count
                                while j > 0 {
                                    j &-= 1
                                    if let childEl = children[j] as? Element {
                                        stack.append(childEl)
                                    }
                                }
                            }
                        }
                        return output
                    }
                    let output = Elements()
                    output.reserveCapacity(candidates.size())
                    for el in candidates.array() {
                        var parent = el.parent()
                        var matched = false
                        while let current = parent {
                            if current === target {
                                matched = true
                                break
                            }
                            parent = current.parent()
                        }
                        if matched {
                            output.add(el)
                        }
                    }
                    return output
                }
                if leftCount <= 4 {
                    let leftArray = leftElements.array()
                    let output = Elements()
                    output.reserveCapacity(candidates.size())
                    for el in candidates.array() {
                        var parent = el.parent()
                        var matched = false
                        while let current = parent {
                            for ancestor in leftArray where current === ancestor {
                                matched = true
                                break
                            }
                            if matched { break }
                            parent = current.parent()
                        }
                        if matched {
                            output.add(el)
                        }
                    }
                    return output
                }
                var leftIds = Set<ObjectIdentifier>()
                leftIds.reserveCapacity(leftElements.size())
                for el in leftElements.array() {
                    leftIds.insert(ObjectIdentifier(el))
                }
                let output = Elements()
                output.reserveCapacity(candidates.size())
                for el in candidates.array() {
                    var parent = el.parent()
                    var matched = false
                    while let current = parent {
                        if leftIds.contains(ObjectIdentifier(current)) {
                            matched = true
                            break
                        }
                        parent = current.parent()
                    }
                    if matched {
                        output.add(el)
                    }
                }
                return output
            }
        }
    }
    
    @inline(__always)
    private static func matchesTagBytes(_ element: Element, _ tagBytes: [UInt8], _ tagId: Token.Tag.TagId?) -> Bool {
        if let tagId, tagId != .none {
            let elTagId = element._tag.tagId
            if elTagId != .none {
                return elTagId == tagId
            }
        }
        return element.tagNameNormalUTF8() == tagBytes
    }

    @inline(__always)
    private static func isSimplePlan(_ plan: FastQueryPlan) -> Bool {
        switch plan {
        case .none, .descendant:
            return false
        case .group:
            return false
        default:
            return true
        }
    }

    /// Ultra-fast path for very simple selectors without combinators or pseudos.
    private static func fastSelectQuery(_ query: String, _ root: Element, _ trimmed: String) throws -> Elements? {
        DebugTrace.log("CssSelector.fastSelectQuery: \(query)")
        let plan = cachedFastQueryPlan(trimmed)
        DebugTrace.log("CssSelector.fastSelectQuery: plan=\(plan)")
        return try plan.apply(root)
    }

    @inline(__always)
    private static func simpleTagQueryBytes(_ trimmed: String) -> [UInt8]? {
        if trimmed.isEmpty {
            return nil
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(trimmed.utf8.count)
        for b in trimmed.utf8 {
            switch b {
            case TokeniserStateVars.upperAByte...TokeniserStateVars.upperZByte:
                bytes.append(b &+ 32)
            case TokeniserStateVars.lowerAByte...TokeniserStateVars.lowerZByte,
                 TokeniserStateVars.zeroByte...TokeniserStateVars.nineByte,
                 TokeniserStateVars.hyphenByte,
                 TokeniserStateVars.underscoreByte:
                bytes.append(b)
            default:
                return nil
            }
        }
        return bytes.isEmpty ? nil : bytes
    }

    private static func cachedFastQueryPlan(_ trimmed: String) -> FastQueryPlan {
        fastQueryCache.lock.lock()
        if let cached = fastQueryCache.items[trimmed] {
            fastQueryCache.lock.unlock()
            DebugTrace.log("CssSelector.cachedFastQueryPlan: cache hit")
            return cached
        }
        fastQueryCache.lock.unlock()
        
        DebugTrace.log("CssSelector.cachedFastQueryPlan: cache miss")
        let plan = fastQueryPlan(trimmed)
        
        fastQueryCache.lock.lock()
        if fastQueryCache.items[trimmed] == nil {
            fastQueryCache.items[trimmed] = plan
            fastQueryCache.record(trimmed, capacity: fastQueryCacheCapacity)
        }
        fastQueryCache.lock.unlock()
        return plan
    }
    
    private static func fastQueryPlan(_ query: String) -> FastQueryPlan {
        DebugTrace.log("CssSelector.fastQueryPlan: \(query)")
        if let grouped = fastGroupPlan(query) {
            return grouped
        }
        return fastQueryPlanNoGroup(query)
    }

    private static func fastQueryPlanNoGroup(_ query: String) -> FastQueryPlan {
        let trimmed = query
        if trimmed.isEmpty {
            return .none
        }
        var hasWhitespace = false
        var sawNonAscii = false
        for b in trimmed.utf8 {
            switch b {
            case TokeniserStateVars.commaByte,
                 TokeniserStateVars.greaterThanByte,
                 TokeniserStateVars.plusByte,
                 TokeniserStateVars.tildeByte,
                 TokeniserStateVars.colonByte,
                 TokeniserStateVars.pipeByte: // , > + ~ : |
                return .none
            case TokeniserStateVars.spaceByte,
                 TokeniserStateVars.newLineByte,
                 TokeniserStateVars.tabByte,
                 TokeniserStateVars.carriageReturnByte: // space, \n, \t, \r
                hasWhitespace = true
            default:
                if b >= TokeniserStateVars.asciiUpperLimitByte {
                    sawNonAscii = true
                    break
                }
            }
            if sawNonAscii {
                break
            }
        }
        if sawNonAscii {
            for ch in trimmed {
                switch ch {
                case ",", ">", "+", "~", ":", "|":
                    return .none
                case " ", "\n", "\t", "\r":
                    hasWhitespace = true
                default:
                    break
                }
            }
        }
        if hasWhitespace {
            if let (leftToken, rightToken) = splitDescendantTokens(trimmed[...]) {
                let leftPlan = fastSimpleQueryPlan(leftToken)
                if case .none = leftPlan { return .none }
                let rightPlan = fastSimpleQueryPlan(rightToken)
                if case .none = rightPlan { return .none }
                return .descendant(leftPlan, rightPlan)
            }
            return .none
        }
        return fastSimpleQueryPlan(trimmed[...])
    }

    private static func fastGroupPlan(_ query: String) -> FastQueryPlan? {
        if !query.contains(",") {
            return nil
        }
        var groups: [Substring] = []
        var start = query.startIndex
        var quote: Character? = nil
        var bracketDepth = 0
        var parenDepth = 0
        for idx in query.indices {
            let ch = query[idx]
            if let q = quote {
                if ch == q { quote = nil }
                continue
            }
            if ch == "'" || ch == "\"" {
                quote = ch
                continue
            }
            if ch == "[" {
                bracketDepth &+= 1
                continue
            }
            if ch == "]" {
                if bracketDepth > 0 { bracketDepth &-= 1 }
                continue
            }
            if ch == "(" {
                parenDepth &+= 1
                continue
            }
            if ch == ")" {
                if parenDepth > 0 { parenDepth &-= 1 }
                continue
            }
            if ch == "," && bracketDepth == 0 && parenDepth == 0 {
                groups.append(query[start..<idx])
                start = query.index(after: idx)
            }
        }
        if bracketDepth != 0 || parenDepth != 0 || quote != nil {
            return nil
        }
        if groups.isEmpty {
            return nil
        }
        groups.append(query[start..<query.endIndex])
        var plans: [FastQueryPlan] = []
        plans.reserveCapacity(groups.count)
        for group in groups {
            let trimmed = group.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            let plan = fastQueryPlanNoGroup(trimmed)
            if case .none = plan { return nil }
            if case .descendant = plan { return nil }
            plans.append(plan)
        }
        if plans.isEmpty {
            return nil
        }
        return plans.count == 1 ? plans[0] : .group(plans)
    }

    @inline(__always)
    private static func isWhitespace(_ ch: Character) -> Bool {
        switch ch {
        case " ", "\n", "\t", "\r":
            return true
        default:
            return false
        }
    }

    private static func splitDescendantTokens(_ query: Substring) -> (Substring, Substring)? {
        var bracketDepth = 0
        var quote: Character? = nil
        var splitStart: String.Index? = nil
        var splitEnd: String.Index? = nil
        var idx = query.startIndex
        while idx < query.endIndex {
            let ch = query[idx]
            if let quoteChar = quote {
                if ch == quoteChar {
                    quote = nil
                }
                idx = query.index(after: idx)
                continue
            }
            if ch == "\"" || ch == "'" {
                quote = ch
                idx = query.index(after: idx)
                continue
            }
            if ch == "[" {
                bracketDepth += 1
                idx = query.index(after: idx)
                continue
            }
            if ch == "]" {
                if bracketDepth > 0 {
                    bracketDepth -= 1
                }
                idx = query.index(after: idx)
                continue
            }
            if bracketDepth == 0, isWhitespace(ch) {
                if splitStart != nil {
                    return nil
                }
                splitStart = idx
                var wsEnd = query.index(after: idx)
                while wsEnd < query.endIndex, isWhitespace(query[wsEnd]) {
                    wsEnd = query.index(after: wsEnd)
                }
                splitEnd = wsEnd
                idx = wsEnd
                continue
            }
            idx = query.index(after: idx)
        }
        guard let splitStart, let splitEnd else {
            return nil
        }
        let left = query[..<splitStart]
        let right = query[splitEnd...]
        if left.isEmpty || right.isEmpty {
            return nil
        }
        return (left, right)
    }

    private static func fastSimpleQueryPlan(_ trimmed: Substring) -> FastQueryPlan {
        DebugTrace.log("CssSelector.fastSimpleQueryPlan: \(trimmed)")
        if trimmed.isEmpty {
            return .none
        }
        @inline(__always)
        func isIdentChar(_ ch: Character) -> Bool {
            switch ch {
            case "a"..."z", "A"..."Z", "0"..."9", "-", "_":
                return true
            default:
                return false
            }
        }
        @inline(__always)
        func isSimpleIdent(_ s: Substring) -> Bool {
            guard !s.isEmpty else { return false }
            for ch in s {
                if !isIdentChar(ch) {
                    return false
                }
            }
            return true
        }
        @inline(__always)
        func asciiClassPartsLowercased(_ bytes: [UInt8]) -> [[UInt8]]? {
            var parts: [[UInt8]] = []
            var current: [UInt8] = []
            current.reserveCapacity(bytes.count)
            var i = 0
            while i < bytes.count {
                let b = bytes[i]
                if b == TokeniserStateVars.dotByte { // "."
                    if current.isEmpty {
                        return nil
                    }
                    parts.append(current)
                    current = []
                } else if (b >= TokeniserStateVars.zeroByte && b <= TokeniserStateVars.nineByte) || // 0-9
                            (b >= TokeniserStateVars.upperAByte && b <= TokeniserStateVars.upperZByte) || // A-Z
                            (b >= TokeniserStateVars.lowerAByte && b <= TokeniserStateVars.lowerZByte) || // a-z
                            b == TokeniserStateVars.hyphenByte || b == TokeniserStateVars.underscoreByte { // - _
                    let lower = (b >= TokeniserStateVars.upperAByte && b <= TokeniserStateVars.upperZByte) ? (b &+ 32) : b
                    current.append(lower)
                } else {
                    return nil
                }
                i &+= 1
            }
            if current.isEmpty {
                return nil
            }
            parts.append(current)
            return parts
        }
        @inline(__always)
        func splitClassList(_ s: Substring) -> [Substring]? {
            if s.isEmpty {
                return nil
            }
            var parts: [Substring] = []
            var start = s.startIndex
            var idx = s.startIndex
            while idx < s.endIndex {
                let ch = s[idx]
                if ch == "." {
                    if start == idx {
                        return nil
                    }
                    let part = s[start..<idx]
                    if !isSimpleIdent(part) {
                        return nil
                    }
                    parts.append(part)
                    start = s.index(after: idx)
                    idx = start
                    continue
                }
                if !isIdentChar(ch) {
                    return nil
                }
                idx = s.index(after: idx)
            }
            if start == s.endIndex {
                return nil
            }
            let tail = s[start..<s.endIndex]
            if !isSimpleIdent(tail) {
                return nil
            }
            parts.append(tail)
            return parts
        }
        
        if trimmed.first == "#" {
            let id = trimmed.dropFirst()
            if id.isEmpty {
                return .none
            }
            var asciiOnly = true
            var bytes: [UInt8] = []
            bytes.reserveCapacity(id.count)
            for b in id.utf8 {
                bytes.append(b)
                if b >= TokeniserStateVars.asciiUpperLimitByte {
                    asciiOnly = false
                    continue
                }
                switch b {
                case TokeniserStateVars.spaceByte,
                     TokeniserStateVars.tabByte,
                     TokeniserStateVars.newLineByte,
                     TokeniserStateVars.carriageReturnByte,
                     TokeniserStateVars.commaByte,
                     TokeniserStateVars.greaterThanByte,
                     TokeniserStateVars.plusByte,
                     TokeniserStateVars.tildeByte,
                     TokeniserStateVars.colonByte,
                     TokeniserStateVars.dotByte,
                     TokeniserStateVars.leftBracketByte,
                     TokeniserStateVars.hashByte:
                    return .none
                default:
                    break
                }
            }
            let idBytes = asciiOnly ? bytes : bytes.trim()
            if !idBytes.isEmpty {
                return .id(idBytes)
            }
            return .none
        }
        if trimmed.first == "." {
            let className = trimmed.dropFirst()
            if className.isEmpty {
                return .none
            }
            let classBytes = Array(className.utf8)
            var asciiOnly = true
            for b in classBytes {
                if b >= TokeniserStateVars.asciiUpperLimitByte {
                    asciiOnly = false
                    break
                }
                switch b {
                case TokeniserStateVars.spaceByte,
                     TokeniserStateVars.tabByte,
                     TokeniserStateVars.newLineByte,
                     TokeniserStateVars.carriageReturnByte,
                     TokeniserStateVars.commaByte,
                     TokeniserStateVars.greaterThanByte,
                     TokeniserStateVars.plusByte,
                     TokeniserStateVars.tildeByte,
                     TokeniserStateVars.colonByte,
                     TokeniserStateVars.leftBracketByte,
                     TokeniserStateVars.hashByte:
                    return .none
                default:
                    break
                }
            }
            if asciiOnly {
                if let parts = asciiClassPartsLowercased(classBytes) {
                    let firstClassNormalized = parts[0]
                    if parts.count == 1 {
                        return .className(firstClassNormalized)
                    }
                    return .classes(firstClassNormalized, Array(parts.dropFirst()))
                }
            }
            if let classParts = splitClassList(className) {
                let firstClassBytes = Array(classParts[0].utf8)
                let firstClassNormalized = Attributes.containsAsciiUppercase(firstClassBytes)
                    ? firstClassBytes.lowercased()
                    : firstClassBytes
                if classParts.count == 1 {
                    return .className(firstClassNormalized)
                }
                let otherClasses = classParts.dropFirst().map { part -> [UInt8] in
                    let bytes = Array(part.utf8)
                    return Attributes.containsAsciiUppercase(bytes) ? bytes.lowercased() : bytes
                }
                return .classes(firstClassNormalized, otherClasses)
            }
            return .none
        }
        if trimmed == "*" {
            return .all
        }
        
        if let open = trimmed.firstIndex(of: "[") {
            guard let close = trimmed.lastIndex(of: "]"), close == trimmed.index(before: trimmed.endIndex) else {
                return .none
            }
            let tagPart = trimmed[..<open]
            let attrPart = trimmed[trimmed.index(after: open)..<close]
            if attrPart.isEmpty {
                return .none
            }
            if let eq = attrPart.firstIndex(of: "=") {
                if eq != attrPart.startIndex {
                    let op = attrPart[attrPart.index(before: eq)]
                    if op == "!" || op == "^" || op == "$" || op == "*" || op == "~" || op == "|" {
                        return .none
                    }
                }
                let keyPart = attrPart[..<eq]
                var valuePart = attrPart[attrPart.index(after: eq)...]
                if keyPart.isEmpty || valuePart.isEmpty {
                    return .none
                }
                if (valuePart.first == "\"" && valuePart.last == "\"") || (valuePart.first == "'" && valuePart.last == "'") {
                    valuePart = valuePart.dropFirst().dropLast()
                }
                if valuePart.isEmpty {
                    return .none
                }
                let rawKeyBytes = Array(keyPart.utf8).trim()
                let rawValueBytes = Array(valuePart.utf8).trim()
                if rawKeyBytes.isEmpty || rawValueBytes.isEmpty {
                    return .none
                }
                let keyBytes = Attributes.containsAsciiUppercase(rawKeyBytes) ? rawKeyBytes.lowercased() : rawKeyBytes
                let valueBytes = Attributes.containsAsciiUppercase(rawValueBytes) ? rawValueBytes.lowercased() : rawValueBytes
                let needsOriginal = keyBytes.starts(with: UTF8Arrays.absPrefix)
                let key = needsOriginal ? String(keyPart) : ""
                let value = needsOriginal ? String(valuePart) : ""
                if tagPart.isEmpty {
                    return .attrValue(keyBytes, valueBytes, key, value)
                }
                guard isSimpleIdent(tagPart) else { return .none }
                let rawTagBytes = Array(tagPart.utf8).trim()
                if rawTagBytes.isEmpty { return .none }
                let tagBytes = Attributes.containsAsciiUppercase(rawTagBytes) ? rawTagBytes.lowercased() : rawTagBytes
                return .tagAttrValue(tagBytes, Token.Tag.tagIdForBytes(tagBytes), keyBytes, valueBytes, key, value)
            }
            guard isSimpleIdent(attrPart) else { return .none }
            let rawAttrBytes = Array(attrPart.utf8).trim()
            if rawAttrBytes.isEmpty { return .none }
            let attrBytes = Attributes.containsAsciiUppercase(rawAttrBytes) ? rawAttrBytes.lowercased() : rawAttrBytes
            if tagPart.isEmpty {
                return .attr(attrBytes)
            }
            guard isSimpleIdent(tagPart) else { return .none }
            let rawTagBytes = Array(tagPart.utf8).trim()
            if rawTagBytes.isEmpty { return .none }
            let tagBytes = Attributes.containsAsciiUppercase(rawTagBytes) ? rawTagBytes.lowercased() : rawTagBytes
            return .tagAttr(tagBytes, Token.Tag.tagIdForBytes(tagBytes), attrBytes)
        }
        
        if let dot = trimmed.firstIndex(of: ".") {
            let tagPart = trimmed[..<dot]
            let classPart = trimmed[trimmed.index(after: dot)...]
            let tagBytes = Array(tagPart.utf8)
            let classBytes = Array(classPart.utf8)
            var asciiTag = !tagBytes.isEmpty
            for b in tagBytes {
                if b >= TokeniserStateVars.asciiUpperLimitByte {
                    asciiTag = false
                    break
                }
                if (b >= TokeniserStateVars.zeroByte && b <= TokeniserStateVars.nineByte) ||
                    (b >= TokeniserStateVars.upperAByte && b <= TokeniserStateVars.upperZByte) ||
                    (b >= TokeniserStateVars.lowerAByte && b <= TokeniserStateVars.lowerZByte) ||
                    b == TokeniserStateVars.hyphenByte || b == TokeniserStateVars.underscoreByte {
                    continue
                }
                asciiTag = false
                break
            }
            var asciiClass = !classBytes.isEmpty
            if asciiClass {
                for b in classBytes {
                    if b >= TokeniserStateVars.asciiUpperLimitByte {
                        asciiClass = false
                        break
                    }
                    switch b {
                    case TokeniserStateVars.spaceByte,
                         TokeniserStateVars.tabByte,
                         TokeniserStateVars.newLineByte,
                         TokeniserStateVars.carriageReturnByte,
                         TokeniserStateVars.commaByte,
                         TokeniserStateVars.greaterThanByte,
                         TokeniserStateVars.plusByte,
                         TokeniserStateVars.tildeByte,
                         TokeniserStateVars.colonByte,
                         TokeniserStateVars.leftBracketByte,
                         TokeniserStateVars.hashByte:
                        asciiClass = false
                        break
                    default:
                        break
                    }
                    if !asciiClass { break }
                }
            }
            if asciiTag, asciiClass, let parts = asciiClassPartsLowercased(classBytes) {
                let tagLower: [UInt8] = {
                    var out: [UInt8] = []
                    out.reserveCapacity(tagBytes.count)
                    for b in tagBytes {
                        let lower = (b >= TokeniserStateVars.upperAByte && b <= TokeniserStateVars.upperZByte) ? (b &+ 32) : b
                        out.append(lower)
                    }
                    return out
                }()
                let firstClassNormalized = parts[0]
                if parts.count == 1 {
                    return .tagClass(tagLower, Token.Tag.tagIdForBytes(tagLower), firstClassNormalized)
                }
                return .tagClasses(tagLower, Token.Tag.tagIdForBytes(tagLower), firstClassNormalized, Array(parts.dropFirst()))
            }
            if isSimpleIdent(tagPart) {
                if let classParts = splitClassList(classPart) {
                    let rawTagBytes = Array(tagPart.utf8).trim()
                    if rawTagBytes.isEmpty { return .none }
                    let tagBytes = Attributes.containsAsciiUppercase(rawTagBytes) ? rawTagBytes.lowercased() : rawTagBytes
                    if tagBytes.isEmpty { return .none }
                    let firstClassBytes = Array(classParts[0].utf8)
                    let firstClassNormalized = Attributes.containsAsciiUppercase(firstClassBytes)
                        ? firstClassBytes.lowercased()
                        : firstClassBytes
                    if classParts.count == 1 {
                        return .tagClass(tagBytes, Token.Tag.tagIdForBytes(tagBytes), firstClassNormalized)
                    }
                    let otherClasses = classParts.dropFirst().map { part -> [UInt8] in
                        let bytes = Array(part.utf8)
                        return Attributes.containsAsciiUppercase(bytes) ? bytes.lowercased() : bytes
                    }
                    return .tagClasses(tagBytes, Token.Tag.tagIdForBytes(tagBytes), firstClassNormalized, otherClasses)
                }
            }
            return .none
        }
        if let hash = trimmed.firstIndex(of: "#") {
            let tagPart = trimmed[..<hash]
            let idPart = trimmed[trimmed.index(after: hash)...]
            if isSimpleIdent(tagPart), isSimpleIdent(idPart) {
                let idBytes = Array(idPart.utf8).trim()
                if idBytes.isEmpty { return .none }
                let rawTagBytes = Array(tagPart.utf8).trim()
                if rawTagBytes.isEmpty { return .none }
                let tagBytes = Attributes.containsAsciiUppercase(rawTagBytes) ? rawTagBytes.lowercased() : rawTagBytes
                if tagBytes.isEmpty { return .none }
                return .tagId(tagBytes, Token.Tag.tagIdForBytes(tagBytes), idBytes)
            }
            return .none
        }
        if isSimpleIdent(trimmed[...]) {
            let rawTagBytes = Array(trimmed.utf8).trim()
            if rawTagBytes.isEmpty { return .none }
            let tagBytes = Attributes.containsAsciiUppercase(rawTagBytes) ? rawTagBytes.lowercased() : rawTagBytes
            if tagBytes.isEmpty { return .none }
            return .tag(tagBytes, Token.Tag.tagIdForBytes(tagBytes))
        }
        return .none
    }

    private static func fastSelectQuery(_ query: String, _ roots: Array<Element>, _ trimmed: String) throws -> Elements? {
        let plan = cachedFastQueryPlan(trimmed)
        if case .none = plan {
            return nil
        }
        if roots.count == 1, let root = roots.first {
            return try plan.apply(root)
        }
        var elements: Array<Element> = []
        var seenIds = Set<ObjectIdentifier>()
        seenIds.reserveCapacity(roots.count * 8)
        for root in roots {
            guard let found = try plan.apply(root) else {
                return nil
            }
            for el in found.array() {
                let id = ObjectIdentifier(el)
                if seenIds.contains(id) {
                    continue
                }
                seenIds.insert(id)
                elements.append(el)
            }
        }
        return Elements(elements)
    }
    
    /// Fast‑path for simple selectors that map directly onto indexed queries.
    /// Avoids full DOM traversal when the evaluator is a single primitive selector.
    private static func fastSelect(_ evaluator: Evaluator, _ root: Element) throws -> Elements? {
        if let eval = evaluator as? Evaluator.Tag {
            return try root.getElementsByTag(eval.tagNameNormal)
        }
        if let eval = evaluator as? Evaluator.Id {
            return root.getElementsById(eval.idBytes)
        }
        if let eval = evaluator as? Evaluator.Class {
            let key = eval.classNameBytes
            let normalized = Attributes.containsAsciiUppercase(key) ? key.lowercased() : key
            return root.getElementsByClassNormalizedBytes(normalized)
        }
        if let eval = evaluator as? Evaluator.Attribute {
            return root.getElementsByAttributeNormalized(eval.keyBytes)
        }
        if let eval = evaluator as? Evaluator.AttributeWithValue {
            return try root.getElementsByAttributeValueNormalized(
                eval.keyBytes,
                eval.valueBytes,
                eval.key,
                eval.value
            )
        }
        if let eval = evaluator as? CombiningEvaluator.And {
            return try fastSelectAnd(eval, root)
        }
        return nil
    }

    private struct IndexedCandidate {
        let elements: Elements
        let priority: Int
        let evaluator: Evaluator
    }

    /// Fast‑path for AND chains: pick an indexed candidate set, then filter by the full evaluator list.
    /// This preserves document order while avoiding a full traversal in common selector shapes.
    private static func fastSelectAnd(_ evaluator: CombiningEvaluator.And, _ root: Element) throws -> Elements? {
        if root.ownerDocument()?.libxml2Only == true,
           evaluator.evaluators.contains(where: { $0 is StructuralEvaluator }) {
            return nil
        }
        var best: IndexedCandidate? = nil
        for sub in evaluator.evaluators {
            if let candidate = try indexedCandidate(for: sub, root) {
                if best == nil || candidate.priority < best!.priority {
                    best = candidate
                }
            }
        }
        guard let best else { return nil }

        let output = Elements()
        output.reserveCapacity(best.elements.size())
        let skipEval = best.evaluator
        for element in best.elements.array() {
            var matchesAll = true
            for sub in evaluator.evaluators {
                if sub === skipEval {
                    continue
                }
                if try !sub.matches(root, element) {
                    matchesAll = false
                    break
                }
            }
            if matchesAll {
                output.add(element)
            }
        }
        return output
    }

    private static func indexedCandidate(for evaluator: Evaluator, _ root: Element) throws -> IndexedCandidate? {
        if let eval = evaluator as? Evaluator.Id {
            return IndexedCandidate(elements: root.getElementsById(eval.idBytes), priority: 0, evaluator: evaluator)
        }
        if let eval = evaluator as? Evaluator.AttributeWithValue {
            let normalizedKey = eval.keyBytes
            guard Element.isHotAttributeKey(normalizedKey) else { return nil }
            return IndexedCandidate(
                elements: try root.getElementsByAttributeValueNormalized(
                    eval.keyBytes,
                    eval.valueBytes,
                    eval.key,
                    eval.value
                ),
                priority: 1,
                evaluator: evaluator
            )
        }
        if let eval = evaluator as? Evaluator.Class {
            let key = eval.classNameBytes
            let normalized = Attributes.containsAsciiUppercase(key) ? key.lowercased() : key
            return IndexedCandidate(elements: root.getElementsByClassNormalizedBytes(normalized), priority: 2, evaluator: evaluator)
        }
        if let eval = evaluator as? Evaluator.Attribute {
            return IndexedCandidate(elements: root.getElementsByAttributeNormalized(eval.keyBytes), priority: 3, evaluator: evaluator)
        }
        if let eval = evaluator as? Evaluator.Tag {
            return IndexedCandidate(elements: try root.getElementsByTag(eval.tagNameNormal), priority: 4, evaluator: evaluator)
        }
        return nil
    }

#if canImport(CLibxml2) || canImport(libxml2)
    private static let libxml2XPathEnabled: Bool = true
    private static let libxml2XPathCacheEnabled: Bool = true
    private static let libxml2XPathCacheCapacity: Int = 64
    private final class Libxml2XPathCache: @unchecked Sendable {
        final class Node {
            let key: String
            var prev: Node?
            var next: Node?

            init(key: String) {
                self.key = key
            }
        }

        struct Entry {
            let expr: xmlXPathCompExprPtr
            let node: Node
        }

        var items: [String: Entry] = [:]
        var head: Node?
        var tail: Node?
        let lock = NSLock()
    }
    private static let libxml2XPathCache = Libxml2XPathCache()

    private enum Libxml2Combinator {
        case descendant
        case child
        case adjacent
        case sibling
    }

    private enum Libxml2AttrOp {
        case exists
        case equals
        case prefix
        case suffix
        case contains
    }

    private struct Libxml2AttrSelector {
        var name: String
        var op: Libxml2AttrOp
        var value: String?
    }

    private struct Libxml2SimpleSelector {
        var tag: String?
        var id: String?
        var classes: [String]
        var attrs: [Libxml2AttrSelector]
        var pseudos: Libxml2Pseudo
        var nth: Libxml2NthSelector?
    }

    private struct Libxml2Pseudo: OptionSet {
        let rawValue: Int
        static let firstChild = Libxml2Pseudo(rawValue: 1 << 0)
        static let lastChild = Libxml2Pseudo(rawValue: 1 << 1)
        static let firstOfType = Libxml2Pseudo(rawValue: 1 << 2)
        static let lastOfType = Libxml2Pseudo(rawValue: 1 << 3)
        static let onlyChild = Libxml2Pseudo(rawValue: 1 << 4)
        static let onlyOfType = Libxml2Pseudo(rawValue: 1 << 5)
        static let root = Libxml2Pseudo(rawValue: 1 << 6)
        static let empty = Libxml2Pseudo(rawValue: 1 << 7)
    }

    private struct Libxml2NthSelector {
        enum Kind {
            case child
            case lastChild
            case ofType
            case lastOfType
        }

        var kind: Kind
        var a: Int
        var b: Int
    }

    private static let libxml2UpperAscii = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private static let libxml2LowerAscii = "abcdefghijklmnopqrstuvwxyz"
    private static let libxml2NthAB: Pattern = Pattern.compile(
        "((\\+|-)?(\\d+)?)n(\\s*(\\+|-)?\\s*\\d+)?",
        Pattern.CASE_INSENSITIVE
    )
    private static let libxml2NthB: Pattern = Pattern.compile("(\\+|-)?(\\d+)")

    private static func libxml2SelectSimple(
        _ plan: FastQueryPlan,
        _ root: Element,
        _ doc: Document
    ) -> Elements? {
        guard let docPtr = doc.libxml2DocPtr, !doc.libxml2BackedDirty else { return nil }
        let startNode: xmlNodePtr?
        if let rootPtr = root.libxml2NodePtr {
            startNode = rootPtr
        } else if root is Document {
            startNode = xmlDocGetRootElement(docPtr)
        } else {
            return nil
        }
        guard let startNode else { return nil }
        let settings = doc.treeBuilder?.settings ?? ParseSettings.htmlDefault

        var result: Elements?
        switch plan {
        case .tag(let tagBytes, _):
            result = Libxml2Backend.collectElementsByTagName(start: startNode, tag: tagBytes, settings: settings, doc: doc)
        case .id(let idBytes):
            result = Libxml2Backend.collectElementsByAttributeValue(
                start: startNode,
                key: "id".utf8Array,
                value: idBytes,
                doc: doc
            )
        case .className(let className):
            result = Libxml2Backend.collectElementsByClassName(start: startNode, className: className, doc: doc)
        case .classes(let firstClass, let otherClasses):
            let classElements = Libxml2Backend.collectElementsByClassName(start: startNode, className: firstClass, doc: doc)
            if classElements.isEmpty || otherClasses.isEmpty {
                result = classElements
                break
            }
            let output = Elements()
            output.reserveCapacity(classElements.size())
            for el in classElements.array() {
                var matchesAll = true
                for className in otherClasses where !el.hasClass(className) {
                    matchesAll = false
                    break
                }
                if matchesAll {
                    output.add(el)
                }
            }
            result = output
        case .tagClass(let tagBytes, let tagId, let className):
            let classElements = Libxml2Backend.collectElementsByClassName(start: startNode, className: className, doc: doc)
            if classElements.isEmpty {
                result = classElements
                break
            }
            let output = Elements()
            output.reserveCapacity(classElements.size())
            for el in classElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                output.add(el)
            }
            result = output
        case .tagClasses(let tagBytes, let tagId, let firstClass, let otherClasses):
            let classElements = Libxml2Backend.collectElementsByClassName(start: startNode, className: firstClass, doc: doc)
            if classElements.isEmpty {
                result = classElements
                break
            }
            let output = Elements()
            output.reserveCapacity(classElements.size())
            for el in classElements.array() {
                if !CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                    continue
                }
                var matchesAll = true
                for className in otherClasses where !el.hasClass(className) {
                    matchesAll = false
                    break
                }
                if matchesAll {
                    output.add(el)
                }
            }
            result = output
        case .tagId(let tagBytes, let tagId, let idBytes):
            if let found = Libxml2Backend.findFirstElementById(start: startNode, id: idBytes, doc: doc) {
                let output = Elements()
                if CssSelector.matchesTagBytes(found, tagBytes, tagId) {
                    output.add(found)
                }
                result = output
            } else {
                result = Elements()
            }
        case .attr(let attrBytes):
            result = Libxml2Backend.collectElementsByAttributeName(start: startNode, key: attrBytes, doc: doc)
        case .tagAttr(let tagBytes, let tagId, let attrBytes):
            let attrElements = Libxml2Backend.collectElementsByAttributeName(start: startNode, key: attrBytes, doc: doc)
            if attrElements.isEmpty {
                result = attrElements
                break
            }
            let output = Elements()
            output.reserveCapacity(attrElements.size())
            for el in attrElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                output.add(el)
            }
            result = output
        case .attrValue(let keyBytes, let valueBytes, _, _):
            result = Libxml2Backend.collectElementsByAttributeValue(start: startNode, key: keyBytes, value: valueBytes, doc: doc)
        case .tagAttrValue(let tagBytes, let tagId, let keyBytes, let valueBytes, _, _):
            let attrElements = Libxml2Backend.collectElementsByAttributeValue(start: startNode, key: keyBytes, value: valueBytes, doc: doc)
            if attrElements.isEmpty {
                result = attrElements
                break
            }
            let output = Elements()
            output.reserveCapacity(attrElements.size())
            for el in attrElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                output.add(el)
            }
            result = output
        case .group(let plans):
            guard !plans.isEmpty else {
                result = nil
                break
            }
            var tags: [[UInt8]] = []
            tags.reserveCapacity(plans.count)
            for plan in plans {
                guard case .tag(let tagBytes, _) = plan else {
                    tags.removeAll()
                    break
                }
                if tagBytes.contains(0x3A) {
                    tags.removeAll()
                    break
                }
                tags.append(tagBytes)
            }
            if tags.isEmpty {
                result = nil
                break
            }
            result = Libxml2Backend.collectElementsByTagNames(start: startNode, tags: tags, doc: doc)
        case .descendant:
            result = nil
        case .all:
            result = Libxml2Backend.collectAllElements(start: startNode, doc: doc, includeSelf: true)
            if root is Document, let current = result {
                let withRoot = Elements()
                withRoot.reserveCapacity(current.size() + 1)
                withRoot.add(root)
                for el in current.array() {
                    withRoot.add(el)
                }
                result = withRoot
            }
        case .none:
            result = nil
        }
        return result
    }

    private static func libxml2XPathBypassForOverrides(_ query: String, _ doc: Document) -> Bool {
        guard let overrides = doc.libxml2AttributeOverrides, !overrides.isEmpty else {
            return false
        }
        var quote: Character? = nil
        for ch in query {
            if let q = quote {
                if ch == q { quote = nil }
                continue
            }
            if ch == "'" || ch == "\"" {
                quote = ch
                continue
            }
            if ch == "[" || ch == "#" || ch == "." {
                return true
            }
        }
        return false
    }

    private static func libxml2Select(_ query: String, _ root: Element) throws -> Elements? {
        guard let doc = root.ownerDocument() else { return nil }
        let xpathAllowed = libxml2XPathEnabled || doc.isLibxml2Backend || doc.libxml2Preferred
        guard xpathAllowed else { return nil }
        if doc.libxml2LazyState != nil, !doc.libxml2Only { return nil }
        guard let docPtr = doc.libxml2DocPtr, !doc.libxml2BackedDirty else { return nil }
        let trimmed = query.trim()
        if libxml2XPathBypassForOverrides(trimmed, doc) { return nil }
        if doc.libxml2Only {
            let plan = cachedFastQueryPlan(trimmed)
            if let simple = libxml2SelectSimple(plan, root, doc) {
                return simple
            }
        }
        guard let xpath = libxml2XPath(from: trimmed) else { return nil }
        let contextNode: xmlNodePtr?
        if let rootPtr = root.libxml2NodePtr {
            contextNode = rootPtr
        } else if root is Document {
            contextNode = xmlDocGetRootElement(docPtr)
        } else {
            return nil
        }
        guard let contextNode else { return nil }
        let context: xmlXPathContextPtr?
        if let cached = doc.libxml2XPathContext, cached.pointee.doc == docPtr {
            context = cached
        } else {
            if let cached = doc.libxml2XPathContext {
                xmlXPathFreeContext(cached)
                doc.libxml2XPathContext = nil
            }
            let created = xmlXPathNewContext(docPtr)
            doc.libxml2XPathContext = created
            context = created
        }
        guard let context else { return nil }
        context.pointee.node = contextNode
        guard let xpathObj = libxml2EvalXPath(xpath, context) else { return nil }
        defer { xmlXPathFreeObject(xpathObj) }
        guard let nodeset = xpathObj.pointee.nodesetval else {
            return Elements()
        }
        xmlXPathNodeSetSort(nodeset)
        let count = Int(nodeset.pointee.nodeNr)
        if count <= 0 { return Elements() }
        let output = Elements()
        output.reserveCapacity(count)
        let nodeTab = nodeset.pointee.nodeTab
        let preferFastWrap = doc.libxml2Only
        let shouldDedup = !preferFastWrap
        if shouldDedup {
            var seen = Set<ObjectIdentifier>()
            seen.reserveCapacity(count)
            for i in 0..<count {
                guard let nodePtr = nodeTab?[i] else { continue }
                if nodePtr.pointee.type != XML_ELEMENT_NODE { continue }
            let node: Node?
            if let opaque = nodePtr.pointee._private {
                node = Unmanaged<Node>.fromOpaque(opaque).takeUnretainedValue()
            } else if preferFastWrap {
                node = Libxml2Backend.wrapNodeForSelectionFast(nodePtr, doc: doc)
            } else {
                node = Libxml2Backend.wrapNodeForSelection(nodePtr, doc: doc)
            }
                guard let node else { continue }
                guard let element = node as? Element else { continue }
                element.setSiblingIndex(Libxml2Backend.libxml2SiblingIndex(nodePtr, parent: element.parentNode ?? doc, doc: doc))
                let id = ObjectIdentifier(element)
                if seen.contains(id) { continue }
                seen.insert(id)
                output.add(element)
            }
        } else {
            for i in 0..<count {
                guard let nodePtr = nodeTab?[i] else { continue }
                if nodePtr.pointee.type != XML_ELEMENT_NODE { continue }
            let node: Node?
            if let opaque = nodePtr.pointee._private {
                node = Unmanaged<Node>.fromOpaque(opaque).takeUnretainedValue()
            } else if preferFastWrap {
                node = Libxml2Backend.wrapNodeForSelectionFast(nodePtr, doc: doc)
            } else {
                node = Libxml2Backend.wrapNodeForSelection(nodePtr, doc: doc)
            }
                guard let node else { continue }
                guard let element = node as? Element else { continue }
                element.setSiblingIndex(Libxml2Backend.libxml2SiblingIndex(nodePtr, parent: element.parentNode ?? doc, doc: doc))
                output.add(element)
            }
        }
        if doc.libxml2Only, output.size() > 1 {
            for i in 0..<output.size() {
                output.get(i).setSiblingIndex(i)
            }
        }
        if trimmed == "*" && root is Document {
            let withRoot = Elements()
            withRoot.reserveCapacity(output.size() + 1)
            withRoot.add(root)
            for el in output.array() {
                withRoot.add(el)
            }
            return withRoot
        }
        return output
    }

    private static func libxml2EvalXPath(_ xpath: String, _ context: xmlXPathContextPtr) -> xmlXPathObjectPtr? {
        if libxml2XPathCacheEnabled, let compiled = libxml2XPathCachedCompile(xpath) {
            return xmlXPathCompiledEval(compiled, context)
        }
        var bytes = Array(xpath.utf8)
        bytes.append(0)
        return bytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return nil }
            return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                xmlXPathEvalExpression(ptr, context)
            }
        }
    }

    private static func libxml2XPathCachedCompile(_ xpath: String) -> xmlXPathCompExprPtr? {
        libxml2XPathCache.lock.lock()
        if let cached = libxml2XPathCache.items[xpath] {
            let node = cached.node
            if libxml2XPathCache.head !== node {
                if let prev = node.prev {
                    prev.next = node.next
                } else {
                    libxml2XPathCache.head = node.next
                }
                if let next = node.next {
                    next.prev = node.prev
                } else {
                    libxml2XPathCache.tail = node.prev
                }
                node.prev = nil
                node.next = libxml2XPathCache.head
                libxml2XPathCache.head?.prev = node
                libxml2XPathCache.head = node
                if libxml2XPathCache.tail == nil {
                    libxml2XPathCache.tail = node
                }
            }
            let expr = cached.expr
            libxml2XPathCache.lock.unlock()
            return expr
        }
        libxml2XPathCache.lock.unlock()
        var bytes = Array(xpath.utf8)
        bytes.append(0)
        let compiled: xmlXPathCompExprPtr? = bytes.withUnsafeBufferPointer { buf in
            guard let base = buf.baseAddress else { return nil }
            return base.withMemoryRebound(to: xmlChar.self, capacity: buf.count) { ptr in
                xmlXPathCompile(ptr)
            }
        }
        guard let compiled else { return nil }
        libxml2XPathCache.lock.lock()
        if let cached = libxml2XPathCache.items[xpath] {
            let expr = cached.expr
            libxml2XPathCache.lock.unlock()
            xmlXPathFreeCompExpr(compiled)
            return expr
        }
        let node = Libxml2XPathCache.Node(key: xpath)
        node.next = libxml2XPathCache.head
        libxml2XPathCache.head?.prev = node
        libxml2XPathCache.head = node
        if libxml2XPathCache.tail == nil {
            libxml2XPathCache.tail = node
        }
        libxml2XPathCache.items[xpath] = Libxml2XPathCache.Entry(expr: compiled, node: node)
        if libxml2XPathCache.items.count > libxml2XPathCacheCapacity, let tail = libxml2XPathCache.tail {
            let key = tail.key
            if let prev = tail.prev {
                prev.next = nil
            } else {
                libxml2XPathCache.head = nil
            }
            libxml2XPathCache.tail = tail.prev
            if let removed = libxml2XPathCache.items.removeValue(forKey: key) {
                xmlXPathFreeCompExpr(removed.expr)
            }
        }
        libxml2XPathCache.lock.unlock()
        return compiled
    }

    private static func libxml2XPath(from query: String) -> String? {
        if query.isEmpty { return nil }
        if libxml2HasUnsupportedTokens(query) { return nil }
        for b in query.utf8 where b >= 0x80 {
            return nil
        }
        let groups = libxml2SplitGroups(query)
        if groups.isEmpty { return nil }
        var expressions: [String] = []
        expressions.reserveCapacity(groups.count)
        for group in groups {
            let trimmed = group.trim()
            if trimmed.isEmpty { continue }
            guard let steps = libxml2ParseSequence(trimmed) else { return nil }
            guard let xpath = libxml2BuildXPath(steps) else { return nil }
            expressions.append(xpath)
        }
        return expressions.isEmpty ? nil : expressions.joined(separator: " | ")
    }

    private static func libxml2HasUnsupportedTokens(_ query: String) -> Bool {
        var bracketDepth = 0
        var quote: Character? = nil
        for ch in query {
            if let q = quote {
                if ch == q { quote = nil }
                continue
            }
            if ch == "'" || ch == "\"" {
                quote = ch
                continue
            }
            if ch == "[" {
                bracketDepth += 1
                continue
            }
            if ch == "]" {
                if bracketDepth > 0 { bracketDepth -= 1 }
                continue
            }
            if bracketDepth == 0 {
                if ch == ":" || ch == "|" {
                    return true
                }
            }
        }
        return false
    }

    private static func libxml2SplitGroups(_ query: String) -> [String] {
        var groups: [String] = []
        groups.reserveCapacity(2)
        var start = query.startIndex
        var i = query.startIndex
        var bracketDepth = 0
        var quote: Character? = nil
        while i < query.endIndex {
            let ch = query[i]
            if let q = quote {
                if ch == q { quote = nil }
            } else {
                if ch == "'" || ch == "\"" {
                    quote = ch
                } else if ch == "[" {
                    bracketDepth += 1
                } else if ch == "]" {
                    if bracketDepth > 0 { bracketDepth -= 1 }
                } else if ch == "," && bracketDepth == 0 {
                    groups.append(String(query[start..<i]))
                    start = query.index(after: i)
                }
            }
            i = query.index(after: i)
        }
        if start < query.endIndex {
            groups.append(String(query[start..<query.endIndex]))
        } else if start == query.endIndex {
            groups.append("")
        }
        return groups
    }

    private static func libxml2ParseSequence(_ query: String) -> [(Libxml2Combinator?, Libxml2SimpleSelector)]? {
        var steps: [(Libxml2Combinator?, Libxml2SimpleSelector)] = []
        var pendingCombinator: Libxml2Combinator? = nil
        var i = query.startIndex
        while i < query.endIndex {
            var sawWhitespace = false
            while i < query.endIndex, query[i].isWhitespace {
                sawWhitespace = true
                i = query.index(after: i)
            }
            if i >= query.endIndex { break }
            if sawWhitespace, !steps.isEmpty, pendingCombinator == nil {
                pendingCombinator = .descendant
            }
            let ch = query[i]
            if ch == ">" || ch == "+" || ch == "~" {
                if steps.isEmpty { return nil }
                pendingCombinator = (ch == ">") ? .child : (ch == "+") ? .adjacent : .sibling
                i = query.index(after: i)
                continue
            }
            if ch == "," { return nil }
            let start = i
            var bracketDepth = 0
            var quote: Character? = nil
            while i < query.endIndex {
                let current = query[i]
                if let q = quote {
                    if current == q { quote = nil }
                } else {
                    if current == "'" || current == "\"" {
                        quote = current
                    } else if current == "[" {
                        bracketDepth += 1
                    } else if current == "]" {
                        if bracketDepth > 0 { bracketDepth -= 1 }
                    } else if bracketDepth == 0 {
                        if current.isWhitespace || current == ">" || current == "+" || current == "~" || current == "," {
                            break
                        }
                    }
                }
                i = query.index(after: i)
            }
            let token = String(query[start..<i]).trim()
            guard let selector = libxml2ParseSimpleSelector(token) else { return nil }
            let combinator = pendingCombinator ?? (steps.isEmpty ? nil : .descendant)
            steps.append((combinator, selector))
            pendingCombinator = nil
        }
        if pendingCombinator != nil {
            return nil
        }
        return steps
    }

    private static func libxml2ParseSimpleSelector(_ token: String) -> Libxml2SimpleSelector? {
        let bytes = Array(token.utf8)
        if bytes.isEmpty { return nil }
        var i = 0
        var tag: String? = nil
        var id: String? = nil
        var classes: [String] = []
        var attrs: [Libxml2AttrSelector] = []
        var pseudos: Libxml2Pseudo = []
        var nthSelector: Libxml2NthSelector? = nil

        func isNameChar(_ b: UInt8) -> Bool {
            switch b {
            case TokeniserStateVars.lowerAByte...TokeniserStateVars.lowerZByte,
                 TokeniserStateVars.upperAByte...TokeniserStateVars.upperZByte,
                 TokeniserStateVars.zeroByte...TokeniserStateVars.nineByte,
                 TokeniserStateVars.hyphenByte,
                 TokeniserStateVars.underscoreByte:
                return true
            default:
                return false
            }
        }

        if bytes[i] == 0x2A { // *
            tag = "*"
            i += 1
        } else if isNameChar(bytes[i]) {
            let start = i
            i += 1
            while i < bytes.count && isNameChar(bytes[i]) {
                i += 1
            }
            tag = String(decoding: bytes[start..<i], as: UTF8.self).lowercased()
        }

        func parseName() -> String? {
            let start = i
            while i < bytes.count && isNameChar(bytes[i]) {
                i += 1
            }
            if i == start { return nil }
            return String(decoding: bytes[start..<i], as: UTF8.self).lowercased()
        }

        while i < bytes.count {
            let b = bytes[i]
            if b == 0x23 { // #
                i += 1
                guard let value = parseName() else { return nil }
                if id != nil { return nil }
                id = value
                continue
            }
            if b == 0x2E { // .
                i += 1
                guard let value = parseName() else { return nil }
                classes.append(value)
                continue
            }
            if b == 0x5B { // [
                i += 1
                while i < bytes.count && bytes[i].isWhitespace {
                    i += 1
                }
                let nameStart = i
                while i < bytes.count && isNameChar(bytes[i]) {
                    i += 1
                }
                if i == nameStart { return nil }
                let name = String(decoding: bytes[nameStart..<i], as: UTF8.self).lowercased()
                while i < bytes.count && bytes[i].isWhitespace {
                    i += 1
                }
                if i >= bytes.count { return nil }
                if bytes[i] == 0x5D { // ]
                    i += 1
                    attrs.append(Libxml2AttrSelector(name: name, op: .exists, value: nil))
                    continue
                }
                var op: Libxml2AttrOp?
                if i + 1 < bytes.count {
                    let op0 = bytes[i]
                    let op1 = bytes[i + 1]
                    if op0 == 0x5E && op1 == 0x3D { // ^=
                        op = .prefix
                        i += 2
                    } else if op0 == 0x24 && op1 == 0x3D { // $=
                        op = .suffix
                        i += 2
                    } else if op0 == 0x2A && op1 == 0x3D { // *=
                        op = .contains
                        i += 2
                    } else if op0 == 0x3D { // =
                        op = .equals
                        i += 1
                    }
                } else if bytes[i] == 0x3D {
                    op = .equals
                    i += 1
                }
                guard let attrOp = op else { return nil }
                while i < bytes.count && bytes[i].isWhitespace {
                    i += 1
                }
                if i >= bytes.count { return nil }
                var valueBytes: ArraySlice<UInt8>
                if bytes[i] == 0x22 || bytes[i] == 0x27 { // " or '
                    let quote = bytes[i]
                    i += 1
                    let startValue = i
                    while i < bytes.count && bytes[i] != quote {
                        i += 1
                    }
                    if i >= bytes.count { return nil }
                    valueBytes = bytes[startValue..<i]
                    i += 1
                } else {
                    let startValue = i
                    while i < bytes.count && bytes[i] != 0x5D {
                        i += 1
                    }
                    if i > bytes.count { return nil }
                    var endValue = i
                    while endValue > startValue && bytes[endValue - 1].isWhitespace {
                        endValue -= 1
                    }
                    valueBytes = bytes[startValue..<endValue]
                }
                while i < bytes.count && bytes[i].isWhitespace {
                    i += 1
                }
                if i >= bytes.count || bytes[i] != 0x5D { return nil }
                i += 1
                let value = String(decoding: valueBytes, as: UTF8.self).trim().lowercased()
                attrs.append(Libxml2AttrSelector(name: name, op: attrOp, value: value))
                continue
            }
            if b == 0x3A { // :
                i += 1
                let start = i
                while i < bytes.count && isNameChar(bytes[i]) {
                    i += 1
                }
                if i == start { return nil }
                let pseudo = String(decoding: bytes[start..<i], as: UTF8.self).lowercased()
                switch pseudo {
                case "first-child":
                    pseudos.insert(.firstChild)
                case "last-child":
                    pseudos.insert(.lastChild)
                case "first-of-type":
                    pseudos.insert(.firstOfType)
                case "last-of-type":
                    pseudos.insert(.lastOfType)
                case "only-child":
                    pseudos.insert(.onlyChild)
                case "only-of-type":
                    pseudos.insert(.onlyOfType)
                case "root":
                    pseudos.insert(.root)
                case "empty":
                    pseudos.insert(.empty)
                case "nth-child", "nth-last-child", "nth-of-type", "nth-last-of-type":
                    if nthSelector != nil { return nil }
                    while i < bytes.count && bytes[i].isWhitespace {
                        i += 1
                    }
                    if i >= bytes.count || bytes[i] != 0x28 { return nil } // (
                    i += 1
                    let argStart = i
                    while i < bytes.count && bytes[i] != 0x29 {
                        i += 1
                    }
                    if i >= bytes.count { return nil }
                    let arg = String(decoding: bytes[argStart..<i], as: UTF8.self).trim().lowercased()
                    i += 1
                    guard let (a, b) = libxml2ParseNthExpression(arg) else { return nil }
                    let kind: Libxml2NthSelector.Kind
                    switch pseudo {
                    case "nth-child":
                        kind = .child
                    case "nth-last-child":
                        kind = .lastChild
                    case "nth-of-type":
                        kind = .ofType
                    default:
                        kind = .lastOfType
                    }
                    nthSelector = Libxml2NthSelector(kind: kind, a: a, b: b)
                default:
                    return nil
                }
                continue
            }
            return nil
        }

        return Libxml2SimpleSelector(
            tag: tag,
            id: id,
            classes: classes,
            attrs: attrs,
            pseudos: pseudos,
            nth: nthSelector
        )
    }

    private static func libxml2ParseNthExpression(_ arg: String) -> (Int, Int)? {
        if arg == "odd" {
            return (2, 1)
        }
        if arg == "even" {
            return (2, 0)
        }
        let mAB = libxml2NthAB.matcher(in: arg)
        let mB = libxml2NthB.matcher(in: arg)
        if !mAB.matches.isEmpty {
            _ = mAB.find()
            let a = mAB.group(3) != nil
                ? Int(mAB.group(1)!.replaceFirst(of: "^\\+", with: ""))!
                : 1
            let b = mAB.group(4) != nil
                ? Int(mAB.group(4)!.replaceFirst(of: "^\\+", with: ""))!
                : 0
            return (a, b)
        }
        if !mB.matches.isEmpty {
            _ = mB.find()
            let b = Int(mB.group()!.replaceFirst(of: "^\\+", with: ""))!
            return (0, b)
        }
        return nil
    }

    private static func libxml2BuildXPath(_ steps: [(Libxml2Combinator?, Libxml2SimpleSelector)]) -> String? {
        if steps.isEmpty { return nil }
        var parts: [String] = []
        parts.reserveCapacity(steps.count * 2)
        for (index, step) in steps.enumerated() {
            let combinator = step.0
            let selector = step.1
            guard let segment = libxml2XPathSegment(selector) else { return nil }
            if index == 0 {
                parts.append("descendant-or-self::" + segment)
            } else {
                let axis: String
                switch combinator ?? .descendant {
                case .descendant:
                    axis = "descendant::"
                case .child:
                    axis = "child::"
                case .adjacent:
                    axis = "following-sibling::*[1]/self::"
                case .sibling:
                    axis = "following-sibling::"
                }
                parts.append("/" + axis + segment)
            }
        }
        return parts.joined()
    }

    private static func libxml2XPathSegment(_ selector: Libxml2SimpleSelector) -> String? {
        let tag = selector.tag ?? "*"
        if tag.contains(":") { return nil }
        var predicates: [String] = []
        let pseudos = selector.pseudos
        if !pseudos.isEmpty {
            if pseudos.contains(.root) {
                predicates.append("not(parent::*)")
            }
            if pseudos.contains(.empty) {
                predicates.append("not(node())")
            }
            if pseudos.contains(.onlyChild) {
                predicates.append("not(preceding-sibling::*) and not(following-sibling::*)")
            } else {
                if pseudos.contains(.firstChild) {
                    predicates.append("not(preceding-sibling::*)")
                }
                if pseudos.contains(.lastChild) {
                    predicates.append("not(following-sibling::*)")
                }
            }
            if pseudos.contains(.onlyOfType) {
                if tag == "*" { return nil }
                predicates.append("not(preceding-sibling::\(tag)) and not(following-sibling::\(tag))")
            } else {
                if pseudos.contains(.firstOfType) {
                    if tag == "*" { return nil }
                    predicates.append("not(preceding-sibling::\(tag))")
                }
                if pseudos.contains(.lastOfType) {
                    if tag == "*" { return nil }
                    predicates.append("not(following-sibling::\(tag))")
                }
            }
        }
        if let nth = selector.nth {
            let posExpr: String
            switch nth.kind {
            case .child:
                posExpr = "count(preceding-sibling::*) + 1"
            case .lastChild:
                posExpr = "count(following-sibling::*) + 1"
            case .ofType:
                if tag == "*" { return nil }
                posExpr = "count(preceding-sibling::\(tag)) + 1"
            case .lastOfType:
                if tag == "*" { return nil }
                posExpr = "count(following-sibling::\(tag)) + 1"
            }
            predicates.append(libxml2NthPredicate(posExpr: posExpr, a: nth.a, b: nth.b))
        }
        if let id = selector.id {
            let idExpr = libxml2LowercaseExpr("@id")
            predicates.append("\(idExpr) = \(libxml2XPathLiteral(id))")
        }
        if !selector.classes.isEmpty {
            let classExpr = "concat(' ', normalize-space(\(libxml2LowercaseExpr("@class"))), ' ')"
            for cls in selector.classes {
                predicates.append("contains(\(classExpr), \(libxml2XPathLiteral(" " + cls + " ")))")
            }
        }
        for attr in selector.attrs {
            let name = attr.name
            if name.contains(":") { return nil }
            switch attr.op {
            case .exists:
                predicates.append("@\(name)")
            case .equals:
                guard let value = attr.value else { return nil }
                let expr = "normalize-space(\(libxml2LowercaseExpr("@\(name)")))"
                predicates.append("\(expr) = \(libxml2XPathLiteral(value))")
            case .prefix:
                guard let value = attr.value else { return nil }
                let expr = libxml2LowercaseExpr("@\(name)")
                predicates.append("starts-with(\(expr), \(libxml2XPathLiteral(value)))")
            case .suffix:
                guard let value = attr.value else { return nil }
                let expr = libxml2LowercaseExpr("@\(name)")
                let literal = libxml2XPathLiteral(value)
                predicates.append("substring(\(expr), string-length(\(expr)) - string-length(\(literal)) + 1) = \(literal)")
            case .contains:
                guard let value = attr.value else { return nil }
                let expr = libxml2LowercaseExpr("@\(name)")
                predicates.append("contains(\(expr), \(libxml2XPathLiteral(value)))")
            }
        }
        if predicates.isEmpty {
            return tag
        }
        return "\(tag)[\(predicates.joined(separator: " and "))]"
    }

    private static func libxml2NthPredicate(posExpr: String, a: Int, b: Int) -> String {
        if a == 0 {
            return "\(posExpr) = \(b)"
        }
        if a > 0 {
            return "(\(posExpr) >= \(b)) and (((\(posExpr) - \(b)) mod \(a)) = 0)"
        }
        let aAbs = -a
        return "(\(posExpr) <= \(b)) and (((\(b) - \(posExpr)) mod \(aAbs)) = 0)"
    }

    @inline(__always)
    private static func libxml2LowercaseExpr(_ expr: String) -> String {
        return "translate(\(expr), '\(libxml2UpperAscii)', '\(libxml2LowerAscii)')"
    }

    private static func libxml2XPathLiteral(_ value: String) -> String {
        if !value.contains("'") {
            return "'\(value)'"
        }
        if !value.contains("\"") {
            return "\"\(value)\""
        }
        var parts: [String] = []
        var start = value.startIndex
        var i = value.startIndex
        while i < value.endIndex {
            if value[i] == "'" {
                let segment = String(value[start..<i])
                if !segment.isEmpty {
                    parts.append("'\(segment)'")
                }
                parts.append("\"'\"")
                i = value.index(after: i)
                start = i
                continue
            }
            i = value.index(after: i)
        }
        let tail = String(value[start..<value.endIndex])
        if !tail.isEmpty {
            parts.append("'\(tail)'")
        }
        return "concat(\(parts.joined(separator: ", ")))"
    }
#endif

    // exclude set. package open so that Elements can implement .not() selector.
    static func filterOut(_ elements: Array<Element>, _ outs: Array<Element>) -> Elements {
        let output: Elements = Elements()
        for el: Element in elements where !outs.contains(el) {
            output.add(el)
        }
        return output
    }
}
