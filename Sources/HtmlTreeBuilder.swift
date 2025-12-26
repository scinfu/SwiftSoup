//
//  HtmlTreeBuilder.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//

import Foundation

/**
 * HTML Tree Builder; creates a DOM from Tokens.
 */
class HtmlTreeBuilder: TreeBuilder {
    enum PendingTableCharacter {
        case slice(ArraySlice<UInt8>)
        case bytes([UInt8])
    }

    private static let useFastStackSearch: Bool = {
        ProcessInfo.processInfo.environment["SWIFTSOUP_DISABLE_STACK_FAST_PATH"] != "1"
    }()
    
    private enum TagSets {
        // tag searches
        static let inScope = ParsingStrings(["applet", "caption", "html", "table", "td", "th", "marquee", "object"])
        static let list = ParsingStrings(["ol", "ul"])
        static let button = ParsingStrings(["button"])
        static let tableScope = ParsingStrings(["html", "table"])
        static let selectScope = ParsingStrings(["optgroup", "option"])
        static let endTags = ParsingStrings(["dd", "dt", "li", "option", "optgroup", "p", "rp", "rt"])
        static let titleTextarea = ParsingStrings(["title", "textarea"])
        static let frames = ParsingStrings(["iframe", "noembed", "noframes", "style", "xmp"])
        
        static let special = ParsingStrings(["address", "applet", "area", "article", "aside", "base", "basefont", "bgsound",
                                             "blockquote", "body", "br", "button", "caption", "center", "col", "colgroup", "command", "dd",
                                             "details", "dir", "div", "dl", "dt", "embed", "fieldset", "figcaption", "figure", "footer", "form",
                                             "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html",
                                             "iframe", "img", "input", "isindex", "li", "link", "listing", "marquee", "menu", "meta", "nav",
                                             "noembed", "noframes", "noscript", "object", "ol", "p", "param", "plaintext", "pre", "script",
                                             "section", "select", "style", "summary", "table", "tbody", "td", "textarea", "tfoot", "th", "thead",
                                             "title", "tr", "ul", "wbr", "xmp"])
    }
    
    private var _state: HtmlTreeBuilderState = HtmlTreeBuilderState.Initial // the current state
    private var _originalState: HtmlTreeBuilderState = HtmlTreeBuilderState.Initial // original / marked state
    
    private var baseUriSetFromDoc: Bool = false
    private var headElement: Element? // the current head element
    private var formElement: FormElement? // the current form element
    private var contextElement: Element? // fragment parse context -- could be null even if fragment parsing
    private var formattingElements: Array<Element?> = Array<Element?>() // active (open) formatting elements
    private var pendingTableCharacters: Array<PendingTableCharacter> =  Array<PendingTableCharacter>() // chars in table to be shifted out
    private var emptyEnd: Token.EndTag = Token.EndTag() // reused empty end tag
    
    private var _framesetOk: Bool = true // if ok to go into frameset
    private var fosterInserts: Bool = false // if next inserts should be fostered
    private var fragmentParsing: Bool = false // if parsing a fragment of html

    
    public override init() {
        super.init()
    }
    
    public override func defaultSettings() -> ParseSettings {
        return ParseSettings.htmlDefault
    }
    
    override func parse(_ input: [UInt8], _ baseUri: [UInt8], _ errors: ParseErrorList, _ settings: ParseSettings) throws -> Document {
        _state = HtmlTreeBuilderState.Initial
        baseUriSetFromDoc = false
        return try super.parse(input, baseUri, errors, settings)
    }
    
    func parseFragment(_ inputFragment: [UInt8], _ context: Element?, _ baseUri: [UInt8], _ errors: ParseErrorList, _ settings: ParseSettings) throws -> Array<Node> {
        // context may be null
        _state = HtmlTreeBuilderState.Initial
        initialiseParse(inputFragment, baseUri, errors, settings)
        contextElement = context
        fragmentParsing = true
        var root: Element? = nil
        
        if let context = context {
            if let d = context.ownerDocument() { // quirks setup:
                doc.quirksMode(d.quirksMode())
            }
            
            // initialise the tokeniser state:
            if TagSets.titleTextarea.contains(context.tagNameUTF8()) || TagSets.frames.contains(context.tagNameUTF8()) {
                tokeniser.transition(TokeniserState.Rcdata)
            } else {
                switch context.tagNameUTF8() {
                case UTF8Arrays.script:
                    tokeniser.transition(TokeniserState.ScriptData)
                case UTF8Arrays.noscript:
                    tokeniser.transition(TokeniserState.Data) // if scripting enabled, rawtext
                case UTF8Arrays.plaintext:
                    tokeniser.transition(TokeniserState.Data)
                default:
                    tokeniser.transition(TokeniserState.Data)
                }
            }
            
            root = try Element(Tag.valueOf(UTF8Arrays.html, settings), baseUri)
            root?.treeBuilder = self
            try Validate.notNull(obj: root)
            try doc.appendChild(root!)
            stack.append(root!)
            resetInsertionMode()
            
            // setup form element to nearest form on context (up ancestor chain). ensures form controls are associated
            // with form correctly
            let contextChain: Elements = context.parents()
            contextChain.add(0, context)
            for parent: Element in contextChain.array() {
                if let x = (parent as? FormElement) {
                    formElement = x
                    break
                }
            }
        }
        
        try runParser()
        if (context != nil && root != nil) {
            return root!.getChildNodes()
        } else {
            return doc.getChildNodes()
        }
    }

    
    @discardableResult
    public override func process(_ token: Token)throws->Bool {
        #if PROFILE
        let _p = Profiler.start("HtmlTreeBuilder.process")
        defer { Profiler.end("HtmlTreeBuilder.process", _p) }
        #endif
        let trackToken = tracksErrors || (tracksSourceRanges && token.type == Token.TokenType.EndTag)
        if trackToken {
            currentToken = token
        } else if tracksSourceRanges {
            currentToken = nil
        }
        return try self._state.process(token, self)
    }
    
