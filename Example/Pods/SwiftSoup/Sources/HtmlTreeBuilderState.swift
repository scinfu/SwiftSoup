//
//  HtmlTreeBuilderState.swift
//  SwiftSoup
//
//  Created by Nabil Chatbi on 24/10/16.
//  Copyright © 2016 Nabil Chatbi.. All rights reserved.
//

import Foundation

protocol HtmlTreeBuilderStateProtocol {
    func process(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool
}

enum HtmlTreeBuilderState: String, HtmlTreeBuilderStateProtocol {
    case Initial
    case BeforeHtml
    case BeforeHead
    case InHead
    case InHeadNoscript
    case AfterHead
    case InBody
    case Text
    case InTable
    case InTableText
    case InCaption
    case InColumnGroup
    case InTableBody
    case InRow
    case InCell
    case InSelect
    case InSelectInTable
    case AfterBody
    case InFrameset
    case AfterFrameset
    case AfterAfterBody
    case AfterAfterFrameset
    case ForeignContent

    private static let nullString: String = "\u{0000}"

    public func equals(_ s: HtmlTreeBuilderState) -> Bool {
        return self.hashValue == s.hashValue
    }

    func process(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
        switch self {
        case .Initial:
            if (HtmlTreeBuilderState.isWhitespace(t)) {
                return true // ignore whitespace
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (t.isDoctype()) {
                // todo: parse error check on expected doctypes
                // todo: quirk state check on doctype ids
                let d: Token.Doctype = t.asDoctype()
                let doctype: DocumentType = DocumentType(
                tb.settings.normalizeTag(d.getName()), d.getPubSysKey(), d.getPublicIdentifier(), d.getSystemIdentifier(), tb.getBaseUri())
                    //tb.settings.normalizeTag(d.getName()), d.getPublicIdentifier(), d.getSystemIdentifier(), tb.getBaseUri())
                try tb.getDocument().appendChild(doctype)
                if (d.isForceQuirks()) {
                    tb.getDocument().quirksMode(Document.QuirksMode.quirks)
                }
                tb.transition(.BeforeHtml)
            } else {
                // todo: check not iframe srcdoc
                tb.transition(.BeforeHtml)
                return try tb.process(t) // re-process token
            }
            return true
        case .BeforeHtml:

            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                try tb.insertStartTag("html")
                tb.transition(.BeforeHead)
                return try tb.process(t)
            }

            if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (HtmlTreeBuilderState.isWhitespace(t)) {
                return true // ignore whitespace
            } else if (t.isStartTag() && (t.asStartTag().normalName()?.equals("html"))!) {
                try tb.insert(t.asStartTag())
                tb.transition(.BeforeHead)
            } else if (t.isEndTag() && (StringUtil.inString(t.asEndTag().normalName()!, haystack: "head", "body", "html", "br"))) {
                return try anythingElse(t, tb)
            } else if (t.isEndTag()) {
                tb.error(self)
                return false
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .BeforeHead:
            if (HtmlTreeBuilderState.isWhitespace(t)) {
                return true
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if (t.isStartTag() && (t.asStartTag().normalName()?.equals("html"))!) {
                return try HtmlTreeBuilderState.InBody.process(t, tb) // does not transition
            } else if (t.isStartTag() && (t.asStartTag().normalName()?.equals("head"))!) {
                let head: Element = try tb.insert(t.asStartTag())
                tb.setHeadElement(head)
                tb.transition(.InHead)
            } else if (t.isEndTag() && (StringUtil.inString(t.asEndTag().normalName()!, haystack: "head", "body", "html", "br"))) {
                try tb.processStartTag("head")
                return try tb.process(t)
            } else if (t.isEndTag()) {
                tb.error(self)
                return false
            } else {
                try tb.processStartTag("head")
                return try tb.process(t)
            }
            return true
        case .InHead:
            func anythingElse(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                try tb.processEndTag("head")
                return try tb.process(t)
            }

            if (HtmlTreeBuilderState.isWhitespace(t)) {
                try tb.insert(t.asCharacter())
                return true
            }
            switch (t.type) {
            case .Comment:
                try tb.insert(t.asComment())
                break
            case .Doctype:
                tb.error(self)
                return false
            case .StartTag:
                let start: Token.StartTag = t.asStartTag()
                var name: String = start.normalName()!
                if (name.equals("html")) {
                    return try HtmlTreeBuilderState.InBody.process(t, tb)
                } else if (StringUtil.inString(name, haystack: "base", "basefont", "bgsound", "command", "link")) {
                    let el: Element = try tb.insertEmpty(start)
                    // jsoup special: update base the frist time it is seen
                    if (name.equals("base") && el.hasAttr("href")) {
                        try tb.maybeSetBaseUri(el)
                    }
                } else if (name.equals("meta")) {
                    let meta: Element = try tb.insertEmpty(start)
                    // todo: charset switches
                } else if (name.equals("title")) {
                    try HtmlTreeBuilderState.handleRcData(start, tb)
                } else if (StringUtil.inString(name, haystack:"noframes", "style")) {
                    try HtmlTreeBuilderState.handleRawtext(start, tb)
                } else if (name.equals("noscript")) {
                    // else if noscript && scripting flag = true: rawtext (jsoup doesn't run script, to handle as noscript)
                    try tb.insert(start)
                    tb.transition(.InHeadNoscript)
                } else if (name.equals("script")) {
                    // skips some script rules as won't execute them

                    tb.tokeniser.transition(TokeniserState.ScriptData)
                    tb.markInsertionMode()
                    tb.transition(.Text)
                    try tb.insert(start)
                } else if (name.equals("head")) {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                let name = end.normalName()
                if (name?.equals("head"))! {
                    tb.pop()
                    tb.transition(.AfterHead)
                } else if (name != nil && StringUtil.inString(name!, haystack:"body", "html", "br")) {
                    return try anythingElse(t, tb)
                } else {
                    tb.error(self)
                    return false
                }
                break
            default:
                return try anythingElse(t, tb)
            }
            return true
        case .InHeadNoscript:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                tb.error(self)
                try tb.insert(Token.Char().data(t.toString()))
                return true
            }
            if (t.isDoctype()) {
                tb.error(self)
            } else if (t.isStartTag() && (t.asStartTag().normalName()?.equals("html"))!) {
                return try tb.process(t, .InBody)
            } else if (t.isEndTag() && (t.asEndTag().normalName()?.equals("noscript"))!) {
                tb.pop()
                tb.transition(.InHead)
            } else if (HtmlTreeBuilderState.isWhitespace(t) || t.isComment() || (t.isStartTag() && StringUtil.inString(t.asStartTag().normalName()!,
                                                                                                                       haystack: "basefont", "bgsound", "link", "meta", "noframes", "style"))) {
                return try tb.process(t, .InHead)
            } else if (t.isEndTag() && (t.asEndTag().normalName()?.equals("br"))!) {
                return try anythingElse(t, tb)
            } else if ((t.isStartTag() && StringUtil.inString(t.asStartTag().normalName()!, haystack: "head", "noscript")) || t.isEndTag()) {
                tb.error(self)
                return false
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .AfterHead:
            @discardableResult
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                try tb.processStartTag("body")
                tb.framesetOk(true)
                return try tb.process(t)
            }

            if (HtmlTreeBuilderState.isWhitespace(t)) {
                try tb.insert(t.asCharacter())
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
            } else if (t.isDoctype()) {
                tb.error(self)
            } else if (t.isStartTag()) {
                let startTag: Token.StartTag = t.asStartTag()
                let name: String = startTag.normalName()!
                if (name.equals("html")) {
                    return try tb.process(t, .InBody)
                } else if (name.equals("body")) {
                    try tb.insert(startTag)
                    tb.framesetOk(false)
                    tb.transition(.InBody)
                } else if (name.equals("frameset")) {
                    try tb.insert(startTag)
                    tb.transition(.InFrameset)
                } else if (StringUtil.inString(name, haystack: "base", "basefont", "bgsound", "link", "meta", "noframes", "script", "style", "title")) {
                    tb.error(self)
                    let head: Element = tb.getHeadElement()!
                    tb.push(head)
                    try tb.process(t, .InHead)
                    tb.removeFromStack(head)
                } else if (name.equals("head")) {
                    tb.error(self)
                    return false
                } else {
                    try anythingElse(t, tb)
                }
            } else if (t.isEndTag()) {
                if (StringUtil.inString(t.asEndTag().normalName()!, haystack: "body", "html")) {
                    try anythingElse(t, tb)
                } else {
                    tb.error(self)
                    return false
                }
            } else {
                try anythingElse(t, tb)
            }
            return true
        case .InBody:
            func anyOtherEndTag(_ t: Token, _ tb: HtmlTreeBuilder) -> Bool {
                let name: String? = t.asEndTag().normalName()
                let stack: Array<Element> = tb.getStack()
                for pos in (0..<stack.count).reversed() {
                    let node: Element = stack[pos]
                    if (name != nil && node.nodeName().equals(name!)) {
                        tb.generateImpliedEndTags(name)
                        if (!name!.equals((tb.currentElement()?.nodeName())!)) {
                            tb.error(self)
                        }
                        tb.popStackToClose(name!)
                        break
                    } else {
                        if (tb.isSpecial(node)) {
                            tb.error(self)
                            return false
                        }
                    }
                }
                return true
            }

            switch (t.type) {
            case Token.TokenType.Char:
                let c: Token.Char = t.asCharacter()
                if (c.getData() != nil && c.getData()!.equals(HtmlTreeBuilderState.nullString)) {
                    // todo confirm that check
                    tb.error(self)
                    return false
                } else if (tb.framesetOk() && HtmlTreeBuilderState.isWhitespace(c)) { // don't check if whitespace if frames already closed
                    try tb.reconstructFormattingElements()
                    try tb.insert(c)
                } else {
                    try tb.reconstructFormattingElements()
                    try tb.insert(c)
                    tb.framesetOk(false)
                }
                break
            case Token.TokenType.Comment:
                try tb.insert(t.asComment())
                break
            case Token.TokenType.Doctype:
                tb.error(self)
                return false
            case Token.TokenType.StartTag:
                let startTag: Token.StartTag = t.asStartTag()
                if let name: String = startTag.normalName() {
                    if (name.equals("a")) {
                        if (tb.getActiveFormattingElement("a") != nil) {
                            tb.error(self)
                            try tb.processEndTag("a")

                            // still on stack?
                            let remainingA: Element? = tb.getFromStack("a")
                            if (remainingA != nil) {
                                tb.removeFromActiveFormattingElements(remainingA)
                                tb.removeFromStack(remainingA!)
                            }
                        }
                        try tb.reconstructFormattingElements()
                        let a = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(a)
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartEmptyFormatters)) {
                        try tb.reconstructFormattingElements()
                        try tb.insertEmpty(startTag)
                        tb.framesetOk(false)
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartPClosers)) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                    } else if (name.equals("span")) {
                        // same as final else, but short circuits lots of checks
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    } else if (name.equals("li")) {
                        tb.framesetOk(false)
                        let stack: Array<Element> = tb.getStack()
                        for i in (0..<stack.count).reversed() {
                            let el: Element = stack[i]
                            if (el.nodeName().equals("li")) {
                                try tb.processEndTag("li")
                                break
                            }
                            if (tb.isSpecial(el) && !StringUtil.inSorted(el.nodeName(), haystack: Constants.InBodyStartLiBreakers)) {
                                break
                            }
                        }
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                    } else if (name.equals("html")) {
                        tb.error(self)
                        // merge attributes onto real html
                        let html: Element = tb.getStack()[0]
                        for attribute in startTag.getAttributes().iterator() {
                            if (!html.hasAttr(attribute.getKey())) {
                                html.getAttributes()?.put(attribute: attribute)
                            }
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartToHead)) {
                        return try tb.process(t, .InHead)
                    } else if (name.equals("body")) {
                        tb.error(self)
                        let stack: Array<Element> = tb.getStack()
                        if (stack.count == 1 || (stack.count > 2 && !stack[1].nodeName().equals("body"))) {
                            // only in fragment case
                            return false // ignore
                        } else {
                            tb.framesetOk(false)
                            let body: Element = stack[1]
                            for attribute: Attribute in startTag.getAttributes().iterator() {
                                if (!body.hasAttr(attribute.getKey())) {
                                    body.getAttributes()?.put(attribute: attribute)
                                }
                            }
                        }
                    } else if (name.equals("frameset")) {
                        tb.error(self)
                        var stack: Array<Element> = tb.getStack()
                        if (stack.count == 1 || (stack.count > 2 && !stack[1].nodeName().equals("body"))) {
                            // only in fragment case
                            return false // ignore
                        } else if (!tb.framesetOk()) {
                            return false // ignore frameset
                        } else {
                            let second: Element = stack[1]
                            if (second.parent() != nil) {
                                try second.remove()
                            }
                            // pop up to html element
                            while (stack.count > 1) {
                                stack.remove(at: stack.count-1)
                            }
                            try tb.insert(startTag)
                            tb.transition(.InFrameset)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.Headings)) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        if (tb.currentElement() != nil && StringUtil.inSorted(tb.currentElement()!.nodeName(), haystack: Constants.Headings)) {
                            tb.error(self)
                            tb.pop()
                        }
                        try tb.insert(startTag)
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartPreListing)) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                        // todo: ignore LF if next token
                        tb.framesetOk(false)
                    } else if (name.equals("form")) {
                        if (tb.getFormElement() != nil) {
                            tb.error(self)
                            return false
                        }
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insertForm(startTag, true)
                    } else if (StringUtil.inSorted(name, haystack: Constants.DdDt)) {
                        tb.framesetOk(false)
                        let stack: Array<Element> = tb.getStack()
                        for i in (1..<stack.count).reversed() {
                            let el: Element = stack[i]
                            if (StringUtil.inSorted(el.nodeName(), haystack: Constants.DdDt)) {
                                try tb.processEndTag(el.nodeName())
                                break
                            }
                            if (tb.isSpecial(el) && !StringUtil.inSorted(el.nodeName(), haystack: Constants.InBodyStartLiBreakers)) {
                                break
                            }
                        }
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                    } else if (name.equals("plaintext")) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                        tb.tokeniser.transition(TokeniserState.PLAINTEXT) // once in, never gets out
                    } else if (name.equals("button")) {
                        if (try tb.inButtonScope("button")) {
                            // close and reprocess
                            tb.error(self)
                            try tb.processEndTag("button")
                            try tb.process(startTag)
                        } else {
                            try tb.reconstructFormattingElements()
                            try tb.insert(startTag)
                            tb.framesetOk(false)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.Formatters)) {
                        try tb.reconstructFormattingElements()
                        let el: Element = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(el)
                    } else if (name.equals("nobr")) {
                        try tb.reconstructFormattingElements()
                        if (try tb.inScope("nobr")) {
                            tb.error(self)
                            try tb.processEndTag("nobr")
                            try tb.reconstructFormattingElements()
                        }
                        let el: Element = try tb.insert(startTag)
                        tb.pushActiveFormattingElements(el)
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartApplets)) {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                        tb.insertMarkerToFormattingElements()
                        tb.framesetOk(false)
                    } else if (name.equals("table")) {
                        if (try tb.getDocument().quirksMode() != Document.QuirksMode.quirks && tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insert(startTag)
                        tb.framesetOk(false)
                        tb.transition(.InTable)
                    } else if (name.equals("input")) {
                        try tb.reconstructFormattingElements()
                        let el: Element = try tb.insertEmpty(startTag)
                        if (try !el.attr("type").equalsIgnoreCase(string: "hidden")) {
                            tb.framesetOk(false)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartMedia)) {
                        try tb.insertEmpty(startTag)
                    } else if (name.equals("hr")) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.insertEmpty(startTag)
                        tb.framesetOk(false)
                    } else if (name.equals("image")) {
                        if (tb.getFromStack("svg") == nil) {
                            return try tb.process(startTag.name("img")) // change <image> to <img>, unless in svg
                        } else {
                            try tb.insert(startTag)
                        }
                    } else if (name.equals("isindex")) {
                        // how much do we care about the early 90s?
                        tb.error(self)
                        if (tb.getFormElement() != nil) {
                            return false
                        }

                        tb.tokeniser.acknowledgeSelfClosingFlag()
                        try tb.processStartTag("form")
                        if (startTag._attributes.hasKey(key: "action")) {
                            if let form: Element = tb.getFormElement() {
                                try form.attr("action", startTag._attributes.get(key: "action"))
                            }
                        }
                        try tb.processStartTag("hr")
                        try tb.processStartTag("label")
                        // hope you like english.
                        let prompt: String = startTag._attributes.hasKey(key: "prompt") ?
                            startTag._attributes.get(key: "prompt") :
                        "self is a searchable index. Enter search keywords: "

                        try tb.process(Token.Char().data(prompt))

                        // input
                        let inputAttribs: Attributes = Attributes()
                        for attr: Attribute in startTag._attributes.iterator() {
                            if (!StringUtil.inSorted(attr.getKey(), haystack: Constants.InBodyStartInputAttribs)) {
                                inputAttribs.put(attribute: attr)
                            }
                        }
                        try inputAttribs.put("name", "isindex")
                        try tb.processStartTag("input", inputAttribs)
                        try tb.processEndTag("label")
                        try tb.processStartTag("hr")
                        try tb.processEndTag("form")
                    } else if (name.equals("textarea")) {
                        try tb.insert(startTag)
                        // todo: If the next token is a U+000A LINE FEED (LF) character token, then ignore that token and move on to the next one. (Newlines at the start of textarea elements are ignored as an authoring convenience.)
                        tb.tokeniser.transition(TokeniserState.Rcdata)
                        tb.markInsertionMode()
                        tb.framesetOk(false)
                        tb.transition(.Text)
                    } else if (name.equals("xmp")) {
                        if (try tb.inButtonScope("p")) {
                            try tb.processEndTag("p")
                        }
                        try tb.reconstructFormattingElements()
                        tb.framesetOk(false)
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if (name.equals("iframe")) {
                        tb.framesetOk(false)
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if (name.equals("noembed")) {
                        // also handle noscript if script enabled
                        try HtmlTreeBuilderState.handleRawtext(startTag, tb)
                    } else if (name.equals("select")) {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                        tb.framesetOk(false)

                        let state: HtmlTreeBuilderState = tb.state()
                        if (state.equals(.InTable) || state.equals(.InCaption) || state.equals(.InTableBody) || state.equals(.InRow) || state.equals(.InCell)) {
                            tb.transition(.InSelectInTable)
                        } else {
                            tb.transition(.InSelect)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartOptions)) {
                        if (tb.currentElement() != nil && tb.currentElement()!.nodeName().equals("option")) {
                            try tb.processEndTag("option")
                        }
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartRuby)) {
                        if (try tb.inScope("ruby")) {
                            tb.generateImpliedEndTags()
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals("ruby")) {
                                tb.error(self)
                                tb.popStackToBefore("ruby") // i.e. close up to but not include name
                            }
                            try tb.insert(startTag)
                        }
                    } else if (name.equals("math")) {
                        try tb.reconstructFormattingElements()
                        // todo: handle A start tag whose tag name is "math" (i.e. foreign, mathml)
                        try tb.insert(startTag)
                        tb.tokeniser.acknowledgeSelfClosingFlag()
                    } else if (name.equals("svg")) {
                        try tb.reconstructFormattingElements()
                        // todo: handle A start tag whose tag name is "svg" (xlink, svg)
                        try tb.insert(startTag)
                        tb.tokeniser.acknowledgeSelfClosingFlag()
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartDrop)) {
                        tb.error(self)
                        return false
                    } else {
                        try tb.reconstructFormattingElements()
                        try tb.insert(startTag)
                    }
                } else {
                    try tb.reconstructFormattingElements()
                    try tb.insert(startTag)
                }
                break

            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                if let name = endTag.normalName() {
                    if (StringUtil.inSorted(name, haystack: Constants.InBodyEndAdoptionFormatters)) {
                        // Adoption Agency Algorithm.
                        for i in 0..<8 {
                            let formatEl: Element? = tb.getActiveFormattingElement(name)
                            if (formatEl == nil) {
                                return anyOtherEndTag(t, tb)
                            } else if (!tb.onStack(formatEl!)) {
                                tb.error(self)
                                tb.removeFromActiveFormattingElements(formatEl!)
                                return true
                            } else if (try !tb.inScope(formatEl!.nodeName())) {
                                tb.error(self)
                                return false
                            } else if (tb.currentElement() != formatEl!) {
                                tb.error(self)
                            }

                            var furthestBlock: Element? = nil
                            var commonAncestor: Element? = nil
                            var seenFormattingElement: Bool = false
                            let stack: Array<Element> = tb.getStack()
                            // the spec doesn't limit to < 64, but in degenerate cases (9000+ stack depth) self prevents
                            // run-aways
                            var stackSize = stack.count
                            if(stackSize > 64) {stackSize = 64}
                            for si in 0..<stackSize {
                                let el: Element = stack[si]
                                if (el == formatEl) {
                                    commonAncestor = stack[si - 1]
                                    seenFormattingElement = true
                                } else if (seenFormattingElement && tb.isSpecial(el)) {
                                    furthestBlock = el
                                    break
                                }
                            }
                            if (furthestBlock == nil) {
                                tb.popStackToClose(formatEl!.nodeName())
                                tb.removeFromActiveFormattingElements(formatEl)
                                return true
                            }

                            // todo: Let a bookmark note the position of the formatting element in the list of active formatting elements relative to the elements on either side of it in the list.
                            // does that mean: int pos of format el in list?
                            var node: Element? = furthestBlock
                            var lastNode: Element? = furthestBlock
                            for j in 0..<3 {
                                if (node != nil && tb.onStack(node!)) {
                                    node = tb.aboveOnStack(node!)
                                }
                                // note no bookmark check
                                if (node != nil && !tb.isInActiveFormattingElements(node!)) {
                                    tb.removeFromStack(node!)
                                    continue
                                } else if (node == formatEl) {
                                    break
                                }

                                let replacement: Element = try Element(Tag.valueOf(node!.nodeName(), ParseSettings.preserveCase), tb.getBaseUri())
                                // case will follow the original node (so honours ParseSettings)
                                try tb.replaceActiveFormattingElement(node!, replacement)
                                try tb.replaceOnStack(node!, replacement)
                                node = replacement

                                if (lastNode == furthestBlock) {
                                    // todo: move the aforementioned bookmark to be immediately after the node in the list of active formatting elements.
                                    // not getting how self bookmark both straddles the element above, but is inbetween here...
                                }
                                if (lastNode!.parent() != nil) {
                                    try lastNode?.remove()
                                }
                                try node!.appendChild(lastNode!)

                                lastNode = node
                            }

                            if (StringUtil.inSorted(commonAncestor!.nodeName(), haystack: Constants.InBodyEndTableFosters)) {
                                if (lastNode!.parent() != nil) {
                                    try lastNode!.remove()
                                }
                                try tb.insertInFosterParent(lastNode!)
                            } else {
                                if (lastNode!.parent() != nil) {
                                    try lastNode!.remove()
                                }
                                try commonAncestor!.appendChild(lastNode!)
                            }

                            let adopter: Element = Element(formatEl!.tag(), tb.getBaseUri())
                            adopter.getAttributes()?.addAll(incoming: formatEl!.getAttributes())
                            var childNodes: [Node] = furthestBlock!.getChildNodes()
                            for childNode: Node in childNodes {
                                try adopter.appendChild(childNode) // append will reparent. thus the clone to avoid concurrent mod.
                            }
                            try furthestBlock?.appendChild(adopter)
                            tb.removeFromActiveFormattingElements(formatEl)
                            // todo: insert the element into the list of active formatting elements at the position of the aforementioned bookmark.
                            tb.removeFromStack(formatEl!)
                            try tb.insertOnStackAfter(furthestBlock!, adopter)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyEndClosers)) {
                        if (try !tb.inScope(name)) {
                            // nothing to close
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags()
                            if (!tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if (name.equals("span")) {
                        // same as final fall through, but saves short circuit
                        return anyOtherEndTag(t, tb)
                    } else if (name.equals("li")) {
                        if (try !tb.inListItemScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if (name.equals("body")) {
                        if (try !tb.inScope("body")) {
                            tb.error(self)
                            return false
                        } else {
                            // todo: error if stack contains something not dd, dt, li, optgroup, option, p, rp, rt, tbody, td, tfoot, th, thead, tr, body, html
                            tb.transition(.AfterBody)
                        }
                    } else if (name.equals("html")) {
                        let notIgnored: Bool = try tb.processEndTag("body")
                        if (notIgnored) {
                            return try tb.process(endTag)
                        }
                    } else if (name.equals("form")) {
                        let currentForm: Element? = tb.getFormElement()
                        tb.setFormElement(nil)
                        if (try currentForm == nil || !tb.inScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags()
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            // remove currentForm from stack. will shift anything under up.
                            tb.removeFromStack(currentForm!)
                        }
                    } else if (name.equals("p")) {
                        if (try !tb.inButtonScope(name)) {
                            tb.error(self)
                            try tb.processStartTag(name) // if no p to close, creates an empty <p></p>
                            return try tb.process(endTag)
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.DdDt)) {
                        if (try !tb.inScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                        }
                    } else if (StringUtil.inSorted(name, haystack: Constants.Headings)) {
                        if (try !tb.inScope(Constants.Headings)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.generateImpliedEndTags(name)
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(Constants.Headings)
                        }
                    } else if (name.equals("sarcasm")) {
                        // *sigh*
                        return anyOtherEndTag(t, tb)
                    } else if (StringUtil.inSorted(name, haystack: Constants.InBodyStartApplets)) {
                        if (try !tb.inScope("name")) {
                            if (try !tb.inScope(name)) {
                                tb.error(self)
                                return false
                            }
                            tb.generateImpliedEndTags()
                            if (tb.currentElement() != nil && !tb.currentElement()!.nodeName().equals(name)) {
                                tb.error(self)
                            }
                            tb.popStackToClose(name)
                            tb.clearFormattingElementsToLastMarker()
                        }
                    } else if (name.equals("br")) {
                        tb.error(self)
                        try tb.processStartTag("br")
                        return false
                    } else {
                        return anyOtherEndTag(t, tb)
                    }
                } else {
                    return anyOtherEndTag(t, tb)
                }

                break
            case .EOF:
                // todo: error if stack contains something not dd, dt, li, p, tbody, td, tfoot, th, thead, tr, body, html
                // stop parsing
                break
            }
            return true
        case .Text:
            if (t.isCharacter()) {
                try tb.insert(t.asCharacter())
            } else if (t.isEOF()) {
                tb.error(self)
                // if current node is script: already started
                tb.pop()
                tb.transition(tb.originalState())
                return try tb.process(t)
            } else if (t.isEndTag()) {
                // if: An end tag whose tag name is "script" -- scripting nesting level, if evaluating scripts
                tb.pop()
                tb.transition(tb.originalState())
            }
            return true
        case .InTable:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                tb.error(self)
                var processed: Bool
                if (tb.currentElement() != nil && StringUtil.inString(tb.currentElement()!.nodeName(), haystack: "table", "tbody", "tfoot", "thead", "tr")) {
                    tb.setFosterInserts(true)
                    processed = try tb.process(t, .InBody)
                    tb.setFosterInserts(false)
                } else {
                    processed = try tb.process(t, .InBody)
                }
                return processed
            }

            if (t.isCharacter()) {
                tb.newPendingTableCharacters()
                tb.markInsertionMode()
                tb.transition(.InTableText)
                return try tb.process(t)
            } else if (t.isComment()) {
                try tb.insert(t.asComment())
                return true
            } else if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if (t.isStartTag()) {
                let startTag: Token.StartTag = t.asStartTag()
                if let name: String = startTag.normalName() {
                    if (name.equals("caption")) {
                        tb.clearStackToTableContext()
                        tb.insertMarkerToFormattingElements()
                        try tb.insert(startTag)
                        tb.transition(.InCaption)
                    } else if (name.equals("colgroup")) {
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InColumnGroup)
                    } else if (name.equals("col")) {
                        try tb.processStartTag("colgroup")
                        return try tb.process(t)
                    } else if (StringUtil.inString(name, haystack: "tbody", "tfoot", "thead")) {
                        tb.clearStackToTableContext()
                        try tb.insert(startTag)
                        tb.transition(.InTableBody)
                    } else if (StringUtil.inString(name, haystack: "td", "th", "tr")) {
                        try tb.processStartTag("tbody")
                        return try tb.process(t)
                    } else if (name.equals("table")) {
                        tb.error(self)
                        let processed: Bool = try tb.processEndTag("table")
                        if (processed) // only ignored if in fragment
                        {return try tb.process(t)}
                    } else if (StringUtil.inString(name, haystack: "style", "script")) {
                        return try tb.process(t, .InHead)
                    } else if (name.equals("input")) {
                        if (!startTag._attributes.get(key: "type").equalsIgnoreCase(string: "hidden")) {
                            return try anythingElse(t, tb)
                        } else {
                            try tb.insertEmpty(startTag)
                        }
                    } else if (name.equals("form")) {
                        tb.error(self)
                        if (tb.getFormElement() != nil) {
                            return false
                        } else {
                            try tb.insertForm(startTag, false)
                        }
                    } else {
                        return try anythingElse(t, tb)
                    }
                }
                return true // todo: check if should return processed http://www.whatwg.org/specs/web-apps/current-work/multipage/tree-construction.html#parsing-main-intable
            } else if (t.isEndTag()) {
                let endTag: Token.EndTag = t.asEndTag()
                if let name: String = endTag.normalName() {
                    if (name.equals("table")) {
                        if (try !tb.inTableScope(name)) {
                            tb.error(self)
                            return false
                        } else {
                            tb.popStackToClose("table")
                        }
                        tb.resetInsertionMode()
                    } else if (StringUtil.inString(name,
                                                   haystack: "body", "caption", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr")) {
                        tb.error(self)
                        return false
                    } else {
                        return try anythingElse(t, tb)
                    }
                } else {
                    return try anythingElse(t, tb)
                }
                return true // todo: as above todo
            } else if (t.isEOF()) {
                if (tb.currentElement() != nil && tb.currentElement()!.nodeName().equals("html")) {
                    tb.error(self)
                }
                return true // stops parsing
            }
            return try anythingElse(t, tb)
        case .InTableText:
            switch (t.type) {
            case .Char:
                let c: Token.Char = t.asCharacter()
                if (c.getData() != nil && c.getData()!.equals(HtmlTreeBuilderState.nullString)) {
                    tb.error(self)
                    return false
                } else {
                    var a = tb.getPendingTableCharacters()
                    a.append(c.getData()!)
                    tb.setPendingTableCharacters(a)
                }
                break
            default:
                // todo - don't really like the way these table character data lists are built
                if (tb.getPendingTableCharacters().count > 0) {
                    for character: String in tb.getPendingTableCharacters() {
                        if (!HtmlTreeBuilderState.isWhitespace(character)) {
                            // InTable anything else section:
                            tb.error(self)
                            if (tb.currentElement() != nil && StringUtil.inString(tb.currentElement()!.nodeName(), haystack: "table", "tbody", "tfoot", "thead", "tr")) {
                                tb.setFosterInserts(true)
                                try tb.process(Token.Char().data(character), .InBody)
                                tb.setFosterInserts(false)
                            } else {
                                try tb.process(Token.Char().data(character), .InBody)
                            }
                        } else {
                            try tb.insert(Token.Char().data(character))
                        }
                    }
                    tb.newPendingTableCharacters()
                }
                tb.transition(tb.originalState())
                return try tb.process(t)
            }
            return true
        case .InCaption:
            if (t.isEndTag() && t.asEndTag().normalName()!.equals("caption")) {
                let endTag: Token.EndTag = t.asEndTag()
                let name: String? = endTag.normalName()
                if (try name != nil && !tb.inTableScope(name!)) {
                    tb.error(self)
                    return false
                } else {
                    tb.generateImpliedEndTags()
                    if (!tb.currentElement()!.nodeName().equals("caption")) {
                        tb.error(self)
                    }
                    tb.popStackToClose("caption")
                    tb.clearFormattingElementsToLastMarker()
                    tb.transition(.InTable)
                }
            } else if ((
                t.isStartTag() && StringUtil.inString(t.asStartTag().normalName()!,
                                                      haystack: "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr") ||
                    t.isEndTag() && t.asEndTag().normalName()!.equals("table"))
                ) {
                tb.error(self)
                let processed: Bool = try tb.processEndTag("caption")
                if (processed) {
                    return try tb.process(t)
                }
            } else if (t.isEndTag() && StringUtil.inString(t.asEndTag().normalName()!,
                                                           haystack: "body", "col", "colgroup", "html", "tbody", "td", "tfoot", "th", "thead", "tr")) {
                tb.error(self)
                return false
            } else {
                return try tb.process(t, .InBody)
            }
            return true
        case .InColumnGroup:
            func anythingElse(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                let processed: Bool = try tb.processEndTag("colgroup")
                if (processed) { // only ignored in frag case
                    return try tb.process(t)
                }
                return true
            }

            if (HtmlTreeBuilderState.isWhitespace(t)) {
                try tb.insert(t.asCharacter())
                return true
            }
            switch (t.type) {
            case .Comment:
                try tb.insert(t.asComment())
                break
            case .Doctype:
                tb.error(self)
                break
            case .StartTag:
                let startTag: Token.StartTag = t.asStartTag()
                let name: String? = startTag.normalName()
                if ("html".equals(name)) {
                    return try tb.process(t, .InBody)
                } else if ("col".equals(name)) {
                    try tb.insertEmpty(startTag)
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if ("colgroup".equals(name)) {
                    if ("html".equals(tb.currentElement()?.nodeName())) { // frag case
                        tb.error(self)
                        return false
                    } else {
                        tb.pop()
                        tb.transition(.InTable)
                    }
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EOF:
                if ("html".equals(tb.currentElement()?.nodeName())) {
                    return true // stop parsing; frag case
                } else {
                    return try anythingElse(t, tb)
                }
            default:
                return try anythingElse(t, tb)
            }
            return true
        case .InTableBody:
            @discardableResult
            func exitTableBody(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                if (try !(tb.inTableScope("tbody") || tb.inTableScope("thead") || tb.inScope("tfoot"))) {
                    // frag case
                    tb.error(self)
                    return false
                }
                tb.clearStackToTableBodyContext()
                try tb.processEndTag(tb.currentElement()!.nodeName()) // tbody, tfoot, thead
                return try tb.process(t)
            }

            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                return try tb.process(t, .InTable)
            }

            switch (t.type) {
            case .StartTag:
                let startTag: Token.StartTag = t.asStartTag()
                let name: String? = startTag.normalName()
                if ("tr".equals(name)) {
                    tb.clearStackToTableBodyContext()
                    try tb.insert(startTag)
                    tb.transition(.InRow)
                } else if (StringUtil.inString(name, haystack: "th", "td")) {
                    tb.error(self)
                    try tb.processStartTag("tr")
                    return try tb.process(startTag)
                } else if (StringUtil.inString(name, haystack: "caption", "col", "colgroup", "tbody", "tfoot", "thead")) {
                    return try exitTableBody(t, tb)
                } else {
                    return try anythingElse(t, tb)
                }
                break
            case .EndTag:
                let endTag: Token.EndTag = t.asEndTag()
                let name = endTag.normalName()
                if (StringUtil.inString(name, haystack: "tbody", "tfoot", "thead")) {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self)
                        return false
                    } else {
                        tb.clearStackToTableBodyContext()
                        tb.pop()
                        tb.transition(.InTable)
                    }
                } else if ("table".equals(name)) {
                    return try exitTableBody(t, tb)
                } else if (StringUtil.inString(name, haystack: "body", "caption", "col", "colgroup", "html", "td", "th", "tr")) {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
                break
            default:
                return try anythingElse(t, tb)
            }
            return true
        case .InRow:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                return try tb.process(t, .InTable)
            }

            func handleMissingTr(_ t: Token, _ tb: TreeBuilder)throws->Bool {
                let processed: Bool = try tb.processEndTag("tr")
                if (processed) {
                    return try tb.process(t)
                } else {
                    return false
                }
            }

            if (t.isStartTag()) {
                let startTag: Token.StartTag = t.asStartTag()
                let name: String? = startTag.normalName()

                if (StringUtil.inString(name, haystack: "th", "td")) {
                    tb.clearStackToTableRowContext()
                    try tb.insert(startTag)
                    tb.transition(.InCell)
                    tb.insertMarkerToFormattingElements()
                } else if (StringUtil.inString(name, haystack: "caption", "col", "colgroup", "tbody", "tfoot", "thead", "tr")) {
                    return try handleMissingTr(t, tb)
                } else {
                    return try anythingElse(t, tb)
                }
            } else if (t.isEndTag()) {
                let endTag: Token.EndTag = t.asEndTag()
                let name: String? = endTag.normalName()

                if ("tr".equals(name)) {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self) // frag
                        return false
                    }
                    tb.clearStackToTableRowContext()
                    tb.pop() // tr
                    tb.transition(.InTableBody)
                } else if ("table".equals(name)) {
                    return try handleMissingTr(t, tb)
                } else if (StringUtil.inString(name, haystack: "tbody", "tfoot", "thead")) {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self)
                        return false
                    }
                    try tb.processEndTag("tr")
                    return try tb.process(t)
                } else if (StringUtil.inString(name, haystack: "body", "caption", "col", "colgroup", "html", "td", "th")) {
                    tb.error(self)
                    return false
                } else {
                    return try anythingElse(t, tb)
                }
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .InCell:
            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder)throws->Bool {
                return try  tb.process(t, .InBody)
            }

            func closeCell(_ tb: HtmlTreeBuilder)throws {
                if (try tb.inTableScope("td")) {
                    try tb.processEndTag("td")
                } else {
                    try tb.processEndTag("th") // only here if th or td in scope
                }
            }

            if (t.isEndTag()) {
                let endTag: Token.EndTag = t.asEndTag()
                let name: String? = endTag.normalName()

                if (StringUtil.inString(name, haystack: "td", "th")) {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self)
                        tb.transition(.InRow) // might not be in scope if empty: <td /> and processing fake end tag
                        return false
                    }
                    tb.generateImpliedEndTags()
                    if (!name!.equals(tb.currentElement()?.nodeName())) {
                        tb.error(self)
                    }
                    tb.popStackToClose(name!)
                    tb.clearFormattingElementsToLastMarker()
                    tb.transition(.InRow)
                } else if (StringUtil.inString(name, haystack: "body", "caption", "col", "colgroup", "html")) {
                    tb.error(self)
                    return false
                } else if (StringUtil.inString(name, haystack: "table", "tbody", "tfoot", "thead", "tr")) {
                    if (try !tb.inTableScope(name!)) {
                        tb.error(self)
                        return false
                    }
                    try closeCell(tb)
                    return try tb.process(t)
                } else {
                    return try anythingElse(t, tb)
                }
            } else if (t.isStartTag() &&
                StringUtil.inString(t.asStartTag().normalName(),
                                    haystack: "caption", "col", "colgroup", "tbody", "td", "tfoot", "th", "thead", "tr")) {
                if (try !(tb.inTableScope("td") || tb.inTableScope("th"))) {
                    tb.error(self)
                    return false
                }
                try closeCell(tb)
                return try tb.process(t)
            } else {
                return try anythingElse(t, tb)
            }
            return true
        case .InSelect:

            func anythingElse(_ t: Token, _ tb: HtmlTreeBuilder) -> Bool {
                tb.error(self)
                return false
            }

            switch (t.type) {
            case .Char:
                let c: Token.Char = t.asCharacter()
                if (HtmlTreeBuilderState.nullString.equals(c.getData())) {
                    tb.error(self)
                    return false
                } else {
                    try tb.insert(c)
                }
                break
            case .Comment:
                try tb.insert(t.asComment())
                break
            case .Doctype:
                tb.error(self)
                return false
            case .StartTag:
                let start: Token.StartTag = t.asStartTag()
                let name: String? = start.normalName()
                if ("html".equals(name)) {
                    return try tb.process(start, .InBody)
                } else if ("option".equals(name)) {
                    try tb.processEndTag("option")
                    try tb.insert(start)
                } else if ("optgroup".equals(name)) {
                    if ("option".equals(tb.currentElement()?.nodeName())) {
                        try tb.processEndTag("option")
                    } else if ("optgroup".equals(tb.currentElement()?.nodeName())) {
                        try tb.processEndTag("optgroup")
                    }
                    try tb.insert(start)
                } else if ("select".equals(name)) {
                    tb.error(self)
                    return try tb.processEndTag("select")
                } else if (StringUtil.inString(name, haystack: "input", "keygen", "textarea")) {
                    tb.error(self)
                    if (try !tb.inSelectScope("select")) {
                        return false // frag
                    }
                    try tb.processEndTag("select")
                    return try tb.process(start)
                } else if ("script".equals(name)) {
                    return try tb.process(t, .InHead)
                } else {
                    return anythingElse(t, tb)
                }
                break
            case .EndTag:
                let end: Token.EndTag = t.asEndTag()
                let name = end.normalName()
                if ("optgroup".equals(name)) {
                    if ("option".equals(tb.currentElement()?.nodeName()) && tb.currentElement() != nil && tb.aboveOnStack(tb.currentElement()!) != nil && "optgroup".equals(tb.aboveOnStack(tb.currentElement()!)?.nodeName())) {
                        try tb.processEndTag("option")
                    }
                    if ("optgroup".equals(tb.currentElement()?.nodeName())) {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                } else if ("option".equals(name)) {
                    if ("option".equals(tb.currentElement()?.nodeName())) {
                        tb.pop()
                    } else {
                        tb.error(self)
                    }
                } else if ("select".equals(name)) {
                    if (try !tb.inSelectScope(name!)) {
                        tb.error(self)
                        return false
                    } else {
                        tb.popStackToClose(name!)
                        tb.resetInsertionMode()
                    }
                } else {
                    return anythingElse(t, tb)
                }
                break
            case .EOF:
                if (!"html".equals(tb.currentElement()?.nodeName())) {
                    tb.error(self)
                }
                break
//            default:
//                return anythingElse(t, tb)
            }
            return true
        case .InSelectInTable:
            if (t.isStartTag() && StringUtil.inString(t.asStartTag().normalName(), haystack: "caption", "table", "tbody", "tfoot", "thead", "tr", "td", "th")) {
                tb.error(self)
                try tb.processEndTag("select")
                return try tb.process(t)
            } else if (t.isEndTag() && StringUtil.inString(t.asEndTag().normalName(), haystack: "caption", "table", "tbody", "tfoot", "thead", "tr", "td", "th")) {
                tb.error(self)
                if (try t.asEndTag().normalName() != nil &&  tb.inTableScope(t.asEndTag().normalName()!)) {
                    try tb.processEndTag("select")
                    return try (tb.process(t))
                } else {
                return false
                }
            } else {
                return try tb.process(t, .InSelect)
            }
        case .AfterBody:
            if (HtmlTreeBuilderState.isWhitespace(t)) {
                return try tb.process(t, .InBody)
            } else if (t.isComment()) {
                try tb.insert(t.asComment()) // into html node
            } else if (t.isDoctype()) {
                tb.error(self)
                return false
            } else if (t.isStartTag() && "html".equals(t.asStartTag().normalName())) {
                return try tb.process(t, .InBody)
            } else if (t.isEndTag() && "html".equals(t.asEndTag().normalName())) {
                if (tb.isFragmentParsing()) {
                    tb.error(self)
                    return false
                } else {
                    tb.transition(.AfterAfterBody)
                }
            } else if (t.isEOF()) {
                // chillax! we're done
            } else {
                tb.error(self)
                tb.transition(.InBody)
                return try tb.process(t)
            }
            return true
        case .InFrameset:

                if (HtmlTreeBuilderState.isWhitespace(t)) {
                    try tb.insert(t.asCharacter())
                } else if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype()) {
                    tb.error(self)
                    return false
                } else if (t.isStartTag()) {
                    let start: Token.StartTag = t.asStartTag()
                    let name: String? = start.normalName()
                    if ("html".equals(name)) {
                        return try tb.process(start, .InBody)
                    } else if ("frameset".equals(name)) {
                        try tb.insert(start)
                    } else if ("frame".equals(name)) {
                        try tb.insertEmpty(start)
                    } else if ("noframes".equals(name)) {
                        return try tb.process(start, .InHead)
                    } else {
                        tb.error(self)
                        return false
                    }
                } else if (t.isEndTag() && "frameset".equals(t.asEndTag().normalName())) {
                    if ("html".equals(tb.currentElement()?.nodeName())) { // frag
                        tb.error(self)
                        return false
                    } else {
                        tb.pop()
                        if (!tb.isFragmentParsing() && !"frameset".equals(tb.currentElement()?.nodeName())) {
                            tb.transition(.AfterFrameset)
                        }
                    }
                } else if (t.isEOF()) {
                    if (!"html".equals(tb.currentElement()?.nodeName())) {
                        tb.error(self)
                        return true
                    }
                } else {
                    tb.error(self)
                    return false
                }
                return true
        case .AfterFrameset:

                if (HtmlTreeBuilderState.isWhitespace(t)) {
                    try tb.insert(t.asCharacter())
                } else if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype()) {
                    tb.error(self)
                    return false
                } else if (t.isStartTag() && "html".equals(t.asStartTag().normalName())) {
                    return try tb.process(t, .InBody)
                } else if (t.isEndTag() && "html".equals(t.asEndTag().normalName())) {
                    tb.transition(.AfterAfterFrameset)
                } else if (t.isStartTag() && "noframes".equals(t.asStartTag().normalName())) {
                    return try tb.process(t, .InHead)
                } else if (t.isEOF()) {
                    // cool your heels, we're complete
                } else {
                    tb.error(self)
                    return false
                }
                return true
        case .AfterAfterBody:

                if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype() || HtmlTreeBuilderState.isWhitespace(t) || (t.isStartTag() && "html".equals(t.asStartTag().normalName()))) {
                    return try tb.process(t, .InBody)
                } else if (t.isEOF()) {
                    // nice work chuck
                } else {
                    tb.error(self)
                    tb.transition(.InBody)
                    return try tb.process(t)
                }
                return true
        case .AfterAfterFrameset:

                if (t.isComment()) {
                    try tb.insert(t.asComment())
                } else if (t.isDoctype() || HtmlTreeBuilderState.isWhitespace(t) || (t.isStartTag() && "html".equals(t.asStartTag().normalName()))) {
                    return try tb.process(t, .InBody)
                } else if (t.isEOF()) {
                    // nice work chuck
                } else if (t.isStartTag() && "noframes".equals(t.asStartTag().normalName())) {
                    return try tb.process(t, .InHead)
                } else {
                    tb.error(self)
                    return false
                }
                return true
        case .ForeignContent:
            return true
            // todo: implement. Also how do we get here?
        }

    }

    private static func isWhitespace(_ t: Token) -> Bool {
        if (t.isCharacter()) {
            let data: String? = t.asCharacter().getData()
            return isWhitespace(data)
        }
        return false
    }

    private static func isWhitespace(_ data: String?) -> Bool {
        // todo: self checks more than spec - "\t", "\n", "\f", "\r", " "
        if let data = data {
            for c in data.characters {
                if (!StringUtil.isWhitespace(c)) {
                    return false}
            }
        }
        return true
    }

    private static func handleRcData(_ startTag: Token.StartTag, _ tb: HtmlTreeBuilder)throws {
        try tb.insert(startTag)
        tb.tokeniser.transition(TokeniserState.Rcdata)
        tb.markInsertionMode()
        tb.transition(.Text)
    }

    private static func handleRawtext(_ startTag: Token.StartTag, _ tb: HtmlTreeBuilder)throws {
        try tb.insert(startTag)
        tb.tokeniser.transition(TokeniserState.Rawtext)
        tb.markInsertionMode()
        tb.transition(.Text)
    }

    // lists of tags to search through. A little harder to read here, but causes less GC than dynamic varargs.
    // was contributing around 10% of parse GC load.
    fileprivate final class Constants {
        fileprivate static let InBodyStartToHead: [String] = ["base", "basefont", "bgsound", "command", "link", "meta", "noframes", "script", "style", "title"]
        fileprivate static let InBodyStartPClosers: [String] = ["address", "article", "aside", "blockquote", "center", "details", "dir", "div", "dl",
                                                                "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "menu", "nav", "ol",
                                                                "p", "section", "summary", "ul"]
        fileprivate static let Headings: [String] = ["h1", "h2", "h3", "h4", "h5", "h6"]
        fileprivate static let InBodyStartPreListing: [String] = ["pre", "listing"]
        fileprivate static let InBodyStartLiBreakers: [String] = ["address", "div", "p"]
        fileprivate static let DdDt: [String] = ["dd", "dt"]
        fileprivate static let Formatters: [String] = ["b", "big", "code", "em", "font", "i", "s", "small", "strike", "strong", "tt", "u"]
        fileprivate static let InBodyStartApplets: [String] = ["applet", "marquee", "object"]
        fileprivate static let InBodyStartEmptyFormatters: [String] = ["area", "br", "embed", "img", "keygen", "wbr"]
        fileprivate static let InBodyStartMedia: [String] = ["param", "source", "track"]
        fileprivate static let InBodyStartInputAttribs: [String] = ["name", "action", "prompt"]
        fileprivate static let InBodyStartOptions: [String] = ["optgroup", "option"]
        fileprivate static let InBodyStartRuby: [String] = ["rp", "rt"]
        fileprivate static let InBodyStartDrop: [String] = ["caption", "col", "colgroup", "frame", "head", "tbody", "td", "tfoot", "th", "thead", "tr"]
        fileprivate static let InBodyEndClosers: [String] = ["address", "article", "aside", "blockquote", "button", "center", "details", "dir", "div",
                                                             "dl", "fieldset", "figcaption", "figure", "footer", "header", "hgroup", "listing", "menu",
                                                             "nav", "ol", "pre", "section", "summary", "ul"]
        fileprivate static let InBodyEndAdoptionFormatters: [String] = ["a", "b", "big", "code", "em", "font", "i", "nobr", "s", "small", "strike", "strong", "tt", "u"]
        fileprivate static let InBodyEndTableFosters: [String] = ["table", "tbody", "tfoot", "thead", "tr"]
    }
}
