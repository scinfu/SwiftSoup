//
//  HtmlTreeBuilder.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

/**
 * HTML Tree Builder; creates a DOM from Tokens.
 */
class HtmlTreeBuilder: TreeBuilder {
    
    private enum TagSets {
        // tag searches
        static let inScope =  ["applet", "caption", "html", "table", "td", "th", "marquee", "object"]
        static let list = ["ol", "ul"]
        static let button = ["button"]
        static let tableScope = ["html", "table"]
        static let selectScope = ["optgroup", "option"]
        static let endTags = ["dd", "dt", "li", "option", "optgroup", "p", "rp", "rt"]
        static let titleTextarea = ["title", "textarea"]
        static let frames = ["iframe", "noembed", "noframes", "style", "xmp"]
        
        static let special: Set<String> = ["address", "applet", "area", "article", "aside", "base", "basefont", "bgsound",
                              "blockquote", "body", "br", "button", "caption", "center", "col", "colgroup", "command", "dd",
                              "details", "dir", "div", "dl", "dt", "embed", "fieldset", "figcaption", "figure", "footer", "form",
                              "frame", "frameset", "h1", "h2", "h3", "h4", "h5", "h6", "head", "header", "hgroup", "hr", "html",
                              "iframe", "img", "input", "isindex", "li", "link", "listing", "marquee", "menu", "meta", "nav",
                              "noembed", "noframes", "noscript", "object", "ol", "p", "param", "plaintext", "pre", "script",
                              "section", "select", "style", "summary", "table", "tbody", "td", "textarea", "tfoot", "th", "thead",
                              "title", "tr", "ul", "wbr", "xmp"]
    }

    private var _state: HtmlTreeBuilderState = HtmlTreeBuilderState.Initial // the current state
    private var _originalState: HtmlTreeBuilderState = HtmlTreeBuilderState.Initial // original / marked state

    private var baseUriSetFromDoc: Bool = false
    private var headElement: Element? // the current head element
    private var formElement: FormElement? // the current form element
    private var contextElement: Element? // fragment parse context -- could be null even if fragment parsing
    private var formattingElements: Array<Element?> = Array<Element?>() // active (open) formatting elements
    private var pendingTableCharacters: Array<String> =  Array<String>() // chars in table to be shifted out
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

    override func parse(_ input: String, _ baseUri: String, _ errors: ParseErrorList, _ settings: ParseSettings)throws->Document {
        _state = HtmlTreeBuilderState.Initial
        baseUriSetFromDoc = false
        return try super.parse(input, baseUri, errors, settings)
    }

    func parseFragment(_ inputFragment: String, _ context: Element?, _ baseUri: String, _ errors: ParseErrorList, _ settings: ParseSettings)throws->Array<Node> {
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
            switch context.tagName() {
                case TagSets.titleTextarea:
                    tokeniser.transition(TokeniserState.Rcdata)
                case TagSets.frames:
                    tokeniser.transition(TokeniserState.Rawtext)
                case "script":
                    tokeniser.transition(TokeniserState.ScriptData)
                case "noscript":
                    tokeniser.transition(TokeniserState.Data) // if scripting enabled, rawtext
                case "plaintext":
                    tokeniser.transition(TokeniserState.Data)
                default:
                    tokeniser.transition(TokeniserState.Data)
            }

            root = try Element(Tag.valueOf("html", settings), baseUri)
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
		currentToken = token
		return try self._state.process(token, self)
	}

	@discardableResult
    func process(_ token: Token, _ state: HtmlTreeBuilderState)throws->Bool {
        currentToken = token
        return try state.process(token, self)
    }