    @discardableResult
    func process(_ token: Token, _ state: HtmlTreeBuilderState)throws->Bool {
        #if PROFILE
        let _p = Profiler.start("HtmlTreeBuilder.process.state")
        defer { Profiler.end("HtmlTreeBuilder.process.state", _p) }
        #endif
        let trackToken = tracksErrors || (tracksSourceRanges && token.type == Token.TokenType.EndTag)
        if trackToken {
            currentToken = token
        } else if tracksSourceRanges {
            currentToken = nil
        }
        return try state.process(token, self)
    }
    
    func transition(_ state: HtmlTreeBuilderState) {
        self._state = state
    }

    @inline(__always)
    func markStructuralChange(_ node: Node? = nil) {
        (node ?? currentElement())?.markSourceDirty(force: true)
    }
    
    func state() -> HtmlTreeBuilderState {
        return _state
    }
    
    func markInsertionMode() {
        _originalState = _state
    }


    
    func originalState() -> HtmlTreeBuilderState {
        return _originalState
    }
    
    func framesetOk(_ framesetOk: Bool) {
        self._framesetOk = framesetOk
    }
    
    func framesetOk() -> Bool {
        return _framesetOk
    }
    
    func getDocument() -> Document {
        return doc
    }
    
    func getBaseUri() -> [UInt8] {
        return baseUri
    }
    
    func maybeSetBaseUri(_ base: Element) throws {
        if (baseUriSetFromDoc) { // only listen to the first <base href> in parse
            return
        }
        
        let href: [UInt8] = try base.absUrl(UTF8Arrays.href)
        if (!href.isEmpty) { // ignore <base target> etc
            baseUri = href
            baseUriSetFromDoc = true
            try doc.setBaseUri(href) // set on the doc so doc.createElement(Tag) will get updated base, and to update all descendants
        }
    }
    
    func isFragmentParsing() -> Bool {
        return fragmentParsing
    }
    
    func error(_ state: HtmlTreeBuilderState) {
        if (tracksErrors && errors.canAddError() && currentToken != nil) {
            errors.add(ParseError(reader.getPos(), "Unexpected token [\(currentToken!.tokenType())] when in state [\(state.rawValue)]"))
        }
    }
    
    @inlinable
    @discardableResult
    func insert(_ startTag: Token.StartTag) throws -> Element {
        #if PROFILE
        let _p = Profiler.start("HtmlTreeBuilder.insert.startTag")
        defer { Profiler.end("HtmlTreeBuilder.insert.startTag", _p) }
        #endif
        // handle empty unknown tags
        // when the spec expects an empty tag, will directly hit insertEmpty, so won't generate this fake end tag.
        let isSelfClosing = startTag.isSelfClosing()
        if isSelfClosing {
            let el: Element = try insertEmpty(startTag)
            stack.append(el)
            tokeniser.transition(TokeniserState.Data) // handles <script />, otherwise needs breakout steps from script data
            try tokeniser.emit(emptyEnd.reset().name(el.tagNameUTF8()))  // ensure we get out of whatever state we are in. emitted for yielded processing
            return el
        }
        if startTag.hasAnyAttributes() {
            startTag.ensureAttributes()
        }
        // Resolve tag once and avoid normalizeAttributes when there are no attrs.
        let tag: Tag
        if settings.preservesTagCase() {
            tag = try Tag.valueOf(startTag.name(), settings)
        } else if let fastTag = Tag.valueOfTagId(startTag.tagId) {
            tag = fastTag
        } else if let normalName = startTag.normalName() {
            tag = try Tag.valueOfNormalized(normalName, isSelfClosing: isSelfClosing)
        } else {
            tag = try Tag.valueOf(startTag.name(), settings)
        }
        let skipChildReserve = isBulkBuilding
        let el: Element
        if let attributes = startTag._attributes {
            if attributes.attributes.isEmpty && attributes.pendingAttributesCount == 0 {
                el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
            } else {
                if startTag.attributesAreNormalized() || settings.preservesAttributeCase() || !startTag.hasUppercaseAttributeNames() {
                    el = Element(tag, baseUri, attributes, skipChildReserve: skipChildReserve)
                } else {
                    el = try Element(tag, baseUri, settings.normalizeAttributes(attributes), skipChildReserve: skipChildReserve)
                }
            }
        } else {
            el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
        }
        el.treeBuilder = self
        if let range = startTag.sourceRange {
            el.setSourceRange(range, complete: false)
        }
        try insert(el)
        return el
    }
    
