//
//  CssSelector.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 21/10/16.
//

import Foundation


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
        let lock = NSLock()
    }
    private static let selectorCache = SelectorCache()
    private static let fastQueryCacheCapacity: Int = selectorCacheCapacity
    private final class FastQueryCache: @unchecked Sendable {
        var items: [String: FastQueryPlan] = [:]
        var order: [String] = []
        let lock = NSLock()
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
        #if PROFILE
        let _p = Profiler.start("CssSelector.select")
        defer { Profiler.end("CssSelector.select", _p) }
        #endif
        let query = query.trim()
        try Validate.notEmpty(string: query.utf8Array)
        DebugTrace.log("CssSelector.select(query): \(query)")
        if let cached = root.cachedSelectorResult(query) {
            DebugTrace.log("CssSelector.select(query): selector cache hit")
            return cached
        }
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
        #if PROFILE
        let _p = Profiler.start("CssSelector.select.query")
        defer { Profiler.end("CssSelector.select.query", _p) }
        #endif
        let query = query.trim()
        try Validate.notEmpty(string: query.utf8Array)
        if roots.count == 1, let root = roots.first {
            if let cached = root.cachedSelectorResult(query) {
                #if PROFILE
                let _pHit = Profiler.start("CssSelector.select.resultCache.hit")
                Profiler.end("CssSelector.select.resultCache.hit", _pHit)
                #endif
                return cached
            }
        }
        if let tagBytes = simpleTagQueryBytes(query) {
            #if PROFILE
            let _pSimple = Profiler.start("CssSelector.select.simpleTag")
            defer { Profiler.end("CssSelector.select.simpleTag", _pSimple) }
            #endif
            if roots.count == 1, let root = roots.first {
                #if PROFILE
                let _pLookup = Profiler.start("CssSelector.select.simpleTag.lookup")
                #endif
                let result = try root.getElementsByTagNormalized(tagBytes)
                #if PROFILE
                Profiler.end("CssSelector.select.simpleTag.lookup", _pLookup)
                #endif
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
        if let fast = try fastSelectQuery(query, roots, query) {
            #if PROFILE
            let _pFast = Profiler.start("CssSelector.select.fastQuery")
            Profiler.end("CssSelector.select.fastQuery", _pFast)
            #endif
            if roots.count == 1, let root = roots.first {
                root.storeSelectorResult(query, fast)
            }
            return fast
        }
        #if PROFILE
        let _pEval = Profiler.start("CssSelector.select.evaluator")
        #endif
        let evaluator: Evaluator = try cachedEvaluatorTrimmed(query)
        #if PROFILE
        Profiler.end("CssSelector.select.evaluator", _pEval)
        let _pCollect = Profiler.start("CssSelector.select.collect")
        #endif
        let result = try self.select(evaluator, roots)
        #if PROFILE
        Profiler.end("CssSelector.select.collect", _pCollect)
        #endif
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
            selectorCache.order.append(key)
            if selectorCache.order.count > selectorCacheCapacity {
                let overflow = selectorCache.order.count - selectorCacheCapacity
                if overflow > 0 {
                    for _ in 0..<overflow {
                        let removedKey = selectorCache.order.removeFirst()
                        selectorCache.items.removeValue(forKey: removedKey)
                    }
                }
            }
        }
        selectorCache.lock.unlock()
        return parsed
    }

    private indirect enum FastQueryPlan: Sendable {
        case none
        case all
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
                return root.getElementsByAttributeNormalized(attrBytes)
            case .tagAttr(let tagBytes, let tagId, let attrBytes):
                let attrElements = root.getElementsByAttributeNormalized(attrBytes)
                if attrElements.isEmpty { return attrElements }
                let output = Elements()
                output.reserveCapacity(attrElements.size())
                for el in attrElements.array() where CssSelector.matchesTagBytes(el, tagBytes, tagId) {
                    output.add(el)
                }
                return output
            case .attrValue(let keyBytes, let valueBytes, let key, let value):
                return try root.getElementsByAttributeValueNormalized(keyBytes, valueBytes, key, value)
            case .tagAttrValue(let tagBytes, let tagId, let keyBytes, let valueBytes, let key, let value):
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
                let candidateCount = candidates.size()
                if leftCount <= 8 || candidateCount <= 16 {
                    let leftArray = leftElements.array()
                    let output = Elements()
                    output.reserveCapacity(candidateCount)
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
                leftIds.reserveCapacity(leftCount)
                for el in leftElements.array() {
                    leftIds.insert(ObjectIdentifier(el))
                }
                let output = Elements()
                output.reserveCapacity(candidateCount)
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
        if let lookup = UTF8Arrays.tagLookup[trimmed] {
            return lookup
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(trimmed.utf8.count)
        var sawNonAscii = false
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
                if b >= TokeniserStateVars.asciiUpperLimitByte {
                    sawNonAscii = true
                    break
                }
                return nil
            }
        }
        if sawNonAscii {
            let lowercased = trimmed.lowercased()
            if lowercased != trimmed, let lookup = UTF8Arrays.tagLookup[lowercased] {
                return lookup
            }
            return nil
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
            fastQueryCache.order.append(trimmed)
            if fastQueryCache.order.count > fastQueryCacheCapacity {
                let overflow = fastQueryCache.order.count - fastQueryCacheCapacity
                if overflow > 0 {
                    for _ in 0..<overflow {
                        let removedKey = fastQueryCache.order.removeFirst()
                        fastQueryCache.items.removeValue(forKey: removedKey)
                    }
                }
            }
        }
        fastQueryCache.lock.unlock()
        return plan
    }
    
    private static func fastQueryPlan(_ query: String) -> FastQueryPlan {
        DebugTrace.log("CssSelector.fastQueryPlan: \(query)")
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

    // exclude set. package open so that Elements can implement .not() selector.
    static func filterOut(_ elements: Array<Element>, _ outs: Array<Element>) -> Elements {
        let output: Elements = Elements()
        for el: Element in elements where !outs.contains(el) {
            output.add(el)
        }
        return output
    }
}