    func transition(_ state: HtmlTreeBuilderState) {
        self._state = state
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

    func getBaseUri() -> String {
        return baseUri
    }

    func maybeSetBaseUri(_ base: Element)throws {
        if (baseUriSetFromDoc) { // only listen to the first <base href> in parse
            return
        }

        let href: String = try base.absUrl("href")
        if (href.count != 0) { // ignore <base target> etc
            baseUri = href
            baseUriSetFromDoc = true
            try doc.setBaseUri(href) // set on the doc so doc.createElement(Tag) will get updated base, and to update all descendants
        }
    }

    func isFragmentParsing() -> Bool {
        return fragmentParsing
    }

    func error(_ state: HtmlTreeBuilderState) {
        if (errors.canAddError() && currentToken != nil) {
            errors.add(ParseError(reader.getPos(), "Unexpected token [\(currentToken!.tokenType())] when in state [\(state.rawValue)]"))
        }
    }

    @discardableResult
    func insert(_ startTag: Token.StartTag)throws->Element {
        // handle empty unknown tags
        // when the spec expects an empty tag, will directly hit insertEmpty, so won't generate this fake end tag.
        if (startTag.isSelfClosing()) {
            let el: Element = try insertEmpty(startTag)
            stack.append(el)
            tokeniser.transition(TokeniserState.Data) // handles <script />, otherwise needs breakout steps from script data
            try tokeniser.emit(emptyEnd.reset().name(el.tagName()))  // ensure we get out of whatever state we are in. emitted for yielded processing
            return el
        }
        try Validate.notNull(obj: startTag._attributes)
        let el: Element = try Element(Tag.valueOf(startTag.name(), settings), baseUri, settings.normalizeAttributes(startTag._attributes))
        try insert(el)
        return el
    }

    @discardableResult
    func insertStartTag(_ startTagName: String)throws->Element {
        let el: Element = try Element(Tag.valueOf(startTagName, settings), baseUri)
        try insert(el)
        return el
    }

    func insert(_ el: Element)throws {
        try insertNode(el)
        stack.append(el)
    }

    @discardableResult
    func insertEmpty(_ startTag: Token.StartTag)throws->Element {
        let tag: Tag = try Tag.valueOf(startTag.name(), settings)
        try Validate.notNull(obj: startTag._attributes)
        let el: Element = Element(tag, baseUri, startTag._attributes)
        try insertNode(el)
        if (startTag.isSelfClosing()) {
            if (tag.isKnownTag()) {
                if (tag.isSelfClosing()) {tokeniser.acknowledgeSelfClosingFlag()} // if not acked, promulagates error
            } else {
                // unknown tag, remember this is self closing for output
                tag.setSelfClosing()
                tokeniser.acknowledgeSelfClosingFlag() // not an distinct error
            }
        }
        return el
    }

    @discardableResult
    func insertForm(_ startTag: Token.StartTag, _ onStack: Bool)throws->FormElement {
        let tag: Tag = try Tag.valueOf(startTag.name(), settings)
        try Validate.notNull(obj: startTag._attributes)
        let el: FormElement = FormElement(tag, baseUri, startTag._attributes)
        setFormElement(el)
        try insertNode(el)
        if (onStack) {
            stack.append(el)
        }
        return el
    }

    func insert(_ commentToken: Token.Comment)throws {
        let comment: Comment = Comment(commentToken.getData(), baseUri)
        try insertNode(comment)
    }

    func insert(_ characterToken: Token.Char)throws {
        var node: Node
        // characters in script and style go in as datanodes, not text nodes
        let tagName: String? = currentElement()?.tagName()
        if (tagName=="script" || tagName=="style") {
            try Validate.notNull(obj: characterToken.getData())
            node = DataNode(characterToken.getData()!, baseUri)
        } else {
            try Validate.notNull(obj: characterToken.getData())
            node = TextNode(characterToken.getData()!, baseUri)
        }
        try currentElement()?.appendChild(node) // doesn't use insertNode, because we don't foster these; and will always have a stack.
    }

    private func insertNode(_ node: Node)throws {
        // if the stack hasn't been set up yet, elements (doctype, comments) go into the doc
        if (stack.count == 0) {
            try doc.appendChild(node)
        } else if (isFosterInserts()) {
            try insertInFosterParent(node)
        } else {
            try currentElement()?.appendChild(node)
        }

        // connect form controls to their form element
        if let n = (node as? Element) {
            if(n.tag().isFormListed()) {
                if ( formElement != nil) {
                    formElement!.addElement(n)
                }
            }
        }
    }

    @discardableResult
    func pop() -> Element {
        let size: Int = stack.count
        return stack.remove(at: size-1)
    }

    func push(_ element: Element) {
        stack.append(element)
    }

    func getStack()->Array<Element> {
        return stack
    }

    @discardableResult
    func onStack(_ el: Element) -> Bool {
        return isElementInQueue(stack, el)
    }

    private func isElementInQueue(_ queue: Array<Element?>, _ element: Element?) -> Bool {
        for pos in (0..<queue.count).reversed() {
            let next: Element? = queue[pos]
            if (next == element) {
                return true
            }
        }
        return false
    }

    func getFromStack(_ elName: String) -> Element? {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if next.nodeName() == elName {
                return next
            }
        }
        return nil
    }