    @discardableResult
    func insertStartTag(_ startTagName: [UInt8]) throws -> Element {
        let tag: Tag
        if settings.preservesTagCase() {
            tag = try Tag.valueOf(startTagName, settings)
        } else {
            tag = try Tag.valueOfNormalized(startTagName)
        }
        let el: Element = Element(tag, baseUri, skipChildReserve: isBulkBuilding)
        el.treeBuilder = self
        markStructuralChange(el)
        try insert(el)
        return el
    }
    
    @inlinable
    func insert(_ el: Element) throws {
        #if PROFILE
        let _p = Profiler.start("HtmlTreeBuilder.insert.element")
        defer { Profiler.end("HtmlTreeBuilder.insert.element", _p) }
        #endif
        try insertNode(el)
        stack.append(el)
    }
    
    @discardableResult
    func insertEmpty(_ startTag: Token.StartTag) throws -> Element {
        if startTag.hasPendingAttributes() {
            startTag.ensureAttributes()
        }
        // For unknown tags, remember this is self closing for output
        let isSelfClosing = startTag.isSelfClosing()
        let tag: Tag
        if settings.preservesTagCase() {
            tag = try Tag.valueOf(startTag.name(), settings, isSelfClosing: isSelfClosing)
        } else if let fastTag = Tag.valueOfTagId(startTag.tagId) {
            tag = fastTag
        } else if let normalName = startTag.normalName() {
            tag = try Tag.valueOfNormalized(normalName, isSelfClosing: isSelfClosing)
        } else {
            tag = try Tag.valueOf(startTag.name(), settings, isSelfClosing: isSelfClosing)
        }
        let skipChildReserve = isSelfClosing || isBulkBuilding
        let el: Element
        if let attributes = startTag._attributes {
            if attributes.attributes.isEmpty && attributes.pendingAttributesCount == 0 {
                el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
            } else if startTag.attributesAreNormalized() || settings.preservesAttributeCase() || !startTag.hasUppercaseAttributeNames() {
                el = Element(tag, baseUri, attributes, skipChildReserve: skipChildReserve)
            } else {
                el = try Element(tag, baseUri, settings.normalizeAttributes(attributes), skipChildReserve: skipChildReserve)
            }
        } else {
            el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
        }
        el.treeBuilder = self
        if let range = startTag.sourceRange {
            el.setSourceRange(range, complete: true)
        }
        try insertNode(el)
        if isSelfClosing, tag.isSelfClosing() {
            // if not acked, promulagates error
            tokeniser.acknowledgeSelfClosingFlag()
        }
        return el
    }
    
    @discardableResult
    func insertForm(_ startTag: Token.StartTag, _ onStack: Bool) throws -> FormElement {
        if startTag.hasPendingAttributes() {
            startTag.ensureAttributes()
        }
        let tag: Tag = try Tag.valueOf(startTag.name(), settings)
        let el: FormElement
        if let attributes = startTag._attributes {
            el = FormElement(tag, baseUri, attributes, skipChildReserve: isBulkBuilding)
        } else {
            el = FormElement(tag, baseUri, skipChildReserve: isBulkBuilding)
        }
        setFormElement(el)
        if let range = startTag.sourceRange {
            el.setSourceRange(range, complete: false)
        }
        try insertNode(el)
        if (onStack) {
            stack.append(el)
        }
        return el
    }

    
    func insert(_ commentToken: Token.Comment) throws {
        let comment: Comment = Comment(commentToken.getData(), baseUri)
        if let range = commentToken.sourceRange {
            comment.setSourceRange(range, complete: true)
        }
        try insertNode(comment)
    }
    
