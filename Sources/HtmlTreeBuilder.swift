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
        case slice(ByteSlice)
        case bytes([UInt8])
    }

    
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
    
    private enum StackContexts {
        static let table = ParsingStrings(["table"])
        static let tableBody = ParsingStrings(["tbody", "tfoot", "thead"])
        static let tableRow = ParsingStrings(["tr"])
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

    private var stackTrackingDirty: Bool = false
    private var stackUnknownTagIdCount: Int = 0
    private var stackTagIdP: [Int] = []
    private var stackTagIdButton: [Int] = []

    
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

    override func initialiseParse(_ input: [UInt8], _ baseUri: [UInt8], _ errors: ParseErrorList, _ settings: ParseSettings) {
        super.initialiseParse(input, baseUri, errors, settings)
        resetStackTracking()
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
            push(root!)
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
        if !tracksErrors, !tracksSourceRanges, _state == .InBody {
            switch token.type {
            case .Char:
                let c = token.asCharacter()
                let data = c.getDataSlice()
                if let data, data.count == 1, data.first == TokeniserStateVars.nullByte {
                    return false
                }
                let wasFramesetOk = framesetOk()
                let isWhitespace = wasFramesetOk ? HtmlTreeBuilderState.isWhitespace(data) : false
                if lastFormattingElement() != nil {
                    try reconstructFormattingElements()
                }
                try insert(c)
                if wasFramesetOk && !isWhitespace {
                    framesetOk(false)
                }
                return true
            case .Comment:
                try insert(token.asComment())
                return true
            default:
                break
            }
        }
        if !tracksErrors && !tracksSourceRanges {
            return try self._state.process(token, self)
        }
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
        if !tracksErrors && !tracksSourceRanges {
            return try state.process(token, self)
        }
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
            push(el)
            tokeniser.transition(TokeniserState.Data) // handles <script />, otherwise needs breakout steps from script data
            try tokeniser.emit(emptyEnd.reset().name(el.tagNameUTF8()))  // ensure we get out of whatever state we are in. emitted for yielded processing
            return el
        }
        let hasAttributes = startTag.hasAnyAttributes()
        if hasAttributes {
            startTag.ensureAttributes()
        }
        // Resolve tag once and avoid normalizeAttributes when there are no attrs.
        let tag: Tag = try startTag.resolveTag(settings, isSelfClosing: isSelfClosing)
        let skipChildReserve = isBulkBuilding || !hasAttributes
        let el: Element
        if hasAttributes {
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
        } else {
            el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
        }
        if hasAttributes {
            registerPendingAttributes(el)
        }
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
        } else if let tagId = Token.Tag.tagIdForBytes(startTagName),
                  let fastTag = Tag.valueOfTagId(tagId) {
            tag = fastTag
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
        push(el)
    }
    
    @discardableResult
    func insertEmpty(_ startTag: Token.StartTag) throws -> Element {
        let hasAttributes = startTag.hasAnyAttributes()
        if hasAttributes {
            startTag.ensureAttributes()
        }
        // For unknown tags, remember this is self closing for output
        let isSelfClosing = startTag.isSelfClosing()
        let tag: Tag = try startTag.resolveTag(settings, isSelfClosing: isSelfClosing)
        let skipChildReserve = isSelfClosing || isBulkBuilding || !hasAttributes
        let el: Element
        if hasAttributes {
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
        } else {
            el = Element(tag, baseUri, skipChildReserve: skipChildReserve)
        }
        if hasAttributes {
            registerPendingAttributes(el)
        }
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
        if startTag.hasAnyAttributes() {
            startTag.ensureAttributes()
        }
        let tag: Tag
        if settings.preservesTagCase() {
            tag = try Tag.valueOf(startTag.name(), settings)
        } else if let fastTag = Tag.valueOfTagId(startTag.tagId) {
            tag = fastTag
        } else if let normalName = startTag.normalName() {
            tag = try Tag.valueOfNormalized(normalName)
        } else {
            tag = try Tag.valueOf(startTag.name(), settings)
        }
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
        registerPendingAttributes(el)
        try insertNode(el)
        if (onStack) {
            push(el)
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
        let currentTagId = currentTag?.tagId ?? .none
        let isScriptOrStyle = currentTagId == .script || currentTagId == .style
        let fosterInserts = isFosterInserts()
        if isBulkBuilding,
           !tracksSourceRanges,
           !fosterInserts,
           !isScriptOrStyle,
           let current,
           let slice = characterToken.getDataSlice() {
            if let lastText = current.childNodes.last as? TextNode {
                lastText.appendSlice(slice)
                return
            }
            let node = TextNode(slice: slice, baseUri: baseUri)
            node.treeBuilder = self
            node.parentNode = current
            current.childNodes.append(node)
            node.setSiblingIndex(current.childNodes.count - 1)
            return
        }
        @inline(__always)
        func canCoalesceSource(_ lastRange: SourceRange?, _ newRange: SourceRange?) -> Bool {
            guard let lastRange, let newRange else { return false }
            return lastRange.end == newRange.start
        }
        let node: Node
        var useSlice: ByteSlice?
        if !tracksSourceRanges {
            useSlice = characterToken.getDataSlice()
        } else if let tokenSlice = characterToken.getDataSlice() {
            useSlice = tokenSlice
        } else if let range = characterToken.sourceRange,
                  let source = doc.sourceBuffer,
                  range.isValid,
                  range.end <= source.bytes.count {
            useSlice = ByteSlice(storage: source.storage, start: range.start, end: range.end)
        } else {
            useSlice = nil
        }
        let lastChild: Node?
        if let current, !fosterInserts, isBulkBuilding {
            lastChild = current.childNodes.last
        } else {
            lastChild = nil
        }
        if let lastChild {
            if let slice = useSlice {
                if isScriptOrStyle,
                   let lastData = lastChild as? DataNode,
                   (!tracksSourceRanges || canCoalesceSource(lastData.sourceRange, characterToken.sourceRange)) {
                    if tracksSourceRanges,
                       let range = characterToken.sourceRange,
                       let source = doc.sourceBuffer,
                       lastData.extendSliceFromSourceRange(source, newRange: range) {
                        lastData.setSourceRangeEnd(range.end)
                        return
                    } else {
                        lastData.appendSlice(slice)
                        if tracksSourceRanges, let range = characterToken.sourceRange {
                            lastData.setSourceRangeEnd(range.end)
                        }
                        return
                    }
                }
                if let lastText = lastChild as? TextNode,
                   (!tracksSourceRanges || canCoalesceSource(lastText.sourceRange, characterToken.sourceRange)) {
                    if tracksSourceRanges,
                       let range = characterToken.sourceRange,
                       let source = doc.sourceBuffer,
                       lastText.extendSliceFromSourceRange(source, newRange: range) {
                        lastText.setSourceRangeEnd(range.end)
                        return
                    } else {
                        lastText.appendSlice(slice)
                        if tracksSourceRanges, let range = characterToken.sourceRange {
                            lastText.setSourceRangeEnd(range.end)
                        }
                        return
                    }
                }
            } else if !tracksSourceRanges {
                if isScriptOrStyle,
                   let lastData = lastChild as? DataNode,
                   let bytes = characterToken.getData() {
                    lastData.appendBytes(bytes)
                    return
                }
                if let lastText = lastChild as? TextNode,
                   let bytes = characterToken.getData() {
                    lastText.appendBytes(bytes)
                    return
                }
            }
        }
        // characters in script and style go in as datanodes, not text nodes
        if isScriptOrStyle {
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
        if let current, !fosterInserts, isBulkBuilding, node.parentNode == nil {
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
        node.treeBuilder = self
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
        updateStackTrackingOnPop(element)
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
        updateStackTrackingOnPush(element)
    }

    @inline(__always)
    private func resetStackTracking() {
        stackTrackingDirty = false
        stackUnknownTagIdCount = 0
        stackTagIdP.removeAll(keepingCapacity: true)
        stackTagIdButton.removeAll(keepingCapacity: true)
        if stack.isEmpty {
            return
        }
        for (index, element) in stack.enumerated() {
            updateStackTrackingOnPush(element, index: index, allowDirty: false)
        }
    }

    @inline(__always)
    private func rebuildStackTrackingIfNeeded() {
        if stackTrackingDirty {
            resetStackTracking()
        }
    }

    @inline(__always)
    private func updateStackTrackingOnPush(_ element: Element) {
        updateStackTrackingOnPush(element, index: stack.count - 1, allowDirty: true)
    }

    @inline(__always)
    private func updateStackTrackingOnPush(_ element: Element, index: Int, allowDirty: Bool) {
        if allowDirty && stackTrackingDirty {
            return
        }
        let tagId = element._tag.tagId
        if tagId == .none {
            stackUnknownTagIdCount &+= 1
            return
        }
        if tagId == .p {
            stackTagIdP.append(index)
        } else if tagId == .button {
            stackTagIdButton.append(index)
        }
    }

    @inline(__always)
    private func updateStackTrackingOnPop(_ element: Element) {
        if stackTrackingDirty {
            return
        }
        let tagId = element._tag.tagId
        if tagId == .none {
            stackUnknownTagIdCount &-= 1
            return
        }
        if tagId == .p {
            _ = stackTagIdP.popLast()
        } else if tagId == .button {
            _ = stackTagIdButton.popLast()
        }
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
        var i = stack.count
        while i > 0 {
            i &-= 1
            let el = stack[i]
            let tagId = el._tag.tagId
            if tagId != .none {
                if names.containsTagId(tagId) {
                    return i
                }
                continue
            }
            if names.contains(el.nodeNameUTF8()) {
                return i
            }
        }
        return nil
    }

    @inline(__always)
    private func lastIndexOfStackName(in names: [[UInt8]]) -> Int? {
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
            stackTrackingDirty = true
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
            stackTrackingDirty = true
        }
    }

    
    func popStackToClose(_ elName: ParsingStrings) {
        if let index = lastIndexOfStackName(in: elName) {
            stack.removeSubrange(index..<stack.count)
            stackTrackingDirty = true
        }
    }
    
    func popStackToClose(_ elNames: [UInt8]...) {
        popStackToClose(elNames)
    }
    
    func popStackToClose(_ elNames: [[UInt8]]) {
        if let index = lastIndexOfStackName(in: elNames) {
            stack.removeSubrange(index..<stack.count)
            stackTrackingDirty = true
        }
    }
    
    func popStackToClose(_ elNames: Set<[UInt8]>) {
        if let index = lastIndexOfStackName(in: elNames) {
            stack.removeSubrange(index..<stack.count)
            stackTrackingDirty = true
        }
    }
    
    func popStackToBefore(_ elName: [UInt8]) {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if (next.nodeNameUTF8() == elName) {
                break
            } else {
                stack.remove(at: pos)
                stackTrackingDirty = true
            }
        }
    }
    
    func clearStackToTableContext() {
        clearStackToContext(StackContexts.table)
    }
    
    func clearStackToTableBodyContext() {
        clearStackToContext(StackContexts.tableBody)
    }
    
    func clearStackToTableRowContext() {
        clearStackToContext(StackContexts.tableRow)
    }

    private func clearStackToContext(_ nodeNames: ParsingStrings) {
        let index: Int? = {
            var i = stack.count
            while i > 0 {
                i &-= 1
                let next = stack[i]
                let tagId = next._tag.tagId
                if tagId == .html || (tagId != .none && nodeNames.containsTagId(tagId)) {
                    return i
                }
                let nextName = next.nodeNameUTF8()
                if nodeNames.contains(nextName) || nextName == UTF8Arrays.html {
                    return i
                }
            }
            return nil
        }()
        
        guard let index else {
            stack.removeAll()
            stackTrackingDirty = true
            return
        }
        
        stack.removeSubrange(stack.index(after: index) ..< stack.endIndex)
        stackTrackingDirty = true
    }
    
    private func clearStackToContext(_ nodeNames: [UInt8]...) {
        clearStackToContext(nodeNames)
    }
    
    private func clearStackToContext(_ nodeNames: [[UInt8]]) {
        let index: Int? = {
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
            stackTrackingDirty = true
            return
        }
        
        stack.removeSubrange(stack.index(after: index) ..< stack.endIndex)
        stackTrackingDirty = true
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
        stackTrackingDirty = true
    }
    
    func replaceOnStack(_ out: Element, _ input: Element)throws {
        try stack = replaceInQueue(stack, out, input)
        stackTrackingDirty = true
    }
    
    private func replaceInQueue(_ queue: Array<Element>, _ out: Element, _ input: Element)throws->Array<Element> {
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
        let targetTagId = Token.Tag.tagIdForBytes(targetName)
        var i = stack.count
        while i > 0 {
            i &-= 1
            let el = stack[i]
            let tagId = el._tag.tagId
            if tagId != .none {
                if let targetTagId, tagId == targetTagId {
                    return true
                }
                if baseTypes.containsTagId(tagId) {
                    return false
                }
                if let extraTypes = extraTypes, extraTypes.containsTagId(tagId) {
                    return false
                }
                if targetTagId != nil {
                    continue
                }
            }
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

    
    private func inSpecificScope(_ targetNames: Set<[UInt8]>, _ baseTypes: ParsingStrings, _ extraTypes: ParsingStrings? = nil) throws -> Bool {
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
        var i = stack.count
        while i > 0 {
            i &-= 1
            let el = stack[i]
            let tagId = el._tag.tagId
            if tagId != .none {
                if targetNames.containsTagId(tagId) {
                    return true
                }
                if baseTypes.containsTagId(tagId) {
                    return false
                }
                if let extraTypes = extraTypes, extraTypes.containsTagId(tagId) {
                    return false
                }
                continue
            }
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
        if targetName == UTF8Arrays.p {
            return try inButtonScopePFast()
        }
        return try inScope(targetName, TagSets.button)
    }

    
    func inButtonScope(_ targetName: String) throws -> Bool {
        return try inButtonScope(targetName.utf8Array)
    }

    @inline(__always)
    private func inButtonScopePFast() throws -> Bool {
        rebuildStackTrackingIfNeeded()
        if stackUnknownTagIdCount == 0 {
            guard let lastP = stackTagIdP.last else {
                return false
            }
            if let lastButton = stackTagIdButton.last {
                return lastP > lastButton
            }
            return true
        }
        return try inScope(UTF8Arrays.p, TagSets.button)
    }
    
    func inTableScope(_ targetName: [UInt8]) throws -> Bool {
        return try inSpecificScope(targetName, TagSets.tableScope)
    }

    
    func inTableScope(_ targetName: String) throws -> Bool {
        return try inSpecificScope(targetName.utf8Array, TagSets.tableScope)
    }
    
    func inSelectScope(_ targetName: [UInt8]) throws -> Bool {
        let targetTagId = Token.Tag.tagIdForBytes(targetName)
        for el in stack.reversed() {
            let tagId = el._tag.tagId
            if tagId != .none {
                if let targetTagId, tagId == targetTagId {
                    return true
                }
                if !TagSets.selectScope.containsTagId(tagId) {
                    return false
                }
                if targetTagId != nil {
                    continue
                }
            }
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
        if tagId != .none {
            return TagSets.special.containsTagId(tagId)
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
            let newEl: Element = try insertStartTag(entry!.nodeNameUTF8())
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