    @discardableResult
    func removeFromStack(_ el: Element) -> Bool {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if (next == el) {
                stack.remove(at: pos)
                return true
            }
        }
        return false
    }

    func popStackToClose(_ elName: String) {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            stack.remove(at: pos)
            if (next.nodeName() == elName) {
                break
            }
        }
    }

    func popStackToClose(_ elNames: String...) {
		popStackToClose(elNames)
    }
	func popStackToClose(_ elNames: [String]) {
		for pos in (0..<stack.count).reversed() {
			let next: Element = stack[pos]
			stack.remove(at: pos)
            if elNames.contains(next.nodeName()) {
				break
			}
		}
	}

    func popStackToBefore(_ elName: String) {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if (next.nodeName() == elName) {
                break
            } else {
                stack.remove(at: pos)
            }
        }
    }

    func clearStackToTableContext() {
        clearStackToContext("table")
    }

    func clearStackToTableBodyContext() {
        clearStackToContext("tbody", "tfoot", "thead")
    }

    func clearStackToTableRowContext() {
        clearStackToContext("tr")
    }

    private func clearStackToContext(_ nodeNames: String...) {
        clearStackToContext(nodeNames)
    }
    private func clearStackToContext(_ nodeNames: [String]) {
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            let nextName = next.nodeName()
            if nodeNames.contains(nextName) || nextName == "html" {
                break
            } else {
                stack.remove(at: pos)
            }
        }
    }

    func aboveOnStack(_ el: Element) -> Element? {
        //assert(onStack(el), "Invalid parameter")
        onStack(el)
        for pos in (0..<stack.count).reversed() {
            let next: Element = stack[pos]
            if (next == el) {
                return stack[pos-1]
            }
        }
        return nil
    }

    func insertOnStackAfter(_ after: Element, _ input: Element)throws {
        let i: Int = stack.lastIndexOf(after)
        try Validate.isTrue(val: i != -1)
        stack.insert(input, at: i + 1 )
    }

    func replaceOnStack(_ out: Element, _ input: Element)throws {
        try stack = replaceInQueue(stack, out, input)
    }

    private func replaceInQueue(_ queue: Array<Element>, _ out: Element, _ input: Element)throws->Array<Element> {
        var queue = queue
        let i: Int = queue.lastIndexOf(out)
        try Validate.isTrue(val: i != -1)
        queue[i] = input
        return queue
    }

    private func replaceInQueue(_ queue: Array<Element?>, _ out: Element, _ input: Element)throws->Array<Element?> {
        var queue = queue
        var i: Int = -1
        for index in 0..<queue.count {
            if(out == queue[index]) {
                i = index
            }
        }
        try Validate.isTrue(val: i != -1)
        queue[i] = input
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
            let name: String = node.nodeName()
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

    private func inSpecificScope(_ targetName: String, _ baseTypes: [String], _ extraTypes: [String]? = nil)throws->Bool {
        return try inSpecificScope([targetName], baseTypes, extraTypes)
    }

    private func inSpecificScope(_ targetNames: [String], _ baseTypes: [String], _ extraTypes: [String]? = nil)throws->Bool {
        for pos in (0..<stack.count).reversed() {
            let el = stack[pos]
            let elName = el.nodeName()
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

    func inScope(_ targetNames: [String])throws->Bool {
        return try inSpecificScope(targetNames, TagSets.inScope)
    }

    func inScope(_ targetName: String, _ extras: [String]? = nil)throws->Bool {
        return try inSpecificScope(targetName, TagSets.inScope, extras)
        // todo: in mathml namespace: mi, mo, mn, ms, mtext annotation-xml
        // todo: in svg namespace: forignOjbect, desc, title
    }

    func inListItemScope(_ targetName: String)throws->Bool {
        return try inScope(targetName, TagSets.list)
    }

    func inButtonScope(_ targetName: String)throws->Bool {
        return try inScope(targetName, TagSets.button)
    }

    func inTableScope(_ targetName: String)throws->Bool {
        return try inSpecificScope(targetName, TagSets.tableScope)
    }

    func inSelectScope(_ targetName: String)throws->Bool {
        for pos in (0..<stack.count).reversed() {
            let elName = stack[pos].nodeName()
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
        pendingTableCharacters = Array<String>()
    }

    func getPendingTableCharacters()->Array<String> {
        return pendingTableCharacters
    }

    func setPendingTableCharacters(_ pendingTableCharacters: Array<String>) {
        self.pendingTableCharacters = pendingTableCharacters
    }

    /**
     11.2.5.2 Closing elements that have implied end tags<p/>
     When the steps below require the UA to generate implied end tags, then, while the current node is a dd element, a
     dt element, an li element, an option element, an optgroup element, a p element, an rp element, or an rt element,
     the UA must pop the current node off the stack of open elements.
     
     @param excludeTag If a step requires the UA to generate implied end tags but lists an element to exclude from the
     process, then the UA must perform the above steps as if that element was not in the above list.
     */

    func generateImpliedEndTags(_ excludeTag: String? = nil) {
        // Is this correct? I get the sense that something is supposed to happen here
        // even if excludeTag == nil. But the original code doesn't seem to do that. -GS
        //
        // while ((excludeTag != nil && !currentElement()!.nodeName().equals(excludeTag!)) &&
        //    StringUtil.inString(currentElement()!.nodeName(), HtmlTreeBuilder.TagSearchEndTags)) {
        //        pop()
        // }
        guard let excludeTag = excludeTag else { return }
        while true {
            let nodeName = currentElement()!.nodeName()
            guard nodeName != excludeTag else { return }
            guard TagSets.endTags.contains(nodeName) else { return }
            pop()
        }
    }

    func isSpecial(_ el: Element) -> Bool {
        // todo: mathml's mi, mo, mn
        // todo: svg's foreigObject, desc, title
        let name: String = el.nodeName()
        return TagSets.special.contains(name)
    }

    func lastFormattingElement() -> Element? {
        return formattingElements.count > 0 ? formattingElements[formattingElements.count-1] : nil
    }

    func removeLastFormattingElement() -> Element? {
        let size: Int = formattingElements.count
        if (size > 0) {
            return formattingElements.remove(at: size-1)
        } else {
            return nil
        }
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
		if(a.attributes == nil) {
			return false
		}

        return a.nodeName().equals(b.nodeName()) &&
            // a.namespace().equals(b.namespace()) &&
            a.getAttributes()!.equals(o: b.getAttributes())
        // todo: namespaces
    }

    func reconstructFormattingElements()throws {
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
            let newEl: Element = try insertStartTag(entry!.nodeName()) // todo: avoid fostering here?
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
        for pos in (0..<formattingElements.count).reversed() {
            let next: Element? = formattingElements[pos]
            if (next == el) {
                formattingElements.remove(at: pos)
                break
            }
        }
    }

    func isInActiveFormattingElements(_ el: Element) -> Bool {
        return isElementInQueue(formattingElements, el)
    }

    func getActiveFormattingElement(_ nodeName: String) -> Element? {
        for pos in (0..<formattingElements.count).reversed() {
            let next: Element? = formattingElements[pos]
            if (next == nil) { // scope marker
                break
            } else if (next!.nodeName().equals(nodeName)) {
                return next
            }
        }
        return nil
    }

    func replaceActiveFormattingElement(_ out: Element, _ input: Element)throws {
        try formattingElements = replaceInQueue(formattingElements, out, input)
    }

    func insertMarkerToFormattingElements() {
        formattingElements.append(nil)
    }

    func insertInFosterParent(_ input: Node)throws {
        let fosterParent: Element?
        let lastTable: Element? = getFromStack("table")
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