    @inlinable
    func insert(_ characterToken: Token.Char) throws {
        #if PROFILE
        let _p = Profiler.start("HtmlTreeBuilder.insert.char")
        defer { Profiler.end("HtmlTreeBuilder.insert.char", _p) }
        #endif
        let current = currentElement()
        let currentTag = current?._tag
        let node: Node
        let useSlice: ArraySlice<UInt8>?
        if !tracksSourceRanges {
            useSlice = characterToken.getDataSlice()
        } else if let tokenSlice = characterToken.getDataSlice() {
            useSlice = tokenSlice
        } else if let range = characterToken.sourceRange,
                  let source = doc.sourceBuffer?.bytes,
                  range.isValid,
                  range.end <= source.count {
            useSlice = source[range.start..<range.end]
        } else {
            useSlice = nil
        }
        // characters in script and style go in as datanodes, not text nodes
        if let currentTag, Tag.isScriptOrStyle(currentTag) {
            if let slice = useSlice {
                node = DataNode(slice: slice, baseUri: baseUri)
            } else {
                try Validate.notNull(obj: characterToken.getData())
                let data = characterToken.getData()!
                node = DataNode(data, baseUri)
            }
        } else {
            if let slice = useSlice {
                node = TextNode(slice: slice, baseUri: baseUri)
            } else {
                try Validate.notNull(obj: characterToken.getData())
                let data = characterToken.getData()!
                node = TextNode(data, baseUri)
            }
        }
        if tracksSourceRanges, let range = characterToken.sourceRange {
            node.setSourceRange(range, complete: true)
        }
        if tracksSourceRanges, node.sourceBuffer == nil {
            node.sourceBuffer = doc.sourceBuffer
        }
        node.treeBuilder = self
        if let current, !isFosterInserts(), isBulkBuilding, node.parentNode == nil {
            if !tracksSourceRanges,
               let textNode = node as? TextNode,
               let lastText = current.childNodes.last as? TextNode {
                // Coalesce adjacent text nodes during bulk parsing.
                lastText.appendSlice(textNode.wholeTextSlice())
                return
            }
            current.childNodes.append(node)
            node.parentNode = current
            node.setSiblingIndex(current.childNodes.count - 1)
        } else {
            try current?.appendChild(node) // doesn't use insertNode, because we don't foster these; and will always have a stack.
        }
    }
    
    @inlinable
    internal func insertNode(_ node: Node) throws {
        #if PROFILE
        let _p = Profiler.start("HtmlTreeBuilder.insert.node")
        defer { Profiler.end("HtmlTreeBuilder.insert.node", _p) }
        #endif
        // if the stack hasn't been set up yet, elements (doctype, comments) go into the doc
        if stack.isEmpty {
            try doc.appendChild(node)
        } else if (isFosterInserts()) {
            try insertInFosterParent(node)
        } else if let current = currentElement() {
            if isBulkBuilding, node.parentNode == nil {
                node.parentNode = current
                current.childNodes.append(node)
                node.setSiblingIndex(current.childNodes.count - 1)
            } else {
                try current.appendChild(node)
            }
        }
        node.treeBuilder = self
        if tracksSourceRanges, node.sourceBuffer == nil {
            node.sourceBuffer = doc.sourceBuffer
        }
        
        // connect form controls to their form element
        if let n = (node as? Element), n.tag().isFormListed() {
            formElement?.addElement(n)
        }
    }
    
    @discardableResult
    func pop() -> Element {
        let element = stack.removeLast()
        if tracksSourceRanges,
           let endTag = currentToken as? Token.EndTag,
           let endRange = endTag.sourceRange,
           let endName = endTag.normalName(),
           endName == element.nodeNameUTF8() {
            element.setSourceRangeEnd(endRange.end)
        }
        return element
    }
    
    @inlinable
    func push(_ element: Element) {
        stack.append(element)
    }
    
    @inlinable
    func getStack()->Array<Element> {
        return stack
    }
    
    @discardableResult
    func onStack(_ el: Element) -> Bool {
        return isElementInQueue(stack, el)
    }
    
    private func isElementInQueue(_ queue: Array<Element?>, _ element: Element?) -> Bool {
        guard let element else { return false }
        if !Self.useFastStackSearch {
            return queue.reversed().contains(element)
        }
        var i = queue.count
        while i > 0 {
            i &-= 1
            if let candidate = queue[i], candidate == element {
                return true
            }
        }
        return false
    }

    @inline(__always)
    private func lastIndexOfStackName(_ elName: [UInt8]) -> Int? {
        if !Self.useFastStackSearch {
            return stack.lastIndex(where: { $0.nodeNameUTF8() == elName })
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            if stack[i].nodeNameUTF8() == elName {
                return i
            }
        }
        return nil
    }

    @inline(__always)
    private func lastIndexOfStackName(in names: ParsingStrings) -> Int? {
        if !Self.useFastStackSearch {
            return stack.lastIndex(where: { names.contains($0.nodeNameUTF8()) })
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            if names.contains(stack[i].nodeNameUTF8()) {
                return i
            }
        }
        return nil
    }

    @inline(__always)
    private func lastIndexOfStackName(in names: [[UInt8]]) -> Int? {
        if !Self.useFastStackSearch {
            return stack.lastIndex(where: { names.contains($0.nodeNameUTF8()) })
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            if names.contains(stack[i].nodeNameUTF8()) {
                return i
            }
        }
        return nil
    }

    @inline(__always)
    private func lastIndexOfStackName(in names: Set<[UInt8]>) -> Int? {
        if !Self.useFastStackSearch {
            return stack.lastIndex(where: { names.contains($0.nodeNameUTF8()) })
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            if names.contains(stack[i].nodeNameUTF8()) {
                return i
            }
        }
        return nil
    }

    @inline(__always)
    private func lastIndexOfStackElement(_ element: Element) -> Int? {
        if !Self.useFastStackSearch {
            return stack.lastIndex(of: element)
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            if stack[i] == element {
                return i
            }
        }
        return nil
    }
    
    func getFromStack(_ elName: [UInt8]) -> Element? {
        guard let index = lastIndexOfStackName(elName) else { return nil }
        return stack[index]
    }
    
    @inlinable
    func getFromStack(_ elName: String) -> Element? {
        return getFromStack(elName.utf8Array)
    }
    
    @discardableResult
    func removeFromStack(_ el: Element) -> Bool {
        if let index = lastIndexOfStackElement(el) {
            stack.remove(at: index)
            return true
        }
        return false
    }
    
    func popStackToClose(_ elName: [UInt8]) {
        if let index = lastIndexOfStackName(elName) {
            if tracksSourceRanges,
               let endTag = currentToken as? Token.EndTag,
               let endRange = endTag.sourceRange,
               let endName = endTag.normalName(),
               endName == elName {
                stack[index].setSourceRangeEnd(endRange.end)
            }
            stack.removeSubrange(index..<stack.count)
        }
    }

    
    func popStackToClose(_ elName: ParsingStrings) {
        if let index = lastIndexOfStackName(in: elName) {
            stack.removeSubrange(index..<stack.count)
        }
    }
    
    func popStackToClose(_ elNames: [UInt8]...) {
        popStackToClose(elNames)
    }
    
    func popStackToClose(_ elNames: [[UInt8]]) {
        if let index = lastIndexOfStackName(in: elNames) {
            stack.removeSubrange(index..<stack.count)
        }
    }
    
    func popStackToClose(_ elNames: Set<[UInt8]>) {
        if let index = lastIndexOfStackName(in: elNames) {
            stack.removeSubrange(index..<stack.count)
        }
    }
    
    func popStackToBefore(_ elName: [UInt8]) {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if (next.nodeNameUTF8() == elName) {
                break
            } else {
                stack.remove(at: pos)
            }
        }
    }
    
    func clearStackToTableContext() {
        clearStackToContext(UTF8Arrays.table)
    }
    
    func clearStackToTableBodyContext() {
        clearStackToContext(UTF8Arrays.tbody, UTF8Arrays.tfoot, UTF8Arrays.thead)
    }
    
    func clearStackToTableRowContext() {
        clearStackToContext(UTF8Arrays.tr)
    }
    
    private func clearStackToContext(_ nodeNames: [UInt8]...) {
        clearStackToContext(nodeNames)
    }
    
    private func clearStackToContext(_ nodeNames: [[UInt8]]) {
        let index: Int? = {
            if !Self.useFastStackSearch {
                return stack.lastIndex {
                    let nextName = $0.nodeNameUTF8()
                    return nodeNames.contains(nextName) || nextName == UTF8Arrays.html
                }
            }
            var i = stack.count
            while i > 0 {
                i &-= 1
                let nextName = stack[i].nodeNameUTF8()
                if nodeNames.contains(nextName) || nextName == UTF8Arrays.html {
                    return i
                }
            }
            return nil
        }()
        
        guard let index else {
            stack.removeAll()
            return
        }
        
        stack.removeSubrange(stack.index(after: index) ..< stack.endIndex)
    }
    
    func aboveOnStack(_ el: Element) -> Element? {
        //assert(onStack(el), "Invalid parameter")
        onStack(el)
        
        guard let index = lastIndexOfStackElement(el) else {
            return nil
        }
        
        let before = stack.index(before: index)
        guard before >= stack.startIndex else {
            return nil
        }
        
        return stack[before]
    }
    
    func insertOnStackAfter(_ after: Element, _ input: Element)throws {
        guard let index = lastIndexOfStackElement(after) else {
            try Validate.fail(msg: "Element not found")
            return
        }
        
        stack.insert(input, at: stack.index(after: index))
    }
    
    func replaceOnStack(_ out: Element, _ input: Element)throws {
        try stack = replaceInQueue(stack, out, input)
    }
    
    private func replaceInQueue(_ queue: Array<Element>, _ out: Element, _ input: Element)throws->Array<Element> {
        if !Self.useFastStackSearch {
            guard let index = queue.lastIndex(of: out) else {
                try Validate.fail(msg: "Element not found")
                return [] // Not reached
            }
            var queue = queue
            queue[index] = input
            return queue
        }
        var i = queue.count
        while i > 0 {
            i &-= 1
            if queue[i] == out {
                var queue = queue
                queue[i] = input
                return queue
            }
        }
        try Validate.fail(msg: "Element not found")
        return [] // Not reached
    }
    
    private func replaceInQueue(_ queue: Array<Element?>, _ out: Element, _ input: Element)throws->Array<Element?> {
        var queue = queue
        if !Self.useFastStackSearch {
            if let index = queue.lastIndex(of: out) {
                queue[index] = input
                return queue
            } else {
                try Validate.fail(msg: "Element to replace not found")
                return queue
            }
        }
        var i = queue.count
        while i > 0 {
            i &-= 1
            if queue[i] == out {
                queue[i] = input
                return queue
            }
        }
        try Validate.fail(msg: "Element to replace not found")
        return queue
    }
    
    func resetInsertionMode() {
        var last = false
        for pos in (0..<stack.count).reversed() {
            var node: Element = stack[pos]
            if (pos == 0) {
                last = true
                //Validate node
                node = contextElement!
            }
            let name: String = String(decoding: node.nodeNameUTF8(), as: UTF8.self)
            if ("select".equals(name)) {
                transition(HtmlTreeBuilderState.InSelect)
                break // frag
            } else if (("td".equals(name) || "th".equals(name) && !last)) {
                transition(HtmlTreeBuilderState.InCell)
                break
            } else if ("tr".equals(name)) {
                transition(HtmlTreeBuilderState.InRow)
                break
            } else if ("tbody".equals(name) || "thead".equals(name) || "tfoot".equals(name)) {
                transition(HtmlTreeBuilderState.InTableBody)
                break
            } else if ("caption".equals(name)) {
                transition(HtmlTreeBuilderState.InCaption)
                break
            } else if ("colgroup".equals(name)) {
                transition(HtmlTreeBuilderState.InColumnGroup)
                break // frag
            } else if ("table".equals(name)) {
                transition(HtmlTreeBuilderState.InTable)
                break
            } else if ("head".equals(name)) {
                transition(HtmlTreeBuilderState.InBody)
                break // frag
            } else if ("body".equals(name)) {
                transition(HtmlTreeBuilderState.InBody)
                break
            } else if ("frameset".equals(name)) {
                transition(HtmlTreeBuilderState.InFrameset)
                break // frag
            } else if ("html".equals(name)) {
                transition(HtmlTreeBuilderState.BeforeHead)
                break // frag
            } else if (last) {
                transition(HtmlTreeBuilderState.InBody)
                break // frag
            }
        }
    }
    
    private func inSpecificScope(_ targetName: [UInt8], _ baseTypes: ParsingStrings, _ extraTypes: ParsingStrings? = nil) throws -> Bool {
        if !Self.useFastStackSearch {
            for el in stack.reversed() {
                let elName = el.nodeNameUTF8()
                if elName == targetName {
                    return true
                }
                if baseTypes.contains(elName) {
                    return false
                }
                if let extraTypes = extraTypes, extraTypes.contains(elName) {
                    return false
                }
            }
            try Validate.fail(msg: "Should not be reachable")
            return false
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            let elName = stack[i].nodeNameUTF8()
            if elName == targetName {
                return true
            }
            if baseTypes.contains(elName) {
                return false
            }
            if let extraTypes = extraTypes, extraTypes.contains(elName) {
                return false
            }
        }
        try Validate.fail(msg: "Should not be reachable")
        return false
    }

    
    private func inSpecificScope(_ targetNames: Set<[UInt8]>, _ baseTypes: ParsingStrings, _ extraTypes: ParsingStrings? = nil) throws -> Bool {
        if !Self.useFastStackSearch {
            for el in stack.reversed() {
                let elName = el.nodeNameUTF8()
                if targetNames.contains(elName) {
                    return true
                }
                if baseTypes.contains(elName) {
                    return false
                }
                if let extraTypes = extraTypes, extraTypes.contains(elName) {
                    return false
                }
            }
            try Validate.fail(msg: "Should not be reachable")
            return false
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            let elName = stack[i].nodeNameUTF8()
            if targetNames.contains(elName) {
                return true
            }
            if baseTypes.contains(elName) {
                return false
            }
            if let extraTypes = extraTypes, extraTypes.contains(elName) {
                return false
            }
        }
        try Validate.fail(msg: "Should not be reachable")
        return false
    }
    
    private func inSpecificScope(_ targetNames: ParsingStrings, _ baseTypes: ParsingStrings, _ extraTypes: ParsingStrings? = nil) throws -> Bool {
        if !Self.useFastStackSearch {
            for el in stack.reversed() {
                let elName = el.nodeNameUTF8()
                if targetNames.contains(elName) {
                    return true
                }
                if baseTypes.contains(elName) {
                    return false
                }
                if let extraTypes = extraTypes, extraTypes.contains(elName) {
                    return false
                }
            }
            try Validate.fail(msg: "Should not be reachable")
            return false
        }
        var i = stack.count
        while i > 0 {
            i &-= 1
            let elName = stack[i].nodeNameUTF8()
            if targetNames.contains(elName) {
                return true
            }
            if baseTypes.contains(elName) {
                return false
            }
            if let extraTypes = extraTypes, extraTypes.contains(elName) {
                return false
            }
        }
        try Validate.fail(msg: "Should not be reachable")
        return false
    }
    
    
    func inScope(_ targetNames: ParsingStrings) throws -> Bool {
        return try inSpecificScope(targetNames, TagSets.inScope)
    }
    
    func inScope(_ targetNames: Set<[UInt8]>) throws -> Bool {
        return try inSpecificScope(targetNames, TagSets.inScope)
    }
    
    func inScope(_ targetNames: Set<String>) throws -> Bool {
        return try inScope(Set(targetNames.map { $0.utf8Array }))
    }
    
    func inScope(_ targetName: [UInt8], _ extras: ParsingStrings? = nil) throws -> Bool {
        return try inSpecificScope(targetName, TagSets.inScope, extras)
        // todo: in mathml namespace: mi, mo, mn, ms, mtext annotation-xml
        // todo: in svg namespace: forignOjbect, desc, title
    }

    
    func inScope(_ targetName: String, _ extras: ParsingStrings? = nil) throws -> Bool {
        if let extras {
            return try inScope(targetName.utf8Array, extras)
        }
        return try inScope(targetName.utf8Array)
    }
    
    func inListItemScope(_ targetName: [UInt8]) throws -> Bool {
        return try inScope(targetName, TagSets.list)
    }

    
    func inButtonScope(_ targetName: [UInt8]) throws -> Bool {
        return try inScope(targetName, TagSets.button)
    }

    
    func inButtonScope(_ targetName: String) throws -> Bool {
        return try inButtonScope(targetName.utf8Array)
    }
    
    func inTableScope(_ targetName: [UInt8]) throws -> Bool {
        return try inSpecificScope(targetName, TagSets.tableScope)
    }

    
    func inTableScope(_ targetName: String) throws -> Bool {
        return try inSpecificScope(targetName.utf8Array, TagSets.tableScope)
    }
    
    func inSelectScope(_ targetName: [UInt8]) throws -> Bool {
        for el in stack.reversed() {
            let elName = el.nodeNameUTF8()
            if elName == targetName {
                return true
            }
            if !TagSets.selectScope.contains(elName) {
                return false
            }
        }
        try Validate.fail(msg: "Should not be reachable")
        return false
    }
    
    func setHeadElement(_ headElement: Element) {
        self.headElement = headElement
    }
    
    func getHeadElement() -> Element? {
        return headElement
    }
    
    @inlinable
    func isFosterInserts() -> Bool {
        return fosterInserts
    }
    
    func setFosterInserts(_ fosterInserts: Bool) {
        self.fosterInserts = fosterInserts
    }
    
    func getFormElement() -> FormElement? {
        return formElement
    }
    
    func setFormElement(_ formElement: FormElement?) {
        self.formElement = formElement
    }
    
    func newPendingTableCharacters() {
        pendingTableCharacters.removeAll(keepingCapacity: true)
    }
    
    @inline(__always)
    func appendPendingTableCharacter(_ character: PendingTableCharacter) {
        pendingTableCharacters.append(character)
    }
    
    @inline(__always)
    func pendingTableCharactersIsEmpty() -> Bool {
        return pendingTableCharacters.isEmpty
    }
    
    func takePendingTableCharacters() -> Array<PendingTableCharacter> {
        let pending = pendingTableCharacters
        pendingTableCharacters.removeAll(keepingCapacity: true)
        return pending
    }
    
    /**
     11.2.5.2 Closing elements that have implied end tags
     
     When the steps below require the UA to generate implied end tags, then, while the current node is a dd element, a
     dt element, an li element, an option element, an optgroup element, a p element, an rp element, or an rt element,
     the UA must pop the current node off the stack of open elements.
     
     - parameter excludeTag: If a step requires the UA to generate implied end tags but lists an element to exclude from the
     process, then the UA must perform the above steps as if that element was not in the above list.
     */
    
    func generateImpliedEndTags(_ excludeTag: [UInt8]? = nil) {
        // Is this correct? I get the sense that something is supposed to happen here
        // even if excludeTag == nil. But the original code doesn't seem to do that. -GS
        //
        // while ((excludeTag != nil && !currentElement()!.nodeName().equals(excludeTag!)) &&
        //    StringUtil.inString(currentElement()!.nodeName(), HtmlTreeBuilder.TagSearchEndTags)) {
        //        pop()
        // }
        guard let excludeTag = excludeTag else { return }
        let excludeTagId = Token.Tag.tagIdForBytes(excludeTag)
        markStructuralChange(currentElement())
        while true {
            let current = currentElement()!
            let tagId = current._tag.tagId
            if let excludeTagId, tagId != .none {
                guard tagId != excludeTagId else { return }
            } else {
                let nodeName = current.nodeNameUTF8()
                guard nodeName != excludeTag else { return }
            }
            if tagId != .none {
                guard TagSets.endTags.containsTagId(tagId) else { return }
            } else {
                guard TagSets.endTags.contains(current.nodeNameUTF8()) else { return }
            }
            pop()
        }
    }

    
    func isSpecial(_ el: Element) -> Bool {
        // todo: mathml's mi, mo, mn
        // todo: svg's foreigObject, desc, title
        let tagId = el._tag.tagId
        if tagId != .none, TagSets.special.containsTagId(tagId) {
            return true
        }
        return TagSets.special.contains(el.nodeNameUTF8())
    }
    
    func lastFormattingElement() -> Element? {
        return formattingElements.last ?? nil
    }
    
    func removeLastFormattingElement() -> Element? {
        return formattingElements.removeLast()
    }
    
    // active formatting elements
    func pushActiveFormattingElements(_ input: Element) {
        var numSeen: Int = 0
        for pos in (0..<formattingElements.count).reversed() {
            let el: Element? = formattingElements[pos]
            if (el == nil) { // marker
                break
            }
            
            if (isSameFormattingElement(input, el!)) {
                numSeen += 1
            }
            
            if (numSeen == 3) {
                formattingElements.remove(at: pos)
                break
            }
        }
        formattingElements.append(input)
    }
    
    private func isSameFormattingElement(_ a: Element, _ b: Element) -> Bool {
        // same if: same namespace, tag, and attributes. Element.equals only checks tag, might in future check children
        let aAttrs = a.getAttributes()
        let bAttrs = b.getAttributes()
        if aAttrs == nil || bAttrs == nil {
            return aAttrs == nil && bAttrs == nil && a.nodeNameUTF8() == b.nodeNameUTF8()
        }
        
        return a.nodeNameUTF8() == b.nodeNameUTF8() &&
        // a.namespace().equals(b.namespace()) &&
        aAttrs!.equals(o: bAttrs!)
        // todo: namespaces
    }
    
    func reconstructFormattingElements() throws {
        let last: Element? = lastFormattingElement()
        if (last == nil || onStack(last!)) {
            return
        }
        
        var entry: Element? = last
        let size: Int = formattingElements.count
        var pos: Int = size - 1
        var skip: Bool = false
        while (true) {
            if (pos == 0) { // step 4. if none before, skip to 8
                skip = true
                break
            }
            pos -= 1
            entry = formattingElements[pos] // step 5. one earlier than entry
            if (entry == nil || onStack(entry!)) // step 6 - neither marker nor on stack
            {break} // jump to 8, else continue back to 4
        }
        while(true) {
            if (!skip) // step 7: on later than entry
            {
                pos += 1
                entry = formattingElements[pos]
            }
            try Validate.notNull(obj: entry) // should not occur, as we break at last element
            
            // 8. create new element from element, 9 insert into current node, onto stack
            skip = false // can only skip increment from 4.
            let newEl: Element = try insertStartTag(entry!.nodeNameUTF8()) // todo: avoid fostering here?
                                                                           // newEl.namespace(entry.namespace()) // todo: namespaces
            newEl.getAttributes()?.addAll(incoming: entry!.getAttributes())
            
            // 10. replace entry with new entry
            formattingElements[pos] = newEl
            
            // 11
            if (pos == size-1) // if not last entry in list, jump to 7
            {break}
        }
    }
    
    func clearFormattingElementsToLastMarker() {
        while (!formattingElements.isEmpty) {
            let el: Element? = removeLastFormattingElement()
            if (el == nil) {
                break
            }
        }
    }
    
    func removeFromActiveFormattingElements(_ el: Element?) {
        guard let index = formattingElements.lastIndex(of: el) else {
            return
        }
        
        formattingElements.remove(at: index)
    }
    
    func isInActiveFormattingElements(_ el: Element) -> Bool {
        return isElementInQueue(formattingElements, el)
    }
    
    func getActiveFormattingElement(_ nodeName: [UInt8]) -> Element? {
        for next in formattingElements.reversed() {
            if (next == nil) { // scope marker
                break
            } else if next!.nodeNameUTF8() == nodeName {
                return next
            }
        }
        return nil
    }
    
    func replaceActiveFormattingElement(_ out: Element, _ input: Element) throws {
        try formattingElements = replaceInQueue(formattingElements, out, input)
    }
    
    func insertMarkerToFormattingElements() {
        formattingElements.append(nil)
    }
    
    func insertInFosterParent(_ input: Node) throws {
        let fosterParent: Element?
        let lastTable: Element? = getFromStack(UTF8Arrays.table)
        var isLastTableParent: Bool = false
        if let lastTable = lastTable {
            if (lastTable.parent() != nil) {
                fosterParent = lastTable.parent()!
                isLastTableParent = true
            } else {
                fosterParent = aboveOnStack(lastTable)
            }
        } else { // no table == frag
            fosterParent = stack[0]
        }
        
        if (isLastTableParent) {
            try Validate.notNull(obj: lastTable) // last table cannot be null by this point.
            try lastTable!.before(input)
        } else {
            try fosterParent?.appendChild(input)
        }
    }
}

fileprivate func ~= (pattern: [String], value: String) -> Bool {
    return pattern.contains(value)
}
